# Heater Topology Optimization Database

A normalized relational database (3NF) for storing and querying results from an **NSGA-II multi-objective optimization** of printed heater topologies, built during a research internship at **CSIR-NAL** (Council of Scientific & Industrial Research – National Aerospace Laboratories).

## Overview

This project models the full lifecycle of a heater-geometry design space exploration:

| Stage | Table | Rows |
|---|---|---|
| Broad topology sweep | `topology_sweep_results` | ~1 259 candidates |
| Train/test seed sweep | `seed_sweep_results` | split-tagged |
| Pareto-front finalists | `final_candidates` | 23-column objective vector |
| Family-level rollups | `family_summary_snapshot` | aggregate stats |
| Electrical-target funnel | `family_target_summary` | constraint-stage metrics |

## Schema Highlights

- **6 tables**, fully normalized to 3NF with foreign-key constraints.
- `families` is the parent lookup table; every other table references it.
- Proper indexing on frequently filtered columns (`family_id`, `feasible`, `resistance_ohm`).
- `CHECK` constraints for valid `dataset_split` values (`train` / `test`).

## Showcase Queries (`queries.sql`)

Seven interview-ready SQL queries demonstrating:

1. **Window functions** — `RANK() OVER (PARTITION BY ...)` for best candidate per family.
2. **Cross-table consistency check** — snapshot vs. live-computed feasibility rates.
3. **Conditional aggregation** — train/test generalization gap via `CASE WHEN`.
4. **HAVING + subquery logic** — flagging "electrically OK, thermally bad" families.
5. **3-table JOIN** — full candidate lineage across pipeline stages.
6. **ORDER BY + LIMIT** — top-3 lowest thermal-CV candidates.
7. **Funnel analysis** — design space narrowing at each constraint stage.

## Tech Stack

| Component | Technology |
|---|---|
| Database | SQLite 3 (portable, zero-config) |
| Data loader | Python 3 (`sqlite3`, `csv`, `argparse`) |
| Schema definition | Raw SQL DDL |

## Project Structure

```
heater_db/
├── schema.sql      # DDL: 6 tables, indexes, FK constraints
├── load_data.py    # Python ETL script (CSV → SQLite)
├── queries.sql     # 7 showcase analytical queries
├── heater.db       # Pre-built database (ready to query)
└── README.md
```

## Quick Start

```bash
# Query the pre-built database directly
sqlite3 heater.db < queries.sql

# Or rebuild from source CSVs
python load_data.py --data-dir /path/to/csvs --db heater.db --schema schema.sql
```

## Context

This database captures results from an optimization pipeline that designs printed heater elements for aerospace applications. The optimizer (NSGA-II) evaluates candidate geometries across multiple objectives:

- **Electrical resistance** — target 7 Ω (6–8 Ω window)
- **Thermal uniformity** — coefficient of variation across heater zones
- **Hotspot fraction** — percentage of area exceeding thermal threshold
- **Power density uniformity** — evenness of heat distribution
- **Current crowding** — max-to-mean current ratio

## Notes on Portability

The schema targets SQLite but includes comments for Postgres migration:
- `AUTOINCREMENT` → `GENERATED ALWAYS AS IDENTITY`
- `INTEGER` booleans → native `BOOLEAN`
- `datetime('now')` → `now()`

## License

Internal research project — CSIR-NAL.
