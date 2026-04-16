# Refresh Monitoring

Guidelines for monitoring Power BI dataset refresh health after migrating from Crystal Reports and SSRS to the consolidated Power BI solution.

---

## 1. Checking Refresh Status via REST API

Use the Power BI REST API to programmatically query refresh history and current status.

### Get Refresh History

```http
GET https://api.powerbi.com/v1.0/myorg/groups/{workspaceId}/datasets/{datasetId}/refreshes?$top=10
Authorization: Bearer {access_token}
```

**Response fields of interest:**

| Field            | Description                                      |
|------------------|--------------------------------------------------|
| `requestId`      | Unique identifier for the refresh operation      |
| `status`         | `Unknown`, `Completed`, `Failed`, `Disabled`     |
| `startTime`      | UTC timestamp when the refresh began             |
| `endTime`        | UTC timestamp when the refresh completed         |
| `serviceExceptionJson` | Error details if the refresh failed         |

### Get Specific Refresh Detail

```http
GET https://api.powerbi.com/v1.0/myorg/groups/{workspaceId}/datasets/{datasetId}/refreshes/{refreshId}
Authorization: Bearer {access_token}
```

### Trigger On-Demand Refresh

```http
POST https://api.powerbi.com/v1.0/myorg/groups/{workspaceId}/datasets/{datasetId}/refreshes
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "notifyOption": "MailOnFailure",
  "type": "Full"
}
```

> **Tip:** Use `"type": "Automatic"` for incremental-refresh-enabled datasets to let the service decide which partitions need refreshing.

---

## 2. Setting Up Alerts for Refresh Failures

### 2.1 Power BI Service Built-In Notifications

- In **Settings → Datasets → Scheduled Refresh**, enable **Send refresh failure notification email to** and add the BI admin distribution list.

### 2.2 Azure Monitor Integration

1. Enable **Power BI Activity Logs** in the Azure portal.
2. Create an **Azure Monitor Alert Rule** on the `RefreshCompleted` event where `status == "Failed"`.
3. Configure an **Action Group** to send notifications via email, SMS, or a webhook to Microsoft Teams / Slack.

### 2.3 Power Automate Flow

1. Use the **Power BI connector** trigger: *When a data driven refresh fails*.
2. Add actions to post a message to a Teams channel and create a ticket in your ITSM tool.

### 2.4 Custom Monitoring Script (PowerShell)

```powershell
# Poll refresh status and alert on failure
$token   = (Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api").Token
$uri     = "https://api.powerbi.com/v1.0/myorg/groups/{workspaceId}/datasets/{datasetId}/refreshes?`$top=1"
$headers = @{ Authorization = "Bearer $token" }

$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
$latest   = $response.value[0]

if ($latest.status -eq "Failed") {
    $errorMsg = $latest.serviceExceptionJson | ConvertFrom-Json
    Send-MailMessage -To "bi-admins@contoso.com" `
                     -From "powerbi-monitor@contoso.com" `
                     -Subject "Power BI Refresh Failed - $(Get-Date -Format 'yyyy-MM-dd')" `
                     -Body  "Refresh $($latest.requestId) failed.`nError: $($errorMsg.errorDescription)" `
                     -SmtpServer "smtp.contoso.com"
}
```

---

## 3. Performance Tuning Tips

### 3.1 Optimize the Data Source

| Area                  | Recommendation                                                      |
|-----------------------|---------------------------------------------------------------------|
| **Indexes**           | Ensure `modified_date` and date-filter columns are indexed.         |
| **Query Folding**     | Verify incremental refresh queries fold to native SQL.              |
| **Azure SQL Tier**    | Scale up during scheduled refresh windows, scale down after.        |
| **Connection Pooling**| Keep pool size ≥ 20 in the gateway config to avoid connection waits.|

### 3.2 Reduce Refresh Duration

- **Minimize columns:** Remove unused columns from the semantic model to reduce data volume.
- **Partition granularity:** Use `Day` granularity for fact tables. Avoid hourly unless truly needed.
- **Parallel table refresh:** Enable enhanced refresh via the XMLA endpoint:

  ```http
  POST https://api.powerbi.com/v1.0/myorg/groups/{workspaceId}/datasets/{datasetId}/refreshes
  Content-Type: application/json

  {
    "type": "Full",
    "commitMode": "transactional",
    "maxParallelism": 4,
    "objects": [
      { "table": "FactSales" },
      { "table": "FactInventory" }
    ]
  }
  ```

### 3.3 Monitor Key Metrics

Track these metrics over time to detect degradation:

| Metric                       | Target                | Source                          |
|------------------------------|-----------------------|---------------------------------|
| Total refresh duration       | < 30 minutes          | REST API `endTime - startTime`  |
| Rows processed per partition | Stable ± 10 %        | XMLA refresh trace events       |
| Gateway CPU / memory         | < 80 % peak           | On-premises data gateway monitor|
| Failed refresh rate          | 0 % (< 2 % tolerance)| Azure Monitor / refresh history |

### 3.4 Gateway Tuning

- Keep the gateway software up to date.
- Run the gateway on a dedicated VM with ≥ 8 GB RAM and 4 vCPUs.
- Enable **streaming** mode if available to reduce memory pressure.
- Stagger refresh schedules across datasets to avoid gateway saturation.

---

## 4. Troubleshooting Checklist

| Symptom                        | Likely Cause                        | Action                                     |
|--------------------------------|-------------------------------------|--------------------------------------------|
| Refresh times out               | Query doesn't fold or data too large| Verify query folding; add indexes          |
| Credential error                | OAuth token expired                 | Re-authenticate in gateway data source     |
| Gateway unreachable             | VM stopped or network issue         | Check gateway status in Power BI admin     |
| Incremental refresh not working | RangeStart/RangeEnd missing         | Confirm parameters exist in Power Query    |
| High refresh duration           | Too many partitions or full refresh | Review partition count and refresh type    |
