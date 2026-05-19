<?php
// ============================================================
//  HarmaalWale — Auth API
//  Supports BOTH: Mobile OTP  +  Email/Password
//
//  POST ?action=send_otp        → send OTP to mobile
//  POST ?action=verify_otp      → verify OTP → login/register
//  POST ?action=register        → email + password register
//  POST ?action=login           → email/mobile + password login
//  POST ?action=verify_email    → verify email token
//  POST ?action=resend_verify   → resend verification email
//  POST ?action=forgot_password → send reset link
//  POST ?action=reset_password  → reset with token
//  POST ?action=update_profile  → update profile + GPS location
//  GET  ?action=me              → current user info
// ============================================================
error_reporting(0);
ini_set('display_errors', 0);
require_once 'db.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? getBody()['action'] ?? '';
$body   = getBody();

// ============================================================
//  HELPERS
// ============================================================
function ensureUserTables($db) {
    // Ensure all needed columns exist
    $db->query("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) DEFAULT NULL");
    $db->query("ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified TINYINT(1) DEFAULT 0");
    $db->query("ALTER TABLE users ADD COLUMN IF NOT EXISTS mobile_verified TINYINT(1) DEFAULT 0");
}

function logLogin($db, $userId, $method) {
    $ip = $_SERVER['REMOTE_ADDR'] ?? '';
    $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
    $stmt = $db->prepare("INSERT INTO login_history (user_id,ip_address,user_agent,method) VALUES (?,?,?,?)");
    if ($stmt) { $stmt->bind_param('isss', $userId, $ip, $ua, $method); $stmt->execute(); }
}

// ============================================================
//  GET me
// ============================================================
if ($method === 'GET' && $action === 'me') {
    $auth = requireAuth();
    $db   = getDB();
    $stmt = $db->prepare("SELECT id,name,email,mobile,role,avatar,dob,gender,city,state,pincode,country,lat,lng,mobile_verified,email_verified,created_at FROM users WHERE id=?");
    $stmt->bind_param('i', $auth['uid']);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $db->close();
    if (!$user) jsonResponse(['error' => 'User not found'], 404);
    jsonResponse(['success' => true, 'user' => $user]);
}

// ============================================================
//  POST send_otp  — Mobile OTP login
// ============================================================
if ($method === 'POST' && $action === 'send_otp') {
    $mobile = preg_replace('/[^0-9]/', '', $body['mobile'] ?? '');
    if (strlen($mobile) !== 10) jsonResponse(['error' => 'Enter valid 10-digit mobile number'], 400);

    $db  = getDB();
    $otp = str_pad(rand(100000, 999999), 6, '0', STR_PAD_LEFT);
    $exp = date('Y-m-d H:i:s', time() + (OTP_EXPIRY * 60));

    $db->query("UPDATE otp_codes SET used=1 WHERE mobile='" . $db->real_escape_string($mobile) . "' AND used=0");
    $stmt = $db->prepare("INSERT INTO otp_codes (mobile,code,purpose,expires_at) VALUES (?,?,'login',?)");
    $stmt->bind_param('sss', $mobile, $otp, $exp);
    $stmt->execute();
    $db->close();

    $sent = sendOTP($mobile, $otp);
    if (!$sent) jsonResponse(['error' => 'Failed to send OTP. Try again.'], 500);

    jsonResponse(['success' => true, 'message' => 'OTP sent to +91' . substr($mobile, 0, 2) . 'XXXXXXXX', 'expires_in' => OTP_EXPIRY * 60]);
}

// ============================================================
//  POST verify_otp
// ============================================================
if ($method === 'POST' && $action === 'verify_otp') {
    $mobile = preg_replace('/[^0-9]/', '', $body['mobile'] ?? '');
    $code   = trim($body['otp'] ?? '');
    $name   = trim($body['name'] ?? '');

    if (strlen($mobile) !== 10 || strlen($code) !== 6)
        jsonResponse(['error' => 'Invalid mobile or OTP'], 400);

    $db   = getDB();
    $stmt = $db->prepare("SELECT id FROM otp_codes WHERE mobile=? AND code=? AND used=0 AND expires_at>NOW() ORDER BY id DESC LIMIT 1");
    $stmt->bind_param('ss', $mobile, $code);
    $stmt->execute();
    $otpRow = $stmt->get_result()->fetch_assoc();

    if (!$otpRow) { $db->close(); jsonResponse(['error' => 'Invalid or expired OTP'], 400); }
    $db->query("UPDATE otp_codes SET used=1 WHERE id=" . intval($otpRow['id']));

    // Find or create user
    $stmt = $db->prepare("SELECT id,name,email,mobile,role,avatar FROM users WHERE mobile=? LIMIT 1");
    $stmt->bind_param('s', $mobile);
    $stmt->execute();
    $user  = $stmt->get_result()->fetch_assoc();
    $isNew = false;

    if (!$user) {
        if (!$name) { $db->close(); jsonResponse(['success' => false, 'needs_name' => true, 'message' => 'Enter your name to complete registration']); }
        $stmt = $db->prepare("INSERT INTO users (name,mobile,mobile_verified,role) VALUES (?,?,1,'user')");
        $stmt->bind_param('ss', $name, $mobile);
        $stmt->execute();
        $userId = $db->insert_id;
        $isNew  = true;

        // Welcome email if email provided
        if (!empty($body['email'])) {
            $email = $body['email'];
            $upd = $db->prepare("UPDATE users SET email=? WHERE id=?");
            $upd->bind_param('si', $email, $userId);
            $upd->execute();
            $html = emailTemplate('Welcome to HarmaalWale!', "<p>Hi <strong>" . htmlspecialchars($name) . "</strong>,</p><p>Welcome to HarmaalWale! Your account is ready.</p><a href='" . SITE_URL . "' class='btn'>Start Shopping →</a>");
            sendEmail($email, 'Welcome to HarmaalWale! 🎉', $html);
        }

        $stmt = $db->prepare("SELECT id,name,email,mobile,role,avatar FROM users WHERE id=?");
        $stmt->bind_param('i', $userId);
        $stmt->execute();
        $user = $stmt->get_result()->fetch_assoc();
    } else {
        $userId = $user['id'];
        $db->query("UPDATE users SET mobile_verified=1, last_login=NOW() WHERE id=" . intval($userId));
    }

    logLogin($db, $userId, 'otp');
    $token = createToken($userId, $mobile, $user['role'] ?? 'user');
    $db->close();

    jsonResponse(['success' => true, 'token' => $token, 'user' => $user, 'is_new' => $isNew,
        'message' => $isNew ? 'Account created successfully!' : 'Logged in successfully!']);
}

// ============================================================
//  POST register  — Email + Password
// ============================================================
if ($method === 'POST' && $action === 'register') {
    $name  = trim($body['name']  ?? '');
    $email = strtolower(trim($body['email'] ?? ''));
    $pass  = $body['password'] ?? '';
    $mobile = trim($body['mobile'] ?? '');

    if (!$name || !$email || !$pass) jsonResponse(['error' => 'Name, email and password are required'], 400);
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) jsonResponse(['error' => 'Invalid email address'], 400);
    if (strlen($pass) < 6) jsonResponse(['error' => 'Password must be at least 6 characters'], 400);

    $db = getDB();
    $chk = $db->prepare("SELECT id FROM users WHERE email=? LIMIT 1");
    $chk->bind_param('s', $email);
    $chk->execute();
    $chk->store_result();
    if ($chk->num_rows > 0) { $db->close(); jsonResponse(['error' => 'Email already registered. Sign in instead.'], 409); }
    $chk->close();

    $hash  = password_hash($pass, PASSWORD_BCRYPT, ['cost' => 8]);
    $token = bin2hex(random_bytes(32));
    $exp   = date('Y-m-d H:i:s', time() + 86400);

    $stmt = $db->prepare("INSERT INTO users (name,email,mobile,password_hash,role,email_verified) VALUES (?,?,?,?,'user',0)");
    $stmt->bind_param('ssss', $name, $email, $mobile, $hash);
    $stmt->execute();
    $userId = $db->insert_id;

    // Save verification token
    $v = $db->prepare("INSERT INTO email_verifications (user_id,token,expires_at) VALUES (?,?,?)");
    $v->bind_param('iss', $userId, $token, $exp);
    $v->execute();
    $db->close();

    $link = SITE_URL . '/api/auth.php?action=verify_email&token=' . $token;
    $html = emailTemplate('Verify Your Account',
        "<p>Hi <strong>" . htmlspecialchars($name) . "</strong>,</p>
         <p>Thanks for joining HarmaalWale! Click below to verify your email:</p>
         <a href='$link' class='btn'>Verify My Account →</a>
         <p style='font-size:12px;color:#aaa'>Link expires in 24 hours.</p>");
    sendEmail($email, 'Welcome to HarmaalWale — Verify Your Account', $html);

    jsonResponse(['success' => true, 'message' => 'Account created! Check your email to verify.', 'verify' => true]);
}

// ============================================================
//  GET verify_email
// ============================================================
if ($method === 'GET' && $action === 'verify_email') {
    header('Content-Type: text/html');
    $token = trim($_GET['token'] ?? '');
    if (!$token) { header('Location: ' . SITE_URL . '?verified=fail'); exit; }

    $db   = getDB();
    $stmt = $db->prepare("SELECT ev.id, ev.user_id, u.name, u.email FROM email_verifications ev JOIN users u ON u.id=ev.user_id WHERE ev.token=? AND ev.used=0 AND ev.expires_at>NOW() LIMIT 1");
    $stmt->bind_param('s', $token);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();

    if (!$row) { $db->close(); header('Location: ' . SITE_URL . '?verified=expired'); exit; }

    $db->query("UPDATE users SET email_verified=1 WHERE id=" . intval($row['user_id']));
    $db->query("UPDATE email_verifications SET used=1 WHERE id=" . intval($row['id']));
    $db->close();

    $html = emailTemplate('Email Verified! 🎉',
        "<p>Hi <strong>" . htmlspecialchars($row['name']) . "</strong> 🎉</p>
         <p>Your HarmaalWale account is <strong>verified and ready</strong>!</p>
         <a href='" . SITE_URL . "' class='btn'>Start Shopping →</a>");
    sendEmail($row['email'], "You're verified! Welcome to HarmaalWale 🎉", $html);

    header('Location: ' . SITE_URL . '?verified=success&name=' . urlencode($row['name']));
    exit;
}

// ============================================================
//  POST resend_verify
// ============================================================
if ($method === 'POST' && $action === 'resend_verify') {
    $email = strtolower(trim($body['email'] ?? ''));
    if (!$email) jsonResponse(['error' => 'Email required'], 400);

    $db   = getDB();
    $stmt = $db->prepare("SELECT id,name,email_verified FROM users WHERE email=? LIMIT 1");
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();

    if (!$user) { $db->close(); jsonResponse(['error' => 'Email not found'], 404); }
    if ($user['email_verified']) { $db->close(); jsonResponse(['error' => 'Already verified'], 400); }

    $token = bin2hex(random_bytes(32));
    $exp   = date('Y-m-d H:i:s', time() + 86400);
    $v     = $db->prepare("INSERT INTO email_verifications (user_id,token,expires_at) VALUES (?,?,?)");
    $v->bind_param('iss', $user['id'], $token, $exp);
    $v->execute();
    $db->close();

    $link = SITE_URL . '/api/auth.php?action=verify_email&token=' . $token;
    $html = emailTemplate('Verify Your Account',
        "<p>Hi <strong>" . htmlspecialchars($user['name'] ?? '') . "</strong>,</p>
         <p>Click below to verify your HarmaalWale account:</p>
         <a href='$link' class='btn'>Verify My Account →</a>");
    sendEmail($email, 'HarmaalWale — Verify Your Account', $html);

    jsonResponse(['success' => true, 'message' => 'Verification email sent.']);
}

// ============================================================
//  POST login  — Email/Mobile + Password (unified)
// ============================================================
if ($method === 'POST' && $action === 'login') {
    $identifier = trim($body['identifier'] ?? '');
    $password   = $body['password'] ?? '';

    if (!$identifier || !$password) jsonResponse(['error' => 'Enter email/mobile and password'], 400);

    // Hardcoded admin check
    if (strtolower($identifier) === 'admin' && $password === 'Admin@harmaalwale') {
        $db   = getDB();
        $stmt = $db->query("SELECT id,name,email,mobile,role FROM users WHERE role='admin' LIMIT 1");
        $u    = $stmt ? $stmt->fetch_assoc() : null;
        if (!$u) {
            $db->query("INSERT IGNORE INTO users (name,email,mobile,role,mobile_verified,email_verified) VALUES ('Admin','admin@harmaalwale.com','9999999999','admin',1,1)");
            $u = ['id' => $db->insert_id, 'name' => 'Admin', 'email' => 'admin@harmaalwale.com', 'mobile' => '9999999999', 'role' => 'admin'];
        }
        $token = createToken($u['id'], $u['mobile'], 'admin');
        logLogin($db, $u['id'], 'password');
        $db->close();
        jsonResponse(['success' => true, 'token' => $token, 'user' => $u, 'message' => 'Welcome, Admin!']);
    }

    $db      = getDB();
    $isEmail = filter_var($identifier, FILTER_VALIDATE_EMAIL);
    $cleanM  = preg_replace('/\D/', '', $identifier);

    if ($isEmail) {
        $stmt = $db->prepare("SELECT id,name,email,mobile,role,password_hash,email_verified FROM users WHERE email=? LIMIT 1");
        $stmt->bind_param('s', $identifier);
    } else {
        $stmt = $db->prepare("SELECT id,name,email,mobile,role,password_hash,mobile_verified FROM users WHERE mobile=? LIMIT 1");
        $stmt->bind_param('s', $cleanM);
    }
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();

    if (!$user) { $db->close(); jsonResponse(['error' => 'Account not found. Please register first.'], 404); }
    if (empty($user['password_hash'])) { $db->close(); jsonResponse(['error' => 'No password set. Use OTP login.'], 400); }
    if (!password_verify($password, $user['password_hash'])) { $db->close(); jsonResponse(['error' => 'Incorrect password'], 401); }
    if ($isEmail && !$user['email_verified']) { $db->close(); jsonResponse(['error' => 'Please verify your email first.', 'unverified' => true], 403); }

    $db->query("UPDATE users SET last_login=NOW() WHERE id=" . intval($user['id']));
    logLogin($db, $user['id'], 'password');
    $db->close();

    $token = createToken($user['id'], $user['email'] ?? $user['mobile'], $user['role']);
    unset($user['password_hash']);
    jsonResponse(['success' => true, 'token' => $token, 'user' => $user, 'message' => 'Logged in successfully!']);
}

// ============================================================
//  POST update_profile  — also saves GPS location
// ============================================================
if ($method === 'POST' && $action === 'update_profile') {
    $auth   = requireAuth();
    $db     = getDB();
    $fields = []; $params = []; $types = '';

    $allowed = ['name', 'email', 'dob', 'gender', 'city', 'state', 'pincode', 'country', 'avatar'];
    foreach ($allowed as $f) {
        if (isset($body[$f]) && $body[$f] !== '') {
            $fields[] = "$f=?"; $params[] = $body[$f]; $types .= 's';
        }
    }
    // GPS — only save if provided
    if (isset($body['lat']) && isset($body['lng']) && $body['lat'] !== '' && $body['lng'] !== '') {
        $fields[] = 'lat=?'; $params[] = $body['lat']; $types .= 'd';
        $fields[] = 'lng=?'; $params[] = $body['lng']; $types .= 'd';
    }
    // Password change
    if (!empty($body['password']) && strlen($body['password']) >= 6) {
        $fields[] = 'password_hash=?';
        $params[] = password_hash($body['password'], PASSWORD_BCRYPT, ['cost' => 8]);
        $types   .= 's';
    }

    if ($fields) {
        $sql    = "UPDATE users SET " . implode(',', $fields) . " WHERE id=?";
        $params[] = $auth['uid']; $types .= 'i';
        $stmt   = $db->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
    }

    $stmt = $db->prepare("SELECT id,name,email,mobile,role,avatar,dob,gender,city,state,pincode,country,lat,lng FROM users WHERE id=?");
    $stmt->bind_param('i', $auth['uid']);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $db->close();

    jsonResponse(['success' => true, 'user' => $user]);
}

jsonResponse(['error' => 'Unknown action'], 400);
