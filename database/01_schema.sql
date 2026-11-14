CREATE DATABASE EcoCycle;

USE EcoCycle;

SELECT DATABASE();


USE EcoCycle;

-- 1. ROLES
CREATE TABLE Roles (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255)
) ENGINE=InnoDB;

-- 2. ORGANIZATIONS
CREATE TABLE Organizations (
    organization_id INT AUTO_INCREMENT PRIMARY KEY,
    organization_name VARCHAR(150) NOT NULL,
    organization_type VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(15),
    address VARCHAR(255)
) ENGINE=InnoDB;

-- 3. CATEGORIES
CREATE TABLE Categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255)
) ENGINE=InnoDB;

-- 4. COLLECTION CENTRES
CREATE TABLE Collection_Centres (
    centre_id INT AUTO_INCREMENT PRIMARY KEY,
    centre_name VARCHAR(150) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    phone VARCHAR(15)
) ENGINE=InnoDB;

-- 5. FACILITIES
CREATE TABLE Facilities (
    facility_id INT AUTO_INCREMENT PRIMARY KEY,
    facility_name VARCHAR(150) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    license_number VARCHAR(100) UNIQUE,
    contact_phone VARCHAR(15)
) ENGINE=InnoDB;

-- Verify table creation
SHOW TABLES;


USE EcoCycle;

-- 6. USERS
CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    role_id INT NOT NULL,
    organization_id INT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255),
    phone VARCHAR(15),
    address VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id)
        REFERENCES Roles(role_id),

    CONSTRAINT fk_users_organization
        FOREIGN KEY (organization_id)
        REFERENCES Organizations(organization_id)
) ENGINE=InnoDB;


-- 7. COLLECTORS
CREATE TABLE Collectors (
    collector_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    centre_id INT NOT NULL,
    availability_status VARCHAR(30) DEFAULT 'AVAILABLE',

    CONSTRAINT fk_collectors_user
        FOREIGN KEY (user_id)
        REFERENCES Users(user_id),

    CONSTRAINT fk_collectors_centre
        FOREIGN KEY (centre_id)
        REFERENCES Collection_Centres(centre_id)
) ENGINE=InnoDB;


-- 8. WASTE ITEMS
CREATE TABLE Waste_Items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    category_id INT NOT NULL,
    item_name VARCHAR(150) NOT NULL,
    brand VARCHAR(100),
    item_condition VARCHAR(50),
    weight_kg DECIMAL(10,2),
    status VARCHAR(30) DEFAULT 'REGISTERED',
    registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_waste_user
        FOREIGN KEY (user_id)
        REFERENCES Users(user_id),

    CONSTRAINT fk_waste_category
        FOREIGN KEY (category_id)
        REFERENCES Categories(category_id),

    CONSTRAINT chk_waste_weight
        CHECK (weight_kg IS NULL OR weight_kg > 0)
) ENGINE=InnoDB;


-- Verify the tables
SHOW TABLES;

-- Inspect their structures
DESCRIBE Users;
DESCRIBE Collectors;
DESCRIBE Waste_Items;



USE EcoCycle;

-- 9. PICKUP REQUESTS
CREATE TABLE Pickup_Requests (
    request_id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT NOT NULL UNIQUE,
    centre_id INT NOT NULL,
    requested_date DATE NOT NULL,
    preferred_slot VARCHAR(50),
    status VARCHAR(30) DEFAULT 'PENDING',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_request_item
        FOREIGN KEY (item_id)
        REFERENCES Waste_Items(item_id),

    CONSTRAINT fk_request_centre
        FOREIGN KEY (centre_id)
        REFERENCES Collection_Centres(centre_id)
) ENGINE=InnoDB;


-- 10. PICKUP ASSIGNMENTS
CREATE TABLE Pickup_Assignments (
    assignment_id INT AUTO_INCREMENT PRIMARY KEY,
    request_id INT NOT NULL,
    collector_id INT NOT NULL,
    assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    collected_at DATETIME NULL,
    actual_weight_kg DECIMAL(10,2),
    status VARCHAR(30) DEFAULT 'ASSIGNED',

    CONSTRAINT fk_assignment_request
        FOREIGN KEY (request_id)
        REFERENCES Pickup_Requests(request_id),

    CONSTRAINT fk_assignment_collector
        FOREIGN KEY (collector_id)
        REFERENCES Collectors(collector_id),

    CONSTRAINT chk_actual_weight
        CHECK (
            actual_weight_kg IS NULL
            OR actual_weight_kg > 0
        )
) ENGINE=InnoDB;


-- 11. INVENTORY
CREATE TABLE Inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    centre_id INT NOT NULL,
    item_id INT NOT NULL UNIQUE,
    received_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    current_weight_kg DECIMAL(10,2) NOT NULL,
    inventory_status VARCHAR(30) DEFAULT 'AVAILABLE',

    CONSTRAINT fk_inventory_centre
        FOREIGN KEY (centre_id)
        REFERENCES Collection_Centres(centre_id),

    CONSTRAINT fk_inventory_item
        FOREIGN KEY (item_id)
        REFERENCES Waste_Items(item_id),

    CONSTRAINT chk_inventory_weight
        CHECK (current_weight_kg > 0)
) ENGINE=InnoDB;


-- Verify
SHOW TABLES;

DESCRIBE Pickup_Requests;
DESCRIBE Pickup_Assignments;
DESCRIBE Inventory;



USE EcoCycle;

-- 12. SHIPMENTS
CREATE TABLE Shipments (
    shipment_id INT AUTO_INCREMENT PRIMARY KEY,
    centre_id INT NOT NULL,
    facility_id INT NOT NULL,
    item_id INT NOT NULL UNIQUE,
    shipped_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    received_at DATETIME NULL,
    tracking_code VARCHAR(100) UNIQUE,
    status VARCHAR(30) DEFAULT 'IN_TRANSIT',

    CONSTRAINT fk_shipment_centre
        FOREIGN KEY (centre_id)
        REFERENCES Collection_Centres(centre_id),

    CONSTRAINT fk_shipment_facility
        FOREIGN KEY (facility_id)
        REFERENCES Facilities(facility_id),

    CONSTRAINT fk_shipment_item
        FOREIGN KEY (item_id)
        REFERENCES Waste_Items(item_id)
) ENGINE=InnoDB;


-- 13. RECYCLING BATCHES
CREATE TABLE Recycling_Batches (
    batch_id INT AUTO_INCREMENT PRIMARY KEY,
    facility_id INT NOT NULL,
    batch_code VARCHAR(100) NOT NULL UNIQUE,
    processed_at DATETIME,
    status VARCHAR(30) DEFAULT 'PENDING',

    CONSTRAINT fk_batch_facility
        FOREIGN KEY (facility_id)
        REFERENCES Facilities(facility_id)
) ENGINE=InnoDB;


-- 14. MATERIALS
CREATE TABLE Materials (
    material_id INT AUTO_INCREMENT PRIMARY KEY,
    material_name VARCHAR(100) NOT NULL UNIQUE,
    unit VARCHAR(20) DEFAULT 'kg'
) ENGINE=InnoDB;


-- 15. RECOVERED MATERIALS
CREATE TABLE Recovered_Materials (
    recovery_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    material_id INT NOT NULL,
    recovered_weight_kg DECIMAL(10,2) NOT NULL,
    recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_recovered_batch
        FOREIGN KEY (batch_id)
        REFERENCES Recycling_Batches(batch_id),

    CONSTRAINT fk_recovered_material
        FOREIGN KEY (material_id)
        REFERENCES Materials(material_id),

    CONSTRAINT uq_batch_material
        UNIQUE (batch_id, material_id),

    CONSTRAINT chk_recovered_weight
        CHECK (recovered_weight_kg > 0)
) ENGINE=InnoDB;


-- Verify
SHOW TABLES;


ALTER TABLE Waste_Items
ADD COLUMN batch_id INT NULL;

ALTER TABLE Waste_Items
ADD CONSTRAINT fk_waste_batch
FOREIGN KEY (batch_id)
REFERENCES Recycling_Batches(batch_id);

SHOW TABLES;

SELECT COUNT(*) AS total_tables
FROM information_schema.tables
WHERE table_schema = 'EcoCycle';

