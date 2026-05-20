<?php
require_once 'config.php';
require_once 'db.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

// ITEM #1 FIX - OTP SENDING WITH FAST2SMS
function sendOTP($mobile, $otp) {
    $apiKey = SMS_API_KEY;
    $sender = SMS_SENDER;
    $message = str_replace('{otp}', $otp, SMS_TEMPLATE_OTP);
    
    $url = "https://www.fast2sms.com/dev/bulkV2";
    
    $data = [
        'sender_id' => $sender,
        'message' => $message,
        'route' => 'v3',
        'numbers' => $mobile
    ];
    
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: " . $apiKey,
        "Content-Type: application/x-www-form-urlencoded"
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    error_log("Fast2SMS Response: " . $response . " | HTTP Code: " . $httpCode);
    
    if ($httpCode === 200) {
        $result = json_decode($response, true);
        return isset($result['return']) && $result['return'] === true;
    }
    
    return false;
}

// Generate OTP
function generateOTP() {
    return str_pad(rand(0, 999999), OTP_LENGTH, '0', STR_PAD_LEFT);
}

// REQUEST OTP - FIXED
if ($method === 'POST' && isset($input['action']) && $input['action'] === 'request_otp') {
    $mobile = $input['mobile'] ?? '';
    
    if (empty($mobile) || !preg_match('/^[6-9]\d{9}$/', $mobile)) {
        echo json_encode(['success' => false, 'error' => 'Invalid mobile number']);
        exit;
    }
    
    $otp = generateOTP();
    $expiry = date('Y-m-d H:i:s', strtotime('+' . OTP_EXPIRY . ' minutes'));
    
    try {
        $pdo = getDB();
        
        // Store OTP
        $stmt = $pdo->prepare("INSERT INTO otp_verifications (mobile, otp, expires_at, created_at) 
                               VALUES (:mobile, :otp, :expires_at, NOW()) 
                               ON DUPLICATE KEY UPDATE otp = :otp, expires_at = :expires_at, attempts = 0");
        $stmt->execute([
            ':mobile' => $mobile,
            ':otp' => $otp,
            ':expires_at' => $expiry
        ]);
        
        // Send OTP via Fast2SMS
        $sent = sendOTP($mobile, $otp);
        
        if ($sent) {
            echo json_encode([
                'success' => true,
                'message' => 'OTP sent successfully',
                'expires_in' => OTP_EXPIRY * 60 // seconds
            ]);
        } else {
            // Log OTP for debugging if SMS fails
            error_log("OTP not sent via SMS. OTP for $mobile: $otp");
            echo json_encode([
                'success' => false,
                'error' => 'Failed to send OTP. Please try again or contact support.',
                'debug_otp' => $otp // Remove in production
            ]);
        }
        
    } catch (PDOException $e) {
        error_log("OTP Error: " . $e->getMessage());
        echo json_encode(['success' => false, 'error' => 'Database error']);
    }
    exit;
}

// VERIFY OTP
if ($method === 'POST' && isset($input['action']) && $input['action'] === 'verify_otp') {
    $mobile = $input['mobile'] ?? '';
    $otp = $input['otp'] ?? '';
    
    if (empty($mobile) || empty($otp)) {
        echo json_encode(['success' => false, 'error' => 'Mobile and OTP required']);
        exit;
    }
    
    try {
        $pdo = getDB();
        
        $stmt = $pdo->prepare("SELECT * FROM otp_verifications 
                               WHERE mobile = :mobile 
                               AND otp = :otp 
                               AND expires_at > NOW() 
                               AND attempts < 3");
        $stmt->execute([':mobile' => $mobile, ':otp' => $otp]);
        $otpRecord = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$otpRecord) {
            // Increment attempts
            $stmt = $pdo->prepare("UPDATE otp_verifications SET attempts = attempts + 1 WHERE mobile = :mobile");
            $stmt->execute([':mobile' => $mobile]);
            
            echo json_encode(['success' => false, 'error' => 'Invalid or expired OTP']);
            exit;
        }
        
        // Check if user exists
        $stmt = $pdo->prepare("SELECT * FROM users WHERE mobile = :mobile");
        $stmt->execute([':mobile' => $mobile]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user) {
            // Create new user
            $stmt = $pdo->prepare("INSERT INTO users (mobile, created_at) VALUES (:mobile, NOW())");
            $stmt->execute([':mobile' => $mobile]);
            $userId = $pdo->lastInsertId();
            
            $user = [
                'id' => $userId,
                'mobile' => $mobile,
                'name' => null,
                'email' => null
            ];
        }
        
        // Delete OTP record
        $stmt = $pdo->prepare("DELETE FROM otp_verifications WHERE mobile = :mobile");
        $stmt->execute([':mobile' => $mobile]);
        
        // Generate token
        $token = base64_encode(json_encode([
            'user_id' => $user['id'],
            'mobile' => $mobile,
            'exp' => time() + (30 * 24 * 60 * 60) // 30 days
        ]));
        
        echo json_encode([
            'success' => true,
            'token' => $token,
            'user' => [
                'id' => $user['id'],
                'mobile' => $mobile,
                'name' => $user['name'],
                'email' => $user['email']
            ]
        ]);
        
    } catch (PDOException $e) {
        error_log("Verify OTP Error: " . $e->getMessage());
        echo json_encode(['success' => false, 'error' => 'Database error']);
    }
    exit;
}

echo json_encode(['success' => false, 'error' => 'Invalid request']);
?>