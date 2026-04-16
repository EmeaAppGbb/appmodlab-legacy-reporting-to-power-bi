/*
    View: vw_ConsolidatedPatientCensus
    Source: Consolidates Oracle CLINICALPRD tables (wards, patients) into Azure SQL.
    Replaces: SQL/Views/vw_PatientCensus.sql + Crystal Reports inline SQL
    Used by: Power BI Patient Census report (DirectQuery compatible)

    Enhancements over legacy view:
      - Individual patient-level rows (supports drill-through in Power BI)
      - Length of Stay (LOS) calculated per patient
      - Ward-level occupancy percent available via GROUP BY in DAX or a companion summary
      - Snapshot timestamp for audit trail
*/
CREATE OR ALTER VIEW dbo.vw_ConsolidatedPatientCensus
AS
SELECT
    -- Ward dimensions
    w.ward_id,
    w.ward_name,
    w.ward_code,
    w.bed_capacity,

    -- Patient detail
    p.patient_id,
    p.admission_date,
    p.discharge_date,

    -- Length of Stay: days from admission to discharge (or today if still admitted)
    DATEDIFF(DAY, p.admission_date,
        ISNULL(p.discharge_date, CAST(GETDATE() AS DATE))
    ) AS length_of_stay_days,

    -- Current census flag (1 = currently admitted, 0 = discharged)
    CASE
        WHEN p.discharge_date IS NULL THEN 1
        ELSE 0
    END AS is_current_patient,

    -- Ward occupancy: current patient count / bed capacity * 100
    -- Uses a windowed COUNT so every row carries the ward-level metric
    CAST(
        COUNT(CASE WHEN p.discharge_date IS NULL THEN p.patient_id END)
            OVER (PARTITION BY w.ward_id)
        AS FLOAT
    ) / NULLIF(w.bed_capacity, 0) * 100 AS occupancy_percent,

    -- Snapshot timestamp for incremental refresh / audit
    GETDATE() AS snapshot_utc

FROM dbo.wards w
LEFT JOIN dbo.patients p
    ON w.ward_id = p.current_ward_id;
GO
