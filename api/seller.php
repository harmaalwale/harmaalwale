<?php
header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (!$data || empty($data['fullname']) || empty($data['email']) || empty($data['business_name'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Required fields missing']);
    exit;
}

$fullname = htmlspecialchars($data['fullname']);
$email = filter_var($data['email'], FILTER_VALIDATE_EMAIL);
$mobile = htmlspecialchars($data['mobile']);
$business_name = htmlspecialchars($data['business_name']);
$business_type = htmlspecialchars($data['business_type']);
$category = htmlspecialchars($data['category']);
$message = htmlspecialchars($data['message']);

if (!$email) {
    echo json_encode(['success' => false, 'error' => 'Invalid email']);
    exit;
}

// Send to support team
$to = 'support@harmaalwale.com';
$subject = 'New Seller Application - ' . $business_name;
$body = "New Seller Application\n\n";
$body .= "Name: $fullname\n";
$body .= "Email: $email\n";
$body .= "Mobile: $mobile\n";
$body .= "Business Name: $business_name\n";
$body .= "Business Type: $business_type\n";
$body .= "Category: $category\n";
$body .= "Message:\n$message\n\n";
$body .= "Time: " . date('Y-m-d H:i:s');
$headers = "From: noreply@harmaalwale.com\r\nReply-To: $email";

@mail($to, $subject, $body, $headers);

// Send confirmation to applicant
$confirm_subject = 'Seller Application Received';
$confirm_body = "Hello $fullname,\n\nThank you for your interest in becoming a seller with HarmaalWale.\n\nWe have received your application for: $business_name\n\nOur team will review your application and contact you within 24-48 hours.\n\nBest regards,\nHarmaalWale Team\n\nContact: support@harmaalwale.com\nWhatsApp: +91 78910 04042";

@mail($email, $confirm_subject, $confirm_body, "From: noreply@harmaalwale.com");

echo json_encode([
    'success' => true,
    'message' => 'Application submitted successfully!'
]);
?>