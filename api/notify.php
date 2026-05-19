<?php
// Notify/Waitlist API
require_once 'db.php';
if ($_SERVER['REQUEST_METHOD']==='POST') {
    $b=getBody(); $email=strtolower(trim($b['email']??''));
    $cat=$b['category']??'MFD';
    if (!$email||!filter_var($email,FILTER_VALIDATE_EMAIL))
        jsonResponse(['error'=>'Valid email required'],400);
    $db=getDB();
    $db->prepare("INSERT IGNORE INTO notify_list (email,category) VALUES (?,?)")->bind_param('ss',$email,$cat)->execute();
    $db->close();
    jsonResponse(['success'=>true,'message'=>"You're on the list! We'll notify you when $cat launches."]);
}
if ($_SERVER['REQUEST_METHOD']==='GET') {
    requireAdmin();
    $db=getDB();
    $rows=$db->query("SELECT * FROM notify_list ORDER BY created_at DESC")->fetch_all(MYSQLI_ASSOC);
    jsonResponse(['success'=>true,'list'=>$rows,'count'=>count($rows)]);
}
