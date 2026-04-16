# Validation Test Results — Legacy vs Power BI Side-by-Side Comparison

**Project:** Clearwater Health System — Legacy Reporting to Power BI Migration  
**Tester:**  _____________________  
**Test Date:** _____________________  
**Environment:** _____________________  
**Data Snapshot Date:** _____________________

---

## Instructions

1. Run the corresponding query from `validation-queries.sql` against the legacy system
2. Open the Power BI report and navigate to the equivalent visual/measure
3. Record both values and note whether they match within tolerance (±0.01 for decimals)
4. Document any discrepancies in the Notes column

---

## 1. Daily Revenue Report (SSRS DailyRevenue.rdl → Power BI)

| # | Metric | Legacy Value (usp_GetDailyRevenue) | Power BI Value (DAX) | Match | Notes |
|---|--------|------------------------------------|----------------------|-------|-------|
| 1.1 | Total Revenue — Cardiology | | | ☐ Yes ☐ No | |
| 1.2 | Total Revenue — Orthopedics | | | ☐ Yes ☐ No | |
| 1.3 | Total Revenue — Emergency | | | ☐ Yes ☐ No | |
| 1.4 | Total Revenue — All Departments (Grand Total) | | | ☐ Yes ☐ No | |
| 1.5 | Total Payments — Cardiology | | | ☐ Yes ☐ No | |
| 1.6 | Total Payments — All Departments (Grand Total) | | | ☐ Yes ☐ No | |
| 1.7 | Net Revenue — Cardiology | | | ☐ Yes ☐ No | |
| 1.8 | Net Revenue — All Departments (Grand Total) | | | ☐ Yes ☐ No | |
| 1.9 | Department count (number of rows) | | | ☐ Yes ☐ No | |
| 1.10 | Currency formatting ($#,##0.00) | | | ☐ Yes ☐ No | Visual check |

---

## 2. Patient Census Report (Crystal PatientCensus.rpt → Power BI)

| # | Metric | Legacy Value (vw_PatientCensus / Crystal) | Power BI Value (DAX) | Match | Notes |
|---|--------|------------------------------------------|----------------------|-------|-------|
| 2.1 | Current Patients — ICU | | | ☐ Yes ☐ No | |
| 2.2 | Current Patients — Medical Ward | | | ☐ Yes ☐ No | |
| 2.3 | Current Patients — Surgical Ward | | | ☐ Yes ☐ No | |
| 2.4 | Current Patients — All Wards (Total) | | | ☐ Yes ☐ No | |
| 2.5 | Bed Capacity — ICU | | | ☐ Yes ☐ No | |
| 2.6 | Occupancy % — ICU | | | ☐ Yes ☐ No | |
| 2.7 | Occupancy % — Medical Ward | | | ☐ Yes ☐ No | |
| 2.8 | Occupancy % — All Wards (Hospital-wide) | | | ☐ Yes ☐ No | |
| 2.9 | Avg Length of Stay — ICU | | | ☐ Yes ☐ No | |
| 2.10 | Avg Length of Stay — All Wards | | | ☐ Yes ☐ No | |
| 2.11 | Ward count (number of rows) | | | ☐ Yes ☐ No | |
| 2.12 | Red formatting when occupancy > 95% | | | ☐ Yes ☐ No | Visual check |

---

## 3. Surgical Outcomes Report (Crystal SurgicalOutcomes.rpt → Power BI)

| # | Metric | Legacy Value (Crystal formula) | Power BI Value (DAX) | Match | Notes |
|---|--------|-------------------------------|----------------------|-------|-------|
| 3.1 | Total Surgeries (Q1 2026) | | | ☐ Yes ☐ No | |
| 3.2 | Total Complications (Q1 2026) | | | ☐ Yes ☐ No | |
| 3.3 | Complication Rate % (Overall) | | | ☐ Yes ☐ No | |
| 3.4 | Complication Rate % — Surgeon A | | | ☐ Yes ☐ No | |
| 3.5 | Complication Rate % — Surgeon B | | | ☐ Yes ☐ No | |
| 3.6 | Date parameter filtering (StartDate/EndDate) | | | ☐ Yes ☐ No | Verify slicer |
| 3.7 | Complication detail drill-through | | | ☐ Yes ☐ No | Replaces sub-report |
| 3.8 | Readmission Risk Score — Average | | | ☐ Yes ☐ No | |
| 3.9 | Readmission Risk Level distribution | | | ☐ Yes ☐ No | High/Moderate/Low counts |
| 3.10 | Zero-surgery edge case (DIVIDE returns blank) | | | ☐ Yes ☐ No | DAX DIVIDE behavior |

---

## 4. Quality Metrics Report (SSRS QualityMetrics.rdl → Power BI)

| # | Metric | Legacy Value (SSRS CASE logic) | Power BI Value (DAX SWITCH) | Match | Notes |
|---|--------|-------------------------------|----------------------------|-------|-------|
| 4.1 | Total metrics count | | | ☐ Yes ☐ No | |
| 4.2 | Metrics Meeting Target (Green) count | | | ☐ Yes ☐ No | |
| 4.3 | Metrics At Warning (Yellow) count | | | ☐ Yes ☐ No | |
| 4.4 | Metrics Below Target (Red) count | | | ☐ Yes ☐ No | |
| 4.5 | Quality Score % | | | ☐ Yes ☐ No | |
| 4.6 | Individual metric — Metric A actual vs target | | | ☐ Yes ☐ No | |
| 4.7 | Individual metric — Metric B actual vs target | | | ☐ Yes ☐ No | |
| 4.8 | Status color assignment — Green threshold | | | ☐ Yes ☐ No | actual >= target |
| 4.9 | Status color assignment — Yellow threshold | | | ☐ Yes ☐ No | actual >= target × 0.9 |
| 4.10 | Status color assignment — Red threshold | | | ☐ Yes ☐ No | actual < target × 0.9 |
| 4.11 | Period parameter filtering (@Period) | | | ☐ Yes ☐ No | Verify slicer |
| 4.12 | Conditional formatting colors (Green/Yellow/Red) | | | ☐ Yes ☐ No | Visual check |

---

## Summary

| Report | Total Tests | Passed | Failed | Pass Rate |
|--------|-------------|--------|--------|-----------|
| Daily Revenue | 10 | | | |
| Patient Census | 12 | | | |
| Surgical Outcomes | 10 | | | |
| Quality Metrics | 12 | | | |
| **Total** | **44** | | | |

---

## Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| QA Tester | | | |
| Report Developer | | | |
| Business Analyst | | | |
| Data Steward | | | |
