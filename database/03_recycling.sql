-- =====================================================================
-- EcoCycle | 07_recycling_reports.sql | Member 3
-- Report queries, transaction demo, and EXPLAIN/index demo.
-- Run AFTER 01, 03 and 06. Run section by section (select the lines,
-- then use the "execute selection" button) so you can screenshot each.
-- =====================================================================
USE EcoCycle;

-- R1. INNER JOIN across 4 tables: what each facility recovered, by material
SELECT f.facility_name, b.batch_code, m.material_name, rm.recovered_weight_kg
FROM Facilities f
INNER JOIN Recycling_Batches   b  ON b.facility_id = f.facility_id
INNER JOIN Recovered_Materials rm ON rm.batch_id   = b.batch_id
INNER JOIN Materials           m  ON m.material_id = rm.material_id
ORDER BY f.facility_name, b.batch_code;

-- R2. LEFT JOIN: batches that have recovered nothing yet
-- (unmatched rows get NULL on the right side; IS NULL filters to them)
SELECT b.batch_code, b.status
FROM Recycling_Batches b
LEFT JOIN Recovered_Materials rm ON rm.batch_id = b.batch_id
WHERE rm.recovery_id IS NULL;

-- R3. Aggregate + HAVING: facilities that recovered more than 50 kg
-- (WHERE filters rows BEFORE grouping; HAVING filters groups AFTER)
SELECT f.facility_name, SUM(rm.recovered_weight_kg) AS total_kg
FROM Facilities f
JOIN Recycling_Batches   b  ON b.facility_id = f.facility_id
JOIN Recovered_Materials rm ON rm.batch_id   = b.batch_id
GROUP BY f.facility_id, f.facility_name
HAVING SUM(rm.recovered_weight_kg) > 50;

-- R4. Subquery: materials whose total exceeds the average single recovery
SELECT m.material_name, SUM(rm.recovered_weight_kg) AS total_kg
FROM Materials m
JOIN Recovered_Materials rm ON rm.material_id = m.material_id
GROUP BY m.material_id, m.material_name
HAVING SUM(rm.recovered_weight_kg) >
       (SELECT AVG(recovered_weight_kg) FROM Recovered_Materials);

-- R5. Use the views
SELECT * FROM vw_facility_recovery;
SELECT * FROM vw_material_totals;
SELECT * FROM vw_batch_summary;

-- =====================================================================
-- PROCEDURE + TRIGGER DEMOS (screenshot each result)
-- Run these BEFORE you demo the web app, or the app starts with
-- batch 4 already completed. They change data.
-- =====================================================================
CALL sp_create_batch(3, 'BATCH-2026-005');
CALL sp_add_recovered_material(4, 1, 5.50);   -- batch 4 is PENDING: allowed
CALL sp_complete_batch(4);                    -- succeeds: COMMIT
SELECT batch_id, status, processed_at FROM Recycling_Batches WHERE batch_id = 4;
                                              -- processed_at set by trigger 2

-- Trigger 1 should now FAIL (batch 4 is COMPLETED):
-- CALL sp_add_recovered_material(4, 2, 3.00);

-- Rollback path: batch 5 has no recoveries, so this raises an error
-- and the handler rolls back. Status must stay 'PENDING'.
-- CALL sp_complete_batch(5);
-- SELECT status FROM Recycling_Batches WHERE batch_id = 5;

-- =====================================================================
-- TRANSACTION DEMO (manual COMMIT / ROLLBACK)
-- =====================================================================
START TRANSACTION;
INSERT INTO Materials (material_name, unit) VALUES ('Silver', 'kg');
SELECT * FROM Materials;          -- Silver visible inside the transaction
ROLLBACK;
SELECT * FROM Materials;          -- Silver is gone

START TRANSACTION;
INSERT INTO Materials (material_name, unit) VALUES ('Nickel', 'kg');
COMMIT;                           -- Nickel is now permanent

-- =====================================================================
-- INDEXING + EXPLAIN DEMO
-- Compare the 'type', 'key' and 'rows' columns before vs after.
-- NOTE: with only ~10 rows MySQL may still choose a full scan; if the
-- 'after' EXPLAIN doesn't change, use the FORCE INDEX line. Explain
-- that honestly in the viva.
-- =====================================================================
EXPLAIN SELECT * FROM Recovered_Materials WHERE recovered_weight_kg > 10;

CREATE INDEX idx_rm_weight ON Recovered_Materials (recovered_weight_kg);

EXPLAIN SELECT * FROM Recovered_Materials WHERE recovered_weight_kg > 10;
EXPLAIN SELECT * FROM Recovered_Materials FORCE INDEX (idx_rm_weight)
        WHERE recovered_weight_kg > 10;