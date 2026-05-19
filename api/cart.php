<?php
error_reporting(0); ini_set('display_errors', 0);
require_once 'db.php';
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
$auth=$method=$id=null;
$auth=requireAuth(); $uid=$auth['uid'];
$method=$_SERVER['REQUEST_METHOD']; $id=intval($_GET['id']??0);
if($method==='GET'){$db=getDB();$stmt=$db->prepare("SELECT * FROM cart WHERE user_id=? ORDER BY added_at DESC");$stmt->bind_param('i',$uid);$stmt->execute();$items=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);$total=array_sum(array_map(fn($i)=>floatval($i['price'])*intval($i['quantity']),$items));$db->close();jsonResponse(['success'=>true,'items'=>$items,'count'=>count($items),'total'=>$total]);}
if($method==='POST'){$b=getBody();$db=getDB();$pid=intval($b['product_id']??0)?:null;$qty=max(1,intval($b['quantity']??1));if($pid){$chk=$db->prepare("SELECT id,quantity FROM cart WHERE user_id=? AND product_id=?");$chk->bind_param('ii',$uid,$pid);$chk->execute();$ex=$chk->get_result()->fetch_assoc();if($ex){$db->prepare("UPDATE cart SET quantity=? WHERE id=?")->execute([$ex['quantity']+$qty,$ex['id']]);$db->close();jsonResponse(['success'=>true,'action'=>'updated']);}}$stmt=$db->prepare("INSERT INTO cart (user_id,product_id,name,price,image,quantity) VALUES (?,?,?,?,?,?)");$stmt->bind_param('iisdsi',$uid,$pid,$b['name'],floatval($b['price']??0),($b['image']??''),$qty);$stmt->execute();$db->close();jsonResponse(['success'=>true,'action'=>'added']);}
if($method==='PUT'&&$id){$b=getBody();$db=getDB();$db->prepare("UPDATE cart SET quantity=? WHERE id=? AND user_id=?")->execute([max(1,intval($b['quantity']??1)),$id,$uid]);$db->close();jsonResponse(['success'=>true]);}
if($method==='DELETE'){$db=getDB();if(isset($_GET['clear'])){$db->prepare("DELETE FROM cart WHERE user_id=?")->execute([$uid]);$db->close();jsonResponse(['success'=>true,'message'=>'Cart cleared']);}if($id){$db->prepare("DELETE FROM cart WHERE id=? AND user_id=?")->execute([$id,$uid]);$db->close();jsonResponse(['success'=>true]);}}
jsonResponse(['error'=>'Invalid request'],400);
