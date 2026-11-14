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
