<?php
error_reporting(0);
ini_set('display_errors', 0);
require_once 'db.php';

$method = $_SERVER['REQUEST_METHOD'];

/* ═══════════════════════════════════════════════════════════
   POST — Submit enquiry → save to DB + send emails
═══════════════════════════════════════════════════════════ */
if ($method === 'POST') {
    $b       = getBody();
    $name    = trim($b['name']    ?? '');
    $email   = trim($b['email']   ?? '');
    $phone   = trim($b['phone']   ?? '');
    $subject = trim($b['subject'] ?? 'General Enquiry');
    $message = trim($b['message'] ?? '');

    if (!$name || !$email || !$message)
        jsonResponse(['error' => 'Please fill in your name, email and message.'], 400);
    if (!filter_var($email, FILTER_VALIDATE_EMAIL))
        jsonResponse(['error' => 'Please enter a valid email address.'], 400);

    /* ── Save to DB ─────────────────────────────────────── */
    $db = getDB();

    $db->query("CREATE TABLE IF NOT EXISTS enquiries (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        user_id    INT          DEFAULT NULL,
        name       VARCHAR(120) NOT NULL,
        email      VARCHAR(160) NOT NULL,
        phone      VARCHAR(30)  DEFAULT NULL,
        product_id INT          DEFAULT NULL,
        subject    VARCHAR(200) DEFAULT NULL,
        message    TEXT         NOT NULL,
        status     VARCHAR(20)  NOT NULL DEFAULT 'new',
        created_at DATETIME     DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $uid = null;
    $h   = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($h) { $t = str_replace('Bearer ', '', $h); $u = verifyToken($t); if ($u) $uid = $u['uid']; }
    $pid = intval($b['product_id'] ?? 0) ?: null;

    $ins = $db->prepare("INSERT INTO enquiries (user_id,name,email,phone,product_id,subject,message) VALUES (?,?,?,?,?,?,?)");
    $ins->bind_param('isssiss', $uid, $name, $email, $phone, $pid, $subject, $message);
    $ins->execute();
    $ins->close();
    $db->close();

    /* ── Shared mail helper ─────────────────────────────── */
    function hw_send($to, $subjectLine, $htmlBody, $replyTo = '') {
        // Encode subject for UTF-8 safety
        $encSubject = '=?UTF-8?B?' . base64_encode($subjectLine) . '?=';

        // Build headers — cPanel requires From to match a real mailbox on the server
        $headers  = "MIME-Version: 1.0\r\n";
        $headers .= "Content-Type: text/html; charset=UTF-8\r\n";
        $headers .= "From: HarmaalWale <support@harmaalwale.com>\r\n";
        if ($replyTo) $headers .= "Reply-To: $replyTo\r\n";
        $headers .= "X-Mailer: PHP/" . PHP_VERSION . "\r\n";

        // -f sets envelope sender — critical on cPanel to avoid spam rejection
        return mail($to, $encSubject, $htmlBody, $headers, '-f support@harmaalwale.com');
    }

    /* ── Inline styles (Outlook/Gmail safe) ──────────────── */
    $n = htmlspecialchars($name,    ENT_QUOTES);
    $e = htmlspecialchars($email,   ENT_QUOTES);
    $p = htmlspecialchars($phone,   ENT_QUOTES);
    $s = htmlspecialchars($subject, ENT_QUOTES);
    $m = nl2br(htmlspecialchars($message, ENT_QUOTES));
    $phoneRow = $phone ? "<tr><td style='padding:6px 0;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:#999'>Phone</td><td style='padding:6px 0;font-size:14px;color:#333'>$p</td></tr>" : '';
    $ref  = '#HW-' . date('ymd') . '-' . rand(1000, 9999);

    /* ── Email 1: Notification to support@harmaalwale.com ── */
    $notifyHtml = "<!DOCTYPE html>
<html><head><meta charset='UTF-8'>
<title>New Enquiry</title></head>
<body style='margin:0;padding:0;background:#f0f0f0;font-family:Arial,sans-serif'>
<table width='100%' cellpadding='0' cellspacing='0' style='background:#f0f0f0;padding:24px 0'>
<tr><td align='center'>
<table width='600' cellpadding='0' cellspacing='0' style='background:#ffffff;border-radius:10px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.1)'>

  <!-- Header -->
  <tr><td style='background:#111111;padding:22px 28px'>
    <table width='100%' cellpadding='0' cellspacing='0'>
    <tr>
      <td style='font-size:22px;font-weight:900;text-transform:uppercase;color:#ffffff;letter-spacing:1px;font-family:Arial,sans-serif'>
        Harmaal<span style='color:#E87000'>Wale</span>
      </td>
      <td align='right'>
        <span style='background:#E87000;color:#fff;font-size:11px;font-weight:700;padding:5px 12px;border-radius:20px;letter-spacing:1px;text-transform:uppercase'>&#128233; New Enquiry</span>
      </td>
    </tr>
    </table>
  </td></tr>

  <!-- Body -->
  <tr><td style='padding:28px'>
    <p style='font-size:20px;font-weight:700;color:#111;margin:0 0 4px'>New message from your website</p>
    <p style='font-size:13px;color:#999;margin:0 0 24px'>Submitted via harmaalwale.com/support.html &nbsp;·&nbsp; $ref</p>

    <table width='100%' cellpadding='0' cellspacing='0' style='border-collapse:collapse'>
      <tr><td style='padding:6px 0;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:#999'>From</td><td style='padding:6px 0;font-size:14px;color:#333'>$n</td></tr>
      <tr><td style='padding:6px 0;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:#999'>Email</td><td style='padding:6px 0;font-size:14px'><a href='mailto:$e' style='color:#E87000'>$e</a></td></tr>
      $phoneRow
      <tr><td style='padding:6px 0;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:#999'>Subject</td><td style='padding:6px 0;font-size:14px;color:#333'>$s</td></tr>
    </table>

    <div style='background:#f9f9f9;border-left:3px solid #E87000;border-radius:0 6px 6px 0;padding:14px 16px;margin:18px 0'>
      <p style='font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:#999;margin:0 0 8px'>Message</p>
      <p style='font-size:14px;color:#333;margin:0;line-height:1.7'>$m</p>
    </div>

    <a href='mailto:$e?subject=Re: $s' style='display:inline-block;background:#E87000;color:#ffffff;text-decoration:none;padding:12px 26px;border-radius:7px;font-weight:700;font-size:14px;margin-top:6px'>Reply to $n &rarr;</a>
  </td></tr>

  <!-- Footer -->
  <tr><td style='background:#f9f9f9;padding:16px 28px;border-top:1px solid #eee;font-size:11px;color:#aaa;text-align:center'>
    HarmaalWale &nbsp;&middot;&nbsp; harmaalwale.com &nbsp;&middot;&nbsp; Use the Reply button above to respond
  </td></tr>

</table>
</td></tr>
</table>
</body></html>";

    hw_send(
        'support@harmaalwale.com',
        '[HarmaalWale] New Enquiry: ' . $subject,
        $notifyHtml,
        "$name <$email>"
    );

    /* ── Email 2: Auto-reply confirmation to customer ─────── */
    $confirmHtml = "<!DOCTYPE html>
<html><head><meta charset='UTF-8'>
<title>We received your message</title></head>
<body style='margin:0;padding:0;background:#f0f0f0;font-family:Arial,sans-serif'>
<table width='100%' cellpadding='0' cellspacing='0' style='background:#f0f0f0;padding:24px 0'>
<tr><td align='center'>
<table width='600' cellpadding='0' cellspacing='0' style='background:#ffffff;border-radius:10px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.1)'>

  <!-- Header -->
  <tr><td style='background:#111111;padding:22px 28px;text-align:center'>
    <p style='font-size:24px;font-weight:900;text-transform:uppercase;color:#ffffff;letter-spacing:1px;margin:0;font-family:Arial,sans-serif'>
      Harmaal<span style='color:#E87000'>Wale</span>
    </p>
  </td></tr>

  <!-- Body -->
  <tr><td style='padding:36px 28px;text-align:center'>
    <p style='font-size:48px;margin:0 0 16px'>&#9989;</p>
    <p style='font-size:22px;font-weight:700;color:#111;margin:0 0 12px'>We've got your message, $n!</p>
    <p style='font-size:14px;color:#666;line-height:1.7;margin:0 auto 24px;max-width:420px'>
      Thank you for reaching out. Our team will review your message and reply to
      <strong style='color:#111'>$e</strong> within 24 business hours.
    </p>

    <table width='100%' cellpadding='0' cellspacing='0' style='background:#f9f9f9;border:1px solid #eee;border-radius:8px;margin-bottom:24px'>
      <tr>
        <td style='padding:12px 20px;font-size:13px;color:#999;border-bottom:1px solid #eee'>Subject</td>
        <td style='padding:12px 20px;font-size:13px;color:#333;font-weight:600;border-bottom:1px solid #eee'>$s</td>
      </tr>
      <tr>
        <td style='padding:12px 20px;font-size:13px;color:#999'>Reference</td>
        <td style='padding:12px 20px;font-size:13px;color:#333;font-weight:600'>$ref</td>
      </tr>
    </table>

    <!-- Support hours -->
    <table width='100%' cellpadding='0' cellspacing='0' style='background:#111;border-radius:8px;margin-bottom:24px'>
      <tr><td colspan='2' style='padding:14px 20px 6px;font-size:11px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:#E87000'>&#9200; Support Hours</td></tr>
      <tr>
        <td style='padding:6px 20px;font-size:13px;color:#777;border-top:1px solid #1e1e1e'>Monday &ndash; Friday</td>
        <td style='padding:6px 20px;font-size:13px;color:#ccc;font-weight:600;border-top:1px solid #1e1e1e;text-align:right'>10:00 AM &ndash; 6:00 PM</td>
      </tr>
      <tr>
        <td style='padding:6px 20px 14px;font-size:13px;color:#777;border-top:1px solid #1e1e1e'>Saturday &amp; Sunday</td>
        <td style='padding:6px 20px 14px;font-size:13px;color:#e74c3c;font-weight:600;border-top:1px solid #1e1e1e;text-align:right'>Closed</td>
      </tr>
    </table>

    <p style='font-size:13px;color:#999;margin:0 0 14px'>Need a faster reply? Chat with us on WhatsApp.</p>
    <a href='https://wa.me/917891004042?text=Hi%20HarmaalWale%2C%20my%20enquiry%20ref%20is%20$ref' style='display:inline-block;background:#25D366;color:#fff;text-decoration:none;padding:11px 26px;border-radius:7px;font-weight:700;font-size:14px'>&#128172; WhatsApp Us</a>
  </td></tr>

  <!-- Footer -->
  <tr><td style='background:#f9f9f9;padding:16px 28px;border-top:1px solid #eee;font-size:11px;color:#aaa;text-align:center'>
    &copy; " . date('Y') . " HarmaalWale &nbsp;&middot;&nbsp; support@harmaalwale.com &nbsp;&middot;&nbsp; harmaalwale.com
  </td></tr>

</table>
</td></tr>
</table>
</body></html>";

    hw_send(
        $email,
        'We received your message — HarmaalWale Support',
        $confirmHtml
    );

    jsonResponse(['success' => true, 'message' => 'Message sent!'], 201);
}

/* ═══════════════════════════════════════════════════════════
   GET — Admin: list all enquiries
═══════════════════════════════════════════════════════════ */
if ($method === 'GET') {
    requireAdmin();
    $db     = getDB();
    $status = $_GET['status'] ?? '';
    $id     = isset($_GET['id']) ? intval($_GET['id']) : 0;

    if ($id) {
        $s = $db->prepare("SELECT * FROM enquiries WHERE id=?");
        $s->bind_param('i', $id); $s->execute();
        $row = $s->get_result()->fetch_assoc(); $s->close();
        $db->close();
        jsonResponse(['success' => true, 'enquiry' => $row]);
    }

    $where = $status ? "WHERE status='$status'" : '';
    $r = $db->query("SELECT * FROM enquiries $where ORDER BY created_at DESC LIMIT 200");
    $rows = $r ? $r->fetch_all(MYSQLI_ASSOC) : [];
    $db->close();
    jsonResponse(['success' => true, 'enquiries' => $rows, 'count' => count($rows)]);
}

/* ═══════════════════════════════════════════════════════════
   PUT — Admin: update enquiry status
═══════════════════════════════════════════════════════════ */
if ($method === 'PUT' && isset($_GET['id'])) {
    requireAdmin();
    $id     = intval($_GET['id']);
    $status = getBody()['status'] ?? 'read';
    $db     = getDB();
    $s      = $db->prepare("UPDATE enquiries SET status=? WHERE id=?");
    $s->bind_param('si', $status, $id); $s->execute(); $s->close();
    $db->close();
    jsonResponse(['success' => true, 'message' => 'Updated']);
}
