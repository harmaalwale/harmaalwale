<?php
// ============================================================
//  HarmaalWale — Support / Contact Form API
//  POST /api/support.php  → saves enquiry + emails support@harmaalwale.com
// ============================================================
error_reporting(0);
ini_set('display_errors', 0);
require_once 'db.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonResponse(['error' => 'Method not allowed'], 405);

$b       = getBody();
$name    = trim($b['name']    ?? '');
$email   = trim($b['email']   ?? '');
$mobile  = trim($b['mobile']  ?? '');
$subject = trim($b['subject'] ?? 'General Enquiry');
$message = trim($b['message'] ?? '');
$type    = $b['type'] ?? 'support';

if (!$name || !$message) {
    jsonResponse(['error' => 'Name and message are required'], 400);
}
if ($email && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    jsonResponse(['error' => 'Invalid email address'], 400);
}

// ── Save to database ─────────────────────────────────────────
$db   = getDB();
$stmt = $db->prepare(
    "INSERT INTO enquiries (name,email,mobile,subject,message,type) VALUES (?,?,?,?,?,?)"
);
$stmt->bind_param('ssssss', $name, $email, $mobile, $subject, $message, $type);
$stmt->execute();
$enquiryId = $db->insert_id;
$db->close();

// ── Email to support@harmaalwale.com ─────────────────────────
$adminBody = emailTemplate("New Support Enquiry #$enquiryId",
    "<p>You have received a new enquiry on HarmaalWale.</p>
     <table style='width:100%;border-collapse:collapse'>
       <tr><td style='padding:8px;background:#f5f5f5;font-weight:700;width:120px'>From</td>
           <td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($name) . "</td></tr>
       <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Email</td>
           <td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($email ?: '—') . "</td></tr>
       <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Mobile</td>
           <td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($mobile ?: '—') . "</td></tr>
       <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Subject</td>
           <td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($subject) . "</td></tr>
       <tr><td style='padding:8px;background:#f5f5f5;font-weight:700'>Type</td>
           <td style='padding:8px;border-bottom:1px solid #eee'>" . ucfirst($type) . "</td></tr>
       <tr><td style='padding:8px;background:#f5f5f5;font-weight:700;vertical-align:top'>Message</td>
           <td style='padding:8px'>" . nl2br(htmlspecialchars($message)) . "</td></tr>
     </table>
     <p style='margin-top:20px'>Reply directly to this email to respond to the customer.</p>"
);

$replyTo = $email ?: MAIL_SUPPORT;
sendEmail(MAIL_SUPPORT, "[$type] $subject — Enquiry #$enquiryId", $adminBody, $replyTo);

// ── Confirmation email to user (if email provided) ───────────
if ($email) {
    $userBody = emailTemplate('We received your message!',
        "<p>Hi <strong>" . htmlspecialchars($name) . "</strong>,</p>
         <p>Thank you for reaching out to HarmaalWale. We've received your message and our support team will get back to you within <strong>24 hours</strong>.</p>
         <p><strong>Your message:</strong></p>
         <p style='background:#f5f5f5;padding:16px;border-radius:6px;color:#444'>" . nl2br(htmlspecialchars($message)) . "</p>
         <p>For urgent queries, you can also reach us on WhatsApp:</p>
         <a href='https://wa.me/917891004042' class='btn'>💬 Chat on WhatsApp</a>
         <p style='color:#aaa;font-size:12px'>Reference: #$enquiryId</p>"
    );
    sendEmail($email, 'We received your message — HarmaalWale', $userBody);
}

jsonResponse([
    'success'    => true,
    'message'    => 'Your message has been sent! We\'ll get back to you within 24 hours.',
    'enquiry_id' => $enquiryId
]);
