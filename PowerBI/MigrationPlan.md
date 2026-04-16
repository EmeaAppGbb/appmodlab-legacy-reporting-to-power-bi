# Power BI Migration Plan — Clearwater Health System

> **Generated:** 2026-04-16  
> **Source:** [ReportInventory.md](ReportInventory.md)  
> **Goal:** Migrate all legacy Crystal Reports and SSRS reports to Power BI with zero data discrepancies and improved interactivity.

---

## Prioritized Conversion Order

Reports are ordered by migration priority based on business impact, subscription frequency, stakeholder visibility, and technical complexity.

### Wave 1 — Quick Wins (Weeks 1–2)

High-value reports with straightforward conversion paths. Deliver early to build stakeholder confidence.

| # | Report | Platform | Priority | Rationale |
|---|--------|----------|----------|-----------|
| 1 | **Daily Revenue** | SSRS | P1 | Executive-facing daily report to CFO; stored procedure maps cleanly to DAX `SUM`/`CALCULATE` measures; highest stakeholder visibility |
| 2 | **Patient Census** | Crystal | P1 | Most frequently distributed (3×/day); Crystal formulas (`LengthOfStay`, `WardOccupancy`) translate directly to `DATEDIFF` + `DIVIDE` DAX; good proof-of-concept for Oracle-to-Azure SQL migration |

**Wave 1 Deliverables:**
- Azure SQL Database provisioned with consolidated views replacing `usp_GetDailyRevenue` and `vw_PatientCensus`
- Power BI semantic model with `Wards`, `Patients`, `Departments`, `Charges`, `Payments`, `Adjustments` tables
- DAX measures: `Total Revenue`, `Net Revenue`, `Occupancy %`, `Avg Length of Stay`
- Two interactive Power BI reports replacing the legacy versions
- Power BI subscriptions replacing email PDF delivery

### Wave 2 — Compliance Reports (Weeks 3–4)

Reports with regulatory importance that need careful validation before cutover.

| # | Report | Platform | Priority | Rationale |
|---|--------|----------|----------|-----------|
| 3 | **Quality Metrics** | SSRS | P2 | CMS compliance report; SSRS `IIF` conditional formatting → Power BI conditional formatting rules; monthly cadence provides a full cycle for validation before go-live |

**Wave 2 Deliverables:**
- `cms_quality_metrics` table imported into semantic model
- DAX measures: `Metric Status` (using `SWITCH` to replace SQL `CASE`), `Target Variance %`
- KPI card visuals with Green/Yellow/Red status indicators
- Trend sparklines for metric history
- Power BI subscription replacing monthly Excel email

### Wave 3 — Complex Reports (Weeks 5–6)

Reports requiring architectural changes (sub-report elimination, formula redesign).

| # | Report | Platform | Priority | Rationale |
|---|--------|----------|----------|-----------|
| 4 | **Surgical Outcomes** | Crystal | P3 | Sub-report anti-pattern (N+1) must be redesigned as a single flattened query; `ComplicationRate` formula → DAX measure; date-range parameters → Power BI slicers; no active subscription reduces urgency |

**Wave 3 Deliverables:**
- Flattened `surgeries + complications` view replacing the sub-report pattern
- `fn_CalculateReadmissionRisk` logic converted to a DAX calculated column using `SWITCH`/`IF`
- DAX measures: `Complication Rate`, `Readmission Risk Score`
- Interactive report with date-range slicers and drill-through to complication details
- Paginated report version for any regulatory submission needs

---

## Data Source Consolidation Plan

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  Oracle 12c             │     │  SQL Server 2016        │
│  CLINICALPRD            │     │  ClearwaterHealth       │
│  (Crystal Reports)      │     │  (SSRS Reports)         │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                               │
            └───────────┬───────────────────┘
                        ▼
            ┌───────────────────────┐
            │  Azure SQL Database   │
            │  ClearwaterHealth     │
            │  (Unified Source)     │
            └───────────┬───────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │  Power BI Semantic    │
            │  Model (Dataset)      │
            │  DAX Measures         │
            └───────────────────────┘
```

### Migration Steps

1. **Provision Azure SQL Database** — Create `ClearwaterHealth` in Azure
2. **Migrate Oracle tables** — ETL `wards`, `patients`, `surgeries`, `complications` from Oracle to Azure SQL
3. **Migrate SQL Server tables** — Lift-and-shift `departments`, `charges`, `payments`, `adjustments`, `cms_quality_metrics`
4. **Create consolidated views** — Replace stored procedures with views for Power BI import
5. **Validate data parity** — Row counts and aggregated totals must match across old and new sources

---

## SQL Object Conversion Plan

| Legacy Object | Type | Action | Power BI Replacement |
|---------------|------|--------|----------------------|
| `usp_GetDailyRevenue` | Stored Proc | Convert to view `vw_DailyRevenue` | DAX measures: `Total Charges = SUM(Charges[charge_amount])`, `Net Revenue = [Total Charges] - SUM(Adjustments[adjustment_amount])` |
| `vw_PatientCensus` | View | Retain in Azure SQL | Import directly; add DAX: `Occupancy % = DIVIDE(COUNT(Patients[patient_id]), SUM(Wards[bed_capacity])) * 100` |
| `fn_CalculateReadmissionRisk` | Function | Decommission | DAX calculated column: `Risk Level = SWITCH(TRUE(), [Risk Score] >= 8, "High", [Risk Score] >= 5, "Moderate", "Low")` |

---

## Formula Translation Reference

### Crystal Reports → DAX

| Crystal Formula | Report | DAX Equivalent |
|-----------------|--------|----------------|
| `SYSDATE - {patients.admission_date}` (LengthOfStay) | Patient Census | `LOS Days = DATEDIFF(Patients[admission_date], TODAY(), DAY)` |
| `Count({patients.patient_id}) / {wards.bed_capacity} * 100` (WardOccupancy) | Patient Census | `Occupancy % = DIVIDE(COUNT(Patients[patient_id]), SUM(Wards[bed_capacity])) * 100` |
| `Count({complications.complication_id}) / Count({surgeries.surgery_id}) * 100` (ComplicationRate) | Surgical Outcomes | `Complication Rate = DIVIDE(COUNTROWS(Complications), COUNTROWS(Surgeries)) * 100` |

### SSRS Expressions → DAX / Power BI

| SSRS Expression | Report | Power BI Equivalent |
|-----------------|--------|---------------------|
| `CASE WHEN actual >= target THEN 'Green' ...` | Quality Metrics | DAX: `Status = SWITCH(TRUE(), [actual_value] >= [target_value], "Green", [actual_value] >= [target_value] * 0.9, "Yellow", "Red")` |
| `=IIF(Fields!status_color.Value = "Green", "LightGreen", ...)` | Quality Metrics | Conditional formatting rule on cell background (no DAX needed) |
| `EXEC usp_GetDailyRevenue @ReportDate` | Daily Revenue | Direct import of underlying tables; DAX measures replace aggregation |

---

## Subscription Migration

| Legacy Subscription | Power BI Replacement |
|---------------------|----------------------|
| Daily Revenue → PDF email at 7 AM | Power BI email subscription (daily, PDF/PowerPoint) + dataset scheduled refresh at 5 AM |
| Quality Metrics → Excel email on 1st | Power BI email subscription (monthly) + paginated report export for Excel fidelity |
| Patient Census → PDF 3×/day | Power BI email subscription (3×/day) + real-time dashboard bookmark for nursing supervisors + mobile push notifications |

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Oracle → Azure SQL data migration introduces schema differences | Data discrepancies in Patient Census and Surgical Outcomes | Run parallel systems for 2 weeks; validate row counts and aggregation totals daily |
| `usp_GetDailyRevenue` ISNULL logic behaves differently than DAX BLANK handling | Net Revenue calculations may differ | Write validation queries comparing stored-proc output vs DAX output for 30 days of historical data |
| Sub-report elimination changes Surgical Outcomes report behavior | Users accustomed to drill-into sub-report may find new UX unfamiliar | Provide drill-through page in Power BI that mirrors the sub-report content; conduct user training |
| Crystal Reports `WhilePrintingRecords` formulas (if present in other reports) have no direct DAX equivalent | Complex running-total logic may not convert cleanly | Use `CALCULATE` with `FILTER(ALL(...))` pattern; test edge cases with sample data |
| Row-level security scope differs between legacy per-report security and centralized Power BI RLS | Users may see more or less data than expected | Map all existing security rules to DAX RLS filters; validate with test accounts for each role |

---

## Validation Checklist

For each migrated report, complete the following before decommissioning the legacy version:

- [ ] Power BI report renders with identical data for the same parameters/date range
- [ ] All totals and subtotals match to 2 decimal places
- [ ] Conditional formatting (colors, thresholds) matches legacy behavior
- [ ] Parameters/slicers produce the same filtering effect
- [ ] Subscription emails deliver on schedule with correct content
- [ ] Row-level security restricts data appropriately per role
- [ ] Mobile layout is readable on tablet and phone
- [ ] Stakeholder sign-off obtained

---

## Timeline Summary

```
Week 1–2:  ████████████████  Wave 1 — Daily Revenue + Patient Census
Week 3–4:  ████████████████  Wave 2 — Quality Metrics
Week 5–6:  ████████████████  Wave 3 — Surgical Outcomes
Week 7:    ████████          Parallel validation (all reports)
Week 8:    ████████          Legacy decommission + stakeholder sign-off
```

**Total estimated duration:** 8 weeks (with 2-week validation buffer)
