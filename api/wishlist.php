<?php
error_reporting(0);
ini_set('display_errors', 0);
// ============================================================
//  HarmaalWale — Wishlist API
//  GET    /api/wishlist.php          — get wishlist
//  POST   /api/wishlist.php          — add item
//  DELETE /api/wishlist.php?id=1     — remove item
// ============================================================
require_once 'db.php';
$auth   = requireAuth();
$uid    = $auth['uid'];
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $db   = getDB();
    $stmt = $db->prepare(
        "SELECT w.id, w.product_id, p.name, p.price, p.image, p.size, p.fabric
         FROM wishlist w JOIN products p ON w.product_id=p.id
         WHERE w.user_id=? ORDER BY w.created_at DESC");
    $stmt->bind_param('i', $uid);
    $stmt->execute();
    $items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $db->close();
    jsonResponse(['success'=>true,'items'=>$items,'count'=>count($items)]);
}

if ($method === 'POST') {
    $pid = intval(getBody()['product_id'] ?? 0);
    if (!$pid) jsonResponse(['error'=>'Product ID required'], 400);
    $db = getDB();
    $stmt = $db->prepare("INSERT IGNORE INTO wishlist (user_id,product_id) VALUES (?,?)");
    $stmt->bind_param('ii', $uid, $pid);
    $stmt->execute();
    $db->close();
    jsonResponse(['success'=>true,'message'=>'Added to wishlist']);
}

if ($method === 'DELETE') {
    $wid = intval($_GET['id'] ?? 0);
    $db  = getDB();
    $db->prepare("DELETE FROM wishlist WHERE id=? AND user_id=?")->bind_param('ii',$wid,$uid)->execute();
    $db->close();
    jsonResponse(['success'=>true,'message'=>'Removed from wishlist']);
}
