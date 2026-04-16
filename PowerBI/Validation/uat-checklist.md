# User Acceptance Testing (UAT) Checklist

**Project:** Clearwater Health System — Legacy Reporting to Power BI Migration  
**UAT Lead:** _____________________  
**Test Period:** _____________________ to _____________________  
**Power BI Workspace:** _____________________

---

## 1. Data Accuracy Validation

Verify that Power BI report values match legacy system output using `validation-queries.sql`.

| # | Test Case | Steps | Expected Result | Status | Tester | Date | Notes |
|---|-----------|-------|-----------------|--------|--------|------|-------|
| 1.1 | Revenue totals match usp_GetDailyRevenue | Run query 1A, compare with Power BI Daily Revenue page | Values match within ±$0.01 | ☐ Pass ☐ Fail | | | |
| 1.2 | Patient census counts match vw_PatientCensus | Run query 2A, compare with Power BI Patient Census page | Patient counts identical per ward | ☐ Pass ☐ Fail | | | |
| 1.3 | Occupancy percentages match Crystal formula | Compare Crystal `WardOccupancy` formula output vs Power BI `Occupancy Percent` measure | Values match within ±0.01% | ☐ Pass ☐ Fail | | | |
| 1.4 | Complication rates match Crystal formula | Compare Crystal `ComplicationRate` vs Power BI `Complication Rate` measure | Values match within ±0.01% | ☐ Pass ☐ Fail | | | |
| 1.5 | Quality metric statuses match SSRS CASE logic | Run query 4A, compare color assignments | All Green/Yellow/Red assignments identical | ☐ Pass ☐ Fail | | | |
| 1.6 | Net revenue calculation accuracy | Verify `Net Revenue = Total Revenue - Total Adjustments` across departments | Calculation correct for every department | ☐ Pass ☐ Fail | | | |
| 1.7 | Readmission risk scores match fn_CalculateReadmissionRisk | Spot-check 10 patients: compare SQL function output vs DAX calculated column | Risk levels identical for all 10 patients | ☐ Pass ☐ Fail | | | |
| 1.8 | Date filtering produces correct subsets | Apply date slicer in Power BI, run equivalent WHERE clause in SQL | Row counts and totals match | ☐ Pass ☐ Fail | | | |
| 1.9 | NULL/BLANK handling consistency | Check patients with no discharge date, charges with no adjustments | NULLs handled identically (ISNULL vs ISBLANK) | ☐ Pass ☐ Fail | | | |
| 1.10 | Cross-report grand totals | Compare hospital-wide totals across all 4 reports | Totals consistent across reports | ☐ Pass ☐ Fail | | | |

---

## 2. Conditional Formatting Verification

Verify that visual formatting rules match legacy report behavior.

| # | Test Case | Steps | Expected Result | Status | Tester | Date | Notes |
|---|-----------|-------|-----------------|--------|--------|------|-------|
| 2.1 | Occupancy > 95% shows RED | Find or create a ward with occupancy > 95%; open Patient Census report | Ward row/cell displays red background or red text | ☐ Pass ☐ Fail | | | |
| 2.2 | Occupancy ≤ 95% shows normal color | Verify wards below 95% threshold | No red formatting applied | ☐ Pass ☐ Fail | | | |
| 2.3 | Occupancy exactly at 95% boundary | Test ward at exactly 95.00% occupancy | Should NOT be red (> 95% threshold) | ☐ Pass ☐ Fail | | | |
| 2.4 | Quality metric Green (actual ≥ target) | Verify metric where actual ≥ target | Cell shows green / LightGreen background | ☐ Pass ☐ Fail | | | |
| 2.5 | Quality metric Yellow (actual ≥ 90% of target) | Verify metric where actual is between 90–99% of target | Cell shows yellow background | ☐ Pass ☐ Fail | | | |
| 2.6 | Quality metric Red (actual < 90% of target) | Verify metric where actual < 90% of target | Cell shows red / LightCoral background | ☐ Pass ☐ Fail | | | |
| 2.7 | Formatting persists after slicer change | Change date/period slicer and verify formatting updates | Colors update dynamically based on new data | ☐ Pass ☐ Fail | | | |
| 2.8 | Formatting visible in exported PDF | Export Patient Census to PDF | Red occupancy formatting preserved | ☐ Pass ☐ Fail | | | |

---

## 3. Row-Level Security (RLS) Verification

Verify that each role sees only authorized data per the RLS configuration.

| # | Test Case | Steps | Expected Result | Status | Tester | Date | Notes |
|---|-----------|-------|-----------------|--------|--------|------|-------|
| 3.1 | Department Head — own department only | Log in as Cardiology dept head; view Revenue report | Only Cardiology department data visible | ☐ Pass ☐ Fail | | | |
| 3.2 | Department Head — other departments hidden | As Cardiology head, verify no Orthopedics data | Other department rows absent (not just filtered) | ☐ Pass ☐ Fail | | | |
| 3.3 | Nursing Supervisor — assigned wards only | Log in as nursing supervisor; view Patient Census | Only assigned ward data visible | ☐ Pass ☐ Fail | | | |
| 3.4 | Surgeon — own surgical data only | Log in as surgeon; view Surgical Outcomes | Only own surgeries and complications shown | ☐ Pass ☐ Fail | | | |
| 3.5 | Executive / Admin — full access | Log in as CFO or admin; view all reports | Complete unfiltered data across all departments | ☐ Pass ☐ Fail | | | |
| 3.6 | Quality Director — quality metrics access | Log in as quality director; view Quality Metrics | All quality metrics visible | ☐ Pass ☐ Fail | | | |
| 3.7 | RLS with "View As" in Power BI Service | Use "View as role" feature in workspace | Data correctly filtered per selected role | ☐ Pass ☐ Fail | | | |
| 3.8 | RLS does not affect aggregates incorrectly | Verify that filtered totals are context-aware | Totals reflect only visible (authorized) rows | ☐ Pass ☐ Fail | | | |
| 3.9 | Unauthorized role — no data leakage | Test user with no role assignment | No data displayed or access denied | ☐ Pass ☐ Fail | | | |
| 3.10 | RLS persists in embedded/shared scenarios | Share report via link; verify RLS still applies | Recipient sees only their authorized data | ☐ Pass ☐ Fail | | | |

---

## 4. Mobile Access Testing

Verify reports are accessible and functional on mobile devices.

| # | Test Case | Steps | Expected Result | Status | Tester | Date | Notes |
|---|-----------|-------|-----------------|--------|--------|------|-------|
| 4.1 | Power BI Mobile app — report loads | Open report in Power BI Mobile app (iOS/Android) | Report renders without errors | ☐ Pass ☐ Fail | | | |
| 4.2 | Mobile layout responsive | Rotate device; check portrait and landscape modes | Visuals resize and remain readable | ☐ Pass ☐ Fail | | | |
| 4.3 | Touch interactions — slicers | Tap date slicer on mobile | Slicer opens and selections apply correctly | ☐ Pass ☐ Fail | | | |
| 4.4 | Touch interactions — drill-through | Long-press or tap drill-through target on mobile | Drill-through navigation works | ☐ Pass ☐ Fail | | | |
| 4.5 | Conditional formatting on mobile | View Patient Census on mobile with high-occupancy ward | Red formatting visible on mobile display | ☐ Pass ☐ Fail | | | |
| 4.6 | RLS enforced on mobile | Access report via mobile with dept-restricted account | Only authorized data visible | ☐ Pass ☐ Fail | | | |
| 4.7 | Offline indicator | Disconnect from network and attempt to view | Appropriate offline message or cached data shown | ☐ Pass ☐ Fail | | | |

---

## 5. Subscription Delivery Testing

Verify automated report delivery replaces legacy subscriptions.

| # | Test Case | Steps | Expected Result | Status | Tester | Date | Notes |
|---|-----------|-------|-----------------|--------|--------|------|-------|
| 5.1 | Daily Revenue — PDF subscription | Configure daily 7 AM subscription for CFO | PDF delivered to cfo@clearwaterhealth.org by 7:15 AM | ☐ Pass ☐ Fail | | | |
| 5.2 | Patient Census — 3×/day subscription | Configure 5 AM, 12 PM, 8 PM subscriptions | PDFs delivered to nursing-supervisors@clearwaterhealth.org at each time | ☐ Pass ☐ Fail | | | |
| 5.3 | Quality Metrics — monthly subscription | Configure 1st-of-month 6 AM subscription | Excel delivered to quality-director and compliance addresses | ☐ Pass ☐ Fail | | | |
| 5.4 | Subscription content accuracy | Compare subscription PDF values with live report | Values match at time of delivery | ☐ Pass ☐ Fail | | | |
| 5.5 | Subscription respects RLS | Verify subscribed user receives only their authorized data | Data filtered per recipient's role | ☐ Pass ☐ Fail | | | |
| 5.6 | Subscription failure alerting | Simulate delivery failure (invalid email) | Admin notified of delivery failure | ☐ Pass ☐ Fail | | | |
| 5.7 | Data-driven alert — high occupancy | Configure alert for Occupancy > 95% | Alert email sent when threshold exceeded | ☐ Pass ☐ Fail | | | |

---

## 6. Drill-Through Navigation Testing

Verify drill-through paths replace legacy sub-reports and detail views.

| # | Test Case | Steps | Expected Result | Status | Tester | Date | Notes |
|---|-----------|-------|-----------------|--------|--------|------|-------|
| 6.1 | Revenue → Department detail | Click department name in Revenue summary | Drill-through shows department-level charge detail | ☐ Pass ☐ Fail | | | |
| 6.2 | Patient Census → Ward detail | Click ward name in Census summary | Shows individual patient list for selected ward | ☐ Pass ☐ Fail | | | |
| 6.3 | Surgical Outcomes → Complication detail | Click surgery row in outcomes table | Shows complications for selected surgery (replaces Crystal sub-report) | ☐ Pass ☐ Fail | | | |
| 6.4 | Quality Metrics → Metric trend | Click individual metric row | Shows historical trend for selected metric | ☐ Pass ☐ Fail | | | |
| 6.5 | Back button navigation | Use Back button after drill-through | Returns to summary page with prior context preserved | ☐ Pass ☐ Fail | | | |
| 6.6 | Drill-through context passes correctly | Verify filter context is correct on detail page | Only selected item's data displayed | ☐ Pass ☐ Fail | | | |
| 6.7 | Cross-report drill-through | Navigate from Census to Revenue for same department | Correct department context carried across reports | ☐ Pass ☐ Fail | | | |

---

## 7. Parameter Filtering Testing

Verify that Power BI slicers replicate legacy report parameter behavior.

| # | Test Case | Steps | Expected Result | Status | Tester | Date | Notes |
|---|-----------|-------|-----------------|--------|--------|------|-------|
| 7.1 | Date slicer — Revenue report | Select specific date in Revenue report slicer | Data filters to selected date (replaces @ReportDate) | ☐ Pass ☐ Fail | | | |
| 7.2 | Date range slicer — Surgical Outcomes | Select date range in Surgical Outcomes slicer | Data filters to range (replaces @StartDate/@EndDate) | ☐ Pass ☐ Fail | | | |
| 7.3 | Period slicer — Quality Metrics | Select reporting period (e.g., 2026-Q1) | Data filters to period (replaces @Period) | ☐ Pass ☐ Fail | | | |
| 7.4 | Default slicer value — today's date | Open Revenue report without changing slicer | Defaults to today's date (replaces =Today() default) | ☐ Pass ☐ Fail | | | |
| 7.5 | Multi-select department filter | Select multiple departments in slicer | Data shows combined results for selected departments | ☐ Pass ☐ Fail | | | |
| 7.6 | Clear all filters | Click "Clear all" or reset slicers | Report shows unfiltered data | ☐ Pass ☐ Fail | | | |
| 7.7 | Slicer cascading / cross-filtering | Select department, verify ward slicer updates | Dependent slicers reflect valid options only | ☐ Pass ☐ Fail | | | |
| 7.8 | Bookmark with saved filters | Create bookmark with specific filter state | Bookmark restores exact filter combination | ☐ Pass ☐ Fail | | | |
| 7.9 | URL parameter filtering | Append filter parameter to report URL | Report opens with pre-applied filter | ☐ Pass ☐ Fail | | | |

---

## UAT Summary

| Category | Total Tests | Passed | Failed | Blocked | Pass Rate |
|----------|-------------|--------|--------|---------|-----------|
| Data Accuracy | 10 | | | | |
| Conditional Formatting | 8 | | | | |
| RLS Verification | 10 | | | | |
| Mobile Access | 7 | | | | |
| Subscription Delivery | 7 | | | | |
| Drill-Through Navigation | 7 | | | | |
| Parameter Filtering | 9 | | | | |
| **Total** | **58** | | | | |

---

## UAT Sign-Off

| Role | Name | Approval | Date | Comments |
|------|------|----------|------|----------|
| CFO (Revenue Stakeholder) | | ☐ Approved ☐ Rejected | | |
| Chief Nursing Officer | | ☐ Approved ☐ Rejected | | |
| Chief Medical Officer (Surgical) | | ☐ Approved ☐ Rejected | | |
| Quality Director | | ☐ Approved ☐ Rejected | | |
| IT Director | | ☐ Approved ☐ Rejected | | |
| Compliance Officer | | ☐ Approved ☐ Rejected | | |

---

## Defect Log

| # | Date | Category | Description | Severity | Status | Assigned To | Resolution |
|---|------|----------|-------------|----------|--------|-------------|------------|
| | | | | | | | |
| | | | | | | | |
| | | | | | | | |
