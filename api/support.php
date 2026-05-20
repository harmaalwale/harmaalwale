<?php
// ============================================================
// HarmaalWale Support Ticket System (api/support.php)
// ============================================================

header('Content-Type: application/json');
require_once 'config.php';
require_once 'db.php';

// Create support table if not exists
$pdo->exec("CREATE TABLE IF NOT EXISTS support_tickets (
    id INT PRIMARY KEY AUTO_INCREMENT,
    case_id VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    message LONGTEXT NOT NULL,
    status ENUM('open', 'in-progress', 'resolved') DEFAULT 'open',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

if($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $phone = trim($_POST['phone'] ?? '');
    $category = trim($_POST['category'] ?? 'general');
    $message = trim($_POST['message'] ?? '');
    
    // Validation
    if(!$name || !$email || !$phone || !$message) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'All fields are required'
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
    
    // Generate unique Case ID
    $caseId = 'CASE-' . strtoupper(substr(md5(time() . rand()), 0, 8));
    
    try {
        // Insert into database
        $stmt = $pdo->prepare("
            INSERT INTO support_tickets (case_id, name, email, phone, category, message, status) 
            VALUES (?, ?, ?, ?, ?, ?, 'open')
        ");
        
        $stmt->execute([
            $caseId,
            $name,
            $email,
            $phone,
            $category,
            $message
        ]);
        
        // Category-specific response messages
        $categoryMessages = [
            'technical' => 'Our technical team will review your issue and contact you within 24 hours.',
            'orders' => 'Our order team will review your concern and respond within 12 hours.',
            'returns' => 'Our returns team will process your request and contact you shortly.',
            'billing' => 'Our billing team will review your concern immediately.',
            'general' => 'Thank you for reaching out. Our team will get back to you soon.'
        ];
        
        $responseMessage = $categoryMessages[$category] ?? $categoryMessages['general'];
        
        // ========== Send Email to Customer ==========
        $customerSubject = "HarmaalWale Support - Case ID: $caseId";
        
        $customerEmailBody = "
Hello $name,

Thank you for contacting HarmaalWale!

Your Support Case Details:
========================================
Case ID: $caseId
Category: " . ucfirst($category) . "
Submitted: " . date('Y-m-d H:i:s') . "
Status: Open
========================================

$responseMessage

If you have any additional information to add to this case, please reply to this email with your Case ID.

Best regards,
HarmaalWale Support Team
support@harmaalwale.com
";
        
        $headers = "From: noreply@harmaalwale.com\r\n";
        $headers .= "Reply-To: support@harmaalwale.com\r\n";
        $headers .= "X-Mailer: HarmaalWale System\r\n";
        
        mail($email, $customerSubject, $customerEmailBody, $headers);
        
        // ========== Send Notification to Support Team ==========
        $supportSubject = "New Support Ticket - $caseId - " . ucfirst($category);
        
        $supportEmailBody = "
NEW SUPPORT TICKET RECEIVED
========================================

Case ID: $caseId
Category: " . ucfirst($category) . "
Status: Open
Received: " . date('Y-m-d H:i:s') . "

CUSTOMER INFORMATION
========================================
Name: $name
Email: $email
Phone: $phone

ISSUE DETAILS
========================================
$message

ACTION REQUIRED:
- Review and respond within appropriate timeframe
- Update status in system
- Provide resolution or escalate if needed

========================================
HarmaalWale Automated System
";
        
        mail('support@harmaalwale.com', $supportSubject, $supportEmailBody, $headers);
        
        // ========== Success Response ==========
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'caseId' => $caseId,
            'message' => 'Your concern will be addressed soon',
            'responseMessage' => $responseMessage
        ]);
        
    } catch(PDOException $e) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Database error: ' . $e->getMessage()
        ]);
    }
    
} else if($_SERVER['REQUEST_METHOD'] === 'GET') {
    
    // Get ticket status
    if(isset($_GET['case_id'])) {
        $caseId = $_GET['case_id'];
        
        try {
            $stmt = $pdo->prepare("
                SELECT case_id, status, name, email, created_at 
                FROM support_tickets 
                WHERE case_id = ?
            ");
            
            $stmt->execute([$caseId]);
            $ticket = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if($ticket) {
                echo json_encode([
                    'success' => true,
                    'ticket' => $ticket
                ]);
            } else {
                http_response_code(404);
                echo json_encode([
                    'success' => false,
                    'error' => 'Case not found'
                ]);
            }
        } catch(PDOException $e) {
            http_response_code(500);
            echo json_encode([
                'success' => false,
                'error' => $e->getMessage()
            ]);
        }
    } else {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'Case ID required'
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
