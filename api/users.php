<?php
// ============================================================
//  HarmaalWale — Users API
//  GET    /api/users.php?action=profile
//  POST   /api/users.php?action=update_profile
//  GET    /api/users.php?action=addresses
//  POST   /api/users.php?action=add_address
//  PUT    /api/users.php?action=update_address&id=1
//  DELETE /api/users.php?action=delete_address&id=1
//  POST   /api/users.php?action=set_default_address&id=1
//  GET    /api/users.php?action=wishlist
//  POST   /api/users.php?action=add_wishlist
//  DELETE /api/users.php?action=remove_wishlist&id=1
//  GET    /api/users.php?action=orders
// ============================================================
error_reporting(0);
ini_set('display_errors', 0);
require_once 'db.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

$auth   = requireAuth();
$uid    = $auth['uid'];
$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? getBody()['action'] ?? '';
$id     = intval($_GET['id'] ?? 0);

// ── Profile ──────────────────────────────────────────────────
if ($action === 'profile') {
    $db   = getDB();
    $stmt = $db->prepare("SELECT id,name,email,mobile,role,avatar,dob,gender,created_at FROM users WHERE id=?");
    $stmt->bind_param('i', $uid);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $db->close();
    jsonResponse(['success' => true, 'user' => $user]);
}

if ($action === 'update_profile') {
    $b  = getBody();
    $db = getDB();
    $allowed = ['name','email','dob','gender'];
    $fields  = []; $params = []; $types = '';
    foreach ($allowed as $f) {
        if (isset($b[$f]) && $b[$f] !== '') {
            $fields[] = "$f=?"; $params[] = $b[$f]; $types .= 's';
        }
    }
    if ($fields) {
        $stmt = $db->prepare("UPDATE users SET " . implode(',', $fields) . " WHERE id=?");
        $params[] = $uid; $types .= 'i';
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
    }
    $stmt = $db->prepare("SELECT id,name,email,mobile,avatar,dob,gender FROM users WHERE id=?");
    $stmt->bind_param('i', $uid);
    $stmt->execute();
    $db->close();
    jsonResponse(['success' => true, 'user' => $stmt->get_result()->fetch_assoc()]);
}

// ── Addresses ────────────────────────────────────────────────
if ($action === 'addresses') {
    $db   = getDB();
    $stmt = $db->prepare("SELECT * FROM addresses WHERE user_id=? ORDER BY is_default DESC, id DESC");
    $stmt->bind_param('i', $uid);
    $stmt->execute();
    $addresses = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $db->close();
    jsonResponse(['success' => true, 'addresses' => $addresses]);
}

if ($action === 'add_address') {
    $b = getBody();
    foreach (['name','mobile','line1','city','state','pincode'] as $f) {
        if (empty($b[$f])) jsonResponse(['error' => "Missing: $f"], 400);
    }
    $db = getDB();
    // If first address, make it default
    $countStmt = $db->prepare("SELECT COUNT(*) as c FROM addresses WHERE user_id=?");
    $countStmt->bind_param('i', $uid); $countStmt->execute();
    $count = $countStmt->get_result()->fetch_assoc()['c'];
    $isDefault = ($count === 0) ? 1 : intval($b['is_default'] ?? 0);
    if ($isDefault) $db->prepare("UPDATE addresses SET is_default=0 WHERE user_id=?")->execute([$uid]);
    $stmt = $db->prepare("INSERT INTO addresses (user_id,label,name,mobile,line1,line2,city,state,pincode,is_default) VALUES (?,?,?,?,?,?,?,?,?,?)");
    $label = $b['label'] ?? 'Home';
    $stmt->bind_param('issssssssi', $uid,$label,$b['name'],$b['mobile'],$b['line1'],($b['line2']??''),$b['city'],$b['state'],$b['pincode'],$isDefault);
    $stmt->execute();
    $newId = $db->insert_id;
    $db->close();
    jsonResponse(['success' => true, 'id' => $newId, 'message' => 'Address saved']);
}

if ($action === 'update_address' && $id) {
    $b  = getBody();
    $db = getDB();
    $stmt = $db->prepare("UPDATE addresses SET label=?,name=?,mobile=?,line1=?,line2=?,city=?,state=?,pincode=? WHERE id=? AND user_id=?");
    $stmt->bind_param('ssssssssii', $b['label'],$b['name'],$b['mobile'],$b['line1'],($b['line2']??''),$b['city'],$b['state'],$b['pincode'],$id,$uid);
    $stmt->execute();
    $db->close();
    jsonResponse(['success' => true, 'message' => 'Address updated']);
}

if ($action === 'delete_address' && $id) {
    $db = getDB();
    $db->prepare("DELETE FROM addresses WHERE id=? AND user_id=?")->execute([$id, $uid]);
    $db->close();
    jsonResponse(['success' => true, 'message' => 'Address deleted']);
}

if ($action === 'set_default_address' && $id) {
    $db = getDB();
    $db->prepare("UPDATE addresses SET is_default=0 WHERE user_id=?")->execute([$uid]);
    $db->prepare("UPDATE addresses SET is_default=1 WHERE id=? AND user_id=?")->execute([$id, $uid]);
    $db->close();
    jsonResponse(['success' => true, 'message' => 'Default address updated']);
}

// ── Wishlist ─────────────────────────────────────────────────
if ($action === 'wishlist') {
    $db   = getDB();
    $stmt = $db->prepare("SELECT * FROM wishlist WHERE user_id=? ORDER BY added_at DESC");
    $stmt->bind_param('i', $uid);
    $stmt->execute();
    $items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $db->close();
    jsonResponse(['success' => true, 'items' => $items, 'count' => count($items)]);
}

if ($action === 'add_wishlist') {
    $b  = getBody();
    $db = getDB();
    $productId = intval($b['product_id'] ?? 0) ?: null;
    $stmt = $db->prepare("INSERT IGNORE INTO wishlist (user_id,product_id,name,price,image) VALUES (?,?,?,?,?)");
    $stmt->bind_param('iisss', $uid, $productId, $b['name'], ($b['price']??''), ($b['image']??''));
    $stmt->execute();
    $db->close();
    jsonResponse(['success' => true, 'message' => 'Added to wishlist']);
}

if ($action === 'remove_wishlist' && $id) {
    $db = getDB();
    $db->prepare("DELETE FROM wishlist WHERE id=? AND user_id=?")->execute([$id, $uid]);
    $db->close();
    jsonResponse(['success' => true, 'message' => 'Removed from wishlist']);
}

// ── Orders ───────────────────────────────────────────────────
if ($action === 'orders') {
    $db   = getDB();
    $stmt = $db->prepare("SELECT * FROM orders WHERE user_id=? ORDER BY created_at DESC");
    $stmt->bind_param('i', $uid);
    $stmt->execute();
    $orders = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    foreach ($orders as &$ord) {
        $s = $db->prepare("SELECT * FROM order_items WHERE order_id=?");
        $s->bind_param('i', $ord['id']); $s->execute();
        $ord['items'] = $s->get_result()->fetch_all(MYSQLI_ASSOC);
    }
    $db->close();
    jsonResponse(['success' => true, 'orders' => $orders, 'count' => count($orders)]);
}

jsonResponse(['error' => 'Unknown action'], 400);
