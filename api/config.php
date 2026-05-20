<?php
// Database Configuration
define('DB_HOST', 'localhost');
define('DB_NAME', 'harmakko_hw_customer');
define('DB_USER', 'harmakko_hw_custadmin');
define('DB_PASS', 'Customer@Harmaalwale');

// Security
define('JWT_SECRET', 'HW_JWT_harmaalwale_2026_!@#$%^&*');

// Site Configuration
define('SITE_URL', 'https://harmaalwale.com');
define('SITE_NAME', 'HarmaalWale');

// Email Configuration (ALL EMAILS GO TO SUPPORT@)
define('MAIL_HOST', 'mail.harmaalwale.com');
define('MAIL_PORT', 587);
define('MAIL_USER', 'noreply@harmaalwale.com');
define('MAIL_PASS', 'Harmaalwale6969++');
define('MAIL_FROM', 'noreply@harmaalwale.com');
define('MAIL_FROM_NAME', 'HarmaalWale');
define('MAIL_SUPPORT', 'support@harmaalwale.com'); // ALL EMAILS GO HERE
define('MAIL_SELLER', 'support@harmaalwale.com'); // SELLERS TOO

// SMS Configuration (Fast2SMS)
define('SMS_API_KEY', 'QSuhxr6AK2RgJdU9XBvfLE7kHpMjDWO4ecClPNiFq0Iz3V1waZAGhqeXcw6R5ELdxHvnf7Z8zbB1jrWu');
define('SMS_SENDER', 'HWALE');
define('SMS_TEMPLATE_OTP', 'HarmaalWale OTP: {otp}. Valid for 3 minutes. Do not share.');

// OTP Configuration - ITEM #1 FIX
define('OTP_EXPIRY', 3); // 3 MINUTES (was causing failures)
define('OTP_LENGTH', 6);

// File Upload
define('UPLOAD_MAX_SIZE', 5242880); // 5MB
define('ALLOWED_IMAGE_TYPES', ['image/jpeg', 'image/png', 'image/jpg']);

// Timezone
date_default_timezone_set('Asia/Kolkata');

// Error Reporting (disable in production)
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/../error.log');
?>