
USE EcoCycle;

-- 1. ROLES
INSERT INTO Roles (role_name, description) VALUES
('ADMIN', 'System administrator'),
('CUSTOMER', 'E-waste contributor'),
('COLLECTOR', 'E-waste collection staff'),
('FACILITY_MANAGER', 'Recycling facility manager');

-- 2. ORGANIZATIONS
INSERT INTO Organizations
(organization_name, organization_type, email, phone, address)
VALUES
('GreenTech Solutions', 'Recycling Company',
 'greentech@example.com', '9876543210', 'Patna, Bihar'),
('EcoCare Foundation', 'NGO',
 'ecocare@example.com', '9876543211', 'Bihta, Bihar');

-- 3. CATEGORIES
INSERT INTO Categories (category_name, description) VALUES
('Computers', 'Laptops and desktops'),
('Mobile Devices', 'Phones and tablets'),
('Home Appliances', 'Electronic household equipment'),
('Accessories', 'Chargers, cables and peripherals');

-- 4. COLLECTION CENTRES
INSERT INTO Collection_Centres
(centre_name, address, city, phone)
VALUES
('Patna E-Waste Centre', 'Bailey Road', 'Patna', '9876500001'),
('Bihta Collection Hub', 'Bihta Main Road', 'Bihta', '9876500002');

-- 5. FACILITIES
INSERT INTO Facilities
(facility_name, address, city, license_number, contact_phone)
VALUES
('Green Recycling Plant', 'Industrial Area', 'Patna',
 'LIC-001', '9876500003'),
('Tech Recovery Unit', 'Industrial Zone', 'Bihta',
 'LIC-002', '9876500004');

-- VERIFY MASTER DATA
SELECT * FROM Roles;
SELECT * FROM Organizations;
SELECT * FROM Categories;
SELECT * FROM Collection_Centres;
SELECT * FROM Facilities;
