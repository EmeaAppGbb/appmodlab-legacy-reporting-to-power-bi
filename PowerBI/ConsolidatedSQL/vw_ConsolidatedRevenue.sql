/*
    View: vw_ConsolidatedRevenue
    Source: Consolidates SQL Server ClearwaterHealth tables
            (departments, charges, payments, adjustments) into Azure SQL.
    Replaces: SQL/StoredProcedures/usp_GetDailyRevenue.sql
    Used by: Power BI Daily Revenue report (DirectQuery compatible)

    Key changes from the stored procedure:
      - Converted from stored proc with @ReportDate parameter to a view.
        Date filtering is now handled by Power BI slicers / DAX CALCULATE.
      - Exposes charge_date so Power BI can slice by any date range.
      - Row-level detail preserved; aggregation moves to DAX measures:
          Total Charges = SUM(charges_amount)
          Total Payments = SUM(payments_amount)
          Net Revenue   = SUM(net_revenue)
*/
CREATE OR ALTER VIEW dbo.vw_ConsolidatedRevenue
AS
SELECT
    -- Department dimension
    d.department_id,
    d.department_name,

    -- Charge detail
    c.charge_id,
    CAST(c.charge_date AS DATE) AS charge_date,
    c.charge_amount,

    -- Payment (may be NULL if unpaid)
    ISNULL(p.payment_amount, 0) AS payment_amount,

    -- Adjustment (may be NULL if no adjustment)
    ISNULL(adj.adjustment_amount, 0) AS adjustment_amount,

    -- Net revenue per charge line (charge minus adjustments)
    c.charge_amount - ISNULL(adj.adjustment_amount, 0) AS net_revenue

FROM dbo.departments d
INNER JOIN dbo.charges c
    ON d.department_id = c.department_id
LEFT JOIN dbo.payments p
    ON c.charge_id = p.charge_id
LEFT JOIN dbo.adjustments adj
    ON c.charge_id = adj.charge_id;
GO
