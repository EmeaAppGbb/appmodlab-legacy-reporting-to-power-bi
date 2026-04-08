CREATE PROCEDURE dbo.usp_GetDailyRevenue
    @ReportDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        d.department_name,
        SUM(c.charge_amount) AS charges_amount,
        SUM(p.payment_amount) AS payments_amount,
        SUM(c.charge_amount) - SUM(ISNULL(adj.adjustment_amount, 0)) AS net_revenue
    FROM departments d
    INNER JOIN charges c ON d.department_id = c.department_id
    LEFT JOIN payments p ON c.charge_id = p.charge_id
    LEFT JOIN adjustments adj ON c.charge_id = adj.charge_id
    WHERE CAST(c.charge_date AS DATE) = @ReportDate
    GROUP BY d.department_name
    ORDER BY net_revenue DESC;
END
GO
