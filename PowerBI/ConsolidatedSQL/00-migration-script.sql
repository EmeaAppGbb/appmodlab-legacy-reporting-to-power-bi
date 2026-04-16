/*
    ============================================================================
    Clearwater Health System — Consolidated View Migration Script
    ============================================================================
    Target:  Azure SQL Database (ClearwaterHealth)
    Purpose: Create all consolidated views that replace legacy Oracle/SQL Server
             stored procedures, functions, and report-specific SQL for the
             Power BI migration.

    Prerequisites:
      - Azure SQL Database provisioned with base tables migrated:
          From Oracle CLINICALPRD: wards, patients, surgeries, complications
          From SQL Server ClearwaterHealth: departments, charges, payments,
              adjustments, cms_quality_metrics
      - Columns referenced below must exist (see individual view headers).

    Execution order matters — views are independent, but this script runs them
    in a logical sequence (dimensions → facts → derived).

    Usage:
      sqlcmd -S <server>.database.windows.net -d ClearwaterHealth -i 00-migration-script.sql
      -- or execute in Azure Data Studio / SSMS
    ============================================================================
*/

PRINT '=== Clearwater Health: Consolidated View Migration ===';
PRINT 'Started at ' + CONVERT(VARCHAR(30), GETDATE(), 121);
PRINT '';

-- --------------------------------------------------------------------------
-- 1. Patient Census (ward occupancy, LOS)
--    Replaces: SQL/Views/vw_PatientCensus.sql + Crystal Reports inline SQL
--    Source tables: wards, patients (originally Oracle)
-- --------------------------------------------------------------------------
PRINT '1/5 Creating vw_ConsolidatedPatientCensus...';
GO

CREATE OR ALTER VIEW dbo.vw_ConsolidatedPatientCensus
AS
SELECT
    w.ward_id,
    w.ward_name,
    w.ward_code,
    w.bed_capacity,
    p.patient_id,
    p.admission_date,
    p.discharge_date,
    DATEDIFF(DAY, p.admission_date,
        ISNULL(p.discharge_date, CAST(GETDATE() AS DATE))
    ) AS length_of_stay_days,
    CASE
        WHEN p.discharge_date IS NULL THEN 1
        ELSE 0
    END AS is_current_patient,
    CAST(
        COUNT(CASE WHEN p.discharge_date IS NULL THEN p.patient_id END)
            OVER (PARTITION BY w.ward_id)
        AS FLOAT
    ) / NULLIF(w.bed_capacity, 0) * 100 AS occupancy_percent,
    GETDATE() AS snapshot_utc
FROM dbo.wards w
LEFT JOIN dbo.patients p
    ON w.ward_id = p.current_ward_id;
GO

PRINT '   Done.';

-- --------------------------------------------------------------------------
-- 2. Consolidated Revenue (replaces usp_GetDailyRevenue stored procedure)
--    Source tables: departments, charges, payments, adjustments (originally SQL Server)
-- --------------------------------------------------------------------------
PRINT '2/5 Creating vw_ConsolidatedRevenue...';
GO

CREATE OR ALTER VIEW dbo.vw_ConsolidatedRevenue
AS
SELECT
    d.department_id,
    d.department_name,
    c.charge_id,
    CAST(c.charge_date AS DATE) AS charge_date,
    c.charge_amount,
    ISNULL(p.payment_amount, 0) AS payment_amount,
    ISNULL(adj.adjustment_amount, 0) AS adjustment_amount,
    c.charge_amount - ISNULL(adj.adjustment_amount, 0) AS net_revenue
FROM dbo.departments d
INNER JOIN dbo.charges c
    ON d.department_id = c.department_id
LEFT JOIN dbo.payments p
    ON c.charge_id = p.charge_id
LEFT JOIN dbo.adjustments adj
    ON c.charge_id = adj.charge_id;
GO

PRINT '   Done.';

-- --------------------------------------------------------------------------
-- 3. Surgical Outcomes (flattened — eliminates N+1 sub-report pattern)
--    Source tables: surgeries, complications (originally Oracle)
-- --------------------------------------------------------------------------
PRINT '3/5 Creating vw_SurgicalOutcomes...';
GO

CREATE OR ALTER VIEW dbo.vw_SurgicalOutcomes
AS
SELECT
    s.surgery_id,
    s.patient_id,
    s.surgery_date,
    s.procedure_code,
    s.procedure_name,
    s.surgeon_id,
    comp.complication_id,
    comp.complication_type,
    comp.severity,
    CASE
        WHEN comp.complication_id IS NOT NULL THEN 1
        ELSE 0
    END AS has_complication,
    CAST(
        COUNT(comp.complication_id) OVER (PARTITION BY s.procedure_code)
        AS FLOAT
    ) / NULLIF(
        COUNT(s.surgery_id) OVER (PARTITION BY s.procedure_code), 0
    ) * 100 AS procedure_complication_rate_pct
FROM dbo.surgeries s
LEFT JOIN dbo.complications comp
    ON s.surgery_id = comp.surgery_id;
GO

PRINT '   Done.';

-- --------------------------------------------------------------------------
-- 4. Quality Metrics (with status thresholds for conditional formatting)
--    Source table: cms_quality_metrics (originally SQL Server)
-- --------------------------------------------------------------------------
PRINT '4/5 Creating vw_QualityMetrics...';
GO

CREATE OR ALTER VIEW dbo.vw_QualityMetrics
AS
SELECT
    m.metric_id,
    m.metric_name,
    m.metric_category,
    m.reporting_period,
    m.actual_value,
    m.target_value,
    m.actual_value - m.target_value AS target_variance,
    CASE
        WHEN m.target_value = 0 THEN NULL
        ELSE ROUND(
            (m.actual_value - m.target_value) * 100.0 / m.target_value,
            2
        )
    END AS target_variance_pct,
    CASE
        WHEN m.actual_value >= m.target_value THEN 'Green'
        WHEN m.actual_value >= m.target_value * 0.9 THEN 'Yellow'
        ELSE 'Red'
    END AS status_color,
    CASE
        WHEN m.actual_value >= m.target_value THEN 1
        WHEN m.actual_value >= m.target_value * 0.9 THEN 2
        ELSE 3
    END AS status_sort_order
FROM dbo.cms_quality_metrics m;
GO

PRINT '   Done.';

-- --------------------------------------------------------------------------
-- 5. Readmission Risk (inline CASE replaces fn_CalculateReadmissionRisk)
--    Source table: patients (originally Oracle)
-- --------------------------------------------------------------------------
PRINT '5/5 Creating vw_ReadmissionRisk...';
GO

CREATE OR ALTER VIEW dbo.vw_ReadmissionRisk
AS
SELECT
    p.patient_id,
    p.patient_age,
    p.diagnosis_code,
    p.prior_admissions,
    p.comorbidity_count,
    (
        CASE WHEN p.patient_age >= 75 THEN 3
             WHEN p.patient_age >= 65 THEN 2
             ELSE 0
        END
        + (p.prior_admissions * 2)
        + p.comorbidity_count
        + CASE WHEN p.diagnosis_code IN ('I50', 'J44', 'N18') THEN 3 ELSE 0 END
    ) AS risk_score,
    CASE
        WHEN (
            CASE WHEN p.patient_age >= 75 THEN 3
                 WHEN p.patient_age >= 65 THEN 2
                 ELSE 0
            END
            + (p.prior_admissions * 2)
            + p.comorbidity_count
            + CASE WHEN p.diagnosis_code IN ('I50', 'J44', 'N18') THEN 3 ELSE 0 END
        ) >= 8 THEN 'High'
        WHEN (
            CASE WHEN p.patient_age >= 75 THEN 3
                 WHEN p.patient_age >= 65 THEN 2
                 ELSE 0
            END
            + (p.prior_admissions * 2)
            + p.comorbidity_count
            + CASE WHEN p.diagnosis_code IN ('I50', 'J44', 'N18') THEN 3 ELSE 0 END
        ) >= 5 THEN 'Moderate'
        ELSE 'Low'
    END AS risk_level
FROM dbo.patients p;
GO

PRINT '   Done.';
PRINT '';
PRINT '=== All 5 consolidated views created successfully ===';
PRINT 'Completed at ' + CONVERT(VARCHAR(30), GETDATE(), 121);
GO
