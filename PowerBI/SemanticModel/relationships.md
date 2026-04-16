# Star Schema Relationships — Clearwater Health Semantic Model

> **Generated:** 2026-04-16
> **Source model:** [`model.tmdl`](model.tmdl)
> **Design pattern:** Star schema with Calendar as the shared date dimension

---

## Schema Diagram

```
                          ┌─────────────┐
                          │  Calendar    │
                          │  (Date Dim)  │
                          └──────┬───────┘
                   ┌─────────────┼─────────────────┐
                   │             │                  │
              admission_date  surgery_date     charge_date
                   │             │                  │
        ┌──────────▼──┐  ┌──────▼──────┐  ┌───────▼───────┐
        │  Patients    │  │  Surgeries  │  │   Charges     │
        │  (Fact/Dim)  │  │  (Fact)     │  │   (Fact)      │
        └──┬───────────┘  └──┬──────────┘  └──┬─────┬──────┘
           │                 │                 │     │
      current_ward_id   patient_id      dept_id  charge_id
           │                 │                 │     ├──────────┐
     ┌─────▼─────┐   ┌──────▼──────┐   ┌──────▼──┐  │          │
     │   Wards   │   │ (Patients)  │   │ Depts   │  │          │
     │   (Dim)   │   │  ◄── back   │   │ (Dim)   │  │          │
     └───────────┘   └─────────────┘   └─────────┘  │          │
                                              ┌──────▼───┐ ┌────▼────────┐
                                              │ Payments │ │ Adjustments │
                                              │ (Fact)   │ │ (Fact)      │
                                              └──────────┘ └─────────────┘

        ┌──────────────┐
        │ Complications│
        │ (Fact)       │
        └──────┬───────┘
               │
          surgery_id
               │
        ┌──────▼──────┐
        │  Surgeries  │
        │  ◄── back   │
        └─────────────┘

        ┌────────────────────┐
        │ CmsQualityMetrics  │  (standalone — no FK relationships,
        │ (Fact)             │   filtered by reporting_period slicer)
        └────────────────────┘
```

---

## Relationship Definitions

### Patient Census Star

| # | From (Many) | Column | → | To (One) | Column | Cardinality | Cross-Filter | Active |
|---|-------------|--------|---|----------|--------|-------------|--------------|--------|
| 1 | Patients | `current_ward_id` | → | Wards | `ward_id` | Many-to-One | One direction (Wards → Patients) | ✅ |
| 2 | Patients | `admission_date` | → | Calendar | `Date` | Many-to-One | One direction (Calendar → Patients) | ✅ |
| 3 | Patients | `discharge_date` | → | Calendar | `Date` | Many-to-One | One direction (Calendar → Patients) | ❌ (inactive) |

**Relationship 3 — Inactive:** Power BI allows only one active relationship between two tables. `admission_date` is the default active date relationship. To filter by discharge date, use `USERELATIONSHIP` in DAX:

```dax
Discharged Count =
    CALCULATE(
        COUNTROWS( Patients ),
        USERELATIONSHIP( Patients[discharge_date], Calendar[Date] )
    )
```

### Surgical Outcomes Star

| # | From (Many) | Column | → | To (One) | Column | Cardinality | Cross-Filter | Active |
|---|-------------|--------|---|----------|--------|-------------|--------------|--------|
| 4 | Surgeries | `patient_id` | → | Patients | `patient_id` | Many-to-One | One direction (Patients → Surgeries) | ✅ |
| 5 | Surgeries | `surgery_date` | → | Calendar | `Date` | Many-to-One | One direction (Calendar → Surgeries) | ✅ |
| 6 | Complications | `surgery_id` | → | Surgeries | `surgery_id` | Many-to-One | One direction (Surgeries → Complications) | ✅ |

**Design note:** The `Complications → Surgeries → Patients` chain enables drill-through from a complication record all the way to patient demographics. This replaces the Crystal Reports N+1 sub-report pattern where `ComplicationDetails` was a linked sub-report on `surgery_id`.

### Revenue Cycle Star

| # | From (Many) | Column | → | To (One) | Column | Cardinality | Cross-Filter | Active |
|---|-------------|--------|---|----------|--------|-------------|--------------|--------|
| 7 | Charges | `department_id` | → | Departments | `department_id` | Many-to-One | One direction (Departments → Charges) | ✅ |
| 8 | Charges | `charge_date` | → | Calendar | `Date` | Many-to-One | One direction (Calendar → Charges) | ✅ |
| 9 | Payments | `charge_id` | → | Charges | `charge_id` | Many-to-One | One direction (Charges → Payments) | ✅ |
| 10 | Adjustments | `charge_id` | → | Charges | `charge_id` | Many-to-One | One direction (Charges → Adjustments) | ✅ |

**Design note:** `Payments` and `Adjustments` are both on the many-side of `Charges`. A single charge can have multiple payment records or adjustment records. The DAX measures `Total Payments` and `Total Adjustments` aggregate correctly because they SUM the respective amount columns through the one-direction cross-filter from Charges.

### Quality Metrics (Standalone)

| # | Table | Relationship | Notes |
|---|-------|-------------|-------|
| 11 | CmsQualityMetrics | None | No FK to other tables. Filtered by `reporting_period` slicer. Status color calculated column (`StatusColor`) replaces SSRS CASE expression. |

---

## Cross-Filter Direction Rationale

All relationships use **one-direction** cross-filtering (dimension → fact). This follows Power BI best practices:

1. **Performance** — Bidirectional filters create ambiguous paths and degrade query performance.
2. **Predictability** — Slicing on a dimension (Ward, Department, Calendar) filters the related facts. Facts never filter dimensions unexpectedly.
3. **Ambiguity prevention** — Calendar connects to three fact tables (Patients, Surgeries, Charges). Bidirectional filters would create circular dependency warnings.

---

## Legacy Mapping

| Legacy Report | Data Path | Power BI Relationship Chain |
|---------------|-----------|---------------------------|
| Patient Census (Crystal) | `wards → patients` (grouped by ward) | `Wards → Patients` via `ward_id` + `Calendar → Patients` via `admission_date` |
| Surgical Outcomes (Crystal) | `surgeries LEFT JOIN complications` + sub-report | `Surgeries → Complications` via `surgery_id` + `Patients → Surgeries` via `patient_id` |
| Daily Revenue (SSRS) | `departments → charges → payments/adjustments` (via SP) | `Departments → Charges` via `department_id` + `Charges → Payments` / `Charges → Adjustments` via `charge_id` |
| Quality Metrics (SSRS) | `cms_quality_metrics` (standalone, filtered by @Period) | `CmsQualityMetrics` (standalone, filtered by `reporting_period` slicer) |
