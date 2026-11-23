-- ===== RUN THIS ONE FILE: part 1 = sample data (03), part 2 = views/procedures/triggers (06) =====
-- =====================================================================
-- EcoCycle | 03_recycling.sql | Member 3 (DATA + CONSTRAINT ONLY)
-- Member 1's 01_schema.sql ALREADY creates Facilities, Materials,
-- Recycling_Batches and Recovered_Materials (and the Waste_Items.batch_id
-- foreign key). So this file creates NO tables. Run it right AFTER
-- 01_schema.sql, and BEFORE Member 2's file (their Shipments need the
-- facility ids below).
-- Status values follow Member 1's convention: UPPERCASE.
-- =====================================================================
USE EcoCycle;

-- 01_schema.sql has no CHECK on batch status; add it here.
ALTER TABLE Recycling_Batches
    ADD CONSTRAINT chk_batch_status
    CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED'));

-- ---------- Sample data (parents before children) ----------
INSERT INTO Facilities (facility_id, facility_name, address, city, license_number, contact_phone) VALUES
(1, 'GreenTech Recyclers',  '12 Industrial Area', 'Patna',   'LIC-BR-1001', '9000000001'),
(2, 'MetalWorks E-Cycle',   '45 Ring Road',       'Ranchi',  'LIC-JH-2002', '9000000002'),
(3, 'EcoRecover Pvt Ltd',   '8 Tech Park',        'Kolkata', 'LIC-WB-3003', '9000000003');

INSERT INTO Materials (material_id, material_name, unit) VALUES
(1, 'Copper',    'kg'),
(2, 'Aluminium', 'kg'),
(3, 'Plastic',   'kg'),
(4, 'Gold',      'kg'),
(5, 'Lead',      'kg'),
(6, 'Glass',     'kg');

INSERT INTO Recycling_Batches (batch_id, facility_id, batch_code, processed_at, status) VALUES
(1, 1, 'BATCH-2026-001', '2026-11-10 10:00:00', 'COMPLETED'),
(2, 1, 'BATCH-2026-002', '2026-11-12 11:30:00', 'COMPLETED'),
(3, 2, 'BATCH-2026-003', '2026-11-15 09:15:00', 'COMPLETED'),
(4, 3, 'BATCH-2026-004', NULL,                  'PENDING');   -- no recoveries: LEFT JOIN demo

INSERT INTO Recovered_Materials (batch_id, material_id, recovered_weight_kg) VALUES
(1, 1, 12.50), (1, 2, 20.00), (1, 3, 15.25), (1, 4, 0.35),
(2, 1,  8.75), (2, 2, 14.50), (2, 5,  6.00),
(3, 3, 18.00), (3, 6,  9.50), (3, 2, 11.25);

-- Run this file ONCE. Re-running it fails on duplicate ids/constraint.
-- To start over: DELETE FROM Recovered_Materials; DELETE FROM Recycling_Batches;
-- DELETE FROM Materials; DELETE FROM Facilities; then drop chk_batch_status.


-- =====================================================================
-- EcoCycle | 06_views_procedures_triggers.sql | Member 3
-- Run AFTER 01_schema.sql and 03_recycling.sql.
-- Safe to re-run: procedures/triggers are dropped first.
-- Status values are UPPERCASE to match 01_schema.sql.
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

DROP PROCEDURE IF EXISTS sp_create_batch$$
DROP PROCEDURE IF EXISTS sp_add_recovered_material$$
DROP PROCEDURE IF EXISTS sp_complete_batch$$
DROP TRIGGER IF EXISTS trg_block_recovery_on_completed$$
DROP TRIGGER IF EXISTS trg_batch_set_processed_at$$

-- Procedure 1: create a batch
CREATE PROCEDURE sp_create_batch(IN p_facility_id INT, IN p_batch_code VARCHAR(100))
BEGIN
    INSERT INTO Recycling_Batches (facility_id, batch_code, status)
    VALUES (p_facility_id, p_batch_code, 'PENDING');
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

    UPDATE Recycling_Batches SET status = 'COMPLETED' WHERE batch_id = p_batch_id;
    UPDATE Waste_Items       SET status = 'RECYCLED'  WHERE batch_id = p_batch_id;
    -- ^ 'RECYCLED' is new vs Member 1's default 'REGISTERED'. Tell the team.

    COMMIT;
END$$

-- =====================================================================
-- TRIGGERS
-- NEW = the row being inserted/updated. OLD = the row before an
-- update/delete. In BEFORE triggers you may modify NEW; in AFTER
-- triggers the row is already written, so you can't.
-- =====================================================================

-- Trigger 1: no new recoveries on a batch that is already COMPLETED
CREATE TRIGGER trg_block_recovery_on_completed
BEFORE INSERT ON Recovered_Materials
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(30);
    SELECT status INTO v_status FROM Recycling_Batches WHERE batch_id = NEW.batch_id;
    IF v_status = 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Batch already completed: cannot add recovered materials';
    END IF;
END$$

-- Trigger 2: auto-stamp processed_at when a batch becomes COMPLETED
CREATE TRIGGER trg_batch_set_processed_at
BEFORE UPDATE ON Recycling_Batches
FOR EACH ROW
BEGIN
    IF NEW.status = 'COMPLETED' AND OLD.status <> 'COMPLETED'
       AND NEW.processed_at IS NULL THEN
        SET NEW.processed_at = NOW();
    END IF;
END$$

DELIMITER ;
