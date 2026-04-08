CREATE FUNCTION dbo.fn_CalculateReadmissionRisk
(
    @PatientAge INT,
    @DiagnosisCode VARCHAR(10),
    @PriorAdmissions INT,
    @ComorbidityCount INT
)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @RiskScore INT = 0;
    DECLARE @RiskLevel VARCHAR(10);
    
    -- Age factor
    IF @PatientAge >= 65 SET @RiskScore = @RiskScore + 2;
    IF @PatientAge >= 75 SET @RiskScore = @RiskScore + 1;
    
    -- Prior admissions factor
    SET @RiskScore = @RiskScore + (@PriorAdmissions * 2);
    
    -- Comorbidity factor
    SET @RiskScore = @RiskScore + @ComorbidityCount;
    
    -- High-risk diagnoses
    IF @DiagnosisCode IN ('I50', 'J44', 'N18') 
        SET @RiskScore = @RiskScore + 3;
    
    -- Determine risk level
    SET @RiskLevel = CASE 
        WHEN @RiskScore >= 8 THEN 'High'
        WHEN @RiskScore >= 5 THEN 'Moderate'
        ELSE 'Low'
    END;
    
    RETURN @RiskLevel;
END
GO
