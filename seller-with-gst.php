<?php
// ============================================================
// HarmaalWale Seller Registration (api/seller.php)
// GST Verification & Special Case Handling
// ============================================================

header('Content-Type: application/json');
require_once 'config.php';
require_once 'db.php';

// Create special seller cases table
$pdo->exec("CREATE TABLE IF NOT EXISTS special_seller_cases (
    id INT PRIMARY KEY AUTO_INCREMENT,
    case_id VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    business_name VARCHAR(255),
    city VARCHAR(100),
    status ENUM('pending_review', 'approved', 'rejected') DEFAULT 'pending_review',
    notes LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

// Function to validate GST format
function validateGSTFormat($gst) {
    // Standard GST format: 2 chars (state) + 10 chars (entity) + 1 check digit = 15 chars
    // Pattern: [0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9]{1}Z[0-9]{1}
    $gstPattern = '/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9]{1}$/';
    
    return preg_match($gstPattern, strtoupper($gst)) ? true : false;
}

// Function to verify GST online
function verifyGSTOnline($gst) {
    // Using GSTIN API (replace with actual API)
    // This is a simplified example - use actual GST verification API
    
    $gst = strtoupper(trim($gst));
    
    // Validate format first
    if(!validateGSTFormat($gst)) {
        return [
            'valid' => false,
            'verified' => false,
            'message' => 'Invalid GST format'
        ];
    }
    
    try {
        // API endpoint for GST verification
        $apiUrl = "https://api.gstin.online/api/search?gstin=" . urlencode($gst);
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $apiUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if($response && $httpCode == 200) {
            $data = json_decode($response, true);
            
            if($data && isset($data['status']) && $data['status'] === 'active') {
                return [
                    'valid' => true,
                    'verified' => true,
                    'status' => 'active',
                    'message' => 'GST verified successfully',
                    'businessName' => $data['business_name'] ?? 'N/A'
                ];
            }
        }
        
        // If API fails or returns inactive
        return [
            'valid' => true,
            'verified' => false,
            'message' => 'Could not verify GST online. Manual verification required.'
        ];
        
    } catch(Exception $e) {
        return [
            'valid' => true,
            'verified' => false,
            'message' => 'Verification API unavailable. Will verify manually.'
        ];
    }
}

// Function to create special case for sellers without GST
function createSpecialSellerCase($email, $name, $phone, $businessName, $city) {
    global $pdo;
    
    try {
        $caseId = 'SPECIAL-' . strtoupper(substr(md5(time() . rand()), 0, 8));
        
        $stmt = $pdo->prepare("
            INSERT INTO special_seller_cases 
            (case_id, email, name, phone, business_name, city, status) 
            VALUES (?, ?, ?, ?, ?, ?, 'pending_review')
        ");
        
        $stmt->execute([
            $caseId,
            $email,
            $name,
            $phone,
            $businessName,
            $city
        ]);
        
        // Notify admin
        $adminSubject = "New Seller Registration Without GST - $caseId";
        
        $adminEmailBody = "
NEW SELLER REGISTRATION - SPECIAL CASE
========================================

Case ID: $caseId
Status: Pending Admin Review
Date: " . date('Y-m-d H:i:s') . "

SELLER INFORMATION
========================================
Name: $name
Email: $email
Phone: $phone
Business Name: $businessName
City: $city

NOTES:
- Seller does not have GST number
- Manual verification required
- Follow up for documentation

ACTION REQUIRED:
1. Verify seller information
2. Check if business is legitimate
3. Approve or reject registration
4. Send response to seller

========================================
HarmaalWale Seller System
";
        
        $headers = "From: noreply@harmaalwale.com\r\n";
        $headers .= "Reply-To: support@harmaalwale.com\r\n";
        
        mail('support@harmaalwale.com', $adminSubject, $adminEmailBody, $headers);
        
        return [
            'success' => true,
            'caseId' => $caseId,
            'message' => 'Special case created. Admin will review your application.'
        ];
        
    } catch(PDOException $e) {
        return [
            'success' => false,
            'error' => 'Database error: ' . $e->getMessage()
        ];
    }
}

// ========== MAIN REQUEST HANDLING ==========

if($_SERVER['REQUEST_METHOD'] === 'POST') {
    
    if(isset($_POST['action']) && $_POST['action'] === 'register_seller') {
        $name = trim($_POST['name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $phone = trim($_POST['phone'] ?? '');
        $businessName = trim($_POST['business_name'] ?? '');
        $city = trim($_POST['city'] ?? '');
        $gstNumber = trim($_POST['gst_number'] ?? '');
        $hasGST = isset($_POST['has_gst']) ? (int)$_POST['has_gst'] : 0;
        
        // Validation
        if(!$name || !$email || !$phone || !$businessName) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'error' => 'Required fields missing'
            ]);
            exit;
        }
        
        if(!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'error' => 'Invalid email address'
            ]);
            exit;
        }
        
        // ========== GST HANDLING ==========
        if($hasGST && $gstNumber) {
            // Verify GST
            $gstVerification = verifyGSTOnline($gstNumber);
            
            if($gstVerification['valid'] && $gstVerification['verified']) {
                // GST verified - proceed with normal registration
                try {
                    $sellerId = 'SELLER-' . strtoupper(substr(md5(time()), 0, 8));
                    
                    $stmt = $pdo->prepare("
                        INSERT INTO sellers 
                        (seller_id, name, email, phone, business_name, city, gst_number, gst_verified, status, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'active', NOW())
                    ");
                    
                    $stmt->execute([
                        $sellerId,
                        $name,
                        $email,
                        $phone,
                        $businessName,
                        $city,
                        strtoupper($gstNumber)
                    ]);
                    
                    // Send welcome email
                    $welcomeEmail = "
Hello $name,

Welcome to HarmaalWale Seller Program!

Your seller account has been created and verified.
Seller ID: $sellerId

You can now start listing products.

Login to your dashboard: https://harmaalwale.com/seller_admin.html

Best regards,
HarmaalWale Team
";
                    
                    $headers = "From: noreply@harmaalwale.com\r\n";
                    mail($email, "Welcome to HarmaalWale - Seller Registration Confirmed", $welcomeEmail, $headers);
                    
                    http_response_code(200);
                    echo json_encode([
                        'success' => true,
                        'sellerId' => $sellerId,
                        'message' => 'Registration successful! Your GST has been verified.'
                    ]);
                    
                } catch(PDOException $e) {
                    http_response_code(500);
                    echo json_encode([
                        'success' => false,
                        'error' => 'Database error: ' . $e->getMessage()
                    ]);
                }
            } else {
                // GST format valid but couldn't verify online - create special case
                $result = createSpecialSellerCase($email, $name, $phone, $businessName, $city);
                
                if($result['success']) {
                    // Send email to seller about special case
                    $specialCaseEmail = "
Hello $name,

Thank you for registering as a seller on HarmaalWale!

Your application has been received and is under review.
Case ID: " . $result['caseId'] . "

We could not verify your GST number online. Our admin team will review your documentation.
We will contact you within 2-3 business days.

Please keep your Case ID for reference.

Best regards,
HarmaalWale Team
";
                    
                    $headers = "From: noreply@harmaalwale.com\r\n";
                    mail($email, "HarmaalWale Seller Registration - Pending Review", $specialCaseEmail, $headers);
                    
                    http_response_code(202);
                    echo json_encode([
                        'success' => true,
                        'caseId' => $result['caseId'],
                        'message' => 'GST could not be verified online. Your application is under admin review.',
                        'status' => 'pending_review'
                    ]);
                } else {
                    http_response_code(500);
                    echo json_encode($result);
                }
            }
            
        } else if(!$hasGST) {
            // No GST - create special case for manual verification
            $result = createSpecialSellerCase($email, $name, $phone, $businessName, $city);
            
            if($result['success']) {
                // Send email to seller
                $noGSTEmail = "
Hello $name,

Thank you for registering as a seller on HarmaalWale!

We noticed you don't have a GST number. No problem!
Your application has been created as a special case.

Case ID: " . $result['caseId'] . "

Our admin team will review your business details and contact you soon.
We may request additional documentation for verification.

Timeline: 2-5 business days

Best regards,
HarmaalWale Team
";
                
                $headers = "From: noreply@harmaalwale.com\r\n";
                mail($email, "HarmaalWale Seller Registration - Special Case Created", $noGSTEmail, $headers);
                
                http_response_code(202);
                echo json_encode([
                    'success' => true,
                    'caseId' => $result['caseId'],
                    'message' => 'Special case created for sellers without GST. Admin will review soon.',
                    'status' => 'pending_review'
                ]);
            } else {
                http_response_code(500);
                echo json_encode($result);
            }
            
        } else {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'error' => 'Invalid GST information provided'
            ]);
        }
        
    } else {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'Invalid action'
        ]);
    }
    
} else {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Method not allowed'
    ]);
}
?>
