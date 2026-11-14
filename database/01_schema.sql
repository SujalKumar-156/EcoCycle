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
