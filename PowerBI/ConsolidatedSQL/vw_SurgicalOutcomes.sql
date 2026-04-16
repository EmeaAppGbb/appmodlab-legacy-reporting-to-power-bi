/*
    View: vw_SurgicalOutcomes
    Source: Consolidates Oracle CLINICALPRD tables
            (surgeries, complications) into Azure SQL.
    Replaces: Crystal Reports SurgicalOutcomes.rpt embedded SQL + sub-report
    Used by: Power BI Surgical Outcomes report (DirectQuery compatible)

    Key changes from legacy:
      - Flattened join eliminates the N+1 sub-report anti-pattern.
      - Complication flag per row enables DAX complication-rate measure:
          Complication Rate = DIVIDE(
              CALCULATE(COUNTROWS(SurgicalOutcomes), [has_complication] = 1),
              COUNTROWS(SurgicalOutcomes)
          ) * 100
      - Date columns exposed for slicer-based filtering (replaces Crystal parameters).
*/
CREATE OR ALTER VIEW dbo.vw_SurgicalOutcomes
AS
SELECT
    -- Surgery detail
    s.surgery_id,
    s.patient_id,
    s.surgery_date,
    s.procedure_code,
    s.procedure_name,
    s.surgeon_id,

    -- Complication detail (NULL when no complication)
    comp.complication_id,
    comp.complication_type,
    comp.severity,

    -- Complication flag for easy DAX aggregation
    CASE
        WHEN comp.complication_id IS NOT NULL THEN 1
        ELSE 0
    END AS has_complication,

    -- Running complication rate per procedure code (window function)
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
