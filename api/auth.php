<?php
// ============================================================
//  HarmaalWale — Unified Auth API
//
//  POST /api/auth.php  action=send_otp      → send OTP to mobile
//  POST /api/auth.php  action=verify_otp    → verify OTP + login/register
//  POST /api/auth.php  action=login         → unified login (email/mobile/admin + password)
//  POST /api/auth.php  action=update_profile
//  GET  /api/auth.php  action=me            → current user
//
//  Admin credentials: username "Admin" / password "Admin@harmaalwale"
//  Backend auto-detects: customer / vendor / admin from identifier
// ============================================================
error_reporting(0);
ini_set('display_errors', 0);
require_once 'db.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? getBody()['action'] ?? '';

// ============================================================
//  GET /api/auth.php?action=me  → current user
// ============================================================
if ($method === 'GET' && $action === 'me') {
    $user = requireAuth();
    $db   = getDB();
    $stmt = $db->prepare("SELECT id,name,email,mobile,role,avatar,dob,gender,created_at FROM users WHERE id=?");
    $stmt->bind_param('i', $user['uid']);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $db->close();
    if (!$row) jsonResponse(['error' => 'User not found'], 404);
    jsonResponse(['success' => true, 'user' => $row]);
}

// ============================================================
//  POST action=send_otp
// ============================================================
if ($method === 'POST' && $action === 'send_otp') {
    $b      = getBody();
    $mobile = preg_replace('/[^0-9]/', '', $b['mobile'] ?? '');

    if (strlen($mobile) !== 10) {
        jsonResponse(['error' => 'Enter a valid 10-digit mobile number'], 400);
    }

    $db  = getDB();
    $otp = str_pad(rand(100000, 999999), 6, '0', STR_PAD_LEFT);
    $exp = date('Y-m-d H:i:s', time() + (OTP_EXPIRY * 60));

    $db->query("UPDATE otp_codes SET used=1 WHERE mobile='" . $db->real_escape_string($mobile) . "' AND used=0");
    $stmt = $db->prepare("INSERT INTO otp_codes (mobile,code,purpose,expires_at) VALUES (?,?,?,?)");
    $purpose = 'login';
    $stmt->bind_param('ssss', $mobile, $otp, $purpose, $exp);
    $stmt->execute();
    $db->close();

    $sent = sendOTP($mobile, $otp);
    if (!$sent) {
        jsonResponse(['error' => 'Failed to send OTP. Please try again.'], 500);
    }

    jsonResponse([
        'success'    => true,
        'message'    => "OTP sent to +91 " . substr($mobile, 0, 2) . "XXXXXXXX",
        'expires_in' => OTP_EXPIRY * 60
    ]);
}

// ============================================================
//  POST action=verify_otp
// ============================================================
if ($method === 'POST' && $action === 'verify_otp') {
    $b      = getBody();
    $mobile = preg_replace('/[^0-9]/', '', $b['mobile'] ?? '');
    $code   = trim($b['otp'] ?? '');
    $name   = trim($b['name'] ?? '');

    if (strlen($mobile) !== 10 || strlen($code) !== 6) {
        jsonResponse(['error' => 'Invalid mobile or OTP'], 400);
    }

    $db   = getDB();
    $stmt = $db->prepare(
        "SELECT id FROM otp_codes
         WHERE mobile=? AND code=? AND used=0 AND expires_at > NOW()
         ORDER BY id DESC LIMIT 1"
    );
    $stmt->bind_param('ss', $mobile, $code);
    $stmt->execute();
    $otpRow = $stmt->get_result()->fetch_assoc();

    if (!$otpRow) {
        $db->close();
        jsonResponse(['error' => 'Invalid or expired OTP. Please try again.'], 400);
    }

    $db->query("UPDATE otp_codes SET used=1 WHERE id=" . intval($otpRow['id']));

    // Find user — check customers, vendors, admin
    $stmt = $db->prepare("SELECT id,name,email,mobile,role FROM users WHERE mobile=? LIMIT 1");
    $stmt->bind_param('s', $mobile);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();

    $isNew = false;
    if (!$user) {
        // New user — require name
        if (!$name) {
            $db->close();
            jsonResponse(['success' => false, 'needs_name' => true, 'message' => 'Please enter your name to complete registration']);
        }
        $role = 'user';
        $stmt = $db->prepare("INSERT INTO users (name, mobile, mobile_verified, role) VALUES (?,?,1,'user')");
        $stmt->bind_param('ss', $name, $mobile);
        $stmt->execute();
        $userId = $db->insert_id;
        $isNew  = true;

        if (!empty($b['email'])) {
            $email = $b['email'];
            $db->prepare("UPDATE users SET email=? WHERE id=?")->execute([$email, $userId]);
            $body = emailTemplate('Welcome to HarmaalWale',
                "<p>Hi <strong>" . htmlspecialchars($name) . "</strong>,</p>
                 <p>Welcome to HarmaalWale! Your account has been created successfully with mobile <strong>+91$mobile</strong>.</p>
                 <a href='" . SITE_URL . "' class='btn'>Start Shopping →</a>"
            );
            sendEmail($email, 'Welcome to HarmaalWale! 🎉', $body);
        }
    } else {
        $userId = $user['id'];
        $role   = $user['role'];
        $db->query("UPDATE users SET mobile_verified=1, last_login=NOW() WHERE id=" . intval($userId));
    }

    // Check if user is a vendor (has approved seller record)
    if ($role === 'user') {
        $stmt = $db->prepare(
            "SELECT s.id FROM sellers s
             LEFT JOIN seller_applications sa ON s.application_id = sa.id
             WHERE sa.phone=? AND s.is_active=1 LIMIT 1"
        );
        $stmt->bind_param('s', $mobile);
        $stmt->execute();
        if ($stmt->get_result()->num_rows > 0) {
            $role = 'vendor';
            $db->query("UPDATE users SET role='vendor' WHERE id=" . intval($userId));
        }
    }

    $token = createToken($userId, $mobile, $role);

    $stmt = $db->prepare("SELECT id,name,email,mobile,role,avatar FROM users WHERE id=?");
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $userData = $stmt->get_result()->fetch_assoc();
    $db->close();

    jsonResponse([
        'success' => true,
        'token'   => $token,
        'user'    => $userData,
        'is_new'  => $isNew,
        'message' => $isNew ? 'Account created successfully!' : 'Logged in successfully!'
    ]);
}

// ============================================================
//  POST action=login  → UNIFIED LOGIN
//  Body: { identifier: "email/mobile/Admin", password: "..." }
//  Backend auto-detects user type (admin / vendor / customer)
// ============================================================
if ($method === 'POST' && $action === 'login') {
    $b          = getBody();
    $identifier = trim($b['identifier'] ?? '');
    $password   = $b['password'] ?? '';

    if (!$identifier || !$password) {
        jsonResponse(['error' => 'Enter your username/email/mobile and password'], 400);
    }

    // ── 1. HARDCODED ADMIN CHECK ───────────────────────────
    // Username "Admin" + password "Admin@harmaalwale"
    if (strcasecmp($identifier, 'admin') === 0 && $password === 'Admin@harmaalwale') {
        $db = getDB();
        // Get or create admin user
        $r = $db->query("SELECT id,name,email,mobile,role FROM users WHERE role='admin' OR email='admin@harmaalwale.com' LIMIT 1");
        $u = $r ? $r->fetch_assoc() : null;
        if (!$u) {
            $db->query("INSERT IGNORE INTO users (name,email,mobile,mobile_verified,role) VALUES ('Admin','admin@harmaalwale.com','9999999999',1,'admin')");
            $u = ['id'=>$db->insert_id, 'name'=>'Admin', 'email'=>'admin@harmaalwale.com', 'mobile'=>'9999999999', 'role'=>'admin'];
        } else {
            $db->query("UPDATE users SET role='admin' WHERE id=" . intval($u['id']));
            $u['role'] = 'admin';
        }
        $db->close();
        $token = createToken($u['id'], $u['mobile'], 'admin');
        jsonResponse(['success'=>true, 'token'=>$token, 'user'=>$u, 'message'=>'Welcome, Admin!']);
    }

    // ── 2. DETECT IDENTIFIER TYPE ──────────────────────────
    $db          = getDB();
    $isEmail     = filter_var($identifier, FILTER_VALIDATE_EMAIL) !== false;
    $isMobile    = preg_match('/^[6-9]\d{9}$/', preg_replace('/\D/', '', $identifier));
    $cleanMobile = preg_replace('/\D/', '', $identifier);

    $user = null;

    // ── 3. FIND USER BY EMAIL OR MOBILE ────────────────────
    if ($isEmail) {
        $stmt = $db->prepare("SELECT id,name,email,mobile,role,password_hash FROM users WHERE email=? LIMIT 1");
        $stmt->bind_param('s', $identifier);
        $stmt->execute();
        $user = $stmt->get_result()->fetch_assoc();
    } elseif ($isMobile) {
        $stmt = $db->prepare("SELECT id,name,email,mobile,role,password_hash FROM users WHERE mobile=? LIMIT 1");
        $stmt->bind_param('s', $cleanMobile);
        $stmt->execute();
        $user = $stmt->get_result()->fetch_assoc();
    }

    if (!$user) {
        $db->close();
        jsonResponse(['error' => 'Account not found. Please register first using OTP login.'], 404);
    }

    // ── 4. VERIFY PASSWORD ─────────────────────────────────
    if (empty($user['password_hash'])) {
        $db->close();
        jsonResponse(['error' => 'Password not set. Please login via mobile OTP first, then set a password from your account settings.'], 400);
    }

    if (!password_verify($password, $user['password_hash'])) {
        $db->close();
        jsonResponse(['error' => 'Incorrect password. Try mobile OTP login if you forgot your password.'], 401);
    }

    // ── 5. AUTO-DETECT VENDOR ROLE ─────────────────────────
    $role = $user['role'];
    if ($role === 'user') {
        $stmt = $db->prepare(
            "SELECT s.id FROM sellers s
             LEFT JOIN seller_applications sa ON s.application_id = sa.id
             WHERE (sa.email=? OR sa.phone=?) AND s.is_active=1 LIMIT 1"
        );
        $stmt->bind_param('ss', $user['email'], $user['mobile']);
        $stmt->execute();
        if ($stmt->get_result()->num_rows > 0) {
            $role = 'vendor';
            $db->query("UPDATE users SET role='vendor' WHERE id=" . intval($user['id']));
        }
    }

    $db->query("UPDATE users SET last_login=NOW() WHERE id=" . intval($user['id']));
    $db->close();

    $token = createToken($user['id'], $user['mobile'], $role);
    unset($user['password_hash']);
    $user['role'] = $role;

    jsonResponse([
        'success' => true,
        'token'   => $token,
        'user'    => $user,
        'message' => 'Logged in successfully!'
    ]);
}

// ============================================================
//  POST action=update_profile
// ============================================================
if ($method === 'POST' && $action === 'update_profile') {
    $auth = requireAuth();
    $b    = getBody();
    $db   = getDB();

    $fields = []; $params = []; $types = '';
    if (!empty($b['name']))   { $fields[] = 'name=?';   $params[] = $b['name'];   $types .= 's'; }
    if (!empty($b['email']))  { $fields[] = 'email=?';  $params[] = $b['email'];  $types .= 's'; }
    if (!empty($b['dob']))    { $fields[] = 'dob=?';    $params[] = $b['dob'];    $types .= 's'; }
    if (!empty($b['gender'])) { $fields[] = 'gender=?'; $params[] = $b['gender']; $types .= 's'; }

    // Allow password change
    if (!empty($b['password']) && strlen($b['password']) >= 6) {
        $fields[] = 'password_hash=?';
        $params[] = password_hash($b['password'], PASSWORD_BCRYPT);
        $types   .= 's';
    }

    if ($fields) {
        $sql = "UPDATE users SET " . implode(',', $fields) . " WHERE id=?";
        $params[] = $auth['uid']; $types .= 'i';
        $stmt = $db->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
    }

    $stmt = $db->prepare("SELECT id,name,email,mobile,role,avatar,dob,gender FROM users WHERE id=?");
    $stmt->bind_param('i', $auth['uid']);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $db->close();

    jsonResponse(['success' => true, 'user' => $user]);
}

jsonResponse(['error' => 'Unknown action'], 400);