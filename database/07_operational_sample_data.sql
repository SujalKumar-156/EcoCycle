-- 1. USERS
INSERT INTO Users
(role_id, organization_id, full_name, email, password_hash, phone, address)
VALUES
(1, 1, 'Rahul Sharma', 'rahul@example.com', 'demo_hash_1', '9000000001', 'Patna'),
(2, 2, 'Priya Singh', 'priya@example.com', 'demo_hash_2', '9000000002', 'Bihta'),
(2, NULL, 'Aman Kumar', 'aman@example.com', 'demo_hash_3', '9000000003', 'Patna'),
(3, 1, 'Rohit Verma', 'rohit@example.com', 'demo_hash_4', '9000000004', 'Patna'),
(3, 2, 'Neha Kumari', 'neha@example.com', 'demo_hash_5', '9000000005', 'Bihta'),
(4, 1, 'Sanjay Das', 'sanjay@example.com', 'demo_hash_6', '9000000006', 'Patna');

-- 2. COLLECTORS
INSERT INTO Collectors
(user_id, centre_id, availability_status)
VALUES
(4, 1, 'AVAILABLE'),
(5, 2, 'AVAILABLE');

-- 3. WASTE ITEMS
INSERT INTO Waste_Items
(user_id, category_id, item_name, brand, item_condition, weight_kg, status)
VALUES
(2, 1, 'Laptop', 'Dell', 'Damaged', 2.50, 'REGISTERED'),
(2, 2, 'Smartphone', 'Samsung', 'Broken Screen', 0.30, 'REGISTERED'),
(3, 1, 'Desktop Computer', 'HP', 'Old', 8.00, 'REGISTERED'),
(3, 3, 'Microwave Oven', 'LG', 'Not Working', 12.00, 'REGISTERED'),
(2, 4, 'Keyboard', 'Logitech', 'Used', 0.50, 'REGISTERED'),
(3, 2, 'Tablet', 'Lenovo', 'Damaged', 0.70, 'REGISTERED');

-- VERIFY
SELECT * FROM Users;
SELECT * FROM Collectors;
SELECT * FROM Waste_Items;



-- PICKUP REQUESTS
USE EcoCycle;

USE EcoCycle;

INSERT INTO Pickup_Requests
(item_id, centre_id, requested_date, preferred_slot, status)
VALUES
(7, 1, '2026-11-24', '10 AM - 12 PM', 'PENDING'),
(8, 1, '2026-11-24', '12 PM - 2 PM', 'PENDING'),
(9, 2, '2026-11-25', '10 AM - 12 PM', 'PENDING'),
(10, 2, '2026-11-25', '2 PM - 4 PM', 'PENDING'),
(11, 1, '2026-11-26', '10 AM - 12 PM', 'PENDING'),
(12, 2, '2026-11-26', '12 PM - 2 PM', 'PENDING');


-- PICKUP ASSIGNMENTS
USE EcoCycle;

INSERT INTO Pickup_Assignments
(request_id, collector_id, status)
VALUES
(43, 17, 'ASSIGNED'),
(44, 17, 'ASSIGNED'),
(45, 18, 'ASSIGNED'),
(46, 18, 'ASSIGNED'),
(47, 17, 'ASSIGNED'),
(48, 18, 'ASSIGNED');

-- Update collection status
UPDATE Waste_Items
SET status = 'COLLECTED'
WHERE item_id BETWEEN 1 AND 6;

-- Update requests
UPDATE Pickup_Requests
SET status = 'COMPLETED'
WHERE request_id BETWEEN 1 AND 6;

-- Record collection time
UPDATE Pickup_Assignments
SET collected_at = CURRENT_TIMESTAMP
WHERE assignment_id BETWEEN 1 AND 6;

-- INVENTORY
USE EcoCycle;

INSERT INTO Inventory
(centre_id, item_id, current_weight_kg, inventory_status)
VALUES
(1, 7, 2.50, 'AVAILABLE'),
(1, 8, 0.30, 'AVAILABLE'),
(2, 9, 8.00, 'AVAILABLE'),
(2, 10, 12.00, 'AVAILABLE'),
(1, 11, 0.50, 'AVAILABLE'),
(2, 12, 0.70, 'AVAILABLE');

INSERT INTO Shipments
(centre_id, facility_id, item_id, tracking_code, status)
VALUES
(1, 1, 7, 'ECO-SHIP-001', 'IN_TRANSIT'),
(1, 1, 8, 'ECO-SHIP-002', 'IN_TRANSIT'),
(2, 2, 9, 'ECO-SHIP-003', 'IN_TRANSIT'),
(2, 2, 10, 'ECO-SHIP-004', 'IN_TRANSIT'),
(1, 1, 11, 'ECO-SHIP-005', 'IN_TRANSIT'),
(2, 2, 12, 'ECO-SHIP-006', 'IN_TRANSIT');


INSERT INTO Recycling_Batches
(facility_id, batch_code, processed_at, status)
VALUES
(1, 'ECO-BATCH-001', NOW(), 'COMPLETED'),
(2, 'ECO-BATCH-002', NOW(), 'COMPLETED');

INSERT INTO Materials (material_name, unit)
VALUES
('Copper', 'kg'),
('Aluminium', 'kg'),
('Plastic', 'kg'),
('Gold', 'gram'),
('Iron', 'kg');

-- VERIFY
SELECT * FROM Pickup_Requests;
SELECT * FROM Pickup_Assignments;
SELECT * FROM Inventory;

DESCRIBE Materials;
DESCRIBE Shipments;
DESCRIBE Inventory;
DESCRIBE Pickup_Requests;
DESCRIBE Pickup_Assignments;
DESCRIBE Recycling_Batches;
DESCRIBE Recovered_Materials;

INSERT INTO Recovered_Materials
(batch_id, material_id, recovered_weight_kg)
VALUES
(1, 1, 0.40),  -- Copper
(1, 2, 0.60),  -- Aluminium
(1, 3, 0.30),  -- Plastic
(2, 1, 0.80),  -- Copper
(2, 5, 1.20),-- Iron 
(2, 3, 0.50);  -- Plastic


SELECT
    rm.recovery_id,
    rb.batch_code,
    m.material_name,
    rm.recovered_weight_kg,
    m.unit
FROM Recovered_Materials rm
JOIN Recycling_Batches rb ON rm.batch_id = rb.batch_id
JOIN Materials m ON rm.material_id = m.material_id;

UPDATE Waste_Items
SET batch_id = 1
WHERE item_id IN (7, 8, 11);

UPDATE Waste_Items
SET batch_id = 2
WHERE item_id IN (9, 10, 12);
SELECT item_id, item_name, batch_id
FROM Waste_Items;
