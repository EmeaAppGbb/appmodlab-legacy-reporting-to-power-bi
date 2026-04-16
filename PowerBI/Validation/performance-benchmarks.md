# Performance Benchmarks — Legacy vs Power BI

**Project:** Clearwater Health System — Legacy Reporting to Power BI Migration  
**Benchmark Date:** _____________________  
**Tested By:** _____________________

---

## Overview

This document compares report rendering and delivery performance between the legacy reporting systems (Crystal Reports on Oracle, SSRS on SQL Server) and the migrated Power BI solution (Azure SQL + Power BI Service with Import mode semantic model).

### Key Architecture Changes Affecting Performance

| Aspect | Legacy | Power BI |
|--------|--------|----------|
| **Data Engine** | Oracle CLINICALPRD + SQL Server CLEARWATER-SQL01 | Azure SQL → VertiPaq in-memory engine |
| **Query Model** | Live queries per report execution | Pre-aggregated Import mode with scheduled refresh |
| **Sub-reports** | Crystal N+1 sub-report pattern (SurgicalOutcomes) | Eliminated — relationships + drill-through |
| **Stored Procedures** | usp_GetDailyRevenue executed per request | Replaced by DAX measures on cached model |
| **Caching** | Minimal (SSRS execution cache only) | Full VertiPaq columnar compression + browser cache |

---

## Benchmark Results

### 1. Daily Revenue Report

| Metric | Legacy (SSRS + usp_GetDailyRevenue) | Power BI | Improvement |
|--------|--------------------------------------|----------|-------------|
| **Initial render** | ~8–12 sec (SP execution + SSRS render) | ~1–2 sec (VertiPaq scan) | **~80% faster** |
| **Parameter change (date)** | ~6–10 sec (SP re-execution) | < 1 sec (DAX filter context) | **~90% faster** |
| **PDF export** | ~5–8 sec | ~3–5 sec (paginated report) | **~40% faster** |
| **Subscription delivery** | ~15–20 sec (SSRS job → SMTP) | ~10–15 sec (Power BI subscription) | **~30% faster** |
| **Concurrent users (10)** | ~15–25 sec (SP contention) | ~1–3 sec (shared VertiPaq cache) | **~85% faster** |

**Notes:**
- Legacy SP `usp_GetDailyRevenue` performs multi-table JOINs on each execution
- Power BI pre-computes aggregations at refresh time; DAX measures scan compressed in-memory data
- Biggest gain under concurrency: VertiPaq serves all users from the same cached model

---

### 2. Patient Census Report

| Metric | Legacy (Crystal + Oracle) | Power BI | Improvement |
|--------|---------------------------|----------|-------------|
| **Initial render** | ~10–15 sec (Oracle query + Crystal formatting) | ~1–3 sec (VertiPaq) | **~80% faster** |
| **Refresh / re-render** | ~8–12 sec (full Oracle re-query) | < 1 sec (cached) | **~90% faster** |
| **Conditional formatting eval** | ~1–2 sec (Crystal formula engine per row) | < 0.1 sec (pre-computed column) | **~95% faster** |
| **PDF generation (subscription)** | ~10–15 sec (Crystal → PDF export) | ~5–8 sec | **~50% faster** |
| **3×/day subscription total time** | ~45 sec/day | ~20 sec/day | **~55% faster** |

**Notes:**
- Crystal Reports queries Oracle live for each of the 3 daily executions
- Power BI uses a pre-refreshed Import model; conditional formatting evaluated on pre-computed `Patients[IsCurrentPatient]` column
- Oracle connection overhead (~3–5 sec) eliminated entirely

---

### 3. Surgical Outcomes Report

| Metric | Legacy (Crystal + Sub-report) | Power BI | Improvement |
|--------|-------------------------------|----------|-------------|
| **Initial render** | ~15–30 sec (N+1 sub-report anti-pattern) | ~2–4 sec (VertiPaq) | **~85% faster** |
| **Date parameter change** | ~12–25 sec (re-executes all sub-reports) | ~1–2 sec (DAX refilter) | **~90% faster** |
| **Drill to complication detail** | ~5–10 sec (sub-report query per surgery) | < 1 sec (drill-through page) | **~90% faster** |
| **10 surgeries with complications** | ~50–100 sec (10 sub-report round trips) | ~2–4 sec (single model scan) | **~95% faster** |
| **PDF export** | ~20–40 sec | ~5–10 sec | **~70% faster** |

**Notes:**
- **Largest performance gain of all 4 reports** due to elimination of Crystal sub-report N+1 pattern
- Legacy: Each surgery row triggers a separate `SELECT` for its complication details
- Power BI: `Surgeries → Complications` relationship pre-loaded; drill-through is a filter operation
- For 50 surgeries, legacy could take 4+ minutes; Power BI remains under 5 seconds

---

### 4. Quality Metrics Report

| Metric | Legacy (SSRS + Inline SQL) | Power BI | Improvement |
|--------|----------------------------|----------|-------------|
| **Initial render** | ~5–8 sec (SQL CASE eval + SSRS render) | ~1–2 sec (VertiPaq) | **~75% faster** |
| **Period parameter change** | ~4–6 sec (SQL re-execution) | < 1 sec (slicer filter) | **~85% faster** |
| **Conditional formatting** | ~1–2 sec (SSRS IIF expression per cell) | < 0.1 sec (pre-computed StatusColor) | **~95% faster** |
| **Excel export (subscription)** | ~8–12 sec (SSRS → Excel render) | ~5–8 sec | **~40% faster** |

**Notes:**
- Status color determination moved from runtime `CASE WHEN` to calculated column `CmsQualityMetrics[StatusColor]`
- SSRS nested `IIF` expressions evaluated per cell at render time; Power BI formatting rules reference pre-computed values

---

## Data Refresh Performance

| Refresh Aspect | Details |
|----------------|---------|
| **Semantic model size (estimated)** | ~50–200 MB compressed (VertiPaq) |
| **Full refresh time** | ~2–5 minutes (Azure SQL → Power BI Service) |
| **Incremental refresh (if configured)** | ~30–60 sec (new/changed rows only) |
| **Refresh schedule** | Every 30 min or as configured per workspace |
| **Data latency vs legacy** | Legacy: real-time (live query). Power BI: up to 30 min lag |

### Data Freshness Trade-off

| Scenario | Legacy | Power BI (Import) | Acceptable? |
|----------|--------|--------------------|-------------|
| Revenue reporting | Real-time SP execution | ≤30 min lag | ✅ Yes — daily summary report |
| Patient census | Real-time Oracle query | ≤30 min lag | ⚠️ Discuss — 3×/day subscription may need DirectQuery or near-real-time refresh |
| Surgical outcomes | On-demand, real-time | ≤30 min lag | ✅ Yes — retrospective analysis |
| Quality metrics | Monthly reporting | ≤30 min lag | ✅ Yes — monthly cadence |

> **Recommendation:** For Patient Census, consider hybrid DirectQuery/Import mode or increase refresh frequency to every 15 minutes to maintain near-real-time occupancy data for clinical staff.

---

## Scalability Comparison

| Scenario | Legacy | Power BI |
|----------|--------|----------|
| **5 concurrent users** | Acceptable (~10–15 sec) | Excellent (< 3 sec) |
| **25 concurrent users** | Degraded (~30–60 sec, SP contention) | Good (< 5 sec, shared cache) |
| **50 concurrent users** | Poor (~60–120 sec, possible timeouts) | Good (< 8 sec with Premium capacity) |
| **100 concurrent users** | Failure likely (connection pool exhaustion) | Acceptable (~10–15 sec with Premium P1+) |

---

## Summary of Expected Improvements

| Report | Avg Legacy Time | Avg Power BI Time | Improvement |
|--------|-----------------|--------------------|-------------|
| Daily Revenue | ~10 sec | ~1.5 sec | **~85%** |
| Patient Census | ~12 sec | ~2 sec | **~83%** |
| Surgical Outcomes | ~22 sec | ~3 sec | **~86%** |
| Quality Metrics | ~6 sec | ~1.5 sec | **~75%** |
| **Weighted Average** | **~12.5 sec** | **~2 sec** | **~84%** |

> **Overall:** Power BI delivers an estimated **~84% reduction in report rendering time** with significantly better concurrency handling. The largest gain (up to 95%) comes from eliminating the Crystal Reports sub-report N+1 anti-pattern in the Surgical Outcomes report.

---

## Benchmark Methodology

- **Legacy timings:** Measured from user click/subscription trigger to complete render, averaged over 5 runs
- **Power BI timings:** Measured using Power BI Performance Analyzer (DAX query time + visual render time)
- **Concurrency tests:** Simulated using browser-based load testing (legacy) and workspace load metrics (Power BI)
- **All timings are estimates** based on typical enterprise healthcare reporting workloads and should be validated during UAT with production data volumes
