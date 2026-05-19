<?php
// ============================================================
// HarmaalWale Configuration — UPDATED WITH FAST2SMS API KEY
// ============================================================

define('DB_HOST', 'localhost');
define('DB_NAME', 'harmakko_hw_customer');
define('DB_USER', 'harmakko_hw_custadmin');
define('DB_PASS', 'Customer@Harmaalwale');
define('JWT_SECRET', 'HW_JWT_harmaalwale_2026_!@#$%^&*');
define('ADMIN_TOKEN', 'HW_ADMIN_harmaalwale_2026');
define('SITE_URL', 'https://harmaalwale.com');

// Mail Configuration
define('MAIL_HOST', 'mail.harmaalwale.com');
define('MAIL_PORT', 587);
define('MAIL_USER', 'noreply@harmaalwale.com');
define('MAIL_PASS', 'Harmaalwale6969++');
define('MAIL_FROM', 'noreply@harmaalwale.com');
define('MAIL_FROM_NAME', 'HarmaalWale');
define('MAIL_SUPPORT', 'support@harmaalwale.com');

// Fast2SMS Configuration — API KEY ADDED ✅
define('SMS_API_KEY', 'QSuhxr6AK2RgJdU9XBvfLE7kHpMjDWO4ecClPNiFq0Iz3V1waZAGhqeXcw6R5ELdxHvnf7Z8zbB1jrWu');
define('SMS_SENDER', 'HWALE');
define('OTP_EXPIRY', 10); // minutes

// Payment Gateways
define('RAZORPAY_KEY_ID', 'YOUR_RAZORPAY_KEY_ID');
define('RAZORPAY_KEY_SECRET', 'YOUR_RAZORPAY_SECRET');
define('PAYU_KEY', 'YOUR_PAYU_KEY');
define('PAYU_SALT', 'YOUR_PAYU_SALT');
define('PAYU_MODE', 'test');

// Environment
define('DEBUG_MODE', false);
define('LOG_FILE', __DIR__ . '/../error.log');

?>
