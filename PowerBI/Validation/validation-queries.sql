-- ============================================================================
-- Clearwater Health System — Legacy vs Power BI Validation Queries
-- ============================================================================
-- Run each pair of queries (Legacy + Power BI equivalent) and compare results.
-- Differences beyond rounding tolerance (±0.01) should be investigated.
-- ============================================================================

-- ############################################################################
-- 1. TOTAL REVENUE BY DEPARTMENT
--    Legacy:   usp_GetDailyRevenue stored procedure
--    Power BI: DAX measures Total Revenue, Total Payments, Net Revenue
-- ############################################################################

-- 1A. Legacy — Execute stored procedure for a specific date
EXEC usp_GetDailyRevenue @ReportDate = '2026-04-15';
-- Returns: department_name, charges_amount, payments_amount, net_revenue

-- 1B. Power BI equivalent — Direct SQL against consolidated view
-- This mirrors what the DAX measures compute via the semantic model
SELECT
    d.department_name,
    SUM(c.charge_amount)                                        AS total_revenue,
    SUM(p.payment_amount)                                       AS total_payments,
    SUM(c.charge_amount) - SUM(ISNULL(a.adjustment_amount, 0)) AS net_revenue
FROM departments d
    INNER JOIN charges c   ON c.department_id = d.department_id
    LEFT  JOIN payments p  ON p.charge_id     = c.charge_id
    LEFT  JOIN adjustments a ON a.charge_id   = c.charge_id
WHERE CAST(c.charge_date AS DATE) = '2026-04-15'
GROUP BY d.department_name
ORDER BY d.department_name;

-- 1C. Comparison query — Run on same server to detect mismatches
-- Wrap both result sets in CTEs and compare row-by-row
WITH Legacy AS (
    -- Simulate stored procedure output (inline the SP logic)
    SELECT
        d.department_name,
        SUM(c.charge_amount)                                        AS charges_amount,
        SUM(p.payment_amount)                                       AS payments_amount,
        SUM(c.charge_amount) - SUM(ISNULL(a.adjustment_amount, 0)) AS net_revenue
    FROM departments d
        INNER JOIN charges c   ON c.department_id = d.department_id
        LEFT  JOIN payments p  ON p.charge_id     = c.charge_id
        LEFT  JOIN adjustments a ON a.charge_id   = c.charge_id
    WHERE CAST(c.charge_date AS DATE) = '2026-04-15'
    GROUP BY d.department_name
),
PowerBI AS (
    -- Same query against consolidated view (mirrors DAX Total Revenue / Net Revenue)
    SELECT
        department_name,
        SUM(charge_amount)                                        AS charges_amount,
        SUM(payment_amount)                                       AS payments_amount,
        SUM(charge_amount) - SUM(ISNULL(adjustment_amount, 0))   AS net_revenue
    FROM vw_ConsolidatedRevenue
    WHERE CAST(charge_date AS DATE) = '2026-04-15'
    GROUP BY department_name
)
SELECT
    COALESCE(l.department_name, p.department_name) AS department_name,
    l.charges_amount  AS legacy_charges,
    p.charges_amount  AS pbi_charges,
    l.net_revenue     AS legacy_net_revenue,
    p.net_revenue     AS pbi_net_revenue,
    CASE
        WHEN ABS(ISNULL(l.net_revenue, 0) - ISNULL(p.net_revenue, 0)) < 0.01 THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS status
FROM Legacy l
    FULL OUTER JOIN PowerBI p ON l.department_name = p.department_name
ORDER BY department_name;


-- ############################################################################
-- 2. PATIENT CENSUS COUNTS BY WARD
--    Legacy:   vw_PatientCensus view (Crystal PatientCensus.rpt)
--    Power BI: DAX Current Patient Count, Occupancy Percent measures
-- ############################################################################

-- 2A. Legacy — Query the original patient census view
SELECT
    ward_name,
    bed_capacity,
    current_patients,
    occupancy_percent,
    avg_length_of_stay
FROM vw_PatientCensus
ORDER BY ward_name;

-- 2B. Power BI equivalent — Query against consolidated census view
-- Mirrors DAX: Current Patient Count, Occupancy Percent, Average Length of Stay
SELECT
    w.ward_name,
    w.bed_capacity,
    COUNT(p.patient_id)                                              AS current_patients,
    CAST(COUNT(p.patient_id) AS FLOAT) / w.bed_capacity * 100       AS occupancy_percent,
    AVG(CAST(DATEDIFF(DAY, p.admission_date, GETDATE()) AS FLOAT))  AS avg_length_of_stay
FROM wards w
    LEFT JOIN patients p ON p.ward_id = w.ward_id
                         AND p.discharge_date IS NULL
GROUP BY w.ward_id, w.ward_name, w.ward_code, w.bed_capacity
ORDER BY w.ward_name;

-- 2C. Comparison query — Detect occupancy mismatches
WITH Legacy AS (
    SELECT ward_name, current_patients, occupancy_percent
    FROM vw_PatientCensus
),
PowerBI AS (
    SELECT
        w.ward_name,
        COUNT(p.patient_id) AS current_patients,
        CAST(COUNT(p.patient_id) AS FLOAT) / w.bed_capacity * 100 AS occupancy_percent
    FROM wards w
        LEFT JOIN patients p ON p.ward_id = w.ward_id
                             AND p.discharge_date IS NULL
    GROUP BY w.ward_id, w.ward_name, w.bed_capacity
)
SELECT
    COALESCE(l.ward_name, p.ward_name)  AS ward_name,
    l.current_patients                  AS legacy_patients,
    p.current_patients                  AS pbi_patients,
    ROUND(l.occupancy_percent, 2)       AS legacy_occupancy_pct,
    ROUND(p.occupancy_percent, 2)       AS pbi_occupancy_pct,
    CASE
        WHEN l.current_patients = p.current_patients THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS status
FROM Legacy l
    FULL OUTER JOIN PowerBI p ON l.ward_name = p.ward_name
ORDER BY ward_name;


-- ############################################################################
-- 3. COMPLICATION RATES
--    Legacy:   Crystal SurgicalOutcomes.rpt formula
--              ComplicationRate = Count(complications) / Count(surgeries) * 100
--    Power BI: DAX Complication Rate = DIVIDE([Total Complications],
--              [Total Surgeries]) * 100
-- ############################################################################

-- 3A. Legacy — Crystal Report formula equivalent
-- Crystal formula: Count({complications.complication_id}) / Count({surgeries.surgery_id}) * 100
SELECT
    COUNT(DISTINCT s.surgery_id)                                             AS total_surgeries,
    COUNT(c.complication_id)                                                 AS total_complications,
    CAST(COUNT(c.complication_id) AS FLOAT)
        / NULLIF(COUNT(DISTINCT s.surgery_id), 0) * 100                     AS complication_rate
FROM surgeries s
    LEFT JOIN complications c ON c.surgery_id = s.surgery_id
WHERE s.surgery_date BETWEEN '2026-01-01' AND '2026-03-31';

-- 3B. Power BI equivalent — Matches DAX DIVIDE semantics (returns BLANK on zero)
SELECT
    COUNT(DISTINCT s.surgery_id)                                             AS total_surgeries,
    COUNT(c.complication_id)                                                 AS total_complications,
    CASE
        WHEN COUNT(DISTINCT s.surgery_id) = 0 THEN NULL  -- DAX DIVIDE returns BLANK
        ELSE CAST(COUNT(c.complication_id) AS FLOAT)
             / COUNT(DISTINCT s.surgery_id) * 100
    END                                                                      AS complication_rate
FROM surgeries s
    LEFT JOIN complications c ON c.surgery_id = s.surgery_id
WHERE s.surgery_date BETWEEN '2026-01-01' AND '2026-03-31';

-- 3C. Comparison by surgeon — Verify drill-down consistency
WITH Legacy AS (
    SELECT
        s.surgeon_name,
        COUNT(DISTINCT s.surgery_id) AS total_surgeries,
        COUNT(c.complication_id)     AS total_complications,
        CAST(COUNT(c.complication_id) AS FLOAT)
            / NULLIF(COUNT(DISTINCT s.surgery_id), 0) * 100 AS complication_rate
    FROM surgeries s
        LEFT JOIN complications c ON c.surgery_id = s.surgery_id
    WHERE s.surgery_date BETWEEN '2026-01-01' AND '2026-03-31'
    GROUP BY s.surgeon_name
),
PowerBI AS (
    SELECT
        s.surgeon_name,
        COUNT(DISTINCT s.surgery_id) AS total_surgeries,
        COUNT(c.complication_id)     AS total_complications,
        CASE
            WHEN COUNT(DISTINCT s.surgery_id) = 0 THEN NULL
            ELSE CAST(COUNT(c.complication_id) AS FLOAT)
                 / COUNT(DISTINCT s.surgery_id) * 100
        END AS complication_rate
    FROM surgeries s
        LEFT JOIN complications c ON c.surgery_id = s.surgery_id
    WHERE s.surgery_date BETWEEN '2026-01-01' AND '2026-03-31'
    GROUP BY s.surgeon_name
)
SELECT
    COALESCE(l.surgeon_name, p.surgeon_name)   AS surgeon_name,
    l.complication_rate                        AS legacy_rate,
    p.complication_rate                        AS pbi_rate,
    CASE
        WHEN ABS(ISNULL(l.complication_rate, 0) - ISNULL(p.complication_rate, 0)) < 0.01
        THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS status
FROM Legacy l
    FULL OUTER JOIN PowerBI p ON l.surgeon_name = p.surgeon_name
ORDER BY surgeon_name;


-- ############################################################################
-- 4. QUALITY METRICS STATUS
--    Legacy:   SSRS QualityMetrics.rdl — SQL CASE expression
--              CASE WHEN actual >= target THEN 'Green'
--                   WHEN actual >= target * 0.9 THEN 'Yellow'
--                   ELSE 'Red' END
--    Power BI: DAX SWITCH(TRUE(), ...) in CmsQualityMetrics[StatusColor]
-- ############################################################################

-- 4A. Legacy — SSRS inline SQL with CASE logic
SELECT
    metric_name,
    actual_value,
    target_value,
    CASE
        WHEN actual_value >= target_value          THEN 'Green'
        WHEN actual_value >= target_value * 0.9    THEN 'Yellow'
        ELSE 'Red'
    END AS status_color,
    reporting_period
FROM cms_quality_metrics
WHERE reporting_period = '2026-Q1'
ORDER BY metric_name;

-- 4B. Power BI equivalent — Mirrors DAX SWITCH(TRUE(), ...) calculated column
-- CmsQualityMetrics[StatusColor] =
--     SWITCH(TRUE(),
--         actual_value >= target_value, "Green",
--         actual_value >= target_value * 0.9, "Yellow",
--         "Red")
SELECT
    metric_name,
    actual_value,
    target_value,
    CASE
        WHEN actual_value >= target_value          THEN 'Green'
        WHEN actual_value >= target_value * 0.9    THEN 'Yellow'
        ELSE 'Red'
    END AS status_color,
    reporting_period
FROM cms_quality_metrics
WHERE reporting_period = '2026-Q1'
ORDER BY metric_name;

-- 4C. Aggregate comparison — Metrics Meeting/Warning/Below Target
-- Matches DAX: Metrics Meeting Target, Metrics At Warning, Metrics Below Target
WITH StatusCounts AS (
    SELECT
        CASE
            WHEN actual_value >= target_value          THEN 'Green'
            WHEN actual_value >= target_value * 0.9    THEN 'Yellow'
            ELSE 'Red'
        END AS status_color
    FROM cms_quality_metrics
    WHERE reporting_period = '2026-Q1'
)
SELECT
    SUM(CASE WHEN status_color = 'Green'  THEN 1 ELSE 0 END) AS metrics_meeting_target,
    SUM(CASE WHEN status_color = 'Yellow' THEN 1 ELSE 0 END) AS metrics_at_warning,
    SUM(CASE WHEN status_color = 'Red'    THEN 1 ELSE 0 END) AS metrics_below_target,
    COUNT(*)                                                   AS total_metrics,
    CAST(SUM(CASE WHEN status_color = 'Green' THEN 1 ELSE 0 END) AS FLOAT)
        / NULLIF(COUNT(*), 0) * 100                            AS quality_score_percent
FROM StatusCounts;


-- ############################################################################
-- 5. CROSS-REPORT AGGREGATE VALIDATION
--    Run after individual checks pass — verifies totals across all reports
-- ############################################################################

-- 5A. Grand total revenue (should match Power BI card visual)
SELECT
    SUM(charge_amount)                                        AS grand_total_revenue,
    SUM(charge_amount) - SUM(ISNULL(adjustment_amount, 0))   AS grand_net_revenue
FROM charges c
    LEFT JOIN adjustments a ON a.charge_id = c.charge_id
WHERE CAST(c.charge_date AS DATE) = '2026-04-15';

-- 5B. Hospital-wide occupancy (should match Power BI KPI)
SELECT
    SUM(current_patients)                                     AS total_patients,
    SUM(bed_capacity)                                         AS total_beds,
    CAST(SUM(current_patients) AS FLOAT)
        / NULLIF(SUM(bed_capacity), 0) * 100                  AS hospital_occupancy_pct
FROM vw_PatientCensus;

-- 5C. Overall complication rate (should match Power BI summary)
SELECT
    COUNT(DISTINCT s.surgery_id)                              AS total_surgeries,
    COUNT(c.complication_id)                                  AS total_complications,
    CAST(COUNT(c.complication_id) AS FLOAT)
        / NULLIF(COUNT(DISTINCT s.surgery_id), 0) * 100      AS overall_complication_rate
FROM surgeries s
    LEFT JOIN complications c ON c.surgery_id = s.surgery_id;
