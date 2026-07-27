"""
load_data.py
Ingests the 6 NSGA-II run-output CSVs into the normalized heater_db schema.

Usage:
    python3 load_data.py --data-dir /path/to/csvs --db heater.db

Expects these files in --data-dir (exact names from the project):
    candidate_summary.csv
    family_summary.csv
    topology_family_target_summary.csv
    topology_family_sweep.csv
    seed_family_sweep.csv
    seed_family_sweep_test.csv
"""
import argparse
import csv
import json
import sqlite3
import sys
from pathlib import Path


def to_bool_int(v):
    """Coerce assorted truthy CSV representations to 0/1 (or None)."""
    if v is None or v == "":
        return None
    if isinstance(v, bool):
        return int(v)
    s = str(v).strip().lower()
    if s in ("true", "1", "yes", "y"):
        return 1
    if s in ("false", "0", "no", "n"):
        return 0
    return None


def to_float(v):
    if v is None or v == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def upsert_family(cur, family_id, known_families):
    if family_id and family_id not in known_families:
        cur.execute(
            "INSERT OR IGNORE INTO families (family_id, description) VALUES (?, ?)",
            (family_id, None),
        )
        known_families.add(family_id)


def load_topology_sweep(cur, path, known_families):
    rows = read_csv(path)
    n = 0
    for r in rows:
        fam = r.get("family")
        upsert_family(cur, fam, known_families)
        params = r.get("parameters")
        # store parameters as-is if already JSON-like, else wrap as string
        cur.execute(
            """INSERT OR REPLACE INTO topology_sweep_results
               (candidate_id, family_id, parameters, resistance_ohm, current_amp,
                power_w, coverage, feasible, electrical_in_target_6_to_8_ohm,
                in_target_6_to_8_ohm, violations, electrical_note)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                r.get("candidate_id"),
                fam,
                params,
                to_float(r.get("resistance_ohm")),
                to_float(r.get("current_amp")),
                to_float(r.get("power_w")),
                to_float(r.get("coverage")),
                to_bool_int(r.get("feasible")),
                to_bool_int(r.get("electrical_in_target_6_to_8_ohm")),
                to_bool_int(r.get("in_target_6_to_8_ohm")),
                r.get("violations"),
                r.get("electrical_note"),
            ),
        )
        n += 1
    return n


def load_seed_sweep(cur, path, split_label, known_families):
    rows = read_csv(path)
    n = 0
    for r in rows:
        fam = r.get("family")
        upsert_family(cur, fam, known_families)
        cur.execute(
            """INSERT OR REPLACE INTO seed_sweep_results
               (candidate_id, family_id, dataset_split, feasible, resistance_ohm,
                current_A, power_W, power_cv, current_max_over_mean,
                coverage_frac, violations)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            (
                r.get("candidate_id"),
                fam,
                split_label,
                to_bool_int(r.get("feasible")),
                to_float(r.get("resistance_ohm")),
                to_float(r.get("current_A")),
                to_float(r.get("power_W")),
                to_float(r.get("power_cv")),
                to_float(r.get("current_max_over_mean")),
                to_float(r.get("coverage_frac")),
                r.get("violations"),
            ),
        )
        n += 1
    return n


def load_final_candidates(cur, path, known_families):
    rows = read_csv(path)
    n = 0
    for r in rows:
        fam = r.get("family")
        upsert_family(cur, fam, known_families)
        cur.execute(
            """INSERT OR REPLACE INTO final_candidates
               (candidate_id, family_id, feasible, resistance_ohm, current_A, power_W,
                objective_resistance, objective_thermal_uniformity, objective_hotspot,
                objective_crowding, objective_power_cv, objective_spatial_cv, novelty,
                temperature_max_C, temperature_mean_C, temperature_cv_heater,
                temperature_cv_zone, hotspot_fraction, power_density_cv,
                max_current_crowding_ratio, violations, notes, heater_dxf)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                r.get("candidate"),
                fam,
                to_bool_int(r.get("feasible")),
                to_float(r.get("resistance_ohm")),
                to_float(r.get("current_A")),
                to_float(r.get("power_W")),
                to_float(r.get("objective_resistance")),
                to_float(r.get("objective_thermal_uniformity")),
                to_float(r.get("objective_hotspot")),
                to_float(r.get("objective_crowding")),
                to_float(r.get("objective_power_cv")),
                to_float(r.get("objective_spatial_cv")),
                to_float(r.get("novelty")),
                to_float(r.get("temperature_max_C")),
                to_float(r.get("temperature_mean_C")),
                to_float(r.get("temperature_cv_heater")),
                to_float(r.get("temperature_cv_zone")),
                to_float(r.get("hotspot_fraction")),
                to_float(r.get("power_density_cv")),
                to_float(r.get("max_current_crowding_ratio")),
                r.get("violations"),
                r.get("notes"),
                r.get("heater_dxf"),
            ),
        )
        n += 1
    return n


def load_family_summary(cur, path, known_families):
    rows = read_csv(path)
    n = 0
    for r in rows:
        fam = r.get("family")
        upsert_family(cur, fam, known_families)
        cur.execute(
            """INSERT INTO family_summary_snapshot
               (family_id, total, feasible_count, feasibility_rate,
                mean_resistance_ohm, mean_temp_cv_heater, mean_coverage_frac,
                top_violations)
               VALUES (?,?,?,?,?,?,?,?)""",
            (
                fam,
                int(r["total"]) if r.get("total") else None,
                int(r["feasible_count"]) if r.get("feasible_count") else None,
                to_float(r.get("feasibility_rate")),
                to_float(r.get("mean_resistance_ohm")),
                to_float(r.get("mean_temp_cv_heater")),
                to_float(r.get("mean_coverage_frac")),
                r.get("top_violations"),
            ),
        )
        n += 1
    return n


def load_family_target_summary(cur, path, known_families):
    rows = read_csv(path)
    n = 0
    for r in rows:
        fam = r.get("family")
        upsert_family(cur, fam, known_families)
        cur.execute(
            """INSERT INTO family_target_summary
               (family_id, variants, feasible_variants,
                electrical_target_variants_6_to_8_ohm, target_variants_6_to_8_ohm,
                best_resistance_error, best_target_parameters,
                best_electrical_target_parameters)
               VALUES (?,?,?,?,?,?,?,?)""",
            (
                fam,
                int(r["variants"]) if r.get("variants") else None,
                int(r["feasible_variants"]) if r.get("feasible_variants") else None,
                int(r["electrical_target_variants_6_to_8_ohm"])
                if r.get("electrical_target_variants_6_to_8_ohm")
                else None,
                int(r["target_variants_6_to_8_ohm"])
                if r.get("target_variants_6_to_8_ohm")
                else None,
                to_float(r.get("best_resistance_error")),
                r.get("best_target_parameters"),
                r.get("best_electrical_target_parameters"),
            ),
        )
        n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True, help="Directory containing the 6 CSVs")
    ap.add_argument("--db", default="heater.db", help="Output SQLite file")
    ap.add_argument("--schema", default="schema.sql", help="Path to schema.sql")
    args = ap.parse_args()

    data_dir = Path(args.data_dir)
    db_path = Path(args.db)

    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    conn.executescript(Path(args.schema).read_text())
    cur = conn.cursor()
    known_families = set()

    counts = {}
    file_map = [
        ("topology_family_sweep.csv", lambda p: load_topology_sweep(cur, p, known_families)),
        ("seed_family_sweep.csv", lambda p: load_seed_sweep(cur, p, "train", known_families)),
        ("seed_family_sweep_test.csv", lambda p: load_seed_sweep(cur, p, "test", known_families)),
        ("candidate_summary.csv", lambda p: load_final_candidates(cur, p, known_families)),
        ("family_summary.csv", lambda p: load_family_summary(cur, p, known_families)),
        ("topology_family_target_summary.csv", lambda p: load_family_target_summary(cur, p, known_families)),
    ]

    for fname, loader_fn in file_map:
        fpath = data_dir / fname
        if not fpath.exists():
            print(f"  [skip] {fname} not found in {data_dir}", file=sys.stderr)
            continue
        n = loader_fn(fpath)
        counts[fname] = n
        print(f"  [ok]   {fname}: {n} rows loaded")

    conn.commit()
    conn.close()

    print(f"\nDone. Database written to {db_path.resolve()}")
    print(f"Families discovered: {sorted(known_families)}")
    print(f"Row counts: {json.dumps(counts, indent=2)}")


if __name__ == "__main__":
    main()
