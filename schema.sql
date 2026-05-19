-- ============================================================
--  HarmaalWale — Complete Customer Database Schema
--  Database : harmakko_hw_customer
--  Run in   : cPanel → phpMyAdmin → Select DB → SQL tab → paste & run
-- ============================================================

SET NAMES utf8mb4;
SET time_zone = '+05:30';
SET foreign_key_checks = 0;

-- ── USERS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `users` (
  `id`               INT AUTO_INCREMENT PRIMARY KEY,
  `name`             VARCHAR(120) NOT NULL,
  `email`            VARCHAR(160) DEFAULT NULL,
  `mobile`           VARCHAR(15)  DEFAULT NULL,
  `password_hash`    VARCHAR(255) DEFAULT NULL,
  `role`             ENUM('user','vendor','admin') NOT NULL DEFAULT 'user',
  `avatar`           VARCHAR(255) DEFAULT NULL,
  `dob`              DATE         DEFAULT NULL,
  `gender`           ENUM('male','female','other') DEFAULT NULL,
  `mobile_verified`  TINYINT(1)   DEFAULT 0,
  `email_verified`   TINYINT(1)   DEFAULT 0,
  `city`             VARCHAR(100) DEFAULT NULL,
  `state`            VARCHAR(100) DEFAULT NULL,
  `pincode`          VARCHAR(10)  DEFAULT NULL,
  `country`          VARCHAR(60)  DEFAULT 'India',
  `lat`              DECIMAL(10,8) DEFAULT NULL,
  `lng`              DECIMAL(11,8) DEFAULT NULL,
  `last_login`       DATETIME     DEFAULT NULL,
  `created_at`       DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `email`  (`email`),
  UNIQUE KEY `mobile` (`mobile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── ADDRESSES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `addresses` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`    INT          NOT NULL,
  `label`      VARCHAR(30)  DEFAULT 'Home',
  `name`       VARCHAR(120) NOT NULL,
  `phone`      VARCHAR(15)  NOT NULL,
  `line1`      VARCHAR(255) NOT NULL,
  `line2`      VARCHAR(255) DEFAULT NULL,
  `city`       VARCHAR(100) NOT NULL,
  `state`      VARCHAR(100) NOT NULL,
  `pincode`    VARCHAR(10)  NOT NULL,
  `country`    VARCHAR(60)  DEFAULT 'India',
  `lat`        DECIMAL(10,8) DEFAULT NULL,
  `lng`        DECIMAL(11,8) DEFAULT NULL,
  `is_default` TINYINT(1)   DEFAULT 0,
  `created_at` DATETIME     DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── OTP CODES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `otp_codes` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `mobile`     VARCHAR(15) NOT NULL,
  `code`       VARCHAR(6)  NOT NULL,
  `purpose`    VARCHAR(20) DEFAULT 'login',
  `expires_at` DATETIME    NOT NULL,
  `used`       TINYINT(1)  DEFAULT 0,
  `created_at` DATETIME    DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_mobile` (`mobile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── EMAIL VERIFICATION ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS `email_verifications` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`    INT         NOT NULL,
  `token`      VARCHAR(100) NOT NULL UNIQUE,
  `expires_at` DATETIME    NOT NULL,
  `used`       TINYINT(1)  DEFAULT 0,
  `created_at` DATETIME    DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── LOGIN HISTORY ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `login_history` (
  `id`          INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`     INT          NOT NULL,
  `ip_address`  VARCHAR(45)  DEFAULT NULL,
  `user_agent`  VARCHAR(255) DEFAULT NULL,
  `device_type` VARCHAR(30)  DEFAULT NULL,
  `method`      VARCHAR(20)  DEFAULT 'email',
  `login_at`    DATETIME     DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── CATEGORIES ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `categories` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `name`       VARCHAR(100) NOT NULL,
  `slug`       VARCHAR(120) NOT NULL UNIQUE,
  `parent_id`  INT          DEFAULT NULL,
  `image`      VARCHAR(255) DEFAULT NULL,
  `status`     ENUM('active','inactive') DEFAULT 'active',
  `sort_order` INT          DEFAULT 0,
  `created_at` DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── PRODUCTS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `products` (
  `id`          INT AUTO_INCREMENT PRIMARY KEY,
  `seller_id`   INT          DEFAULT NULL,
  `category_id` INT          DEFAULT NULL,
  `name`        VARCHAR(255) NOT NULL,
  `slug`        VARCHAR(300) NOT NULL UNIQUE,
  `description` TEXT         DEFAULT NULL,
  `short_desc`  VARCHAR(500) DEFAULT NULL,
  `price`       DECIMAL(10,2) NOT NULL DEFAULT 0,
  `mrp`         DECIMAL(10,2) DEFAULT NULL,
  `stock`       INT          DEFAULT 0,
  `sku`         VARCHAR(100) DEFAULT NULL,
  `images`      JSON         DEFAULT NULL,
  `tags`        JSON         DEFAULT NULL,
  `status`      ENUM('active','inactive','draft') DEFAULT 'active',
  `created_at`  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── ORDERS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `orders` (
  `id`                  INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`             INT          NOT NULL,
  `order_number`        VARCHAR(30)  NOT NULL UNIQUE,
  `status`              ENUM('pending','confirmed','processing','shipped','delivered','cancelled','returned','refunded') DEFAULT 'pending',
  `subtotal`            DECIMAL(10,2) DEFAULT 0,
  `discount`            DECIMAL(10,2) DEFAULT 0,
  `shipping`            DECIMAL(10,2) DEFAULT 0,
  `tax`                 DECIMAL(10,2) DEFAULT 0,
  `total`               DECIMAL(10,2) DEFAULT 0,
  `payment_method`      VARCHAR(50)  DEFAULT NULL,
  `payment_status`      ENUM('pending','paid','failed','refunded') DEFAULT 'pending',
  `payment_id`          VARCHAR(100) DEFAULT NULL,
  `shipping_address_id` INT          DEFAULT NULL,
  `tracking_number`     VARCHAR(100) DEFAULT NULL,
  `invoice_number`      VARCHAR(50)  DEFAULT NULL,
  `notes`               TEXT         DEFAULT NULL,
  `created_at`          DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updated_at`          DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── ORDER ITEMS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `order_items` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `order_id`   INT          NOT NULL,
  `product_id` INT          DEFAULT NULL,
  `seller_id`  INT          DEFAULT NULL,
  `name`       VARCHAR(255) NOT NULL,
  `price`      DECIMAL(10,2) NOT NULL,
  `qty`        INT          NOT NULL DEFAULT 1,
  `subtotal`   DECIMAL(10,2) NOT NULL,
  `status`     VARCHAR(30)  DEFAULT 'pending',
  FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── CART ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cart` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`    INT NOT NULL,
  `product_id` INT NOT NULL,
  `qty`        INT DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `user_product` (`user_id`,`product_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── WISHLIST ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `wishlist` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`    INT NOT NULL,
  `product_id` INT NOT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `user_product` (`user_id`,`product_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── SELLER APPLICATIONS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `seller_applications` (
  `id`                INT AUTO_INCREMENT PRIMARY KEY,
  `name`              VARCHAR(120) NOT NULL,
  `email`             VARCHAR(160) NOT NULL,
  `phone`             VARCHAR(15)  NOT NULL,
  `business_name`     VARCHAR(200) NOT NULL,
  `business_type`     VARCHAR(50)  DEFAULT NULL,
  `years_in_business` VARCHAR(30)  DEFAULT NULL,
  `categories`        TEXT         DEFAULT NULL,
  `description`       TEXT         DEFAULT NULL,
  `address`           TEXT         DEFAULT NULL,
  `city`              VARCHAR(100) DEFAULT NULL,
  `state`             VARCHAR(100) DEFAULT NULL,
  `pincode`           VARCHAR(10)  DEFAULT NULL,
  `gst_number`        VARCHAR(20)  DEFAULT NULL,
  `pan_number`        VARCHAR(15)  DEFAULT NULL,
  `bank_account`      VARCHAR(30)  DEFAULT NULL,
  `bank_name`         VARCHAR(100) DEFAULT NULL,
  `ifsc_code`         VARCHAR(15)  DEFAULT NULL,
  `upi_id`            VARCHAR(50)  DEFAULT NULL,
  `status`            ENUM('pending','approved','rejected') DEFAULT 'pending',
  `reference_code`    VARCHAR(20)  DEFAULT NULL,
  `created_at`        DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── SELLERS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `sellers` (
  `id`              INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`         INT          DEFAULT NULL,
  `application_id`  INT          DEFAULT NULL,
  `business_name`   VARCHAR(200) DEFAULT NULL,
  `is_active`       TINYINT(1)   DEFAULT 1,
  `created_at`      DATETIME     DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`)        REFERENCES `users`(`id`),
  FOREIGN KEY (`application_id`) REFERENCES `seller_applications`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── ENQUIRIES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `enquiries` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`    INT          DEFAULT NULL,
  `name`       VARCHAR(120) NOT NULL,
  `email`      VARCHAR(160) DEFAULT NULL,
  `phone`      VARCHAR(15)  DEFAULT NULL,
  `category`   VARCHAR(50)  DEFAULT 'General',
  `subject`    VARCHAR(255) DEFAULT NULL,
  `message`    TEXT         NOT NULL,
  `status`     ENUM('open','in_progress','resolved') DEFAULT 'open',
  `created_at` DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── NOTIFICATIONS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `notifications` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`    INT          NOT NULL,
  `title`      VARCHAR(255) NOT NULL,
  `message`    TEXT         DEFAULT NULL,
  `type`       VARCHAR(30)  DEFAULT 'info',
  `is_read`    TINYINT(1)   DEFAULT 0,
  `created_at` DATETIME     DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET foreign_key_checks = 1;

-- ── DEFAULT DATA ─────────────────────────────────────────────
INSERT IGNORE INTO `users` (`name`,`email`,`mobile`,`role`,`mobile_verified`,`email_verified`)
VALUES ('Admin','admin@harmaalwale.com','9999999999','admin',1,1);

INSERT IGNORE INTO `categories` (`name`,`slug`,`status`,`sort_order`) VALUES
('MFD Spare Parts',  'mfd-spare-parts',  'active',   1),
('Refurbished MFDs', 'refurbished-mfds', 'active',   2),
('Fashion',          'fashion',          'active',   3),
('IT Products',      'it-products',      'inactive', 4),
('Home Essentials',  'home-essentials',  'inactive', 5),
('Electronics',      'electronics',      'inactive', 6);
