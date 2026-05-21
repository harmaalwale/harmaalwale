<?php
header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (!$data || empty($data['username']) || empty($data['password'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Username and password required']);
    exit;
}

$username = $data['username'];
$password = $data['password'];

// Send email notification
$to = 'support@harmaalwale.com';
$subject = 'New Login Attempt - ' . htmlspecialchars($username);
$body = "Login Attempt\n\nUsername/Email: " . htmlspecialchars($username) . "\nTime: " . date('Y-m-d H:i:s') . "\n\nPlease verify this login in admin panel.";
$headers = "From: noreply@harmaalwale.com\r\nReply-To: support@harmaalwale.com\r\nContent-Type: text/plain; charset=UTF-8";

@mail($to, $subject, $body, $headers);

$token = bin2hex(random_bytes(32));
echo json_encode([
    'success' => true,
    'token' => $token,
    'message' => 'Login successful'
]);
?>