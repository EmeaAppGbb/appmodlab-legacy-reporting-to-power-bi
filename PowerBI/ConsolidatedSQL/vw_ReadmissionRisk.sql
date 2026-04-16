/*
    View: vw_ReadmissionRisk
    Source: Replaces SQL/Functions/fn_CalculateReadmissionRisk.sql scalar function
            with inline CASE logic for DirectQuery compatibility.
    Used by: Power BI Surgical Outcomes / Patient Census reports

    Key changes from legacy:
      - Scalar function eliminated (scalar UDFs block parallelism in SQL Server).
      - Risk score and risk level computed inline per patient.
      - Scoring logic preserved exactly from fn_CalculateReadmissionRisk:
          Age >= 65       → +2 points
          Age >= 75       → +1 additional point (cumulative +3)
          Prior admissions → +2 per admission
          Comorbidities   → +1 per comorbidity
          High-risk Dx (I50, J44, N18) → +3 points
          Score >= 8 → High, >= 5 → Moderate, else Low
*/
CREATE OR ALTER VIEW dbo.vw_ReadmissionRisk
AS
SELECT
    p.patient_id,
    p.patient_age,
    p.diagnosis_code,
    p.prior_admissions,
    p.comorbidity_count,

    -- Readmission risk score (mirrors fn_CalculateReadmissionRisk logic)
    (
        -- Age factor: +2 if >= 65, +1 more if >= 75
        CASE WHEN p.patient_age >= 75 THEN 3
             WHEN p.patient_age >= 65 THEN 2
             ELSE 0
        END
        -- Prior admissions factor: 2 points per prior admission
        + (p.prior_admissions * 2)
        -- Comorbidity factor: 1 point per comorbidity
        + p.comorbidity_count
        -- High-risk diagnosis codes
        + CASE WHEN p.diagnosis_code IN ('I50', 'J44', 'N18') THEN 3 ELSE 0 END
    ) AS risk_score,

    -- Risk level derived from the score
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
