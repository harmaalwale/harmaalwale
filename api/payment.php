<?php
// ============================================================
//  HarmaalWale — Payment API
//  POST /api/payment.php?action=create_order     → Razorpay order
//  POST /api/payment.php?action=verify_razorpay  → verify + save
//  POST /api/payment.php?action=payu_hash        → PayU hash generation
//  POST /api/payment.php?action=payu_callback    → PayU success/failure
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

// ── Generate order reference ─────────────────────────────────
function genRef() {
    return 'HW' . strtoupper(substr(md5(uniqid(mt_rand(), true)), 0, 8));
}

// ── Create Razorpay order ────────────────────────────────────
if ($action === 'create_order') {
    $auth = requireAuth();
    $b    = getBody();
    $amount = intval(floatval($b['amount'] ?? 0) * 100); // Convert to paise

    if ($amount < 100) jsonResponse(['error' => 'Invalid amount'], 400);

    $curl = curl_init('https://api.razorpay.com/v1/orders');
    curl_setopt_array($curl, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_USERPWD        => RAZORPAY_KEY_ID . ':' . RAZORPAY_KEY_SECRET,
        CURLOPT_POSTFIELDS     => json_encode([
            'amount'          => $amount,
            'currency'        => 'INR',
            'receipt'         => genRef(),
            'notes'           => ['user_id' => $auth['uid']]
        ]),
        CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
    ]);
    $res  = curl_exec($curl);
    $code = curl_getinfo($curl, CURLINFO_HTTP_CODE);
    curl_close($curl);

    if ($code !== 200) jsonResponse(['error' => 'Payment gateway error. Try again.'], 500);

    $order = json_decode($res, true);
    jsonResponse([
        'success'    => true,
        'order_id'   => $order['id'],
        'amount'     => $order['amount'],
        'currency'   => $order['currency'],
        'key'        => RAZORPAY_KEY_ID
    ]);
}

// ── Verify Razorpay payment ──────────────────────────────────
if ($action === 'verify_razorpay') {
    $auth = requireAuth();
    $b    = getBody();

    $rzpOrderId   = $b['razorpay_order_id']   ?? '';
    $rzpPaymentId = $b['razorpay_payment_id']  ?? '';
    $rzpSignature = $b['razorpay_signature']   ?? '';

    // Verify signature
    $expected = hash_hmac('sha256', $rzpOrderId . '|' . $rzpPaymentId, RAZORPAY_KEY_SECRET);
    if ($expected !== $rzpSignature) {
        jsonResponse(['error' => 'Payment verification failed'], 400);
    }

    // Save order to database
    $db      = getDB();
    $total   = floatval($b['amount'] ?? 0) / 100;
    $addrId  = intval($b['address_id'] ?? 0);
    $ref     = genRef();

    $stmt = $db->prepare(
        "INSERT INTO orders (order_ref,user_id,address_id,total,payment_method,payment_id,payment_status,status)
         VALUES (?,?,?,?,'razorpay',?,'paid','confirmed')"
    );
    $stmt->bind_param('siids', $ref, $auth['uid'], $addrId, $total, $rzpPaymentId);
    $stmt->execute();
    $orderId = $db->insert_id;

    // Save order items
    $items = $b['items'] ?? [];
    foreach ($items as $item) {
        $s = $db->prepare("INSERT INTO order_items (order_id,product_id,name,price,quantity,image) VALUES (?,?,?,?,?,?)");
        $pid = intval($item['product_id'] ?? 0) ?: null;
        $s->bind_param('iisdis', $orderId, $pid, $item['name'], $item['price'], $item['quantity'], ($item['image']??''));
        $s->execute();
    }
    $db->close();

    // Send confirmation email
    $user = requireAuth();
    $db2  = getDB();
    $st   = $db2->prepare("SELECT name,email FROM users WHERE id=?");
    $st->bind_param('i', $auth['uid']); $st->execute();
    $u    = $st->get_result()->fetch_assoc();
    $db2->close();

    if ($u['email']) {
        $itemRows = '';
        foreach ($items as $item) {
            $itemRows .= "<tr><td style='padding:8px;border-bottom:1px solid #eee'>" . htmlspecialchars($item['name']) . "</td>
                              <td style='padding:8px;border-bottom:1px solid #eee;text-align:right'>₹" . number_format($item['price'], 2) . "</td></tr>";
        }
        $body = emailTemplate("Order Confirmed! 🎉",
            "<p>Hi <strong>" . htmlspecialchars($u['name']) . "</strong>,</p>
             <p>Your order has been confirmed. Here's your summary:</p>
             <p><strong>Order Ref:</strong> $ref<br>
                <strong>Payment ID:</strong> $rzpPaymentId<br>
                <strong>Total:</strong> ₹" . number_format($total, 2) . "</p>
             <table style='width:100%;border-collapse:collapse;margin:16px 0'>
               <tr><th style='padding:8px;background:#f5f5f5;text-align:left'>Item</th>
                   <th style='padding:8px;background:#f5f5f5;text-align:right'>Price</th></tr>
               $itemRows
             </table>
             <a href='" . SITE_URL . "/account.html' class='btn'>View Order →</a>
             <p>We'll notify you when your order ships.</p>"
        );
        sendEmail($u['email'], "Order Confirmed #$ref — HarmaalWale", $body);
    }

    jsonResponse(['success' => true, 'order_ref' => $ref, 'order_id' => $orderId]);
}

// ── Generate PayU hash ───────────────────────────────────────
if ($action === 'payu_hash') {
    $auth = requireAuth();
    $b    = getBody();

    $txnId   = genRef();
    $amount  = number_format(floatval($b['amount'] ?? 0), 2, '.', '');
    $name    = $b['name']    ?? '';
    $email   = $b['email']   ?? '';
    $phone   = $b['phone']   ?? '';
    $product = $b['product'] ?? 'HarmaalWale Order';
    $udf1    = $auth['uid'];

    // Hash: key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5||||||salt
    $hashStr = PAYU_MERCHANT_KEY . '|' . $txnId . '|' . $amount . '|' . $product . '|' .
               $name . '|' . $email . '|' . $udf1 . '||||||||||||' . PAYU_MERCHANT_SALT;
    $hash = hash('sha512', $hashStr);

    $mode  = PAYU_MODE;
    $paUrl = ($mode === 'live')
        ? 'https://secure.payu.in/_payment'
        : 'https://test.payu.in/_payment';

    jsonResponse([
        'success'   => true,
        'hash'      => $hash,
        'txn_id'    => $txnId,
        'key'       => PAYU_MERCHANT_KEY,
        'payu_url'  => $paUrl,
        'amount'    => $amount,
        'product'   => $product,
    ]);
}

// ── PayU success callback ────────────────────────────────────
if ($action === 'payu_success') {
    $post      = $_POST;
    $status    = $post['status'] ?? '';
    $txnId     = $post['txnid'] ?? '';
    $paymentId = $post['mihpayid'] ?? '';
    $amount    = $post['amount'] ?? 0;

    // Verify hash
    $hashStr  = PAYU_MERCHANT_SALT . '|' . $status . '||||||||||||' .
                ($post['email']??'') . '|' . ($post['firstname']??'') . '|' .
                ($post['productinfo']??'') . '|' . $amount . '|' . $txnId . '|' . PAYU_MERCHANT_KEY;
    $expected = hash('sha512', $hashStr);

    if ($expected !== ($post['hash'] ?? '') || $status !== 'success') {
        header('Location: ' . SITE_URL . '/checkout.html?status=failed');
        exit;
    }

    header('Location: ' . SITE_URL . '/account.html?tab=orders&status=paid&ref=' . $txnId);
    exit;
}

jsonResponse(['error' => 'Unknown action'], 400);
