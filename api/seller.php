<?php
require_once 'config.php';
require_once 'db.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

$name = trim($input['name'] ?? '');
$businessName = trim($input['business_name'] ?? '');
$gstNumber = strtoupper(trim($input['gst_number'] ?? ''));
$pan = strtoupper(trim($input['pan'] ?? ''));
$email = trim($input['email'] ?? '');
$phone = trim($input['phone'] ?? '');
$category = trim($input['category'] ?? '');
$address = trim($input['address'] ?? '');

if (empty($name) || empty($businessName) || empty($email) || empty($phone) || empty($category) || empty($address)) {
    echo json_encode(['success' => false, 'error' => 'All fields are required']);
    exit;
}

// ITEM #13 - GST Verification
$gstVerified = false;
$gstStatus = 'pending'; // pending, verified, special_case

if (!empty($gstNumber)) {
    // Validate GST format
    if (!preg_match('/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/', $gstNumber)) {
        echo json_encode(['success' => false, 'error' => 'Invalid GST number format']);
        exit;
    }
    
    // Try to verify GST via free API (ITEM #13)
    $gstVerified = verifyGSTOnline($gstNumber);
    $gstStatus = $gstVerified ? 'verified' : 'pending';
} else {
    // No GST - create special case for admin approval (ITEM #13)
    $gstStatus = 'special_case';
}

try {
    $pdo = getDB();
    
    // Generate Case ID
    $caseId = 'SELLER' . date('Ymd') . rand(1000, 9999);
    
    // Insert seller request
    $stmt = $pdo->prepare("INSERT INTO seller_requests 
                           (case_id, name, business_name, gst_number, pan, email, phone, category, address, gst_verified, gst_status, status, created_at) 
                           VALUES (:case_id, :name, :business_name, :gst_number, :pan, :email, :phone, :category, :address, :gst_verified, :gst_status, 'pending', NOW())");
    $stmt->execute([
        ':case_id' => $caseId,
        ':name' => $name,
        ':business_name' => $businessName,
        ':gst_number' => $gstNumber,
        ':pan' => $pan,
        ':email' => $email,
        ':phone' => $phone,
        ':category' => $category,
        ':address' => $address,
        ':gst_verified' => $gstVerified ? 1 : 0,
        ':gst_status' => $gstStatus
    ]);
    
    // Send email to support@harmaalwale.com (ITEM #7)
    $supportEmail = MAIL_SUPPORT;
    $supportSubject = "New Seller Application: $caseId";
    $supportBody = "
    <html>
    <body>
        <h2>New Seller Registration</h2>
        <p><strong>Case ID:</strong> $caseId</p>
        <p><strong>Name:</strong> $name</p>
        <p><strong>Business Name:</strong> $businessName</p>
        <p><strong>GST Number:</strong> " . ($gstNumber ?: 'Not Provided') . "</p>
        <p><strong>GST Status:</strong> " . ($gstStatus === 'verified' ? '✓ Verified Online' : ($gstStatus === 'special_case' ? '⚠ Special Case - Manual Approval Required' : '⏳ Pending Verification')) . "</p>
        <p><strong>PAN:</strong> $pan</p>
        <p><strong>Email:</strong> $email</p>
        <p><strong>Phone:</strong> $phone</p>
        <p><strong>Category:</strong> $category</p>
        <p><strong>Address:</strong> $address</p>
        <hr>
        <p><strong>Action Required:</strong> " . ($gstStatus === 'verified' ? 'Review and approve seller application' : 'Manual verification required') . "</p>
        <p><em>Submitted on: " . date('Y-m-d H:i:s') . "</em></p>
    </body>
    </html>
    ";
    
    $headers = "MIME-Version: 1.0\r\n";
    $headers .= "Content-Type: text/html; charset=UTF-8\r\n";
    $headers .= "From: " . MAIL_FROM_NAME . " <" . MAIL_FROM . ">\r\n";
    
    mail($supportEmail, $supportSubject, $supportBody, $headers);
    
    // Send confirmation to seller
    $sellerSubject = "Seller Application Received: $caseId";
    $sellerBody = "
    <html>
    <body>
        <h2>Thank you for applying to sell on HarmaalWale!</h2>
        <p>Dear $name,</p>
        <p>We have received your seller application.</p>
        <p><strong>Application ID:</strong> $caseId</p>
        <p><strong>Business:</strong> $businessName</p>
        <p><strong>GST Verification:</strong> " . ($gstStatus === 'verified' ? '✓ Verified' : ($gstStatus === 'special_case' ? 'Manual verification required' : 'Under review')) . "</p>
        <hr>
        <p>Our team will review your application and contact you within 48 hours.</p>
        <br>
        <p>Best regards,<br>Team HarmaalWale</p>
    </body>
    </html>
    ";
    
    mail($email, $sellerSubject, $sellerBody, $headers);
    
    echo json_encode([
        'success' => true,
        'case_id' => $caseId,
        'gst_verified' => $gstVerified,
        'gst_status' => $gstStatus,
        'message' => 'Seller application submitted successfully'
    ]);
    
} catch (PDOException $e) {
    error_log("Seller Error: " . $e->getMessage());
    echo json_encode(['success' => false, 'error' => 'Database error']);
}

// GST Verification Function (ITEM #13)
function verifyGSTOnline($gstNumber) {
    // Using free GST verification API
    $url = "https://sheet.gst.gov.in/registration/auth/api/get/gstnbypan?pan=" . substr($gstNumber, 2, 10);
    
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode === 200 && !empty($response)) {
        $data = json_decode($response, true);
        if (isset($data['status']) && $data['status'] === 'success') {
            return true;
        }
    }
    
    return false; // If API fails, mark as pending for manual verification
}
?>