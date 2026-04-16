# Formula & Expression Conversion Guide

> **Purpose:** Document every formula/expression translation from Crystal Reports and SSRS to DAX for the four migrated reports.
> **Semantic Model:** `PowerBI/SemanticModel/` (measures.dax, calculated-columns.dax)

---

## Translation Pattern Reference

| Legacy Pattern | DAX Equivalent | Notes |
|---|---|---|
| Crystal `WhilePrintingRecords` | *(not needed)* | DAX has no multi-pass evaluation; columns materialize at refresh, measures evaluate at query time |
| Crystal `SYSDATE` | `TODAY()` | Oracle current date → DAX today |
| Crystal date subtraction | `DATEDIFF(start, end, DAY)` | Oracle date arithmetic returns days; DAX requires explicit unit |
| Crystal `Count({field})` in group | `COUNTROWS(Table)` | DAX respects filter context from row grouping automatically |
| Crystal `RunningTotal` | `CALCULATE(SUM(...), FILTER(ALL(Calendar), ...))` | Cumulative sum via Calendar filter |
| Crystal sub-report (linked field) | Relationship + inline visual | Eliminates N+1 query pattern |
| SSRS `=Fields!X.Value` | Column/measure binding in visual | Direct mapping to visual data roles |
| SSRS `=Parameters!X.Value` | Slicer on column | Parameters become slicers bound to dimension columns |
| SSRS `=Today()` default | Slicer default = today | Date slicer with relative date default |
| SSRS `=IIF(cond, true, false)` | Power BI conditional formatting rules | Or DAX `IF()` for calculated columns |
| SSRS `CASE WHEN` (in SQL) | `SWITCH(TRUE(), ...)` | Standard DAX pattern for evaluated CASE |
| SQL `ISNULL(x, 0)` | *(implicit)* | DAX `SUM`/`DIVIDE` treats BLANK as 0 in arithmetic |
| SQL `NULLIF(x, 0)` | `DIVIDE(num, denom)` | DAX `DIVIDE` has built-in safe division (returns BLANK for 0 denominator) |

---

## Report 1: Patient Census

**Source:** `CrystalReports/PatientCensus.rpt` → `PowerBI/Reports/PatientCensus.json`

### Formula: LengthOfStay

| | Detail |
|---|---|
| **Crystal** | `WhilePrintingRecords; SYSDATE - {patients.admission_date}` |
| **DAX Calculated Column** | `Patients[LengthOfStay] = DATEDIFF(Patients[admission_date], IF(ISBLANK(Patients[discharge_date]), TODAY(), Patients[discharge_date]), DAY)` |
| **DAX Measure** | `Average Length of Stay = AVERAGE(Patients[LengthOfStay])` |
| **Translation Notes** | Crystal's `SYSDATE` → `TODAY()`. Crystal date subtraction (returns fractional days) → `DATEDIFF(..., DAY)` returns whole days. `WhilePrintingRecords` directive is not needed in DAX — calculated columns materialize at refresh. Added `IF(ISBLANK(...))` to handle still-admitted patients (discharge_date is NULL). |

### Formula: WardOccupancy

| | Detail |
|---|---|
| **Crystal** | `Count({patients.patient_id}) / {wards.bed_capacity} * 100` |
| **DAX Measure** | `Occupancy Percent = DIVIDE([Current Patient Count], SUM(Wards[bed_capacity])) * 100` |
| **Translation Notes** | Crystal `Count()` evaluated within the group context (ward). DAX `DIVIDE` + `COUNTROWS` respects the filter context from matrix row grouping on `Wards[ward_name]`, producing the same per-ward result. `DIVIDE` provides safe division (returns BLANK if bed_capacity is 0). |

### Conditional Formatting: Red > 95% Occupancy

| | Detail |
|---|---|
| **Crystal** | `GroupHeader → Field WardOccupancy: Color="Red" Condition="WardOccupancy > 95"` |
| **Power BI** | Conditional formatting rule on `Occupancy Percent` measure: if value > 95 → foreground `#E81123` (red), background `#FDE7E9`, bold. Also added amber warning at 85–95% (enhancement). |
| **Translation Notes** | Crystal applies color at the field level in the GroupHeader section. Power BI applies conditional formatting rules on the matrix visual's value cells. The rule is configured in the visual's conditional formatting settings, bound to the measure value. |

---

## Report 2: Daily Revenue

**Source:** `SSRS-Reports/RevenueCycle/DailyRevenue.rdl` → `PowerBI/Reports/DailyRevenue.json`

### Parameter: @ReportDate

| | Detail |
|---|---|
| **SSRS** | `<ReportParameter Name="ReportDate"><DataType>DateTime</DataType><DefaultValue>=Today()</DefaultValue></ReportParameter>` |
| **Power BI** | Calendar date slicer with default = today |
| **Translation Notes** | SSRS parameter `=Parameters!ReportDate.Value` was passed to `EXEC usp_GetDailyRevenue @ReportDate`. In Power BI, the Calendar slicer applies a filter context to all DAX measures — no explicit parameter passing needed. |

### Stored Procedure: usp_GetDailyRevenue → DAX Measures

| SP Column | SSRS Expression | DAX Measure | Format |
|---|---|---|---|
| `SUM(c.charge_amount)` | `=Fields!ChargesAmount.Value` | `Total Revenue = SUM(Charges[charge_amount])` | `$#,##0.00` |
| `SUM(p.payment_amount)` | `=Fields!PaymentsAmount.Value` | `Total Payments = SUM(Payments[payment_amount])` | `$#,##0.00` |
| `charges - ISNULL(adj, 0)` | `=Fields!NetRevenue.Value` | `Net Revenue = [Total Revenue] - [Total Adjustments]` | `$#,##0.00` |
| `department_name` | `=Fields!Department.Value` | `Departments[department_name]` column | — |

**Translation Notes:**
- The stored procedure's `ISNULL(adj.adjustment_amount, 0)` is not needed in DAX — `SUM` treats BLANK (NULL equivalent) as 0 in arithmetic.
- The SP's `GROUP BY department_name` is replaced by the table visual's row grouping on `Departments[department_name]`.
- Currency format `$#,##0.00` is preserved from the SSRS Textbox `<Format>` property.

### Enhancement: Drill-Through

| | Detail |
|---|---|
| **SSRS** | No drill-through capability in original report |
| **Power BI** | Department Detail drill-through page. Right-click any department row → navigate to detail page filtered by `Departments[department_name]`. Shows daily breakdown with trend line. |

---

## Report 3: Quality Metrics

**Source:** `SSRS-Reports/Clinical/QualityMetrics.rdl` → `PowerBI/Reports/QualityMetrics.json`

### Parameter: @Period

| | Detail |
|---|---|
| **SSRS** | `<ReportParameter Name="Period"><DataType>String</DataType><Prompt>Reporting Period</Prompt></ReportParameter>` |
| **Power BI** | Dropdown slicer on `CmsQualityMetrics[reporting_period]` |
| **Translation Notes** | SSRS passed `@Period` to the inline SQL query's `WHERE reporting_period = @Period`. In Power BI, the slicer applies filter context to all visuals on the page. |

### SQL CASE → DAX SWITCH (StatusColor)

| | Detail |
|---|---|
| **SQL (inline in SSRS)** | `CASE WHEN actual_value >= target_value THEN 'Green' WHEN actual_value >= target_value * 0.9 THEN 'Yellow' ELSE 'Red' END AS status_color` |
| **DAX Calculated Column** | `CmsQualityMetrics[StatusColor] = SWITCH(TRUE(), CmsQualityMetrics[actual_value] >= CmsQualityMetrics[target_value], "Green", CmsQualityMetrics[actual_value] >= CmsQualityMetrics[target_value] * 0.9, "Yellow", "Red")` |
| **Translation Notes** | SQL `CASE WHEN ... THEN ... ELSE ... END` → DAX `SWITCH(TRUE(), ...)`. The `SWITCH(TRUE(), ...)` pattern evaluates conditions top-to-bottom, returning the first TRUE match — the standard DAX equivalent of evaluated `CASE WHEN`. |

### SSRS IIF → Power BI Conditional Formatting

| | Detail |
|---|---|
| **SSRS** | `=IIF(Fields!status_color.Value = "Green", "LightGreen", IIF(Fields!status_color.Value = "Yellow", "Yellow", "LightCoral"))` |
| **Power BI** | Rules-based conditional formatting on `StatusColor` column: `Green` → background `#90EE90` (LightGreen), `Yellow` → background `#FFFF00`, `Red` → background `#F08080` (LightCoral) |
| **Translation Notes** | SSRS nested `IIF()` expressions for cell background color are replaced by Power BI's built-in conditional formatting rules. No DAX is needed — the rules are configured in the visual's Format pane → Conditional formatting → Background color → Rules. The rules bind directly to the `StatusColor` column value. |

### Enhancement: Trend Sparklines

| | Detail |
|---|---|
| **SSRS** | No trending capability in original report |
| **Power BI** | Line chart showing `actual_value` over `reporting_period` per metric. Can also be configured as inline sparklines within a matrix visual (Power BI Desktop → Analytics pane → Sparklines). |

### New Aggregate Measures

| DAX Measure | Purpose |
|---|---|
| `Metrics Meeting Target` | Count of metrics with StatusColor = "Green" |
| `Metrics At Warning` | Count of metrics with StatusColor = "Yellow" |
| `Metrics Below Target` | Count of metrics with StatusColor = "Red" |
| `Quality Score Percent` | `DIVIDE([Metrics Meeting Target], COUNTROWS(CmsQualityMetrics)) * 100` |
| `Average Target Variance Pct` | `AVERAGE(CmsQualityMetrics[TargetVariancePct])` |

---

## Report 4: Surgical Outcomes

**Source:** `CrystalReports/SurgicalOutcomes.rpt` → `PowerBI/Reports/SurgicalOutcomes.json`

### Parameters: StartDate / EndDate

| | Detail |
|---|---|
| **Crystal** | `<Parameter Name="StartDate" Type="Date" Prompt="Start Date"/>`, `<Parameter Name="EndDate" Type="Date" Prompt="End Date"/>` |
| **Crystal SQL** | `WHERE s.surgery_date BETWEEN :StartDate AND :EndDate` |
| **Power BI** | Date range slicer on `Calendar[Date]` |
| **Translation Notes** | Crystal's `:StartDate` / `:EndDate` bind parameters are replaced by a date range slicer. The slicer applies filter context to the Calendar table, which propagates through relationships to Surgeries. |

### Formula: ComplicationRate

| | Detail |
|---|---|
| **Crystal** | `Count({complications.complication_id}) / Count({surgeries.surgery_id}) * 100` |
| **DAX Measure** | `Complication Rate = DIVIDE([Total Complications], [Total Surgeries]) * 100` |
| **Supporting Measures** | `Total Surgeries = COUNTROWS(Surgeries)`, `Total Complications = COUNTROWS(Complications)` |
| **Translation Notes** | Crystal `Count()` on two different tables → DAX `COUNTROWS` on each table. `DIVIDE` provides safe division. The measure respects filter context from slicers and visual grouping. |

### Sub-Report Elimination (N+1 → Flattened View)

| | Detail |
|---|---|
| **Crystal** | `<SubReport Name="ComplicationDetails" LinkField="surgery_id"/>` — triggers a separate query for each surgery row (N+1 pattern) |
| **Power BI** | Eliminated entirely. Uses `vw_SurgicalOutcomes` (LEFT JOIN surgeries ↔ complications) as a single flattened query. Complications are shown inline in the report via the Surgeries → Complications relationship. |
| **Translation Notes** | Crystal sub-reports execute a separate database round-trip for each parent row — the N+1 anti-pattern. In Power BI, the semantic model defines a relationship between `Surgeries` and `Complications` tables. Visuals can show complication details alongside surgery data without additional queries. The `vw_SurgicalOutcomes` view pre-joins the data with a `has_complication` flag for efficient DAX aggregation. |

### SQL Function: fn_CalculateReadmissionRisk → DAX

| | Detail |
|---|---|
| **SQL Function** | `dbo.fn_CalculateReadmissionRisk(@PatientAge, @DiagnosisCode, @PriorAdmissions, @ComorbidityCount)` — scalar UDF with IF/SET accumulation |
| **DAX Calculated Column** | `Patients[ReadmissionRiskScore]` — arithmetic with nested IF + IN operator |
| **DAX Calculated Column** | `Patients[ReadmissionRiskLevel]` — `SWITCH(TRUE(), score >= 8, "High", score >= 5, "Moderate", "Low")` |
| **DAX Measure** | `Readmission Risk Score = AVERAGE(Patients[ReadmissionRiskScore])` |
| **Translation Notes** | SQL scalar UDFs block parallelism and are a performance anti-pattern. The cumulative IF/SET scoring pattern (age ≥ 65 → +2, age ≥ 75 → +1 more) is translated to DAX nested `IF()` with arithmetic addition. SQL `IN ('I50','J44','N18')` → DAX `IN {"I50","J44","N18"}`. The categorical CASE → `SWITCH(TRUE(), ...)`. |

---

## Quick Reference: DAX Measures by Report

| Report | DAX Measure | Defined In |
|---|---|---|
| Patient Census | `Patient Count` | measures.dax §2 |
| Patient Census | `Current Patient Count` | measures.dax §2 |
| Patient Census | `Occupancy Percent` | measures.dax §2 |
| Patient Census | `Average Length of Stay` | measures.dax §2 |
| Daily Revenue | `Total Revenue` | measures.dax §1 |
| Daily Revenue | `Total Payments` | measures.dax §1 |
| Daily Revenue | `Total Adjustments` | measures.dax §1 |
| Daily Revenue | `Net Revenue` | measures.dax §1 |
| Daily Revenue | `Running Total Revenue` | measures.dax §1 |
| Quality Metrics | `Metrics Meeting Target` | measures.dax §4 |
| Quality Metrics | `Metrics At Warning` | measures.dax §4 |
| Quality Metrics | `Metrics Below Target` | measures.dax §4 |
| Quality Metrics | `Quality Score Percent` | measures.dax §4 |
| Quality Metrics | `Metric Status` | measures.dax §4 |
| Quality Metrics | `Average Target Variance Pct` | measures.dax §4 |
| Surgical Outcomes | `Total Surgeries` | measures.dax §3 |
| Surgical Outcomes | `Total Complications` | measures.dax §3 |
| Surgical Outcomes | `Complication Rate` | measures.dax §3 |
| Surgical Outcomes | `Readmission Risk Score` | measures.dax §3 |
