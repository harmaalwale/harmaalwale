-- ============================================================
--  HarmaalWale — Complete Database Schema
--  Database: harmakko_users
--  Run this in cPanel → phpMyAdmin
-- ============================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+05:30";

-- ── USERS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `users` (
  `id`            INT AUTO_INCREMENT PRIMARY KEY,
  `name`          VARCHAR(200) NOT NULL,
  `email`         VARCHAR(200) UNIQUE,
  `mobile`        VARCHAR(15) UNIQUE NOT NULL,
  `mobile_verified` TINYINT(1) DEFAULT 0,
  `password_hash` VARCHAR(255),
  `role`          ENUM('user','admin') DEFAULT 'user',
  `avatar`        VARCHAR(500),
  `dob`           DATE,
  `gender`        ENUM('male','female','other'),
  `is_active`     TINYINT(1) DEFAULT 1,
  `auth_token`    VARCHAR(500),
  `last_login`    DATETIME,
  `created_at`    DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── OTP CODES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `otp_codes` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `mobile`     VARCHAR(15) NOT NULL,
  `code`       VARCHAR(6) NOT NULL,
  `purpose`    ENUM('login','register','reset') DEFAULT 'login',
  `expires_at` DATETIME NOT NULL,
  `used`       TINYINT(1) DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_mobile` (`mobile`),
  INDEX `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── ADDRESSES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `addresses` (
  `id`        INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`   INT NOT NULL,
  `label`     VARCHAR(50) DEFAULT 'Home',
  `name`      VARCHAR(200) NOT NULL,
  `mobile`    VARCHAR(15) NOT NULL,
  `line1`     VARCHAR(300) NOT NULL,
  `line2`     VARCHAR(300),
  `city`      VARCHAR(100) NOT NULL,
  `state`     VARCHAR(100) NOT NULL,
  `pincode`   VARCHAR(10) NOT NULL,
  `is_default` TINYINT(1) DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── PRODUCTS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `products` (
  `id`          INT AUTO_INCREMENT PRIMARY KEY,
  `seller_id`   INT,
  `category`    VARCHAR(100),
  `name`        VARCHAR(300) NOT NULL,
  `slug`        VARCHAR(300) UNIQUE,
  `description` TEXT,
  `price`       DECIMAL(10,2) DEFAULT 0,
  `mrp`         DECIMAL(10,2) DEFAULT 0,
  `stock`       INT DEFAULT 0,
  `images`      JSON,
  `tags`        VARCHAR(500),
  `is_active`   TINYINT(1) DEFAULT 1,
  `created_at`  DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── WISHLIST ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `wishlist` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`    INT NOT NULL,
  `product_id` INT,
  `name`       VARCHAR(300),
  `price`      VARCHAR(100),
  `image`      TEXT,
  `added_at`   DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `user_product` (`user_id`, `product_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── ORDERS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `orders` (
  `id`             INT AUTO_INCREMENT PRIMARY KEY,
  `order_ref`      VARCHAR(20) UNIQUE NOT NULL,
  `user_id`        INT NOT NULL,
  `address_id`     INT,
  `subtotal`       DECIMAL(10,2) DEFAULT 0,
  `shipping`       DECIMAL(10,2) DEFAULT 0,
  `discount`       DECIMAL(10,2) DEFAULT 0,
  `total`          DECIMAL(10,2) DEFAULT 0,
  `payment_method` VARCHAR(50),
  `payment_id`     VARCHAR(200),
  `payment_status` ENUM('pending','paid','failed','refunded') DEFAULT 'pending',
  `status`         ENUM('placed','confirmed','processing','shipped','delivered','cancelled') DEFAULT 'placed',
  `notes`          TEXT,
  `tracking_id`    VARCHAR(200),
  `created_at`     DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── ORDER ITEMS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `order_items` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `order_id`   INT NOT NULL,
  `product_id` INT,
  `name`       VARCHAR(300) NOT NULL,
  `price`      DECIMAL(10,2) NOT NULL,
  `quantity`   INT NOT NULL DEFAULT 1,
  `image`      TEXT,
  FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── CART ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cart` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `user_id`    INT NOT NULL,
  `product_id` INT,
  `name`       VARCHAR(300),
  `price`      DECIMAL(10,2),
  `image`      TEXT,
  `quantity`   INT DEFAULT 1,
  `added_at`   DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── SELLER APPLICATIONS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `seller_applications` (
  `id`           INT AUTO_INCREMENT PRIMARY KEY,
  `ref_code`     VARCHAR(20) UNIQUE NOT NULL,
  `name`         VARCHAR(200) NOT NULL,
  `biz_name`     VARCHAR(200) NOT NULL,
  `email`        VARCHAR(200) NOT NULL,
  `phone`        VARCHAR(30) NOT NULL,
  `city`         VARCHAR(100),
  `state`        VARCHAR(100),
  `gst`          VARCHAR(20),
  `pan`          VARCHAR(20),
  `address`      TEXT,
  `biz_type`     VARCHAR(50),
  `categories`   TEXT,
  `description`  TEXT,
  `website`      VARCHAR(300),
  `instagram`    VARCHAR(200),
  `status`       ENUM('pending','approved','rejected','info_needed') DEFAULT 'pending',
  `admin_notes`  TEXT,
  `reviewed_at`  DATETIME,
  `submitted_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── APPROVED SELLERS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `sellers` (
  `id`             INT AUTO_INCREMENT PRIMARY KEY,
  `application_id` INT,
  `user_id`        INT,
  `biz_name`       VARCHAR(200) NOT NULL,
  `email`          VARCHAR(200) NOT NULL,
  `phone`          VARCHAR(30),
  `city`           VARCHAR(100),
  `gst`            VARCHAR(20),
  `is_active`      TINYINT(1) DEFAULT 1,
  `approved_at`    DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`application_id`) REFERENCES `seller_applications`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── SELLER PRODUCTS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `seller_products` (
  `id`          INT AUTO_INCREMENT PRIMARY KEY,
  `seller_id`   INT NOT NULL,
  `name`        VARCHAR(300) NOT NULL,
  `category`    VARCHAR(100),
  `description` TEXT,
  `price`       DECIMAL(10,2),
  `mrp`         DECIMAL(10,2),
  `stock`       INT DEFAULT 0,
  `images`      JSON,
  `status`      ENUM('pending','approved','rejected','inactive') DEFAULT 'pending',
  `created_at`  DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`seller_id`) REFERENCES `sellers`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── SUPPORT ENQUIRIES ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `enquiries` (
  `id`         INT AUTO_INCREMENT PRIMARY KEY,
  `name`       VARCHAR(200) NOT NULL,
  `email`      VARCHAR(200),
  `mobile`     VARCHAR(15),
  `subject`    VARCHAR(300),
  `message`    TEXT NOT NULL,
  `type`       ENUM('support','product','seller','other') DEFAULT 'support',
  `status`     ENUM('new','read','resolved') DEFAULT 'new',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── DEFAULT ADMIN USER ───────────────────────────────────────
-- Password: HarmaalWale@2026 (change after first login)
INSERT IGNORE INTO `users` (`name`,`email`,`mobile`,`mobile_verified`,`password_hash`,`role`)
VALUES ('Admin','admin@harmaalwale.com','9999999999',1,
        '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','admin');
