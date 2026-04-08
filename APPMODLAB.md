---
title: "Legacy Reports to Power BI"
description: "Modernize Crystal Reports and SSRS to Power BI with DAX measures and interactive dashboards"
authors: ["marconsilva"]
category: "Data Modernization"
industry: "Healthcare & Life Sciences"
services: ["Power BI", "Azure SQL Database"]
languages: ["SQL", "DAX", "M"]
frameworks: [".NET"]
modernizationTools: []
agenticTools: []
tags: ["power-bi", "crystal-reports", "ssrs", "dax", "reporting", "business-intelligence"]
extensions: ["github.copilot"]
thumbnail: ""
video: ""
version: "1.0.0"
---

# Legacy Reporting to Power BI

## Overview

This lab demonstrates modernizing legacy reporting systems (Crystal Reports and SQL Server Reporting Services) to Power BI. You'll learn to convert report designs, translate report formulas to DAX, migrate data sources, implement row-level security, and set up automated refresh schedules. This enables self-service analytics, mobile access, and real-time dashboards — replacing static, IT-dependent report generation.

**Business Domain:** Hospital operations and clinical quality reporting for "Clearwater Health System"

## Learning Objectives

By completing this lab, you will:
- Assess legacy reports for Power BI migration complexity and priority
- Build a unified semantic model with DAX measures
- Convert Crystal Reports formulas and SSRS expressions to DAX
- Implement row-level security in Power BI datasets
- Set up Power BI Apps for enterprise report distribution

## Prerequisites

- Basic Crystal Reports or SSRS familiarity (reading knowledge)
- Power BI Desktop experience
- DAX fundamentals
- Azure subscription (for Power BI Service)
- SQL Server and/or Oracle (for legacy report data sources)

## Architecture

### Legacy Architecture

The Clearwater Health System reporting infrastructure consists of:
- **Crystal Reports 2016** (20 reports) connected to Oracle 12c
- **SQL Server Reporting Services 2016** (20 reports) connected to SQL Server 2016
- Reports distributed via email subscriptions and shared folders
- Crystal Reports Runtime on client PCs for interactive viewing
- SSRS Report Server with folder-based security

**Key Anti-Patterns:**
- Mixed report platforms requiring different skill sets
- Stored procedures embedding business logic
- Email-based distribution with no interactivity
- No self-service capabilities
- Cascading parameters causing slow rendering
- Static PDF exports with no drill-down
- Row-level security implemented per report

### Target Architecture

- **Analytics Platform:** Power BI Service (Premium or Pro)
- **Semantic Model:** Power BI dataset with DAX measures (single source of truth)
- **Reports:** Power BI reports and paginated reports (for pixel-perfect regulatory)
- **Data Source:** Azure SQL Database (consolidated from Oracle + SQL Server)
- **Row-Level Security:** Power BI RLS with DAX filters
- **Distribution:** Power BI App workspace with role-based access
- **Mobile:** Power BI mobile app for tablet/phone access

## Lab Instructions

### Step 1: Inventory Reports

**Objective:** Catalog all Crystal and SSRS reports, assess usage and complexity.

1. Review the report inventory:
   - Crystal Reports in `CrystalReports/` folder
   - SSRS reports in `SSRS-Reports/` folder

2. Analyze key reports:
   - `PatientCensus.rpt` - Real-time patient census by ward
   - `SurgicalOutcomes.rpt` - Surgical outcomes with sub-reports
   - `DailyRevenue.rdl` - Daily revenue dashboard
   - `QualityMetrics.rdl` - CMS quality measures

3. Identify complexity factors:
   - Crystal formulas (WhilePrintingRecords, RunningTotal)
   - SSRS expressions and custom code
   - Sub-reports and drill-through
   - Cascading parameters

### Step 2: Consolidate Data Sources

**Objective:** Create Azure SQL views replacing report-specific stored procedures.

1. Review existing SQL objects:
   - Stored procedures in `SQL/StoredProcedures/`
   - Views in `SQL/Views/`
   - Functions in `SQL/Functions/`

2. Create consolidated views:
   ```sql
   -- Example: Consolidate patient census logic
   CREATE VIEW vw_PatientCensus AS
   SELECT ward_name, COUNT(patient_id) as patient_count,
          bed_capacity, occupancy_percent
   FROM wards w
   LEFT JOIN patients p ON w.ward_id = p.current_ward_id
   WHERE discharge_date IS NULL
   GROUP BY ward_name, bed_capacity;
   ```

### Step 3: Build Semantic Model

**Objective:** Create Power BI dataset connecting to Azure SQL, define DAX measures.

1. Launch Power BI Desktop
2. Connect to Azure SQL Database
3. Import consolidated views
4. Define relationships between tables
5. Create DAX measures:

```dax
// Convert stored procedure logic to DAX
Total Revenue = 
SUM(Charges[charge_amount]) - SUM(Adjustments[adjustment_amount])

Occupancy % = 
DIVIDE(
    COUNT(Patients[patient_id]),
    SUM(Wards[bed_capacity])
) * 100

// Replace Crystal Reports RunningTotal
YTD Revenue = 
CALCULATE(
    [Total Revenue],
    DATESYTD(Calendar[Date])
)
```

### Step 4: Convert Key Reports

**Objective:** Migrate top 10 reports from Crystal/SSRS to Power BI visuals.

1. **Patient Census Report:**
   - Replace Crystal crosstab with Power BI matrix
   - Convert formulas to DAX measures
   - Add conditional formatting

2. **Daily Revenue Report:**
   - Replace SSRS table with Power BI table visual
   - Implement drill-through to detail
   - Add interactive filters

3. **Quality Metrics Report:**
   - Create KPI visuals for each metric
   - Implement status indicators (Green/Yellow/Red)
   - Add trend sparklines

### Step 5: Implement RLS

**Objective:** Define row-level security roles and DAX filters in the dataset.

1. Create RLS roles in Power BI Desktop:
   - **Department Role:** Users see only their department
   - **Physician Role:** Physicians see only their patients
   - **Executive Role:** Full access

2. Define DAX filters:
   ```dax
   // Department filter
   [department_name] = USERPRINCIPALNAME()
   
   // Physician filter
   [attending_physician] = LOOKUPVALUE(
       Users[email], 
       Users[user_id], 
       USERPRINCIPALNAME()
   )
   ```

### Step 6: Migrate Paginated Reports

**Objective:** Convert regulatory reports to Power BI paginated reports.

1. Identify reports requiring pixel-perfect layout:
   - CMS regulatory submissions
   - Joint Commission compliance reports

2. Use Power BI Report Builder to create paginated reports (.rdl)
3. Migrate SSRS expression logic to Power BI paginated format

### Step 7: Set Up Distribution

**Objective:** Create Power BI App workspace, configure access and subscriptions.

1. Create Power BI workspace:
   - Upload datasets and reports
   - Configure workspace roles (Admin, Member, Contributor, Viewer)

2. Create Power BI App:
   - Select reports to include
   - Configure navigation
   - Set up audiences

3. Configure subscriptions:
   - Email subscriptions for key reports
   - Mobile push notifications
   - Scheduled refreshes

### Step 8: Configure Refresh

**Objective:** Set up scheduled and incremental refresh.

1. Configure scheduled refresh:
   - Daily refresh at 5:00 AM
   - On-demand refresh capability

2. Set up incremental refresh for large datasets:
   - Define date range parameters
   - Configure rolling window (e.g., 2 years historical + current year)

### Step 9: Validate

**Objective:** Compare Power BI output with legacy reports for accuracy.

1. Run side-by-side comparison:
   - Same parameters in both systems
   - Validate totals and calculations
   - Check conditional formatting rules

2. User acceptance testing:
   - Key stakeholders validate output
   - Test mobile access
   - Verify RLS restrictions

## Key Concepts

### Crystal Reports to DAX Translation

| Crystal Formula | DAX Equivalent |
|----------------|----------------|
| `RunningTotal({Revenue})` | `CALCULATE([Total Revenue], FILTER(ALL(Dates), Dates[Date] <= MAX(Dates[Date])))` |
| `WhilePrintingRecords; Global NumberVar x; x := x + 1` | Row number via index column or `RANKX()` |
| `{Table.Field}` field reference | `TableName[ColumnName]` |
| `Sum({Field}, {GroupField})` | `CALCULATE(SUM(Table[Field]), ALLEXCEPT(Table, Table[GroupField]))` |

### SSRS Expression to DAX Translation

| SSRS Expression | DAX Equivalent |
|----------------|----------------|
| `=Sum(Fields!Amount.Value)` | `SUM(Table[Amount])` |
| `=IIF(Fields!Status.Value = "Red", "Alert", "OK")` | `IF(Table[Status] = "Red", "Alert", "OK")` |
| `=Previous(Fields!Amount.Value)` | `CALCULATE([Amount], DATEADD(Calendar[Date], -1, DAY))` |
| `=CountDistinct(Fields!Customer.Value)` | `DISTINCTCOUNT(Table[Customer])` |

## Success Criteria

✅ Legacy Crystal and SSRS reports render with sample data (screenshots provided)  
✅ Power BI semantic model connects to Azure SQL with correct relationships  
✅ DAX measures produce identical results to report stored procedures  
✅ Top 10 reports migrated to interactive Power BI visuals  
✅ Regulatory reports available as Power BI paginated reports  
✅ Row-level security restricts data by department/role  
✅ Power BI App configured with appropriate workspace roles  

## Resources

- [Power BI Documentation](https://docs.microsoft.com/power-bi/)
- [DAX Reference](https://dax.guide)
- [Migrating from SSRS to Power BI](https://docs.microsoft.com/power-bi/guidance/migrate-ssrs-reports-to-power-bi)
- [Power BI Row-Level Security](https://docs.microsoft.com/power-bi/admin/service-admin-rls)

## Troubleshooting

**Issue:** DAX measure returns different results than stored procedure  
**Solution:** Check for differences in NULL handling and aggregation context

**Issue:** RLS not filtering correctly  
**Solution:** Verify username format matches between Azure AD and filter expressions

**Issue:** Paginated report rendering slowly  
**Solution:** Optimize dataset queries, use query folding where possible

---

**Estimated Duration:** 4-6 hours  
**Difficulty:** Intermediate  
**Category:** Data Modernization
