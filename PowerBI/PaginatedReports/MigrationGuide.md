# Paginated Reports Migration Guide

> **Clearwater Health System** — SSRS → Power BI Paginated Reports  
> **Audience:** Report developers migrating legacy SSRS `.rdl` files to Power BI paginated reports  
> **Related:** [`PowerBI/Reports/ConversionGuide.md`](../Reports/ConversionGuide.md) (interactive report conversion)

---

## When to Use Paginated Reports vs Interactive Reports

Power BI offers two report types. Choosing the right one is critical for a successful migration.

### Use Paginated Reports When

| Scenario | Why Paginated |
|----------|---------------|
| **Regulatory submissions** (CMS, Joint Commission) | Must produce identical PDF output every time; pixel-perfect layout required for filing |
| **Printed documents** requiring exact page breaks | Paginated reports control page size, margins, headers/footers, and orphan/widow rules |
| **Long tabular listings** (hundreds/thousands of rows) | Paginated reports render every row across multiple pages; interactive reports truncate or paginate client-side |
| **Invoices, statements, letters** with mail-merge patterns | Fixed-layout repeating sections with per-record page breaks |
| **Reports requiring signature blocks** | Fixed positioning of approval/certification areas |
| **Pixel-perfect Excel export** | Paginated reports export to Excel with precise column alignment matching the RDL layout |
| **Legacy SSRS reports** with complex formatting | Easiest migration path — the RDL format is the same |

### Use Interactive Reports When

| Scenario | Why Interactive |
|----------|----------------|
| **Exploratory analysis** — users slice, filter, drill | Interactive visuals (charts, maps, decomposition trees) can't be built in paginated reports |
| **Dashboards** with KPI cards and charts | Interactive reports support 40+ visual types; paginated reports support only tables, matrices, charts, and gauges |
| **Mobile consumption** | Interactive reports have responsive layouts and a mobile view editor |
| **Cross-filtering** between visuals | Click a chart bar to filter a table — only available in interactive reports |
| **Natural language Q&A** | Only interactive reports support the Q&A visual |
| **Real-time / streaming data** | DirectQuery and streaming datasets work only with interactive reports |
| **Self-service report authoring** by business users | Power BI Desktop is far more approachable than Report Builder |

### Clearwater Health Decision Matrix

| Legacy Report | Recommendation | Rationale |
|---------------|----------------|-----------|
| Daily Revenue (SSRS) | **Interactive** + Paginated for month-end archive | Day-to-day use benefits from slicers and drill-through; month-end PDF needs pixel-perfect layout |
| Quality Metrics (SSRS) | **Interactive** + Paginated for CMS submission | Interactive dashboard for monitoring; paginated version for regulatory filing |
| Patient Census (Crystal) | **Interactive** only | Real-time snapshot with no print/regulatory requirement |
| Surgical Outcomes (Crystal) | **Interactive** only | Exploratory analysis with date-range filtering and drill-through |
| CMS Submission | **Paginated** only | Regulatory document — must be pixel-perfect PDF |
| Joint Commission Checklist | **Paginated** only | Accreditation document — checklist format with pass/fail |
| Month-End Financial | **Paginated** only | CFO sign-off document — must print cleanly with signature blocks |

---

## SSRS RDL → Power BI Paginated Report Expression Mapping

Power BI paginated reports use the same RDL schema as SSRS, but there are important differences when connecting to a Power BI dataset instead of direct SQL.

### Data Source Changes

| SSRS (Legacy) | Power BI Paginated |
|---------------|-------------------|
| `<DataProvider>SQL</DataProvider>` | `<DataProvider>PBIDATASET</DataProvider>` |
| `<ConnectString>Data Source=CLEARWATER-SQL01;Initial Catalog=ClearwaterHealth</ConnectString>` | `<ConnectString>Data Source=powerbi://api.powerbi.com/v1.0/myorg/ClearwaterHealth;Initial Catalog=ClearwaterHealthModel</ConnectString>` |
| T-SQL queries / stored procedures | DAX `EVALUATE` queries against the semantic model |
| `EXEC dbo.usp_GetDailyRevenue @ReportDate` | `EVALUATE ADDCOLUMNS(SUMMARIZE(...), "Measure", [Measure Name])` |

### Expression Syntax (Identical)

Power BI paginated reports use the **exact same** RDL expression language as SSRS. No syntax changes required for:

| Expression Type | Example | Works in Both? |
|----------------|---------|---------------|
| Field references | `=Fields!metric_name.Value` | ✅ Identical |
| Parameters | `=Parameters!ReportDate.Value` | ✅ Identical |
| Globals | `=Globals!PageNumber`, `=Globals!TotalPages` | ✅ Identical |
| IIF | `=IIF(Fields!status.Value = "Green", "LightGreen", "Red")` | ✅ Identical |
| Switch | `=Switch(Fields!x.Value = 1, "A", Fields!x.Value = 2, "B", True, "C")` | ✅ Identical |
| Format | `=Format(Fields!amount.Value, "$#,##0.00")` | ✅ Identical |
| Aggregates | `=Sum(Fields!revenue.Value)`, `=Count(Fields!id.Value)` | ✅ Identical |
| Row number | `=RowNumber(Nothing)` | ✅ Identical |
| String functions | `=Left()`, `=Right()`, `=Len()`, `=Replace()` | ✅ Identical |
| Date functions | `=Today()`, `=Now()`, `=Year()`, `=Month()`, `=DateDiff()` | ✅ Identical |
| Conditional formatting | `=IIF(condition, "Bold", "Normal")` in Style properties | ✅ Identical |

### Key Differences

| Area | SSRS | Power BI Paginated | Migration Action |
|------|------|-------------------|-----------------|
| **Data source** | SQL Server, Oracle, ODBC, etc. | Power BI dataset (recommended) or gateway-connected SQL | Change `DataProvider` and `ConnectString`; rewrite SQL as DAX |
| **Query language** | T-SQL / PL/SQL | DAX `EVALUATE` statements | Rewrite queries using `EVALUATE`, `SUMMARIZE`, `ADDCOLUMNS` |
| **Stored procedures** | Called via `EXEC` | Not supported against PBI datasets | Move logic to DAX measures in the semantic model |
| **Embedded SQL** | Inline SELECT in RDL | Replace with DAX queries | Map SELECT columns to DAX measure/column references |
| **Shared data sources** | `.rds` / `.rsds` files on report server | Connection configured in Power BI service | Reconfigure in Power BI workspace settings |
| **Shared datasets** | `.rsd` files | Power BI shared datasets | Point to published Power BI dataset |
| **Subreports** | `<Subreport>` element | Supported but discouraged | Flatten into single dataset with DAX; use Tablix grouping |
| **Custom code** | VB.NET `<Code>` block | Supported with limitations | Test thoroughly; some .NET classes restricted |
| **Custom assemblies** | `<CodeModules>` referencing DLLs | **Not supported** | Rewrite logic in RDL expressions or DAX measures |
| **Drillthrough** | Linked reports with parameters | Supported (links to other paginated reports) | Update target report URLs to Power BI service paths |
| **Authentication** | Windows Integrated / SQL Auth | Azure AD / Service Principal | Configure gateway or dataset credentials in Power BI service |
| **Deployment** | Report Server / SSRS portal | Power BI service workspace | Upload `.rdl` via Power BI service or REST API |
| **Subscriptions** | SSRS subscription manager | Power BI subscription or Power Automate | Recreate schedules in Power BI service |

### Query Translation Examples

#### SSRS: Inline SQL with Parameters

```xml
<!-- SSRS (Legacy) -->
<Query>
  <DataSourceName>SQLServerConnection</DataSourceName>
  <CommandText>
    SELECT metric_name, actual_value, target_value,
           CASE WHEN actual_value >= target_value THEN 'Green'
                WHEN actual_value >= target_value * 0.9 THEN 'Yellow'
                ELSE 'Red' END AS status_color
    FROM dbo.cms_quality_metrics
    WHERE reporting_period = @Period
  </CommandText>
</Query>
```

#### Power BI Paginated: DAX EVALUATE

```xml
<!-- Power BI Paginated -->
<Query>
  <DataSourceName>PowerBIDataset</DataSourceName>
  <CommandType>DAX</CommandType>
  <CommandText>
    EVALUATE
    CALCULATETABLE(
      ADDCOLUMNS(
        CmsQualityMetrics,
        "StatusColor", CmsQualityMetrics[StatusColor]
      ),
      CmsQualityMetrics[reporting_period] = @Period
    )
  </CommandText>
</Query>
```

> **Key insight:** The `CASE WHEN` logic that was in the SQL query now lives in the `StatusColor` calculated column in the semantic model (see `SemanticModel/calculated-columns.dax`). The paginated report simply reads the pre-computed value.

#### SSRS: Stored Procedure Call

```xml
<!-- SSRS (Legacy) -->
<CommandText>EXEC dbo.usp_GetDailyRevenue @ReportDate</CommandText>
```

#### Power BI Paginated: DAX Equivalent

```xml
<!-- Power BI Paginated -->
<CommandType>DAX</CommandType>
<CommandText>
  EVALUATE
  ADDCOLUMNS(
    SUMMARIZE(Charges, Departments[department_name]),
    "TotalRevenue", [Total Revenue],
    "TotalPayments", [Total Payments],
    "NetRevenue", [Net Revenue]
  )
</CommandText>
```

> **Key insight:** The stored procedure's JOINs and GROUP BY are handled by the semantic model's relationships and DAX `SUMMARIZE`. The aggregation logic (`SUM`, `ISNULL`) is in DAX measures defined in `SemanticModel/measures.dax`.

---

## SSRS Conditional Formatting → Paginated Report Formatting

Conditional formatting expressions transfer directly since the expression syntax is identical:

```xml
<!-- Works in both SSRS and Power BI Paginated Reports -->
<BackgroundColor>
  =Switch(
    Fields!StatusColor.Value = "Green", "#E6F5E6",
    Fields!StatusColor.Value = "Yellow", "#FFF8E1",
    True, "#FDE7E9"
  )
</BackgroundColor>

<Color>
  =IIF(Fields!VariancePct.Value < 0, "#CC0000", "#006600")
</Color>

<FontWeight>
  =IIF(Fields!VariancePct.Value < 0, "Bold", "Normal")
</FontWeight>
```

---

## Migration Checklist

For each SSRS report being converted to a Power BI paginated report:

- [ ] **Data source** — Change `DataProvider` from `SQL` to `PBIDATASET`
- [ ] **Connection string** — Update to `powerbi://api.powerbi.com/...` endpoint
- [ ] **Queries** — Rewrite T-SQL as DAX `EVALUATE` statements
- [ ] **Stored procedures** — Ensure equivalent DAX measures exist in the semantic model
- [ ] **Parameters** — Verify parameter types and defaults still work (expression syntax is the same)
- [ ] **Expressions** — Test all `=IIF()`, `=Switch()`, `=Format()` expressions (should work unchanged)
- [ ] **Custom code** — If `<Code>` blocks exist, test in Power BI Report Builder
- [ ] **Custom assemblies** — If `<CodeModules>` exist, rewrite as RDL expressions or DAX
- [ ] **Subreports** — Flatten to Tablix grouping where possible
- [ ] **Page layout** — Verify margins, page size, headers/footers render correctly
- [ ] **Print test** — Print to PDF and compare against legacy SSRS PDF output
- [ ] **Data validation** — Compare row counts and totals between legacy and migrated versions
- [ ] **Deploy** — Upload `.rdl` to Power BI workspace
- [ ] **Subscriptions** — Recreate delivery schedules in Power BI service
- [ ] **Security** — Verify row-level security filters apply correctly through the dataset

---

## Paginated Reports in This Repository

| Report | File | Purpose | Replaces |
|--------|------|---------|----------|
| CMS Submission | [`CMSSubmission.rdl`](CMSSubmission.rdl) | Regulatory quality metrics filing | `SSRS-Reports/Clinical/QualityMetrics.rdl` (for CMS submission use case) |
| Joint Commission | [`JointCommission.rdl`](JointCommission.rdl) | Accreditation compliance checklist | New — no direct legacy equivalent |
| Month-End Financial | [`MonthEndFinancial.rdl`](MonthEndFinancial.rdl) | Monthly financial close summary | Monthly snapshot archive from `SSRS-Reports/RevenueCycle/DailyRevenue.rdl` subscription |

All three reports connect to the **Power BI semantic model** (`ClearwaterHealthModel`) rather than directly to SQL Server, ensuring a single source of truth for business logic (DAX measures) and data governance (row-level security).
