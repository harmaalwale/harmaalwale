<?php
// ============================================================
//  HarmaalWale — Seller API
//  POST /api/seller.php?action=apply          → submit application
//  GET  /api/seller.php?action=status         → check application status
//  GET  /api/seller.php?action=applications   [admin] → all applications
//  POST /api/seller.php?action=approve        [admin] → approve seller
//  POST /api/seller.php?action=reject         [admin] → reject seller
//  GET  /api/seller.php?action=products       → seller's own products
//  POST /api/seller.php?action=add_product    → add product (approved sellers)
// ============================================================
error_reporting(0);
ini_set('display_errors', 0);
require_once 'db.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

$action = $_GET['action'] ?? getBody()['action'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];

function genRef() {
    return 'HWS-' . strtoupper(substr(md5(uniqid(mt_rand(), true)), 0, 7));
}

// ── Submit Seller Application (public — no auth required) ────
if ($method === 'POST' && $action === 'apply') {
    $b = getBody();

    foreach (['name','biz_name','email','phone','city','state','biz_type','categories'] as $f) {
        if (empty($b[$f])) jsonResponse(['error' => "Missing required field: $f"], 400);
    }

    if (!filter_var($b['email'], FILTER_VALIDATE_EMAIL)) {
        jsonResponse(['error' => 'Invalid email address'], 400);
    }

    $db  = getDB();
    $ref = genRef();

    // Check duplicate
    $chk = $db->prepare("SELECT id FROM seller_applications WHERE email=? OR phone=?");
    $chk->bind_param('ss', $b['email'], $b['phone']);
    $chk->execute();
    if ($chk->get_result()->num_rows > 0) {
        $db->close();
        jsonResponse(['error' => 'An application with this email or phone already exists. Contact support@harmaalwale.com if you need help.'], 400);
    }

    $stmt = $db->prepare(
        "INSERT INTO seller_applications
         (ref_code,name,biz_name,email,phone,city,state,gst,pan,address,biz_type,categories,description,website,instagram)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
    );
    $stmt->bind_param('sssssssssssssss',
        $ref, $b['name'], $b['biz_name'], $b['email'], $b['phone'],
        $b['city'], $b['state'],
        ($b['gst']??''), ($b['pan']??''), ($b['address']??''),
        $b['biz_type'], $b['categories'], ($b['description']??''),
        ($b['website']??''), ($b['instagram']??'')
    );
    $stmt->execute();
    $appId = $db->insert_id;
    $db->close();

    // Email to admin
    $adminBody = emailTemplate("New Seller Application — $ref",
        "<p>A new seller has applied to join HarmaalWale.</p>
         <table style='width:100%;border-collapse:collapse'>
           <tr><td style='padding:8px;background:#f5f5f5;font-weight:700;width:140px'>Ref</td><td style='padding:8px;border-bottom:1px solid #eee'>$ref</td></tr>
           <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Name</td><td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($b['name']) . "</td></tr>
           <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Business</td><td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($b['biz_name']) . "</td></tr>
           <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Email</td><td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($b['email']) . "</td></tr>
           <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Phone</td><td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($b['phone']) . "</td></tr>
           <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>City/State</td><td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($b['city'] . ', ' . $b['state']) . "</td></tr>
           <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Business Type</td><td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($b['biz_type']) . "</td></tr>
           <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Categories</td><td style='padding:8px'>" . htmlspecialchars($b['categories']) . "</td></tr>
         </table>
         <a href='" . SITE_URL . "/admin.html' class='btn'>Review in Admin →</a>"
    );
    sendEmail(MAIL_SUPPORT, "New Seller Application — $ref", $adminBody);

    // Confirmation to seller
    $sellerBody = emailTemplate('Seller Application Received',
        "<p>Hi <strong>" . htmlspecialchars($b['name']) . "</strong>,</p>
         <p>Thank you for applying to sell on HarmaalWale! We've received your application and our team will review it within <strong>48 hours</strong>.</p>
         <p><strong>Application Reference:</strong> $ref<br>Keep this for your records.</p>
         <p>We'll email you at <strong>" . htmlspecialchars($b['email']) . "</strong> once we've reviewed your application.</p>
         <p>Questions? Contact us at <a href='mailto:support@harmaalwale.com' style='color:#E87000'>support@harmaalwale.com</a></p>"
    );
    sendEmail($b['email'], "Seller Application Received — HarmaalWale ($ref)", $sellerBody);

    jsonResponse(['success' => true, 'ref_code' => $ref, 'message' => 'Application submitted! We\'ll review within 48 hours and email you.']);
}

// ── Check application status (by email + ref) ────────────────
if ($method === 'GET' && $action === 'status') {
    $email = trim($_GET['email'] ?? '');
    $ref   = trim($_GET['ref']   ?? '');
    if (!$email && !$ref) jsonResponse(['error' => 'Provide email or ref_code'], 400);

    $db = getDB();
    if ($ref) {
        $stmt = $db->prepare("SELECT ref_code,biz_name,name,status,submitted_at,admin_notes FROM seller_applications WHERE ref_code=?");
        $stmt->bind_param('s', $ref);
    } else {
        $stmt = $db->prepare("SELECT ref_code,biz_name,name,status,submitted_at,admin_notes FROM seller_applications WHERE email=? ORDER BY id DESC LIMIT 1");
        $stmt->bind_param('s', $email);
    }
    $stmt->execute();
    $app = $stmt->get_result()->fetch_assoc();
    $db->close();

    if (!$app) jsonResponse(['error' => 'Application not found'], 404);
    jsonResponse(['success' => true, 'application' => $app]);
}

// ── Admin: list all applications ─────────────────────────────
if ($method === 'GET' && $action === 'applications') {
    requireAdmin();
    $db     = getDB();
    $status = $_GET['status'] ?? '';
    if ($status) {
        $stmt = $db->prepare("SELECT * FROM seller_applications WHERE status=? ORDER BY submitted_at DESC");
        $stmt->bind_param('s', $status);
    } else {
        $stmt = $db->prepare("SELECT * FROM seller_applications ORDER BY submitted_at DESC");
    }
    $stmt->execute();
    $apps = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $db->close();
    jsonResponse(['success' => true, 'applications' => $apps, 'count' => count($apps)]);
}

// ── Admin: approve seller ─────────────────────────────────────
if ($method === 'POST' && $action === 'approve') {
    requireAdmin();
    $b   = getBody();
    $id  = intval($b['id'] ?? 0);
    $db  = getDB();

    $stmt = $db->prepare("SELECT * FROM seller_applications WHERE id=?");
    $stmt->bind_param('i', $id); $stmt->execute();
    $app = $stmt->get_result()->fetch_assoc();
    if (!$app) { $db->close(); jsonResponse(['error' => 'Not found'], 404); }

    $db->prepare("UPDATE seller_applications SET status='approved', reviewed_at=NOW(), admin_notes=? WHERE id=?")
       ->execute([($b['notes']??''), $id]);

    // Add to sellers table
    $s = $db->prepare("INSERT IGNORE INTO sellers (application_id,biz_name,email,phone,city,gst) VALUES (?,?,?,?,?,?)");
    $s->bind_param('isssss', $id, $app['biz_name'], $app['email'], $app['phone'], $app['city'], ($app['gst']??''));
    $s->execute();
    $db->close();

    // Email seller
    $body = emailTemplate('🎉 Your Seller Application is Approved!',
        "<p>Hi <strong>" . htmlspecialchars($app['name']) . "</strong>,</p>
         <p>Congratulations! Your application to sell on HarmaalWale has been <strong style='color:#16a34a'>approved</strong>.</p>
         <p>Your business <strong>" . htmlspecialchars($app['biz_name']) . "</strong> is now a verified seller on HarmaalWale.</p>
         <p>You can now log in and start listing your products:</p>
         <a href='" . SITE_URL . "/seller.html' class='btn'>Go to Seller Dashboard →</a>
         <p>Welcome to the HarmaalWale family! 🎊</p>"
    );
    sendEmail($app['email'], '🎉 Seller Application Approved — HarmaalWale', $body);

    jsonResponse(['success' => true, 'message' => 'Seller approved and notified']);
}

// ── Admin: reject ─────────────────────────────────────────────
if ($method === 'POST' && $action === 'reject') {
    requireAdmin();
    $b  = getBody();
    $id = intval($b['id'] ?? 0);
    $db = getDB();

    $stmt = $db->prepare("SELECT * FROM seller_applications WHERE id=?");
    $stmt->bind_param('i', $id); $stmt->execute();
    $app = $stmt->get_result()->fetch_assoc();

    $db->prepare("UPDATE seller_applications SET status='rejected', reviewed_at=NOW(), admin_notes=? WHERE id=?")
       ->execute([($b['reason']??''), $id]);
    $db->close();

    $reason = $b['reason'] ?? 'Your application did not meet our current requirements.';
    $body = emailTemplate('Seller Application Update',
        "<p>Hi <strong>" . htmlspecialchars($app['name']) . "</strong>,</p>
         <p>Thank you for your interest in selling on HarmaalWale.</p>
         <p>After reviewing your application, we're unable to approve it at this time.</p>
         <p><strong>Reason:</strong> " . htmlspecialchars($reason) . "</p>
         <p>You're welcome to apply again in the future or contact us for more information.</p>
         <a href='mailto:support@harmaalwale.com' class='btn'>Contact Support</a>"
    );
    sendEmail($app['email'], 'Seller Application Update — HarmaalWale', $body);

    jsonResponse(['success' => true, 'message' => 'Application rejected and seller notified']);
}

jsonResponse(['error' => 'Unknown action'], 400);
