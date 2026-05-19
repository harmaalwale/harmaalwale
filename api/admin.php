<?php
// ============================================================
//  HarmaalWale — Admin API
//  GET /api/admin.php?action=stats        → dashboard stats
//  GET /api/admin.php?action=users        → all users
//  GET /api/admin.php?action=orders       → all orders
//  GET /api/admin.php?action=products     → all vendor products
//  GET /api/admin.php?action=enquiries    → all support tickets
// ============================================================
error_reporting(0); ini_set('display_errors', 0);
require_once 'db.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

requireAdmin();

$action = $_GET['action'] ?? '';
$db = getDB();

if ($action === 'stats') {
    $stats = ['users'=>0,'orders'=>0,'revenue'=>0,'sellers'=>0,'pending_apps'=>0,'tickets'=>0,'products'=>0];
    $q = function($sql) use ($db) { $r = $db->query($sql); return $r ? $r->fetch_assoc() : null; };

    $u = $q("SELECT COUNT(*) c FROM users WHERE role='user'");           $stats['users']    = intval($u['c'] ?? 0);
    $o = $q("SELECT COUNT(*) c, COALESCE(SUM(total),0) t FROM orders");  $stats['orders']   = intval($o['c'] ?? 0); $stats['revenue'] = floatval($o['t'] ?? 0);
    $s = $q("SELECT COUNT(*) c FROM sellers WHERE is_active=1");         $stats['sellers']  = intval($s['c'] ?? 0);
    $p = $q("SELECT COUNT(*) c FROM seller_applications WHERE status='pending'"); $stats['pending_apps'] = intval($p['c'] ?? 0);
    $t = $q("SELECT COUNT(*) c FROM enquiries WHERE status='new'");      $stats['tickets']  = intval($t['c'] ?? 0);
    $pr = $q("SELECT COUNT(*) c FROM seller_products");                  $stats['products'] = intval($pr['c'] ?? 0);

    $db->close();
    $stats['success'] = true;
    jsonResponse($stats);
}

if ($action === 'users') {
    $r = $db->query("SELECT id,name,email,mobile,role,is_active,created_at FROM users WHERE role='user' ORDER BY created_at DESC LIMIT 200");
    $users = $r ? $r->fetch_all(MYSQLI_ASSOC) : [];
    $db->close();
    jsonResponse(['success' => true, 'users' => $users, 'count' => count($users)]);
}

if ($action === 'orders') {
    $r = $db->query("SELECT o.*, u.name as user_name FROM orders o LEFT JOIN users u ON o.user_id=u.id ORDER BY o.created_at DESC LIMIT 200");
    $orders = $r ? $r->fetch_all(MYSQLI_ASSOC) : [];
    $db->close();
    jsonResponse(['success' => true, 'orders' => $orders, 'count' => count($orders)]);
}

if ($action === 'products') {
    $r = $db->query("SELECT sp.*, s.biz_name as vendor_name FROM seller_products sp LEFT JOIN sellers s ON sp.seller_id=s.id ORDER BY sp.created_at DESC LIMIT 200");
    $products = $r ? $r->fetch_all(MYSQLI_ASSOC) : [];
    $db->close();
    jsonResponse(['success' => true, 'products' => $products, 'count' => count($products)]);
}

if ($action === 'enquiries') {
    $r = $db->query("SELECT * FROM enquiries ORDER BY created_at DESC LIMIT 200");
    $enquiries = $r ? $r->fetch_all(MYSQLI_ASSOC) : [];
    $db->close();
    jsonResponse(['success' => true, 'enquiries' => $enquiries, 'count' => count($enquiries)]);
}

if ($action === 'approve_product') {
    $b = getBody();
    $id = intval($b['id'] ?? 0);
    $db->prepare("UPDATE seller_products SET status='approved' WHERE id=?")->execute([$id]);
    $db->close();
    jsonResponse(['success' => true, 'message' => 'Product approved and live']);
}

if ($action === 'reject_product') {
    $b = getBody();
    $id = intval($b['id'] ?? 0);
    $db->prepare("UPDATE seller_products SET status='rejected' WHERE id=?")->execute([$id]);
    $db->close();
    jsonResponse(['success' => true, 'message' => 'Product rejected']);
}

$db->close();
jsonResponse(['error' => 'Unknown action'], 400);
