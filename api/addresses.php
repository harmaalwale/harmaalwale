<?php
error_reporting(0);
ini_set('display_errors', 0);
// Addresses API
require_once 'db.php';
$auth = requireAuth(); $uid = $auth['uid'];
$method = $_SERVER['REQUEST_METHOD']; $id = intval($_GET['id']??0);

if ($method==='GET') {
    $db=$db=getDB();
    $s=$db->prepare("SELECT * FROM addresses WHERE user_id=? ORDER BY is_default DESC, id DESC");
    $s->bind_param('i',$uid); $s->execute();
    jsonResponse(['success'=>true,'addresses'=>$s->get_result()->fetch_all(MYSQLI_ASSOC)]);
}
if ($method==='POST') {
    $b=getBody(); $db=getDB();
    if ($b['is_default']??false) $db->prepare("UPDATE addresses SET is_default=0 WHERE user_id=?")->bind_param('i',$uid)->execute();
    $s=$db->prepare("INSERT INTO addresses (user_id,label,name,phone,line1,line2,city,state,pincode,country,is_default) VALUES (?,?,?,?,?,?,?,?,?,?,?)");
    $def=intval($b['is_default']??0);
    $s->bind_param('issssssssi',$uid,$b['label'],$b['name'],$b['phone'],$b['line1'],$b['line2'],$b['city'],$b['state'],$b['pincode'],$b['country'],$def);
    $s->execute(); $newId=$db->insert_id; $db->close();
    jsonResponse(['success'=>true,'id'=>$newId,'message'=>'Address saved'],201);
}
if ($method==='DELETE'&&$id) {
    $db=getDB(); $db->prepare("DELETE FROM addresses WHERE id=? AND user_id=?")->bind_param('ii',$id,$uid)->execute(); $db->close();
    jsonResponse(['success'=>true,'message'=>'Address deleted']);
}
