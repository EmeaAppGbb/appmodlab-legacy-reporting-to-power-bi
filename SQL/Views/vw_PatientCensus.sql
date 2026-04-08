CREATE VIEW dbo.vw_PatientCensus
AS
SELECT 
    w.ward_id,
    w.ward_name,
    w.ward_code,
    w.bed_capacity,
    COUNT(p.patient_id) AS current_patients,
    CAST(COUNT(p.patient_id) AS FLOAT) / w.bed_capacity * 100 AS occupancy_percent,
    AVG(DATEDIFF(DAY, p.admission_date, GETDATE())) AS avg_length_of_stay
FROM wards w
LEFT JOIN patients p ON w.ward_id = p.current_ward_id AND p.discharge_date IS NULL
GROUP BY w.ward_id, w.ward_name, w.ward_code, w.bed_capacity;
GO
