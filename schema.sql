-- ============================================================
-- Heater Topology Optimization Database
-- Normalized schema (3NF) for NSGA-II multi-objective run results
-- Target: SQLite (portable). Notes on Postgres deltas at bottom.
-- ============================================================

PRAGMA foreign_keys = ON;

-- ------------------------------------------------------------
-- 1. FAMILIES  (parent lookup table — every other table FKs here)
-- ------------------------------------------------------------
CREATE TABLE families (
    family_id     TEXT PRIMARY KEY,      -- e.g. 'serpentine', 'spiral'
    description   TEXT
);

-- ------------------------------------------------------------
-- 2. TOPOLOGY_SWEEP_RESULTS
--    Raw per-candidate results from the full topology sweep
--    (source: topology_family_sweep.csv, ~1259 rows)
-- ------------------------------------------------------------
CREATE TABLE topology_sweep_results (
    id                              INTEGER PRIMARY KEY AUTOINCREMENT,
    candidate_id                    TEXT NOT NULL,
    family_id                       TEXT NOT NULL,
    parameters                      TEXT,          -- JSON-encoded param dict
    resistance_ohm                  REAL,
    current_amp                     REAL,
    power_w                         REAL,
    coverage                        REAL,
    feasible                        INTEGER,       -- 0/1
    electrical_in_target_6_to_8_ohm INTEGER,
    in_target_6_to_8_ohm            INTEGER,
    violations                      TEXT,
    electrical_note                 TEXT,
    FOREIGN KEY (family_id) REFERENCES families(family_id),
    UNIQUE (candidate_id)
);

CREATE INDEX idx_sweep_family        ON topology_sweep_results(family_id);
CREATE INDEX idx_sweep_feasible      ON topology_sweep_results(feasible);
CREATE INDEX idx_sweep_resistance    ON topology_sweep_results(resistance_ohm);
CREATE INDEX idx_sweep_in_target     ON topology_sweep_results(in_target_6_to_8_ohm);

-- ------------------------------------------------------------
-- 3. SEED_SWEEP_RESULTS
--    Seed-run results, split across train/test files
--    (source: seed_family_sweep.csv + seed_family_sweep_test.csv)
-- ------------------------------------------------------------
CREATE TABLE seed_sweep_results (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    candidate_id            TEXT NOT NULL,
    family_id               TEXT NOT NULL,
    dataset_split            TEXT NOT NULL CHECK (dataset_split IN ('train','test')),
    feasible                 INTEGER,
    resistance_ohm           REAL,
    current_A                REAL,
    power_W                  REAL,
    power_cv                 REAL,
    current_max_over_mean    REAL,
    coverage_frac            REAL,
    violations                TEXT,
    FOREIGN KEY (family_id) REFERENCES families(family_id),
    UNIQUE (candidate_id, dataset_split)
);

CREATE INDEX idx_seed_family   ON seed_sweep_results(family_id);
CREATE INDEX idx_seed_split    ON seed_sweep_results(dataset_split);

-- ------------------------------------------------------------
-- 4. FINAL_CANDIDATES
--    Fully-evaluated Pareto-front finalists with full objective
--    vector + thermal metrics + DXF artifact reference
--    (source: candidate_summary.csv, 23 cols)
-- ------------------------------------------------------------
CREATE TABLE final_candidates (
    candidate_id                  TEXT PRIMARY KEY,
    family_id                     TEXT NOT NULL,
    feasible                      INTEGER,
    resistance_ohm                REAL,
    current_A                     REAL,
    power_W                       REAL,
    objective_resistance          REAL,
    objective_thermal_uniformity  REAL,
    objective_hotspot             REAL,
    objective_crowding            REAL,
    objective_power_cv            REAL,
    objective_spatial_cv          REAL,
    novelty                       REAL,
    temperature_max_C             REAL,
    temperature_mean_C            REAL,
    temperature_cv_heater         REAL,
    temperature_cv_zone           REAL,
    hotspot_fraction              REAL,
    power_density_cv              REAL,
    max_current_crowding_ratio    REAL,
    violations                    TEXT,
    notes                         TEXT,
    heater_dxf                    TEXT,          -- path/filename of geometry artifact
    FOREIGN KEY (family_id) REFERENCES families(family_id)
);

CREATE INDEX idx_final_family ON final_candidates(family_id);

-- ------------------------------------------------------------
-- 5. FAMILY_SUMMARY_SNAPSHOT
--    Point-in-time aggregate stats per family (denormalized on
--    purpose — this is a materialized rollup, refreshed per run,
--    not a live-computed value, so it's its own table not a view)
--    (source: family_summary.csv)
-- ------------------------------------------------------------
CREATE TABLE family_summary_snapshot (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
    family_id              TEXT NOT NULL,
    snapshot_date           TEXT DEFAULT (datetime('now')),
    total                    INTEGER,
    feasible_count           INTEGER,
    feasibility_rate         REAL,
    mean_resistance_ohm      REAL,
    mean_temp_cv_heater      REAL,
    mean_coverage_frac       REAL,
    top_violations           TEXT,
    FOREIGN KEY (family_id) REFERENCES families(family_id)
);

CREATE INDEX idx_snapshot_family ON family_summary_snapshot(family_id);

-- ------------------------------------------------------------
-- 6. FAMILY_TARGET_SUMMARY
--    Best-fit-to-electrical-target rollup per family
--    (source: topology_family_target_summary.csv)
-- ------------------------------------------------------------
CREATE TABLE family_target_summary (
    id                                        INTEGER PRIMARY KEY AUTOINCREMENT,
    family_id                                 TEXT NOT NULL,
    variants                                  INTEGER,
    feasible_variants                         INTEGER,
    electrical_target_variants_6_to_8_ohm     INTEGER,
    target_variants_6_to_8_ohm                INTEGER,
    best_resistance_error                     REAL,
    best_target_parameters                    TEXT,
    best_electrical_target_parameters         TEXT,
    FOREIGN KEY (family_id) REFERENCES families(family_id)
);

CREATE INDEX idx_target_family ON family_target_summary(family_id);

-- ============================================================
-- Postgres notes (if you want to sound more "production" later):
--   - INTEGER PRIMARY KEY AUTOINCREMENT -> SERIAL / GENERATED ALWAYS AS IDENTITY
--   - Booleans: use native BOOLEAN instead of INTEGER 0/1
--   - datetime('now') -> now()
-- ============================================================
