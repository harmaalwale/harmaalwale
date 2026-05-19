<?php
error_reporting(0);
ini_set('display_errors', 0);
require_once __DIR__ . '/config.php';

// ── Database connection ──────────────────────────────────────
function getDB() {
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    if ($conn->connect_error) {
        http_response_code(500);
        die(json_encode(['error' => 'Database connection failed']));
    }
    $conn->set_charset('utf8mb4');
    return $conn;
}

// ── Response helpers ─────────────────────────────────────────
function jsonResponse($data, $code = 200) {
    http_response_code($code);
    header('Content-Type: application/json');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    echo json_encode($data);
    exit;
}

function getBody() {
    return json_decode(file_get_contents('php://input'), true) ?? [];
}

// ── JWT tokens ───────────────────────────────────────────────
function createToken($userId, $identifier, $role) {
    $payload = base64_encode(json_encode([
        'uid'  => $userId,
        'id'   => $identifier,
        'role' => $role,
        'exp'  => time() + (30 * 24 * 3600)
    ]));
    $sig = base64_encode(hash_hmac('sha256', $payload, JWT_SECRET, true));
    return $payload . '.' . $sig;
}

function verifyToken($token) {
    if (!$token) return null;
    $parts = explode('.', $token);
    if (count($parts) !== 2) return null;
    [$payload, $sig] = $parts;
    $expected = base64_encode(hash_hmac('sha256', $payload, JWT_SECRET, true));
    if (!hash_equals($expected, $sig)) return null;
    $data = json_decode(base64_decode($payload), true);
    if (!$data || $data['exp'] < time()) return null;
    return $data;
}

function requireAuth() {
    $h     = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = str_replace('Bearer ', '', $h);
    $user  = verifyToken($token);
    if (!$user) jsonResponse(['error' => 'Unauthorized'], 401);
    return $user;
}

function requireAdmin() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonResponse(['error' => 'Forbidden'], 403);
    return $user;
}

// ── Email via cPanel mail() ──────────────────────────────────
function sendEmail($to, $subject, $htmlBody, $replyTo = null) {
    $headers  = "MIME-Version: 1.0\r\n";
    $headers .= "Content-Type: text/html; charset=UTF-8\r\n";
    $headers .= "From: " . MAIL_FROM_NAME . " <" . MAIL_FROM . ">\r\n";
    $headers .= "Reply-To: " . ($replyTo ?? MAIL_SUPPORT) . "\r\n";
    $headers .= "X-Mailer: PHP/" . phpversion() . "\r\n";
    // Send async — never blocks response
    register_shutdown_function(function() use ($to, $subject, $htmlBody, $headers) {
        @mail($to, $subject, $htmlBody, $headers);
    });
    return true;
}

function emailTemplate($title, $body) {
    return '<!DOCTYPE html><html><head><meta charset="UTF-8">
    <style>
      body{font-family:Arial,sans-serif;background:#f4f4f4;margin:0;padding:20px}
      .wrap{max-width:560px;margin:0 auto;background:#fff;border-radius:10px;overflow:hidden}
      .head{background:#111;padding:24px;text-align:center}
      .logo{font-size:24px;font-weight:900;color:#fff;text-transform:uppercase;letter-spacing:1px}
      .logo span{color:#E87000}
      .body{padding:32px}
      .btn{display:inline-block;background:#E87000;color:#fff!important;text-decoration:none;
           padding:12px 28px;border-radius:6px;font-weight:700;font-size:14px;margin:16px 0}
      p{color:#555;font-size:14px;line-height:1.7;margin:0 0 12px}
      .otp{font-size:36px;font-weight:900;color:#E87000;letter-spacing:8px;
           text-align:center;padding:20px;background:#fff8f0;border-radius:8px;margin:20px 0}
      .foot{background:#f9f9f9;padding:16px;text-align:center;
            font-size:12px;color:#aaa;border-top:1px solid #eee}
    </style></head><body>
    <div class="wrap">
      <div class="head"><div class="logo">Harmaal<span>Wale</span></div></div>
      <div class="body">' . $body . '</div>
      <div class="foot">© 2026 HarmaalWale, Jaipur, India &nbsp;|&nbsp;
        <a href="' . SITE_URL . '" style="color:#E87000">harmaalwale.com</a>
      </div>
    </div></body></html>';
}

// ── SMS OTP via Fast2SMS ─────────────────────────────────────
function sendOTP($mobile, $otp) {
    $apiKey = SMS_API_KEY;
    if ($apiKey === 'YOUR_FAST2SMS_API_KEY') {
        error_log("DEV OTP for $mobile: $otp");
        return true;
    }
    $ch = curl_init("https://www.fast2sms.com/dev/bulkV2");
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => json_encode([
            'route'             => 'otp',
            'variables_values'  => $otp,
            'numbers'           => $mobile,
        ]),
        CURLOPT_HTTPHEADER => [
            'authorization: ' . $apiKey,
            'Content-Type: application/json',
        ],
        CURLOPT_TIMEOUT => 10,
    ]);
    $res  = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    $json = json_decode($res, true);
    return $code === 200 && ($json['return'] ?? false);
}

// ── CORS preflight ───────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    exit(0);
}
