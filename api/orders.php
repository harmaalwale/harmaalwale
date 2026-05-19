<?php
error_reporting(0);
ini_set('display_errors', 0);
// ============================================================
//  HarmaalWale — Orders API
//  GET  /api/orders.php           — my orders
//  GET  /api/orders.php?id=1      — order detail
//  POST /api/orders.php           — place order
//  PUT  /api/orders.php?id=1      [admin] — update status
//  GET  /api/orders.php?all=1     [admin] — all orders
// ============================================================
require_once 'db.php';
$auth   = requireAuth();
$uid    = $auth['uid'];
$method = $_SERVER['REQUEST_METHOD'];
$id     = intval($_GET['id'] ?? 0);

if ($method === 'GET') {
    $db = getDB();

    // Admin: all orders
    if (isset($_GET['all']) && $auth['role']==='admin') {
        $stmt = $db->prepare(
            "SELECT o.*, u.name as customer_name, u.email as customer_email
             FROM orders o JOIN users u ON o.user_id=u.id
             ORDER BY o.created_at DESC LIMIT 100");
        $stmt->execute();
        $orders = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        foreach ($orders as &$ord) {
            $s = $db->prepare("SELECT * FROM order_items WHERE order_id=?");
            $s->bind_param('i',$ord['id']); $s->execute();
            $ord['items'] = $s->get_result()->fetch_all(MYSQLI_ASSOC);
        }
        jsonResponse(['success'=>true,'orders'=>$orders,'count'=>count($orders)]);
    }

    // Single order
    if ($id) {
        $stmt = $db->prepare("SELECT o.*, a.line1,a.line2,a.city,a.state,a.pincode
                               FROM orders o LEFT JOIN addresses a ON o.address_id=a.id
                               WHERE o.id=? AND o.user_id=?");
        $stmt->bind_param('ii',$id,$uid);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        if (!$order) jsonResponse(['error'=>'Order not found'], 404);
        $s = $db->prepare("SELECT * FROM order_items WHERE order_id=?");
        $s->bind_param('i',$id); $s->execute();
        $order['items'] = $s->get_result()->fetch_all(MYSQLI_ASSOC);
        $db->close();
        jsonResponse(['success'=>true,'order'=>$order]);
    }

    // My orders list
    $stmt = $db->prepare("SELECT * FROM orders WHERE user_id=? ORDER BY created_at DESC");
    $stmt->bind_param('i',$uid);
    $stmt->execute();
    $orders = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    foreach ($orders as &$ord) {
        $s = $db->prepare("SELECT * FROM order_items WHERE order_id=?");
        $s->bind_param('i',$ord['id']); $s->execute();
        $ord['items'] = $s->get_result()->fetch_all(MYSQLI_ASSOC);
    }
    $db->close();
    jsonResponse(['success'=>true,'orders'=>$orders,'count'=>count($orders)]);
}

if ($method === 'POST') {
    $b         = getBody();
    $addressId = intval($b['address_id'] ?? 0);
    $payMethod = $b['payment_method'] ?? 'COD';
    $notes     = $b['notes'] ?? '';
    $db        = getDB();

    // Load cart
    $stmt = $db->prepare(
        "SELECT c.product_id, c.quantity, p.name, p.price, p.size, p.stock
         FROM cart c JOIN products p ON c.product_id=p.id WHERE c.user_id=?");
    $stmt->bind_param('i',$uid);
    $stmt->execute();
    $cart = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    if (empty($cart)) jsonResponse(['error'=>'Cart is empty'], 400);

    $subtotal = array_sum(array_map(fn($i)=>$i['price']*$i['quantity'], $cart));
    $shipping = $subtotal > 499 ? 0 : 49;
    $total    = $subtotal + $shipping;
    $orderNum = 'HW-' . strtoupper(substr(uniqid(),5)) . '-' . date('Ymd');

    // Create order
    $stmt = $db->prepare(
        "INSERT INTO orders (user_id,address_id,order_number,status,payment_method,subtotal,shipping,total,notes)
         VALUES (?,?,?,'pending',?,?,?,?,?)");
    $stmt->bind_param('iissdddis',$uid,$addressId,$orderNum,$payMethod,$subtotal,$shipping,$total,$notes);

    // Fix: correct bind_param types
    $stmt2 = $db->prepare(
        "INSERT INTO orders (user_id,address_id,order_number,status,payment_method,subtotal,shipping,total,notes)
         VALUES (?,?,?,'pending',?,?,?,?,?)");
    $stmt2->bind_param('iissddds',$uid,$addressId,$orderNum,$payMethod,$subtotal,$shipping,$total,$notes);
    $stmt2->execute();
    $orderId = $db->insert_id;

    // Add order items
    $iStmt = $db->prepare("INSERT INTO order_items (order_id,product_id,name,price,quantity,size) VALUES (?,?,?,?,?,?)");
    foreach ($cart as $item) {
        $iStmt->bind_param('iisdis',$orderId,$item['product_id'],$item['name'],$item['price'],$item['quantity'],$item['size']);
        $iStmt->execute();
    }

    // Clear cart
    $db->prepare("DELETE FROM cart WHERE user_id=?")->bind_param('i',$uid)->execute();
    $db->close();

    jsonResponse(['success'=>true,'order_id'=>$orderId,'order_number'=>$orderNum,
                  'total'=>$total,'message'=>'Order placed successfully!'], 201);
}

if ($method === 'PUT' && $id) {
    requireAdmin();
    $b      = getBody();
    $status = $b['status'] ?? '';
    $pstat  = $b['payment_status'] ?? null;
    $db     = getDB();
    if ($pstat) {
        $db->prepare("UPDATE orders SET status=?,payment_status=? WHERE id=?")
           ->bind_param('ssi',$status,$pstat,$id)->execute();
    } else {
        $db->prepare("UPDATE orders SET status=? WHERE id=?")
           ->bind_param('si',$status,$id)->execute();
    }
    $db->close();
    jsonResponse(['success'=>true,'message'=>'Order updated']);
}
