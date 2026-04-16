# Legacy Report Inventory — Clearwater Health System

> **Generated:** 2026-04-16  
> **Scope:** All Crystal Reports (.rpt) and SSRS Reports (.rdl) in this repository  
> **Purpose:** Catalog every legacy report with data-source, complexity, and migration priority to guide the Power BI conversion effort.

---

## Inventory Summary

| Metric | Count |
|--------|-------|
| Crystal Reports (.rpt) | 2 |
| SSRS Reports (.rdl) | 2 |
| **Total Reports** | **4** |
| Supporting SQL Objects | 3 (1 view, 1 stored procedure, 1 function) |
| Data Sources | 2 (Oracle, SQL Server) |
| Active Subscriptions | 3 |

---

## Complexity Rating Scale

| Rating | Criteria |
|--------|----------|
| **Low** | Simple tabular layout, single data source, no parameters or formulas, straightforward SELECT query |
| **Medium** | Parameters, calculated fields/formulas, grouping, conditional formatting, single data source |
| **High** | Sub-reports, multiple data sources, complex business-logic formulas, stored-procedure dependencies, cascading parameters |

---

## Report Catalog

### 1. Patient Census Report

| Attribute | Detail |
|-----------|--------|
| **File** | `CrystalReports/PatientCensus.rpt` |
| **Platform** | Crystal Reports |
| **Data Source** | Oracle — `clearwater-ora-prod.hospital.local:1521/CLINICALPRD` |
| **SQL Object** | Embedded inline SQL (references `wards`, `patients` tables); also backed by `SQL/Views/vw_PatientCensus.sql` |
| **Parameters** | None (real-time snapshot) |
| **Formulas** | `LengthOfStay` — `SYSDATE - admission_date`; `WardOccupancy` — `Count(patient_id) / bed_capacity * 100` |
| **Layout** | Grouped by `ward_name`; detail rows show patient name, admission date, physician, LOS |
| **Conditional Formatting** | Ward occupancy text turns **red** when > 95% |
| **Subscription** | 3×/day (5 AM, 12 PM, 8 PM) → PDF → `nursing-supervisors@clearwaterhealth.org` |
| **Complexity** | **Medium** — grouping, two Crystal formulas, conditional formatting, but no parameters or sub-reports |
| **Migration Priority** | **P1 — High** — Most frequently distributed report (3×/day); formulas translate directly to DAX `DIVIDE` + `DATEDIFF`; good "quick win" to demonstrate Power BI value |

---

### 2. Surgical Outcomes Report

| Attribute | Detail |
|-----------|--------|
| **File** | `CrystalReports/SurgicalOutcomes.rpt` |
| **Platform** | Crystal Reports |
| **Data Source** | Oracle — `clearwater-ora-prod.hospital.local:1521/CLINICALPRD` |
| **SQL Object** | Embedded inline SQL (`surgeries LEFT JOIN complications`); also references `SQL/Functions/fn_CalculateReadmissionRisk.sql` (related logic) |
| **Parameters** | `StartDate` (Date), `EndDate` (Date) |
| **Formulas** | `ComplicationRate` — `Count(complication_id) / Count(surgery_id) * 100` |
| **Layout** | Detail rows with surgery info; **sub-report** `ComplicationDetails` linked on `surgery_id` (N+1 anti-pattern) |
| **Conditional Formatting** | None |
| **Subscription** | None (on-demand) |
| **Complexity** | **High** — Date-range parameters, sub-report with linked field (N+1 query pattern), LEFT JOIN to complications, complication-rate formula |
| **Migration Priority** | **P3 — Medium** — No active subscription; sub-report anti-pattern requires redesign as a single flattened query with DAX measures; defer until team gains Power BI experience from P1/P2 reports |

---

### 3. Daily Revenue Report

| Attribute | Detail |
|-----------|--------|
| **File** | `SSRS-Reports/RevenueCycle/DailyRevenue.rdl` |
| **Platform** | SQL Server Reporting Services (SSRS 2016) |
| **Data Source** | SQL Server — `CLEARWATER-SQL01` / `ClearwaterHealth` (Windows integrated auth) |
| **SQL Object** | `SQL/StoredProcedures/usp_GetDailyRevenue.sql` — JOINs `departments`, `charges`, `payments`, `adjustments`; groups by department; computes `charges_amount`, `payments_amount`, `net_revenue` |
| **Parameters** | `ReportDate` (DateTime, default `=Today()`) |
| **Formulas** | None (all logic in stored procedure) |
| **Layout** | 4-column Tablix: Department, Charges ($), Payments ($), Net Revenue ($); currency formatting `$#,##0.00` |
| **Conditional Formatting** | None |
| **Subscription** | Daily at 7 AM → PDF → `cfo@clearwaterhealth.org`, `finance-team@clearwaterhealth.org` (previous day's data) |
| **Complexity** | **Medium** — Single parameter, stored-procedure dependency (business logic must move to DAX), multi-table JOIN with ISNULL handling, currency formatting |
| **Migration Priority** | **P1 — High** — Executive-facing daily report; stored procedure translates cleanly to Power BI semantic model with `SUM`/`CALCULATE` DAX measures; high visibility win for CFO stakeholder |

---

### 4. Quality Metrics Report

| Attribute | Detail |
|-----------|--------|
| **File** | `SSRS-Reports/Clinical/QualityMetrics.rdl` |
| **Platform** | SQL Server Reporting Services (SSRS 2016) |
| **Data Source** | SQL Server — `CLEARWATER-SQL01` / `ClearwaterHealth` (Windows integrated auth) |
| **SQL Object** | Inline SQL against `dbo.cms_quality_metrics`; CASE expression computes `status_color` (Green/Yellow/Red based on actual vs target thresholds) |
| **Parameters** | `Period` (String — reporting period) |
| **Formulas** | SSRS `IIF` expression for conditional background color: Green → `LightGreen`, Yellow → `Yellow`, Red → `LightCoral` |
| **Layout** | Tablix with metric name, values, and status-colored background |
| **Conditional Formatting** | Cell background color driven by `status_color` field via SSRS `IIF` expression |
| **Subscription** | Monthly on 1st at 6 AM → Excel → `quality-director@clearwaterhealth.org`, `compliance@clearwaterhealth.org` |
| **Complexity** | **Medium** — Single parameter, inline SQL with CASE logic, SSRS conditional formatting expression, but no sub-reports or complex joins |
| **Migration Priority** | **P2 — High** — Regulatory/compliance report (CMS quality measures); conditional formatting maps directly to Power BI conditional formatting rules; monthly cadence allows time for validation before go-live |

---

## Supporting SQL Objects

| Object | Type | File | Used By | Migration Notes |
|--------|------|------|---------|-----------------|
| `vw_PatientCensus` | View | `SQL/Views/vw_PatientCensus.sql` | Patient Census Report | Keep as-is in Azure SQL; import into Power BI semantic model |
| `usp_GetDailyRevenue` | Stored Procedure | `SQL/StoredProcedures/usp_GetDailyRevenue.sql` | Daily Revenue Report | Refactor to a view; move aggregation logic to DAX measures (`Total Revenue`, `Net Revenue`) |
| `fn_CalculateReadmissionRisk` | Scalar Function | `SQL/Functions/fn_CalculateReadmissionRisk.sql` | Related to Surgical Outcomes | Convert scoring logic to a DAX calculated column or measure using `SWITCH`/`IF` |

---

## Data Sources

| Name | Provider | Server | Database/Service | Auth | Used By |
|------|----------|--------|------------------|------|---------|
| OracleConnection | Oracle | `clearwater-ora-prod.hospital.local:1521` | `CLINICALPRD` | Username (`REPORTS_USER`) | Crystal Reports (Patient Census, Surgical Outcomes) |
| SQLServerConnection | SQLOLEDB | `CLEARWATER-SQL01` | `ClearwaterHealth` | Windows Integrated | SSRS Reports (Daily Revenue, Quality Metrics) |

**Target:** Consolidate both sources into a single **Azure SQL Database** for the Power BI semantic model.

---

## Active Subscriptions

| Report | Schedule | Format | Recipients |
|--------|----------|--------|------------|
| Daily Revenue | Daily at 7:00 AM | PDF | CFO, Finance Team |
| Quality Metrics | Monthly on 1st at 6:00 AM | Excel | Quality Director, Compliance |
| Patient Census | 3×/day (5 AM, 12 PM, 8 PM) | PDF | Nursing Supervisors |

**Target:** Replace with Power BI App subscriptions, email subscriptions, and mobile push notifications.
