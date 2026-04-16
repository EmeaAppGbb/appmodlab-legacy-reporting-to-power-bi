/*
    View: vw_QualityMetrics
    Source: SQL Server ClearwaterHealth table cms_quality_metrics migrated to Azure SQL.
    Replaces: SSRS QualityMetrics.rdl inline SQL with CASE expression
    Used by: Power BI Quality Metrics report (DirectQuery compatible)

    Key changes from legacy:
      - Status thresholds (Green/Yellow/Red) computed in the view so Power BI
        conditional formatting can bind directly to status_color.
      - Target variance percent added for KPI card visuals.
      - Period column exposed for slicer-based filtering (replaces SSRS @Period param).
*/
CREATE OR ALTER VIEW dbo.vw_QualityMetrics
AS
SELECT
    m.metric_id,
    m.metric_name,
    m.metric_category,
    m.reporting_period,
    m.actual_value,
    m.target_value,

    -- Variance from target (positive = exceeding, negative = below)
    m.actual_value - m.target_value AS target_variance,

    -- Variance as a percentage of target
    CASE
        WHEN m.target_value = 0 THEN NULL
        ELSE ROUND(
            (m.actual_value - m.target_value) * 100.0 / m.target_value,
            2
        )
    END AS target_variance_pct,

    -- Status color matching legacy SSRS CASE logic:
    --   Green  = meets or exceeds target
    --   Yellow = within 10% of target
    --   Red    = more than 10% below target
    CASE
        WHEN m.actual_value >= m.target_value THEN 'Green'
        WHEN m.actual_value >= m.target_value * 0.9 THEN 'Yellow'
        ELSE 'Red'
    END AS status_color,

    -- Numeric status for sorting (1=Green, 2=Yellow, 3=Red)
    CASE
        WHEN m.actual_value >= m.target_value THEN 1
        WHEN m.actual_value >= m.target_value * 0.9 THEN 2
        ELSE 3
    END AS status_sort_order

FROM dbo.cms_quality_metrics m;
GO
