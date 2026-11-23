-- =====================================================================
-- EcoCycle | 04_views_procedures_triggers.sql | Member 3
-- Run AFTER all tables exist (needs Waste_Items.batch_id from Member 1).
-- =====================================================================
USE EcoCycle;

-- =====================================================================
-- VIEWS  (a view stores a QUERY, not data; it re-runs on every SELECT)
-- =====================================================================

-- View 1: recovery per facility. LEFT JOINs so facilities with
-- no batches still appear (with 0), instead of vanishing.
CREATE OR REPLACE VIEW vw_facility_recovery AS
SELECT f.facility_id,
       f.facility_name,
       f.city,
       COUNT(DISTINCT b.batch_id)                 AS total_batches,
       COALESCE(SUM(rm.recovered_weight_kg), 0)   AS total_recovered_kg
FROM Facilities f
LEFT JOIN Recycling_Batches   b  ON b.facility_id = f.facility_id
LEFT JOIN Recovered_Materials rm ON rm.batch_id   = b.batch_id
GROUP BY f.facility_id, f.facility_name, f.city;

-- View 2: total recovered per material, most recovered first.
CREATE OR REPLACE VIEW vw_material_totals AS
SELECT m.material_id,
       m.material_name,
       m.unit,
       COUNT(DISTINCT rm.batch_id)                AS batches_involved,
       COALESCE(SUM(rm.recovered_weight_kg), 0)   AS total_recovered
FROM Materials m
LEFT JOIN Recovered_Materials rm ON rm.material_id = m.material_id
GROUP BY m.material_id, m.material_name, m.unit
ORDER BY total_recovered DESC;

-- View 3: batch summary (items in, weight in, weight recovered).
-- WHY the two derived tables: joining Waste_Items AND Recovered_Materials
-- directly to a batch multiplies rows (items x materials), which inflates
-- SUM(). Aggregating each side first, then joining, avoids that bug.
CREATE OR REPLACE VIEW vw_batch_summary AS
SELECT b.batch_id,
       b.batch_code,
       f.facility_name,
       b.status,
       COALESCE(i.item_count, 0)      AS item_count,
       COALESCE(i.input_kg, 0)        AS input_weight_kg,
       COALESCE(r.recovered_kg, 0)    AS recovered_weight_kg
FROM Recycling_Batches b
JOIN Facilities f ON f.facility_id = b.facility_id
LEFT JOIN (SELECT batch_id, COUNT(*) AS item_count, SUM(weight_kg) AS input_kg
           FROM Waste_Items
           WHERE batch_id IS NOT NULL
           GROUP BY batch_id) i ON i.batch_id = b.batch_id
LEFT JOIN (SELECT batch_id, SUM(recovered_weight_kg) AS recovered_kg
           FROM Recovered_Materials
           GROUP BY batch_id) r ON r.batch_id = b.batch_id;

-- =====================================================================
-- STORED PROCEDURES
-- DELIMITER is changed so the ';' inside the body doesn't end the
-- CREATE statement early (that's a client rule, not a MySQL one).
-- =====================================================================
DELIMITER $$

-- Procedure 1: create a batch
CREATE PROCEDURE sp_create_batch(IN p_facility_id INT, IN p_batch_code VARCHAR(100))
BEGIN
    INSERT INTO Recycling_Batches (facility_id, batch_code, status)
    VALUES (p_facility_id, p_batch_code, 'Pending');
    SELECT LAST_INSERT_ID() AS new_batch_id;
END$$

-- Procedure 2: record a recovered material
CREATE PROCEDURE sp_add_recovered_material(
    IN p_batch_id INT, IN p_material_id INT, IN p_weight DECIMAL(10,2))
BEGIN
    INSERT INTO Recovered_Materials (batch_id, material_id, recovered_weight_kg)
    VALUES (p_batch_id, p_material_id, p_weight);
END$$

-- Procedure 3: complete a batch ATOMICALLY (this is your transaction demo).
-- Either everything succeeds (COMMIT) or nothing does (ROLLBACK).
CREATE PROCEDURE sp_complete_batch(IN p_batch_id INT)
BEGIN
    DECLARE v_count INT DEFAULT 0;

    -- If ANY SQL error happens below, undo everything and re-raise it.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_count
    FROM Recovered_Materials WHERE batch_id = p_batch_id;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot complete a batch with no recovered materials';
    END IF;

    UPDATE Recycling_Batches SET status = 'Completed' WHERE batch_id = p_batch_id;
    UPDATE Waste_Items       SET status = 'Recycled'  WHERE batch_id = p_batch_id;
    -- ^ 'Recycled' must match the status value Member 1/2 use. Confirm it.

    COMMIT;
END$$

-- =====================================================================
-- TRIGGERS
-- NEW = the row being inserted/updated. OLD = the row before an
-- update/delete. In BEFORE triggers you may modify NEW; in AFTER
-- triggers the row is already written, so you can't.
-- =====================================================================

-- Trigger 1: no new recoveries on a batch that is already Completed
CREATE TRIGGER trg_block_recovery_on_completed
BEFORE INSERT ON Recovered_Materials
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(30);
    SELECT status INTO v_status FROM Recycling_Batches WHERE batch_id = NEW.batch_id;
    IF v_status = 'Completed' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Batch already completed: cannot add recovered materials';
    END IF;
END$$

-- Trigger 2: auto-stamp processed_at when a batch becomes Completed
CREATE TRIGGER trg_batch_set_processed_at
BEFORE UPDATE ON Recycling_Batches
FOR EACH ROW
BEGIN
    IF NEW.status = 'Completed' AND OLD.status <> 'Completed'
       AND NEW.processed_at IS NULL THEN
        SET NEW.processed_at = NOW();
    END IF;
END$$

DELIMITER ;
