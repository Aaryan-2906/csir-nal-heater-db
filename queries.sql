-- ============================================================
-- Showcase queries for heater_db
-- These are the ones to walk an interviewer through.
-- ============================================================

-- 1. Best feasible candidate per family, ranked by closeness to 7.0 ohm target
--    (window function: RANK() partitioned by family)
SELECT family_id, candidate_id, resistance_ohm,
       ABS(resistance_ohm - 7.0) AS resistance_error,
       RANK() OVER (PARTITION BY family_id ORDER BY ABS(resistance_ohm - 7.0)) AS rank_in_family
FROM final_candidates
WHERE feasible = 1
ORDER BY family_id, rank_in_family;


-- 2. Feasibility rate comparison: snapshot table vs. live-computed from raw sweep
--    (join across two independently-loaded tables, cross-check consistency)
SELECT s.family_id,
       s.feasibility_rate                                    AS reported_feasibility_rate,
       ROUND(1.0 * SUM(t.feasible) / COUNT(*), 3)             AS computed_feasibility_rate,
       COUNT(*)                                               AS sweep_rows
FROM family_summary_snapshot s
JOIN topology_sweep_results t ON t.family_id = s.family_id
GROUP BY s.family_id, s.feasibility_rate;


-- 3. Train/test generalization gap per family
--    (self-join style comparison via conditional aggregation)
SELECT family_id,
       ROUND(AVG(CASE WHEN dataset_split = 'train' THEN resistance_ohm END), 3) AS train_mean_ohm,
       ROUND(AVG(CASE WHEN dataset_split = 'test'  THEN resistance_ohm END), 3) AS test_mean_ohm,
       ROUND(AVG(CASE WHEN dataset_split = 'train' THEN power_cv END), 4)       AS train_power_cv,
       ROUND(AVG(CASE WHEN dataset_split = 'test'  THEN power_cv END), 4)       AS test_power_cv
FROM seed_sweep_results
GROUP BY family_id;


-- 4. Families where the electrical target (6-8 ohm) was hit but overall
--    feasibility was still poor -- flags "electrically fine, thermally bad" designs
--    (subquery + having clause)
SELECT family_id,
       COUNT(*)                                          AS total_candidates,
       SUM(electrical_in_target_6_to_8_ohm)               AS in_electrical_target,
       SUM(feasible)                                      AS feasible_count,
       ROUND(1.0 * SUM(feasible) / NULLIF(SUM(electrical_in_target_6_to_8_ohm), 0), 3)
                                                           AS feasible_given_in_target_rate
FROM topology_sweep_results
GROUP BY family_id
HAVING SUM(electrical_in_target_6_to_8_ohm) > 0
ORDER BY feasible_given_in_target_rate ASC;


-- 5. Full candidate lineage: join sweep result -> final candidate -> family target info
--    (3-table join, the "does this candidate look consistent across every stage" check)
SELECT fc.candidate_id,
       fc.family_id,
       fc.resistance_ohm         AS final_resistance,
       tsr.resistance_ohm        AS sweep_resistance,
       fts.best_resistance_error AS family_best_error,
       fc.temperature_cv_heater,
       fc.hotspot_fraction
FROM final_candidates fc
LEFT JOIN topology_sweep_results tsr ON tsr.candidate_id = fc.candidate_id
LEFT JOIN family_target_summary fts ON fts.family_id = fc.family_id
ORDER BY fc.family_id;


-- 6. Top-3 lowest thermal-CV feasible candidates overall (cross-family)
--    (simple but interview-friendly: ORDER BY + LIMIT with a WHERE filter)
SELECT candidate_id, family_id, resistance_ohm, temperature_cv_heater, hotspot_fraction
FROM final_candidates
WHERE feasible = 1
ORDER BY temperature_cv_heater ASC
LIMIT 3;


-- 7. Family-level funnel: variants -> feasible -> in electrical target -> in full target
--    (shows how the design space narrows at each constraint stage)
SELECT family_id,
       variants,
       feasible_variants,
       electrical_target_variants_6_to_8_ohm,
       target_variants_6_to_8_ohm,
       ROUND(1.0 * feasible_variants / NULLIF(variants, 0), 3)                       AS pct_feasible,
       ROUND(1.0 * target_variants_6_to_8_ohm / NULLIF(feasible_variants, 0), 3)     AS pct_feasible_hit_full_target
FROM family_target_summary
ORDER BY pct_feasible_hit_full_target DESC;
