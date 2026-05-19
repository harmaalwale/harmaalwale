<?php
// ============================================================
//  HarmaalWale — Products API
//  GET  /api/products.php                  — list all
//  GET  /api/products.php?id=1             — single product
//  GET  /api/products.php?category=fashion — by category
//  POST /api/products.php         [admin]  — create
//  PUT  /api/products.php?id=1    [admin]  — update
//  DELETE /api/products.php?id=1  [admin]  — delete
// ============================================================
require_once 'db.php';

$method = $_SERVER['REQUEST_METHOD'];
$id     = intval($_GET['id'] ?? 0);

if ($method === 'GET') {
    $db = getDB();

    if ($id) {
        $stmt = $db->prepare("SELECT p.*, c.name as category_name, c.slug as category_slug 
                              FROM products p JOIN categories c ON p.category_id=c.id 
                              WHERE p.id=? AND p.status='active'");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $product = $stmt->get_result()->fetch_assoc();
        if (!$product) jsonResponse(['error'=>'Product not found'], 404);
        jsonResponse(['success'=>true,'product'=>$product]);
    }

    $where  = "WHERE p.status='active'";
    $params = [];
    $types  = '';

    if (!empty($_GET['category'])) {
        $slug = $_GET['category'];
        $where .= " AND c.slug=?";
        $types   .= 's';
        $params[] = $slug;
    }
    if (!empty($_GET['size'])) {
        $where .= " AND p.size=?";
        $types   .= 's';
        $params[] = $_GET['size'];
    }
    if (!empty($_GET['search'])) {
        $where .= " AND (p.name LIKE ? OR p.description LIKE ?)";
        $types   .= 'ss';
        $q = '%'.$_GET['search'].'%';
        $params[] = $q;
        $params[] = $q;
    }

    $sql  = "SELECT p.*, c.name as category_name, c.slug as category_slug 
             FROM products p JOIN categories c ON p.category_id=c.id 
             $where ORDER BY p.created_at DESC";
    $stmt = $db->prepare($sql);
    if ($types) $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $products = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $db->close();
    jsonResponse(['success'=>true,'count'=>count($products),'products'=>$products]);
}

if ($method === 'POST') {
    requireAdmin();
    $b = getBody();
    $db = getDB();
    $stmt = $db->prepare("INSERT INTO products (category_id,name,slug,description,price,stock,size,fabric,shoulder,neck,sleeve,length,chest,image) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
    $slug = strtolower(preg_replace('/[^a-z0-9]+/','-', $b['name']??''));
    $stmt->bind_param('isssdissssssss',
        $b['category_id'],$b['name'],$slug,$b['description'],$b['price'],
        $b['stock'],$b['size'],$b['fabric'],$b['shoulder'],$b['neck'],
        $b['sleeve'],$b['length'],$b['chest'],$b['image']);
    $stmt->execute();
    $newId = $db->insert_id;
    $db->close();
    jsonResponse(['success'=>true,'id'=>$newId,'message'=>'Product created'], 201);
}

if ($method === 'PUT' && $id) {
    requireAdmin();
    $b = getBody();
    $db = getDB();
    $stmt = $db->prepare("UPDATE products SET name=?,description=?,price=?,stock=?,size=?,fabric=?,shoulder=?,neck=?,sleeve=?,`length`=?,chest=?,image=?,status=? WHERE id=?");
    $stmt->bind_param('ssdissssssssi',
        $b['name'],$b['description'],$b['price'],$b['stock'],
        $b['size'],$b['fabric'],$b['shoulder'],$b['neck'],
        $b['sleeve'],$b['length'],$b['chest'],$b['image'],$b['status'],$id);
    $stmt->execute();
    $db->close();
    jsonResponse(['success'=>true,'message'=>'Product updated']);
}

if ($method === 'DELETE' && $id) {
    requireAdmin();
    $db = getDB();
    $db->prepare("UPDATE products SET status='inactive' WHERE id=?")->bind_param('i',$id)->execute();
    $db->close();
    jsonResponse(['success'=>true,'message'=>'Product removed']);
}
