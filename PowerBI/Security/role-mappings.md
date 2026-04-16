# Row-Level Security Role Mappings

## Clearwater Health System — Legacy to Power BI RLS Migration

This document maps legacy SSRS folder-based security and Crystal Reports client-side security to the new centralized Power BI RLS model. All security is now enforced at the dataset level through DAX RLS roles, replacing the fragmented per-report permission model.

---

## Legacy Security Model (Being Replaced)

### SSRS Folder-Based Security

SSRS reports were organized into folders with NTLM group-based permissions:

| SSRS Folder Path | AD Security Group | Access Level | Reports |
|---|---|---|---|
| `/RevenueCycle/` | `CLEARWATER\Finance_All` | Browse + View | DailyRevenue.rdl |
| `/RevenueCycle/Cardiology/` | `CLEARWATER\Cardiology_Managers` | Browse + View | Department-filtered revenue |
| `/RevenueCycle/ICU/` | `CLEARWATER\ICU_Managers` | Browse + View | Department-filtered revenue |
| `/RevenueCycle/Emergency/` | `CLEARWATER\ED_Managers` | Browse + View | Department-filtered revenue |
| `/RevenueCycle/Orthopedics/` | `CLEARWATER\Ortho_Managers` | Browse + View | Department-filtered revenue |
| `/Clinical/` | `CLEARWATER\Clinical_Staff` | Browse + View | QualityMetrics.rdl |
| `/Executive/` | `CLEARWATER\Domain Admins` | Full Control | All reports |

**Problems with this model:**
- Security maintained per folder/report across 40+ reports
- No data-level filtering — stored procedure `usp_GetDailyRevenue` returned **all** departments
- Adding a new department required creating a new folder and updating AD groups
- No audit trail of who accessed which data

### Crystal Reports Client-Side Security

Crystal Reports used a shared Oracle service account (`REPORTS_USER`) with client-side filtering:

| Crystal Report | Service Account | Client-Side Filter | Security Gap |
|---|---|---|---|
| PatientCensus.rpt | `REPORTS_USER` (Oracle) | `RecordSelectionFormula: {patients.attending_physician} = CurrentUser` | All patient PHI transmitted to client before filtering |
| SurgicalOutcomes.rpt | `REPORTS_USER` (Oracle) | None — all surgeries visible to all users | No access control on surgical data |

**Problems with this model:**
- Shared service account with broad read access to all clinical tables
- Client-side filtering transmitted all PHI over the network (HIPAA risk)
- No server-side enforcement — determined users could bypass client filters
- SurgicalOutcomes had no security at all

---

## New Power BI RLS Model

### Role Definitions

All roles are defined in the Power BI semantic model and enforced server-side. Users are assigned to roles in Power BI Service.

### Role 1: DepartmentRole

**DAX Filter:** `[department_name] = USERPRINCIPALNAME()`
**Applied to Table:** `Departments`
**Filter Propagation:** `Departments` → `Charges` → `Payments`, `Adjustments`

| Azure AD User / Group | Department | Legacy Equivalent |
|---|---|---|
| `cardiology-mgrs@clearwaterhealth.org` | Cardiology | `CLEARWATER\Cardiology_Managers` → `/RevenueCycle/Cardiology/` |
| `icu-mgrs@clearwaterhealth.org` | ICU | `CLEARWATER\ICU_Managers` → `/RevenueCycle/ICU/` |
| `ed-mgrs@clearwaterhealth.org` | Emergency | `CLEARWATER\ED_Managers` → `/RevenueCycle/Emergency/` |
| `ortho-mgrs@clearwaterhealth.org` | Orthopedics | `CLEARWATER\Ortho_Managers` → `/RevenueCycle/Orthopedics/` |
| `oncology-mgrs@clearwaterhealth.org` | Oncology | (New — no legacy equivalent) |
| `neurology-mgrs@clearwaterhealth.org` | Neurology | (New — no legacy equivalent) |

**What users see:**
- Daily revenue, charges, payments, and adjustments for their department only
- All time periods (Calendar table is not filtered)
- DAX measures (Total Revenue, Net Revenue) automatically respect the department filter

**What users cannot see:**
- Revenue data for other departments
- Patient-level clinical data (Patients table not in DepartmentRole scope)
- Surgical outcomes data

### Role 2: PhysicianRole

**DAX Filter:** `[attending_physician] = USERPRINCIPALNAME()`
**Applied to Table:** `Patients`
**Filter Propagation:** `Patients` → `Surgeries` → `Complications`; `Patients` → `Wards`

| Azure AD User / Group | Physician | Specialty | Legacy Equivalent |
|---|---|---|---|
| `dr.chen@clearwaterhealth.org` | Dr. Chen | Cardiology | Crystal `PatientCensus.rpt` client-side filter |
| `dr.martinez@clearwaterhealth.org` | Dr. Martinez | ICU | Crystal `PatientCensus.rpt` client-side filter |
| `dr.williams@clearwaterhealth.org` | Dr. Williams | Emergency | Crystal `PatientCensus.rpt` client-side filter |
| `dr.patel@clearwaterhealth.org` | Dr. Patel | Orthopedics | Crystal `PatientCensus.rpt` client-side filter |
| `dr.johnson@clearwaterhealth.org` | Dr. Johnson | Oncology | (New — no legacy Crystal report) |
| `dr.kim@clearwaterhealth.org` | Dr. Kim | Neurology | (New — no legacy Crystal report) |

**What users see:**
- Patient census for only their assigned patients
- Surgical outcomes for their patients' surgeries
- Complications for their patients' surgeries
- Readmission risk scores for their patients
- Ward occupancy data (filtered to wards where their patients reside)

**What users cannot see:**
- Other physicians' patients
- Department-level financial data (Charges, Payments, Adjustments not in PhysicianRole scope)
- Quality metrics (CmsQualityMetrics not in PhysicianRole scope)

**HIPAA Improvement:** RLS is enforced server-side. Unlike the legacy Crystal Reports model, no PHI for other physicians' patients is ever transmitted to the client.

### Role 3: ExecutiveRole

**DAX Filter:** None (no filter expression — full access)
**Applied to Table:** None

| Azure AD User / Group | Title | Legacy Equivalent |
|---|---|---|
| `cfo@clearwaterhealth.org` | Chief Financial Officer | `CLEARWATER\Domain Admins` (SSRS all folders) |
| `ceo@clearwaterhealth.org` | Chief Executive Officer | `CLEARWATER\Domain Admins` (SSRS all folders) |
| `quality-director@clearwaterhealth.org` | Quality Director | `CLEARWATER\Clinical_Staff` (SSRS `/Clinical/` folder) |
| `compliance@clearwaterhealth.org` | Compliance Officer | `CLEARWATER\Clinical_Staff` (SSRS `/Clinical/` folder) |
| `cmo@clearwaterhealth.org` | Chief Medical Officer | Crystal viewer direct access |
| `vp-finance@clearwaterhealth.org` | VP Finance | `CLEARWATER\Finance_All` (SSRS `/RevenueCycle/`) |

**What users see:**
- All departments' revenue, charges, payments, and adjustments
- All patients' census, surgeries, complications, and readmission risk
- All quality metrics across all reporting periods
- All wards' occupancy data

**What users cannot see:**
- Nothing is restricted — full dataset access

---

## Security Mapping Lookup Table

For production deployments where `USERPRINCIPALNAME()` does not directly match column values (e.g., department names are "Cardiology" but UPNs are "jsmith@clearwaterhealth.org"), create a `SecurityUserMapping` table:

```
| user_principal_name              | department_name | physician_id | role_type   |
|----------------------------------|-----------------|--------------|-------------|
| jsmith@clearwaterhealth.org      | Cardiology      | NULL         | Department  |
| dr.chen@clearwaterhealth.org     | NULL            | dr.chen      | Physician   |
| cfo@clearwaterhealth.org         | NULL            | NULL         | Executive   |
```

Update DAX filters to use:
```dax
-- DepartmentRole with lookup table
LOOKUPVALUE(
    SecurityUserMapping[department_name],
    SecurityUserMapping[user_principal_name],
    USERPRINCIPALNAME()
) = [department_name]
```

---

## Subscription Security Mapping

Power BI Service subscriptions respect RLS. Each subscriber receives only the data visible under their role.

| Report | Subscriber | Role | Schedule | Data Visible |
|---|---|---|---|---|
| Daily Revenue | CFO | ExecutiveRole | Daily 7:00 AM | All departments |
| Daily Revenue | ICU Manager | DepartmentRole | Daily 7:00 AM | ICU only |
| Daily Revenue | Cardiology Manager | DepartmentRole | Daily 7:00 AM | Cardiology only |
| Quality Metrics | Quality Director | ExecutiveRole | Monthly 1st | All metrics |
| Patient Census | Dr. Chen | PhysicianRole | 3×/day (5 AM, 12 PM, 8 PM) | Dr. Chen's patients only |
| Patient Census | Dr. Martinez | PhysicianRole | 3×/day (5 AM, 12 PM, 8 PM) | Dr. Martinez's patients only |
| Patient Census | CMO | ExecutiveRole | Daily 8:00 AM | All patients |

---

## Test Scenarios for Validating RLS

Use Power BI Desktop **"View as Role"** or Power BI Service **"Test as Role"** with specific user identities.

### Scenario 1: Department User Sees Only ICU Data

1. Open Daily Revenue report
2. Select "View as" → DepartmentRole → enter `icu-mgrs@clearwaterhealth.org`
3. **Expected:** Only ICU revenue rows visible; Total Revenue shows ICU total only
4. **Verify:** No Cardiology, Emergency, Orthopedics, or other department data appears
5. **Legacy comparison:** Run `usp_GetDailyRevenue` in SSMS — compare ICU rows to Power BI output

### Scenario 2: Physician Sees Only Their Patients

1. Open Patient Census report
2. Select "View as" → PhysicianRole → enter `dr.chen@clearwaterhealth.org`
3. **Expected:** Only Dr. Chen's patients visible; patient count matches legacy Census report
4. **Verify:** No other physicians' patients appear
5. **Legacy comparison:** Run Crystal Reports PatientCensus.rpt with Dr. Chen's login — compare patient list

### Scenario 3: Executive Sees All Data

1. Open any report
2. Select "View as" → ExecutiveRole → enter `cfo@clearwaterhealth.org`
3. **Expected:** All departments, all patients, all metrics visible
4. **Verify:** Total Revenue matches the unfiltered `usp_GetDailyRevenue` result for all departments

### Scenario 4: Physician Cannot See Financial Data

1. Open Daily Revenue report
2. Select "View as" → PhysicianRole → enter `dr.chen@clearwaterhealth.org`
3. **Expected:** Revenue data is empty or report shows no data (Charges table not in PhysicianRole)
4. **Verify:** No financial figures appear

### Scenario 5: User With No Role Sees No Data

1. Open any report
2. Select "View as" → a user not assigned to any role
3. **Expected:** All visuals show "No data" or are empty
4. **Verify:** This confirms the security-by-default behavior

### Scenario 6: Subscription Delivers Filtered Data

1. Configure Daily Revenue subscription for ICU Manager (`icu-mgrs@clearwaterhealth.org`)
2. Trigger subscription delivery
3. **Expected:** Emailed PDF/attachment contains only ICU department revenue
4. **Verify:** Compare to Executive subscription — Executive should see all departments

---

## Migration Checklist

- [ ] Define DepartmentRole, PhysicianRole, and ExecutiveRole in Power BI Desktop (Modeling → Manage Roles)
- [ ] Add `attending_physician` column to `vw_ConsolidatedPatientCensus` view (required for PhysicianRole)
- [ ] Publish dataset to Power BI Service
- [ ] Assign Azure AD users/groups to roles in Dataset Settings → Row-Level Security
- [ ] Create `SecurityUserMapping` table if UPNs don't match column values directly
- [ ] Test each role using "Test as Role" in Power BI Service (see test-matrix.md)
- [ ] Validate subscription delivery respects RLS for each subscriber
- [ ] Document role assignments in IT operations runbook
- [ ] Decommission legacy SSRS folder permissions after validation
- [ ] Revoke Oracle `REPORTS_USER` account after Crystal Reports retirement
