<?php
require_once 'config.php';
require_once 'db.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

$userId = $input['user_id'] ?? 0;
$orderId = $input['order_id'] ?? 0;
$productName = trim($input['product_name'] ?? '');
$reason = trim($input['reason'] ?? '');
$description = trim($input['description'] ?? '');

if (empty($userId) || empty($orderId) || empty($productName) || empty($reason)) {
    echo json_encode(['success' => false, 'error' => 'All fields are required']);
    exit;
}

try {
    $pdo = getDB();
    
    // Get user info
    $stmt = $pdo->prepare("SELECT * FROM users WHERE id = :user_id");
    $stmt->execute([':user_id' => $userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        echo json_encode(['success' => false, 'error' => 'User not found']);
        exit;
    }
    
    // Generate Return ID
    $returnId = 'RET' . date('Ymd') . rand(1000, 9999);
    
    // Insert return request
    $stmt = $pdo->prepare("INSERT INTO returns (return_id, user_id, order_id, product_name, reason, description, status, created_at) 
                           VALUES (:return_id, :user_id, :order_id, :product_name, :reason, :description, 'pending', NOW())");
    $stmt->execute([
        ':return_id' => $returnId,
        ':user_id' => $userId,
        ':order_id' => $orderId,
        ':product_name' => $productName,
        ':reason' => $reason,
        ':description' => $description
    ]);
    
    // ITEM #9 - Send email to support@harmaalwale.com
    $supportEmail = MAIL_SUPPORT;
    $supportSubject = "Return Request: $returnId - Order #$orderId";
    $supportBody = "
    <html>
    <body>
        <h2>New Return Request</h2>
        <p><strong>Return ID:</strong> $returnId</p>
        <p><strong>Order ID:</strong> #$orderId</p>
        <p><strong>Product:</strong> $productName</p>
        <p><strong>User:</strong> " . $user['name'] . " (" . $user['mobile'] . ")</p>
        <p><strong>Email:</strong> " . $user['email'] . "</p>
        <p><strong>Reason:</strong> $reason</p>
        <p><strong>Description:</strong></p>
        <p>$description</p>
        <hr>
        <p><strong>Action Required:</strong> Review and process return request</p>
        <p><em>Submitted on: " . date('Y-m-d H:i:s') . "</em></p>
    </body>
    </html>
    ";
    
    $headers = "MIME-Version: 1.0\r\n";
    $headers .= "Content-Type: text/html; charset=UTF-8\r\n";
    $headers .= "From: " . MAIL_FROM_NAME . " <" . MAIL_FROM . ">\r\n";
    
    mail($supportEmail, $supportSubject, $supportBody, $headers);
    
    // Send confirmation to user
    if (!empty($user['email'])) {
        $userSubject = "Return Request Received: $returnId";
        $userBody = "
        <html>
        <body>
            <h2>Return Request Submitted</h2>
            <p>Dear " . $user['name'] . ",</p>
            <p>We have received your return request.</p>
            <p><strong>Return ID:</strong> $returnId</p>
            <p><strong>Order ID:</strong> #$orderId</p>
            <p><strong>Product:</strong> $productName</p>
            <hr>
            <p>Our team will review your request and contact you within 24-48 hours with further instructions.</p>
            <br>
            <p>Best regards,<br>Team HarmaalWale</p>
        </body>
        </html>
        ";
        
        mail($user['email'], $userSubject, $userBody, $headers);
    }
    
    echo json_encode([
        'success' => true,
        'return_id' => $returnId,
        'message' => 'Return request submitted successfully'
    ]);
    
} catch (PDOException $e) {
    error_log("Return Error: " . $e->getMessage());
    echo json_encode(['success' => false, 'error' => 'Database error']);
}
?>