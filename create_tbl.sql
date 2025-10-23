drop database assignment2;
create database assignment2;
use assignment2;

-- 1. Table for clients
CREATE TABLE clients (
    client_id CHAR(36) NOT NULL,
    name VARCHAR(255),
    age TINYINT UNSIGNED,
    gender ENUM('Male', 'Female'),
    device_id CHAR(36),
    PRIMARY KEY (client_id),
    KEY idx_device_id (device_id) -- Index for future joins
);


-- 2. Table for devices
CREATE TABLE devices (
    device_id CHAR(36) NOT NULL,
    device_type ENUM('Computer', 'Mobile', 'Laptop', 'Tablet', 'Watch'),
    device_model VARCHAR(50),
    device_OS ENUM('IOS', 'Android', 'Windows', 'Samsung', 'Linux', 'Other'),
    sold BOOLEAN,
    shop_id CHAR(36),
    PRIMARY KEY (device_id),
    KEY idx_shop_id (shop_id) -- Index for future joins
);


-- 3. Table for shops
CREATE TABLE shops (
    shop_id CHAR(36) NOT NULL,
    shop_address VARCHAR(255),
    device_id CHAR(36), -- Assuming this was an intended column
    employee_amount TINYINT UNSIGNED,
    client_id CHAR(36),
    amount_sold SMALLINT UNSIGNED,
    PRIMARY KEY (shop_id),
    KEY idx_device_id (device_id), -- Index for future joins
    KEY idx_client_id (client_id)  -- Index for future joins
);