# Subscription Migration — Legacy to Power BI

> **Clearwater Health System** — SSRS/Crystal email subscriptions → Power BI subscriptions  
> **Source:** [`Subscriptions/SubscriptionConfig.xml`](../../Subscriptions/SubscriptionConfig.xml)  
> **Related:** [`PowerBI/Security/role-mappings.md`](../Security/role-mappings.md) (RLS enforcement per subscriber)

---

## Migration Summary

| Legacy Subscription | Schedule | Recipients | Power BI Equivalent |
|---|---|---|---|
| Daily Revenue (SSRS) | Daily 7:00 AM | CFO, Finance Team | Power BI email subscription + mobile push |
| Quality Metrics (SSRS) | Monthly 1st 6:00 AM | Quality Director, Compliance | Power BI email subscription |
| Patient Census (Crystal) | 3×/day (5 AM, 12 PM, 8 PM) | Nursing Supervisors | Power BI email subscription + mobile push |

**Key improvement:** Power BI subscriptions respect Row-Level Security. Each subscriber receives only the data visible under their assigned RLS role — unlike legacy SSRS subscriptions that delivered unfiltered data to all recipients.

---

## Subscription 1: Daily Revenue → CFO & Finance Team

### Legacy Configuration (from SubscriptionConfig.xml)

```xml
<Subscription>
  <ReportName>Daily Revenue</ReportName>
  <Schedule>Daily at 7:00 AM</Schedule>
  <Format>PDF</Format>
  <Recipients>
    <Email>cfo@clearwaterhealth.org</Email>
    <Email>finance-team@clearwaterhealth.org</Email>
  </Recipients>
  <Parameters>
    <Parameter Name="ReportDate" Value="=Today()-1"/>
  </Parameters>
</Subscription>
```

### Power BI Subscription Configuration

| Setting | Value |
|---|---|
| **Report** | Daily Revenue (`PowerBI/Reports/DailyRevenue.json`) |
| **Type** | Email subscription |
| **Schedule** | Daily, 7:00 AM Eastern |
| **Start date** | Aligned with SSRS decommission date |
| **Time zone** | Eastern Time (matches legacy SSRS server) |
| **Subject line** | `Daily Revenue Report — {{date}}` |
| **Include preview image** | Yes |
| **Attachment format** | PDF (matches legacy format) |
| **Page** | Daily Revenue Summary |

### Subscriber Mapping

| Recipient | RLS Role | Data Visible | Legacy Behavior |
|---|---|---|---|
| `cfo@clearwaterhealth.org` | ExecutiveRole | All departments — full revenue | Same data (SSRS had no RLS; CFO saw everything) |
| `finance-team@clearwaterhealth.org` | DepartmentRole | Department-scoped revenue | **Changed** — legacy delivered all departments; now each member sees only their department |

### Parameter Migration

The legacy SSRS `@ReportDate = Today()-1` parameter is replaced by the Power BI date slicer default:

- **Legacy:** SSRS passed `@ReportDate` as previous day to stored procedure `usp_GetDailyRevenue`
- **Power BI:** The Calendar date slicer defaults to the current date. Scheduled refresh at 6:00 AM ensures previous day's data is loaded before the 7:00 AM subscription fires
- **Dataset refresh:** Schedule dataset refresh at 6:00 AM daily (1 hour before subscription delivery)

### Additional Subscribers (New)

| Recipient | RLS Role | Rationale |
|---|---|---|
| `vp-finance@clearwaterhealth.org` | ExecutiveRole | VP Finance requested daily delivery; previously accessed SSRS on-demand |
| Department managers (via DepartmentRole) | DepartmentRole | Self-service subscription — each manager subscribes and sees only their department |

---

## Subscription 2: Quality Metrics → Compliance (Monthly)

### Legacy Configuration (from SubscriptionConfig.xml)

```xml
<Subscription>
  <ReportName>Quality Metrics</ReportName>
  <Schedule>Monthly on 1st at 6:00 AM</Schedule>
  <Format>Excel</Format>
  <Recipients>
    <Email>quality-director@clearwaterhealth.org</Email>
    <Email>compliance@clearwaterhealth.org</Email>
  </Recipients>
</Subscription>
```

### Power BI Subscription Configuration

| Setting | Value |
|---|---|
| **Report** | CMS Quality Metrics (`PowerBI/Reports/QualityMetrics.json`) |
| **Type** | Email subscription |
| **Schedule** | Monthly, 1st of each month, 6:00 AM Eastern |
| **Time zone** | Eastern Time |
| **Subject line** | `CMS Quality Metrics — {{month}} {{year}}` |
| **Include preview image** | Yes |
| **Attachment format** | PDF (see note below on Excel) |
| **Page** | Quality Dashboard |

### Excel Export Note

The legacy SSRS subscription delivered an Excel file. Power BI email subscriptions support PDF and PowerPoint attachments natively. For Excel delivery:

- **Option A (recommended):** Use the paginated report version (`PowerBI/PaginatedReports/CMSSubmission.rdl`) which supports native Excel export via paginated report subscriptions
- **Option B:** Use Power BI REST API with `ExportToFile` endpoint to generate Excel and deliver via Power Automate flow
- **Option C:** Recipients use the "Export to Excel" button in the interactive report (self-service)

### Subscriber Mapping

| Recipient | RLS Role | Data Visible | Legacy Behavior |
|---|---|---|---|
| `quality-director@clearwaterhealth.org` | ExecutiveRole | All metrics, all periods | Same data (SSRS had no metric-level filtering) |
| `compliance@clearwaterhealth.org` | ExecutiveRole | All metrics, all periods | Same data |

### Supplemental Paginated Report Subscription

For regulatory filing purposes, also configure a subscription for the paginated CMS Submission report:

| Setting | Value |
|---|---|
| **Report** | CMS Submission (`PowerBI/PaginatedReports/CMSSubmission.rdl`) |
| **Type** | Email subscription (paginated report) |
| **Schedule** | Monthly, 1st of each month, 6:30 AM Eastern |
| **Attachment format** | Excel (native paginated report export) |
| **Recipients** | `compliance@clearwaterhealth.org` |

---

## Subscription 3: Patient Census → Nursing Supervisors (3×/Day)

### Legacy Configuration (from SubscriptionConfig.xml)

```xml
<Subscription>
  <ReportName>Patient Census</ReportName>
  <Schedule>Daily at 5:00 AM, 12:00 PM, 8:00 PM</Schedule>
  <Format>PDF</Format>
  <Recipients>
    <Email>nursing-supervisors@clearwaterhealth.org</Email>
  </Recipients>
</Subscription>
```

### Power BI Subscription Configuration

Power BI subscriptions support up to a maximum frequency. To replicate the 3×/day cadence, create three separate subscriptions:

#### Subscription 3a — Morning Census (Shift Change)

| Setting | Value |
|---|---|
| **Report** | Patient Census (`PowerBI/Reports/PatientCensus.json`) |
| **Type** | Email subscription |
| **Schedule** | Daily, 5:00 AM Eastern |
| **Subject line** | `Patient Census — Morning Update {{date}}` |
| **Attachment format** | PDF |

#### Subscription 3b — Midday Census

| Setting | Value |
|---|---|
| **Report** | Patient Census (`PowerBI/Reports/PatientCensus.json`) |
| **Type** | Email subscription |
| **Schedule** | Daily, 12:00 PM Eastern |
| **Subject line** | `Patient Census — Midday Update {{date}}` |
| **Attachment format** | PDF |

#### Subscription 3c — Evening Census (Shift Change)

| Setting | Value |
|---|---|
| **Report** | Patient Census (`PowerBI/Reports/PatientCensus.json`) |
| **Type** | Email subscription |
| **Schedule** | Daily, 8:00 PM Eastern |
| **Subject line** | `Patient Census — Evening Update {{date}}` |
| **Attachment format** | PDF |

### Subscriber Mapping

| Recipient | RLS Role | Data Visible | Legacy Behavior |
|---|---|---|---|
| `nursing-supervisors@clearwaterhealth.org` | ExecutiveRole | All wards, all patients | Same data — nursing supervisors need full ward visibility for staffing |

### Dataset Refresh Alignment

The Patient Census report requires fresh data before each subscription delivery:

| Refresh | Time | Purpose |
|---|---|---|
| Refresh 1 | 4:30 AM | Prepare data for 5:00 AM morning subscription |
| Refresh 2 | 11:30 AM | Prepare data for 12:00 PM midday subscription |
| Refresh 3 | 7:30 PM | Prepare data for 8:00 PM evening subscription |

Configure scheduled dataset refresh in Power BI Service → Dataset Settings → Scheduled Refresh with these three time slots.

---

## Mobile Push Notification Setup

Power BI mobile app push notifications provide real-time alerts — a new capability not available in the legacy SSRS/Crystal environment.

### Configuring Data-Driven Alerts

| Alert | Report | Condition | Recipients | Rationale |
|---|---|---|---|---|
| High occupancy | Patient Census | Occupancy Percent > 95% | `nursing-supervisors@clearwaterhealth.org` | Immediate notification when any ward exceeds 95% occupancy — replaces the red conditional formatting in the legacy Crystal report |
| Revenue anomaly | Daily Revenue | Net Revenue < $50,000 (daily threshold) | `cfo@clearwaterhealth.org` | Alert CFO when daily net revenue drops below expected floor |
| Quality alert | Quality Metrics | Any metric status = "Red" | `quality-director@clearwaterhealth.org`, `compliance@clearwaterhealth.org` | Immediate notification when a CMS quality metric falls below target |
| Complication spike | Surgical Outcomes | Complication Rate > 10% | `cmo@clearwaterhealth.org` | Alert CMO when surgical complication rate exceeds threshold |

### Alert Configuration Steps

1. **Open the report** in Power BI mobile app or Power BI Service
2. **Navigate to the tile** (card visual) you want to set an alert on
3. **Select the bell icon** (🔔) → Set Alert
4. **Configure the threshold** (e.g., Occupancy Percent > 95)
5. **Set notification frequency** — "At most once an hour" for operational alerts, "At most once a day" for summary alerts
6. **Enable push notifications** in the Power BI mobile app settings
7. **Optionally enable email notifications** as a fallback channel

### Power Automate Integration

For advanced notification workflows beyond built-in alerts:

| Flow | Trigger | Action | Use Case |
|---|---|---|---|
| Census escalation | Occupancy > 95% sustained for 2+ hours | Send Teams message to Bed Management channel | Escalate persistent overcrowding to bed management team |
| Revenue exception | Net Revenue deviation > 20% from 30-day average | Create ServiceNow ticket + email CFO | Trigger investigation workflow for significant revenue variances |
| Compliance deadline | 5 days before CMS submission due date | Email compliance team with attached paginated report | Automated reminder with pre-generated regulatory report |

---

## Migration Checklist

- [ ] Create three dataset refresh schedules (4:30 AM, 11:30 AM, 7:30 PM) for Patient Census
- [ ] Create one dataset refresh schedule (6:00 AM) for Daily Revenue / Quality Metrics
- [ ] Configure Daily Revenue email subscription (7:00 AM daily) for CFO and Finance Team
- [ ] Configure Quality Metrics email subscription (1st of month, 6:00 AM) for Quality Director and Compliance
- [ ] Configure CMS Submission paginated report subscription (1st of month, 6:30 AM) for Compliance — Excel format
- [ ] Configure three Patient Census email subscriptions (5:00 AM, 12:00 PM, 8:00 PM) for Nursing Supervisors
- [ ] Set up data-driven alert for ward occupancy > 95% on Patient Census
- [ ] Set up data-driven alert for quality metrics status = "Red"
- [ ] Set up data-driven alert for revenue anomaly on Daily Revenue
- [ ] Set up data-driven alert for complication rate > 10% on Surgical Outcomes
- [ ] Install Power BI mobile app for key stakeholders (CFO, nursing supervisors, quality director)
- [ ] Enable push notifications in mobile app settings for each stakeholder
- [ ] Test each subscription delivery — verify RLS filters data correctly per subscriber
- [ ] Validate PDF attachment formatting matches legacy SSRS/Crystal output
- [ ] Run parallel delivery (legacy + Power BI) for 2 weeks before decommissioning legacy subscriptions
- [ ] Decommission legacy SSRS subscriptions after validation period
- [ ] Document Power Automate flows for escalation workflows
