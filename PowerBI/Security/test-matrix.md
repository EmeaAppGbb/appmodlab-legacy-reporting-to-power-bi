# RLS Test Matrix

## Clearwater Health System — Row-Level Security Validation

This matrix defines the complete set of test cases for validating that Power BI Row-Level Security correctly restricts data access for each role. Execute all tests before decommissioning legacy SSRS/Crystal Reports security.

---

## Test Environment Setup

### Prerequisites

- Power BI Desktop with semantic model published to Power BI Service
- Test Azure AD accounts for each role (see Test Accounts below)
- Access to legacy systems for comparison (SSRS Report Manager, Crystal Reports Viewer, SSMS)
- DAX Studio installed for validation queries

### Test Accounts

| Test Account | Assigned Role | Expected Access Scope |
|---|---|---|
| `test-icu-mgr@clearwaterhealth.org` | DepartmentRole | ICU department data only |
| `test-cardio-mgr@clearwaterhealth.org` | DepartmentRole | Cardiology department data only |
| `test-ed-mgr@clearwaterhealth.org` | DepartmentRole | Emergency department data only |
| `test-dr-chen@clearwaterhealth.org` | PhysicianRole | Dr. Chen's patients only |
| `test-dr-martinez@clearwaterhealth.org` | PhysicianRole | Dr. Martinez's patients only |
| `test-cfo@clearwaterhealth.org` | ExecutiveRole | All data (unrestricted) |
| `test-norole@clearwaterhealth.org` | (none) | No data (security by default) |

---

## Test Cases

### TC-01: DepartmentRole — ICU Manager Revenue Visibility

| Field | Value |
|---|---|
| **Role** | DepartmentRole |
| **Test User** | `test-icu-mgr@clearwaterhealth.org` |
| **Report** | Daily Revenue |
| **Method** | Power BI Service → "Test as Role" or Desktop → "View as Role" |

**Steps:**
1. Open Daily Revenue report as `test-icu-mgr`
2. Check the Departments slicer / visual
3. Review Total Revenue, Total Charges, Total Payments measures

**Expected Visible Data:**
- Department: ICU only
- Revenue, Charges, Payments, Adjustments: ICU figures only
- Calendar dates: All dates (Calendar table is not filtered)

**Expected Hidden Data:**
- All other departments (Cardiology, Emergency, Orthopedics, Oncology, Neurology)
- Patient-level data (not in DepartmentRole scope)
- Surgical data (not in DepartmentRole scope)

**Validation Query (DAX Studio):**
```dax
EVALUATE
CALCULATETABLE(
    SUMMARIZECOLUMNS(
        Departments[department_name],
        "Revenue", [Total Revenue]
    ),
    USERELATIONSHIP(Charges[department_id], Departments[department_id])
)
-- Expected: Only 1 row (ICU) with revenue > 0
```

**Legacy Comparison:**
```sql
-- Run in SSMS against ClearwaterHealth database
EXEC dbo.usp_GetDailyRevenue @ReportDate = '2026-04-16'
-- Filter results to department_name = 'ICU'
-- Compare ICU charges_amount, payments_amount, net_revenue to Power BI
```

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| Only ICU data visible | Any other department's data visible |
| Revenue figures match legacy query for ICU | Revenue figures differ from legacy |
| No patient-level data accessible | Patient names or IDs visible |

---

### TC-02: DepartmentRole — Cardiology Manager Revenue Visibility

| Field | Value |
|---|---|
| **Role** | DepartmentRole |
| **Test User** | `test-cardio-mgr@clearwaterhealth.org` |
| **Report** | Daily Revenue |

**Steps:**
1. Open Daily Revenue report as `test-cardio-mgr`
2. Verify only Cardiology department is visible

**Expected Visible Data:**
- Department: Cardiology only
- Revenue measures: Cardiology figures only

**Expected Hidden Data:**
- ICU, Emergency, Orthopedics, and all other departments

**Validation Query:**
```dax
EVALUATE
CALCULATETABLE(
    SUMMARIZECOLUMNS(Departments[department_name]),
    KEEPFILTERS(TRUE)
)
-- Expected: Only 1 row (Cardiology)
```

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| Only Cardiology data visible | ICU or other department data visible |

---

### TC-03: DepartmentRole — Cross-Department Isolation

| Field | Value |
|---|---|
| **Role** | DepartmentRole |
| **Test Users** | `test-icu-mgr` and `test-cardio-mgr` |
| **Report** | Daily Revenue |

**Steps:**
1. Open report as ICU Manager — note Total Revenue value
2. Open report as Cardiology Manager — note Total Revenue value
3. Open report as Executive — note overall Total Revenue
4. Verify: ICU Revenue + Cardiology Revenue + Other Departments = Executive Total Revenue

**Expected:**
- Department totals are mutually exclusive (no data overlap)
- Sum of all department-filtered totals equals unfiltered executive total

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| Department totals sum to executive total | Revenue appears in multiple departments or totals don't reconcile |

---

### TC-04: PhysicianRole — Dr. Chen Patient Visibility

| Field | Value |
|---|---|
| **Role** | PhysicianRole |
| **Test User** | `test-dr-chen@clearwaterhealth.org` |
| **Report** | Patient Census |

**Steps:**
1. Open Patient Census report as `test-dr-chen`
2. Check patient list and patient count
3. Verify all listed patients have `attending_physician = dr.chen@clearwaterhealth.org`

**Expected Visible Data:**
- Patients: Only those assigned to Dr. Chen
- Surgeries: Only for Dr. Chen's patients
- Complications: Only for Dr. Chen's patients' surgeries
- Ward info: Only wards where Dr. Chen's patients reside
- Readmission Risk: Only for Dr. Chen's patients

**Expected Hidden Data:**
- Other physicians' patients
- Department financial data (Charges, Payments, Adjustments)
- Quality metrics (CmsQualityMetrics)

**Validation Query:**
```dax
EVALUATE
CALCULATETABLE(
    SUMMARIZECOLUMNS(
        Patients[attending_physician],
        "PatientCount", COUNTROWS(Patients)
    )
)
-- Expected: Only 1 row (dr.chen@clearwaterhealth.org) with patient count > 0
```

**Legacy Comparison:**
Run Crystal Reports PatientCensus.rpt with Dr. Chen's credentials; compare patient list with Power BI output.

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| Only Dr. Chen's patients visible | Other physicians' patients visible |
| Patient count matches legacy report | Patient count differs |
| No financial data accessible | Charges or payments data visible |

---

### TC-05: PhysicianRole — Dr. Martinez Patient Visibility

| Field | Value |
|---|---|
| **Role** | PhysicianRole |
| **Test User** | `test-dr-martinez@clearwaterhealth.org` |
| **Report** | Patient Census |

**Steps:**
1. Open Patient Census as `test-dr-martinez`
2. Verify only Dr. Martinez's patients are visible
3. Confirm no overlap with Dr. Chen's patient list (from TC-04)

**Expected Visible Data:**
- Patients: Only those assigned to Dr. Martinez

**Expected Hidden Data:**
- Dr. Chen's patients and all other physicians' patients

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| Only Dr. Martinez's patients visible | Any of Dr. Chen's patients visible |

---

### TC-06: PhysicianRole — Surgical Outcomes Filter Propagation

| Field | Value |
|---|---|
| **Role** | PhysicianRole |
| **Test User** | `test-dr-chen@clearwaterhealth.org` |
| **Report** | Surgical Outcomes |

**Steps:**
1. Open Surgical Outcomes report as `test-dr-chen`
2. Verify only surgeries for Dr. Chen's patients are shown
3. Check complication details — only for those surgeries

**Expected Visible Data:**
- Surgeries linked to Dr. Chen's patients (via `Patients` → `Surgeries` relationship)
- Complications for those surgeries (via `Surgeries` → `Complications` relationship)

**Expected Hidden Data:**
- Surgeries for patients of other physicians
- Complications for those other surgeries

**Validation Query:**
```dax
EVALUATE
CALCULATETABLE(
    SUMMARIZECOLUMNS(
        "SurgeryCount", [Total Surgeries],
        "ComplicationCount", [Total Complications]
    )
)
-- Expected: Counts reflect only Dr. Chen's patients' surgeries
```

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| Only Dr. Chen's patients' surgeries visible | Surgeries for other physicians' patients visible |
| Complication Rate reflects Dr. Chen's patients only | Complication Rate includes other physicians' data |

---

### TC-07: ExecutiveRole — Full Data Access

| Field | Value |
|---|---|
| **Role** | ExecutiveRole |
| **Test User** | `test-cfo@clearwaterhealth.org` |
| **Report** | All reports (Daily Revenue, Patient Census, Surgical Outcomes, Quality Metrics) |

**Steps:**
1. Open each report as `test-cfo`
2. Verify all departments are visible in Daily Revenue
3. Verify all patients are visible in Patient Census
4. Verify all surgeries are visible in Surgical Outcomes
5. Verify all quality metrics are visible

**Expected Visible Data:**
- All departments with revenue data
- All patients across all physicians
- All surgeries and complications
- All CMS quality metrics
- All wards with occupancy data

**Expected Hidden Data:**
- None — full access

**Validation Query:**
```dax
EVALUATE
ROW(
    "DepartmentCount", COUNTROWS(Departments),
    "PatientCount", COUNTROWS(Patients),
    "SurgeryCount", COUNTROWS(Surgeries),
    "MetricCount", COUNTROWS(CmsQualityMetrics)
)
-- Expected: All counts match unfiltered dataset totals
```

**Legacy Comparison:**
- Compare department count to `SELECT COUNT(*) FROM departments` in SSMS
- Compare patient count to `SELECT COUNT(*) FROM patients` in Oracle
- Totals should match exactly

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| All data visible across all reports | Any data missing or filtered |
| Totals match unfiltered database queries | Totals differ from database |

---

### TC-08: No Role Assignment — Security by Default

| Field | Value |
|---|---|
| **Role** | (none assigned) |
| **Test User** | `test-norole@clearwaterhealth.org` |
| **Report** | All reports |

**Steps:**
1. Open any report as `test-norole`
2. Verify all visuals show "No data" or empty state

**Expected Visible Data:**
- None — all visuals should be empty

**Expected Hidden Data:**
- Everything — no role assignment means no data access

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| All visuals show empty/no data | Any data visible without role assignment |

**CRITICAL:** This test confirms security-by-default. If a user with no role can see data, the RLS configuration is broken.

---

### TC-09: DepartmentRole — Cannot Access Patient Data

| Field | Value |
|---|---|
| **Role** | DepartmentRole |
| **Test User** | `test-icu-mgr@clearwaterhealth.org` |
| **Report** | Patient Census |

**Steps:**
1. Open Patient Census report as `test-icu-mgr`
2. Verify no patient-level data is visible (DepartmentRole only filters Departments table, and Patients table has no relationship-based filter from Departments)

**Expected:**
- Patient Census visuals show no data or show all patients (depends on model design)
- If DepartmentRole users should NOT see patients, ensure no relationship path exists from Departments to Patients

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| Behavior matches intended design (no patient data OR ward-scoped patient data) | Unintended data leakage through indirect relationships |

---

### TC-10: PhysicianRole — Cannot Access Financial Data

| Field | Value |
|---|---|
| **Role** | PhysicianRole |
| **Test User** | `test-dr-chen@clearwaterhealth.org` |
| **Report** | Daily Revenue |

**Steps:**
1. Open Daily Revenue report as `test-dr-chen`
2. Verify revenue data is not visible (PhysicianRole only filters Patients table; Charges/Departments are not filtered by PhysicianRole)

**Expected:**
- Revenue visuals show no data or show all revenue (depends on model design)
- Physicians should not see department-level financial breakdowns

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| No financial data visible to physician | Department revenue data visible to physician |

---

### TC-11: Subscription Delivery Respects RLS

| Field | Value |
|---|---|
| **Role** | DepartmentRole |
| **Test Users** | `test-icu-mgr` and `test-cfo` |
| **Report** | Daily Revenue (subscribed) |

**Steps:**
1. Create subscription for `test-icu-mgr` on Daily Revenue report
2. Create subscription for `test-cfo` on same report
3. Trigger both subscriptions
4. Compare delivered content

**Expected:**
- ICU Manager receives report showing only ICU revenue
- CFO receives report showing all departments' revenue
- Both emails have the same report title but different data

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| ICU email shows only ICU data | ICU email shows all departments |
| CFO email shows all departments | CFO email shows only one department |

---

### TC-12: Dynamic Membership — Adding New Department

| Field | Value |
|---|---|
| **Role** | DepartmentRole |
| **Scenario** | New "Pediatrics" department added to the dataset |

**Steps:**
1. Add "Pediatrics" department to Departments table in the database
2. Refresh Power BI dataset
3. Assign `test-peds-mgr@clearwaterhealth.org` to DepartmentRole in Power BI Service
4. Open Daily Revenue as `test-peds-mgr`

**Expected:**
- Pediatrics data visible (once charges exist for the department)
- No changes needed to DAX filter expressions
- Existing department users' access unchanged

| ✅ Pass Criteria | ❌ Fail Criteria |
|---|---|
| New department works without DAX changes | DAX filter requires modification for new departments |
| Existing department access unaffected | Other departments' data changed |

---

## Test Execution Summary

| Test Case | Role | Focus Area | Status |
|---|---|---|---|
| TC-01 | DepartmentRole | ICU revenue isolation | ⬜ Not tested |
| TC-02 | DepartmentRole | Cardiology revenue isolation | ⬜ Not tested |
| TC-03 | DepartmentRole | Cross-department reconciliation | ⬜ Not tested |
| TC-04 | PhysicianRole | Dr. Chen patient isolation | ⬜ Not tested |
| TC-05 | PhysicianRole | Dr. Martinez patient isolation | ⬜ Not tested |
| TC-06 | PhysicianRole | Surgical outcomes propagation | ⬜ Not tested |
| TC-07 | ExecutiveRole | Full data access | ⬜ Not tested |
| TC-08 | No Role | Security by default | ⬜ Not tested |
| TC-09 | DepartmentRole | Cross-scope (no patient data) | ⬜ Not tested |
| TC-10 | PhysicianRole | Cross-scope (no financial data) | ⬜ Not tested |
| TC-11 | Mixed | Subscription delivery | ⬜ Not tested |
| TC-12 | DepartmentRole | Dynamic membership | ⬜ Not tested |

---

## Approval Sign-Off

| Approver | Role | Date | Signature |
|---|---|---|---|
| IT Security Lead | Security validation | __________ | __________ |
| HIPAA Compliance Officer | PHI access review | __________ | __________ |
| CFO / Finance Lead | Revenue data accuracy | __________ | __________ |
| Chief Medical Officer | Clinical data accuracy | __________ | __________ |
| Power BI Admin | Technical deployment | __________ | __________ |
