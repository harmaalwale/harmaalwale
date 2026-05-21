<?php
header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (!$data || empty($data['fullname']) || empty($data['email']) || empty($data['password'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'All fields required']);
    exit;
}

$fullname = htmlspecialchars($data['fullname']);
$email = filter_var($data['email'], FILTER_VALIDATE_EMAIL);
$mobile = htmlspecialchars($data['mobile']);
$password = $data['password'];

if (!$email) {
    echo json_encode(['success' => false, 'error' => 'Invalid email']);
    exit;
}

// Send confirmation email
$to = $email;
$subject = 'Welcome to HarmaalWale!';
$body = "Hello $fullname,\n\nWelcome to HarmaalWale!\n\nYour account has been created.\n\nEmail: $email\nMobile: $mobile\n\nYou can now login at: https://harmaalwale.com/login\n\nBest regards,\nHarmaalWale Team";
$headers = "From: noreply@harmaalwale.com\r\nReply-To: support@harmaalwale.com";

@mail($to, $subject, $body, $headers);

// Send notification to admin
$admin_to = 'support@harmaalwale.com';
$admin_subject = 'New User Registration - ' . $fullname;
$admin_body = "New User Registration\n\nName: $fullname\nEmail: $email\nMobile: $mobile\nTime: " . date('Y-m-d H:i:s');
$admin_headers = "From: noreply@harmaalwale.com";

@mail($admin_to, $admin_subject, $admin_body, $admin_headers);

echo json_encode([
    'success' => true,
    'message' => 'Registration successful! Check your email.'
]);
?>