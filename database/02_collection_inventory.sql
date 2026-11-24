
USE EcoCycle;

-- 1. INSERT CUSTOMERS AND COLLECTORS

INSERT INTO Users
(role_id, organization_id, full_name, email, password_hash, phone, address)
SELECT r.role_id, NULL, d.full_name, d.email, d.password_hash, d.phone, d.address
FROM (
    SELECT 'CUSTOMER' role_name, 'Aarav Sharma' full_name, 'aarav.customer@ecocycle.test' email, 'demo_hash_aarav' password_hash, '9000000001' phone, 'Kankarbagh, Patna' address
    UNION ALL
    SELECT 'CUSTOMER', 'Priya Kumari', 'priya.customer@ecocycle.test', 'demo_hash_priya', '9000000002', 'Bihta, Bihar'
    UNION ALL
    SELECT 'CUSTOMER', 'Rohan Verma', 'rohan.customer@ecocycle.test', 'demo_hash_rohan', '9000000003', 'Danapur, Patna'
    UNION ALL
    SELECT 'COLLECTOR', 'Amit Kumar', 'amit.collector@ecocycle.test', 'demo_hash_amit', '9000000011', 'Patna, Bihar'
    UNION ALL
    SELECT 'COLLECTOR', 'Neha Singh', 'neha.collector@ecocycle.test', 'demo_hash_neha', '9000000012', 'Bihta, Bihar'
) d
JOIN Roles r ON r.role_name = d.role_name
WHERE NOT EXISTS (
    SELECT 1 FROM Users u WHERE u.email = d.email
);


-- 2. REGISTER COLLECTORS

INSERT INTO Collectors (user_id, centre_id, availability_status)
SELECT u.user_id, cc.centre_id, 'AVAILABLE'
FROM Users u
JOIN Collection_Centres cc
ON cc.centre_name = CASE
    WHEN u.email = 'amit.collector@ecocycle.test'
    THEN 'Patna E-Waste Centre'
    ELSE 'Bihta Collection Hub'
END
WHERE u.email IN ('amit.collector@ecocycle.test',
                  'neha.collector@ecocycle.test')
AND NOT EXISTS (
    SELECT 1 FROM Collectors c WHERE c.user_id = u.user_id
);


-- 3. REGISTER E-WASTE ITEMS

INSERT INTO Waste_Items
(user_id, category_id, item_name, brand, item_condition, weight_kg, status)
SELECT u.user_id, c.category_id, d.item_name, d.brand,
       d.item_condition, d.weight_kg, 'REGISTERED'
FROM (
    SELECT 'aarav.customer@ecocycle.test' email,
           'Computers' category, 'Dell Inspiron Laptop' item_name,
           'Dell' brand, 'NON_WORKING' item_condition, 2.40 weight_kg
    UNION ALL
    SELECT 'priya.customer@ecocycle.test', 'Mobile Devices',
           'Samsung Galaxy Phone', 'Samsung', 'DAMAGED', 0.18
    UNION ALL
    SELECT 'rohan.customer@ecocycle.test', 'Computers',
           'HP Desktop CPU', 'HP', 'NON_WORKING', 5.20
    UNION ALL
    SELECT 'aarav.customer@ecocycle.test', 'Accessories',
           'USB Keyboard', 'Logitech', 'WORKING', 0.45
) d
JOIN Users u ON u.email = d.email
JOIN Categories c ON c.category_name = d.category
WHERE NOT EXISTS (
    SELECT 1 FROM Waste_Items wi
    WHERE wi.user_id = u.user_id
    AND wi.item_name = d.item_name
);


-- 4. CREATE PICKUP REQUESTS

INSERT INTO Pickup_Requests
(item_id, centre_id, requested_date, preferred_slot, status)
SELECT wi.item_id, cc.centre_id,
       DATE_ADD(CURRENT_DATE, INTERVAL d.days DAY),
       d.slot, 'PENDING'
FROM (
    SELECT 'aarav.customer@ecocycle.test' email,
           'Dell Inspiron Laptop' item_name,
           'Patna E-Waste Centre' centre, 1 days,
           '10:00 AM - 12:00 PM' slot
    UNION ALL
    SELECT 'priya.customer@ecocycle.test',
           'Samsung Galaxy Phone', 'Bihta Collection Hub',
           1, '12:00 PM - 02:00 PM'
    UNION ALL
    SELECT 'rohan.customer@ecocycle.test',
           'HP Desktop CPU', 'Patna E-Waste Centre',
           2, '10:00 AM - 12:00 PM'
) d
JOIN Users u ON u.email = d.email
JOIN Waste_Items wi ON wi.user_id = u.user_id
                   AND wi.item_name = d.item_name
JOIN Collection_Centres cc ON cc.centre_name = d.centre
WHERE NOT EXISTS (
    SELECT 1 FROM Pickup_Requests pr
    WHERE pr.item_id = wi.item_id
);


-- 5. ASSIGN COLLECTORS

INSERT INTO Pickup_Assignments
(request_id, collector_id, status)
SELECT pr.request_id, c.collector_id, 'ASSIGNED'
FROM Pickup_Requests pr
JOIN Waste_Items wi ON wi.item_id = pr.item_id
JOIN Users customer ON customer.user_id = wi.user_id
JOIN Users cu ON cu.email = CASE
    WHEN customer.email = 'priya.customer@ecocycle.test'
    THEN 'neha.collector@ecocycle.test'
    ELSE 'amit.collector@ecocycle.test'
END
JOIN Collectors c ON c.user_id = cu.user_id
WHERE customer.email IN (
    'aarav.customer@ecocycle.test',
    'priya.customer@ecocycle.test',
    'rohan.customer@ecocycle.test'
)
AND wi.item_name IN (
    'Dell Inspiron Laptop',
    'Samsung Galaxy Phone',
    'HP Desktop CPU'
)
AND NOT EXISTS (
    SELECT 1 FROM Pickup_Assignments pa
    WHERE pa.request_id = pr.request_id
);


-- 6. UPDATE COLLECTION STATUS

UPDATE Pickup_Assignments pa
JOIN Pickup_Requests pr ON pr.request_id = pa.request_id
JOIN Waste_Items wi ON wi.item_id = pr.item_id
SET pa.status = 'COLLECTED',
    pa.collected_at = CURRENT_TIMESTAMP,
    pa.actual_weight_kg = CASE wi.item_name
        WHEN 'Dell Inspiron Laptop' THEN 2.30
        WHEN 'Samsung Galaxy Phone' THEN 0.17
        WHEN 'HP Desktop CPU' THEN 5.00
    END
WHERE wi.item_name IN (
    'Dell Inspiron Laptop',
    'Samsung Galaxy Phone',
    'HP Desktop CPU'
);

UPDATE Pickup_Requests pr
JOIN Pickup_Assignments pa ON pa.request_id = pr.request_id
SET pr.status = 'COMPLETED'
WHERE pa.status = 'COLLECTED';

UPDATE Waste_Items wi
JOIN Pickup_Requests pr ON pr.item_id = wi.item_id
JOIN Pickup_Assignments pa ON pa.request_id = pr.request_id
SET wi.status = 'COLLECTED'
WHERE pa.status = 'COLLECTED';


-- 7. ADD ITEMS TO INVENTORY

INSERT INTO Inventory
(centre_id, item_id, current_weight_kg, inventory_status)
SELECT pr.centre_id, wi.item_id, pa.actual_weight_kg, 'AVAILABLE'
FROM Pickup_Requests pr
JOIN Pickup_Assignments pa ON pa.request_id = pr.request_id
JOIN Waste_Items wi ON wi.item_id = pr.item_id
WHERE pa.status = 'COLLECTED'
AND pa.actual_weight_kg IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM Inventory i WHERE i.item_id = wi.item_id
);


-- 8. UPDATE AND DELETE

UPDATE Collectors c
JOIN Users u ON u.user_id = c.user_id
SET c.availability_status = 'AVAILABLE'
WHERE u.email IN (
    'amit.collector@ecocycle.test',
    'neha.collector@ecocycle.test'
);

DELETE FROM Pickup_Requests
WHERE status = 'CANCELLED'
AND NOT EXISTS (
    SELECT 1 FROM Pickup_Assignments pa
    WHERE pa.request_id = Pickup_Requests.request_id
);


-- 9. FOUR JOIN QUERIES

-- Query 1: Customer and item details

SELECT u.full_name, u.email, wi.item_name, wi.brand,
       c.category_name, wi.item_condition, wi.weight_kg, wi.status
FROM Users u
JOIN Waste_Items wi ON wi.user_id = u.user_id
JOIN Categories c ON c.category_id = wi.category_id
ORDER BY u.full_name;


-- Query 2: Pickup request details

SELECT pr.request_id, u.full_name, wi.item_name,
       cc.centre_name, pr.requested_date,
       pr.preferred_slot, pr.status
FROM Pickup_Requests pr
JOIN Waste_Items wi ON wi.item_id = pr.item_id
JOIN Users u ON u.user_id = wi.user_id
JOIN Collection_Centres cc ON cc.centre_id = pr.centre_id;


-- Query 3: Collector assignment details

SELECT pa.assignment_id, collector.full_name AS collector,
       customer.full_name AS customer, wi.item_name,
       pa.assigned_at, pa.collected_at,
       pa.actual_weight_kg, pa.status
FROM Pickup_Assignments pa
JOIN Collectors c ON c.collector_id = pa.collector_id
JOIN Users collector ON collector.user_id = c.user_id
JOIN Pickup_Requests pr ON pr.request_id = pa.request_id
JOIN Waste_Items wi ON wi.item_id = pr.item_id
JOIN Users customer ON customer.user_id = wi.user_id;


-- Query 4: Inventory details

SELECT i.inventory_id, wi.item_name, cat.category_name,
       cc.centre_name, i.current_weight_kg,
       i.inventory_status, i.received_at
FROM Inventory i
JOIN Waste_Items wi ON wi.item_id = i.item_id
JOIN Categories cat ON cat.category_id = wi.category_id
JOIN Collection_Centres cc ON cc.centre_id = i.centre_id;


-- 10. FIVE REPORTS

-- Report 1: Requests by status

SELECT status, COUNT(*) AS total_requests
FROM Pickup_Requests
GROUP BY status;


-- Report 2: Collector performance

SELECT u.full_name AS collector,
       COUNT(pa.assignment_id) AS total_assignments,
       COALESCE(SUM(pa.actual_weight_kg), 0) AS total_weight
FROM Collectors c
JOIN Users u ON u.user_id = c.user_id
LEFT JOIN Pickup_Assignments pa
ON pa.collector_id = c.collector_id
AND pa.status = 'COLLECTED'
GROUP BY c.collector_id, u.full_name
ORDER BY total_weight DESC;


-- Report 3: Inventory by centre

SELECT cc.centre_name, COUNT(i.inventory_id) AS total_items,
       COALESCE(SUM(i.current_weight_kg), 0) AS total_weight
FROM Collection_Centres cc
LEFT JOIN Inventory i ON i.centre_id = cc.centre_id
GROUP BY cc.centre_id, cc.centre_name;


-- Report 4: Inventory by category

SELECT cat.category_name, COUNT(i.inventory_id) AS total_items,
       COALESCE(SUM(i.current_weight_kg), 0) AS total_weight
FROM Categories cat
LEFT JOIN Waste_Items wi ON wi.category_id = cat.category_id
LEFT JOIN Inventory i ON i.item_id = wi.item_id
GROUP BY cat.category_id, cat.category_name
ORDER BY total_weight DESC;


-- Report 5: Items without pickup requests

SELECT wi.item_id, wi.item_name, u.full_name, wi.status
FROM Waste_Items wi
JOIN Users u ON u.user_id = wi.user_id
LEFT JOIN Pickup_Requests pr ON pr.item_id = wi.item_id
WHERE pr.request_id IS NULL;


-- 11. FINAL VERIFICATION

-- Verify users

SELECT user_id, full_name, email
FROM Users
WHERE email LIKE '%@ecocycle.test';


-- Verify collectors

SELECT c.collector_id, u.full_name, cc.centre_name,
       c.availability_status
FROM Collectors c
JOIN Users u ON u.user_id = c.user_id
JOIN Collection_Centres cc ON cc.centre_id = c.centre_id
WHERE u.email LIKE '%@ecocycle.test';


-- Verify complete collection workflow

SELECT wi.item_name, customer.full_name AS customer,
       pr.request_id, pr.status AS pickup_status,
       collector.full_name AS collector,
       pa.status AS assignment_status,
       pa.actual_weight_kg, i.inventory_status,
       i.current_weight_kg
FROM Waste_Items wi
JOIN Users customer ON customer.user_id = wi.user_id
LEFT JOIN Pickup_Requests pr ON pr.item_id = wi.item_id
LEFT JOIN Pickup_Assignments pa ON pa.request_id = pr.request_id
LEFT JOIN Collectors c ON c.collector_id = pa.collector_id
LEFT JOIN Users collector ON collector.user_id = c.user_id
LEFT JOIN Inventory i ON i.item_id = wi.item_id
WHERE wi.item_name IN (
    'Dell Inspiron Laptop', 'Samsung Galaxy Phone',
    'HP Desktop CPU', 'USB Keyboard'
)
ORDER BY wi.item_name;


-- Verify total records in all tables

SELECT 'Users' table_name, COUNT(*) total_rows FROM Users
UNION ALL
SELECT 'Collectors', COUNT(*) FROM Collectors
UNION ALL
SELECT 'Waste_Items', COUNT(*) FROM Waste_Items
UNION ALL
SELECT 'Pickup_Requests', COUNT(*) FROM Pickup_Requests
UNION ALL
SELECT 'Pickup_Assignments', COUNT(*) FROM Pickup_Assignments
UNION ALL
SELECT 'Inventory', COUNT(*) FROM Inventory;
