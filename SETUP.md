# HarmaalWale — Setup & Deployment Guide

## 📂 What's in this folder

```
harmaalwale/
├── index.html               Homepage
├── login.html               OTP login/register
├── account.html             User dashboard (orders, addresses, wishlist, profile)
├── cart.html                Shopping cart
├── wishlist.html            Wishlist
├── checkout.html            Razorpay + PayU + COD checkout
├── support.html             Contact form (sends to support@harmaalwale.com)
├── need-help.html           FAQ + help options
├── seller.html              Vendor application form
├── vendor-dashboard.html    Vendor product management
├── seller_admin.html        Admin → seller management
├── admin.html               Admin dashboard
├── mfd-spares.html          MFD Spares catalog (16 products + cart/wishlist)
├── mfd-refurbished.html     Refurbished MFDs
├── fashion.html             Fashion category
├── categories.html          All categories
│
├── api/
│   ├── config.php           ⚠️ EDIT THIS — credentials
│   ├── db.php               DB + email + SMS helpers
│   ├── auth.php             OTP login/register
│   ├── users.php            Profile, addresses, wishlist, orders
│   ├── cart.php             Shopping cart
│   ├── orders.php           Order management
│   ├── payment.php          Razorpay + PayU
│   ├── seller.php           Vendor registration + approval
│   ├── support.php          Contact form → email
│   └── ... (other helpers)
│
├── assets/
│   ├── css/hw.css           Shared stylesheet
│   ├── js/hw.js             Auth + cart + wishlist state
│   └── images/              Logos, backgrounds
│
├── schema.sql               ⚠️ RUN THIS in phpMyAdmin
├── .htaccess                URL routing
├── robots.txt               SEO
└── sitemap.xml              SEO
```

---

## 🚀 Quick Start — Local Testing (XAMPP/WAMP)

### Step 1 — Install XAMPP
Download from [apachefriends.org](https://www.apachefriends.org/)

### Step 2 — Place files
Extract the zip to:
```
C:\xampp\htdocs\harmaalwale\
```

### Step 3 — Start Apache + MySQL
Open XAMPP Control Panel → Start **Apache** and **MySQL**

### Step 4 — Create database
1. Open `http://localhost/phpmyadmin`
2. Click **New** → name it `harmaalwale` → Create
3. Click **Import** → select `schema.sql` → Go

### Step 5 — Configure
Edit `api/config.php`:
```php
define('DB_HOST', 'localhost');
define('DB_USER', 'root');           // XAMPP default
define('DB_PASS', '');                // XAMPP default (empty)
define('DB_NAME', 'harmaalwale');
```

### Step 6 — Open in browser
```
http://localhost/harmaalwale/
```

✅ **You can now browse, register, login, add to cart, etc.**

---

## 🌐 cPanel Production Deployment

### Step 1 — Upload files
Upload zip via cPanel File Manager → extract to `/public_html/`

### Step 2 — Create MySQL database
cPanel → **MySQL Databases** → create database + user → assign all privileges

### Step 3 — Import schema
cPanel → **phpMyAdmin** → select your DB → Import `schema.sql`

### Step 4 — Configure `api/config.php`
```php
define('DB_HOST', 'localhost');
define('DB_USER', 'yourcpanel_dbuser');
define('DB_PASS', 'your_password');
define('DB_NAME', 'yourcpanel_dbname');

// Email (cPanel → Email Accounts → create noreply@yourdomain)
define('MAIL_PASS', 'your_email_password');

// SMS OTP — sign up at fast2sms.com
define('SMS_API_KEY', 'your_fast2sms_key');

// Razorpay — from razorpay.com dashboard
define('RAZORPAY_KEY_ID',     'rzp_live_xxxxxxx');
define('RAZORPAY_KEY_SECRET', 'xxxxxxxxxxxxxxxxx');

// PayU — from payu.in dashboard
define('PAYU_MERCHANT_KEY',  'xxxxxxx');
define('PAYU_MERCHANT_SALT', 'xxxxxxx');
define('PAYU_MODE',          'live');  // or 'test'
```

### Step 5 — Test
Visit `https://harmaalwale.com` → register → place test order

---

## 🔑 Default Admin Login

After importing `schema.sql`:

- **Email**: `admin@harmaalwale.com`
- **Mobile**: `9999999999`
- **Password**: `HarmaalWale@2026`

**Change immediately after first login!**

---

## 🧪 Testing Each Feature

| Feature | How to test |
|---|---|
| **Homepage** | Open `index.html` — all nav icons should work |
| **Register** | Click account icon → enter mobile → enter OTP (dev mode prints OTP to error log) |
| **Login** | Same flow, existing users skip the name field |
| **Cart** | Add product from `mfd-spares.html` → click cart icon |
| **Wishlist** | Click heart on product card → check wishlist |
| **Account** | View Orders, Edit Profile, Manage Addresses |
| **Support form** | Fill form → check `enquiries` table + email arrives |
| **Sell on HarmaalWale** | Visit `seller.html` → submit application |
| **Vendor dashboard** | After approval, login → add products |
| **Admin** | `admin.html` — view applications, approve sellers |

---

## ⚠️ Required External Setup

Before going live, sign up and add API keys to `api/config.php`:

1. **Fast2SMS** (mobile OTP) — [fast2sms.com](https://www.fast2sms.com) — free tier available
2. **Razorpay** — [razorpay.com](https://razorpay.com) — already linked per user
3. **PayU** — [payu.in](https://payu.in) — already linked per user
4. **Email** — cPanel → Email Accounts → create `noreply@harmaalwale.com`

---

## 📧 Email Routing

All forms send to: **support@harmaalwale.com**
- Support form → `api/support.php`
- Seller application → `api/seller.php`
- Order confirmation → user's email + admin

Make sure `support@harmaalwale.com` exists in cPanel → Email Accounts.

---

## 🔒 Security Checklist Before Going Live

- [ ] Change `JWT_SECRET` in `api/config.php`
- [ ] Change `ADMIN_TOKEN` in `api/config.php`
- [ ] Change admin password (default in schema)
- [ ] Ensure `api/.htaccess` blocks direct file listing
- [ ] Switch `PAYU_MODE` to `'live'` when ready
- [ ] Remove `debug_login.php`, `reset_admin.php` if present
- [ ] Use HTTPS only (cPanel → SSL/TLS Status → AutoSSL)

---

## 🆘 Troubleshooting

**"Database connection failed"** → Check credentials in `api/config.php`

**OTP not arriving** → Add Fast2SMS API key. In dev mode, OTP is logged to PHP error log.

**Email not sending** → Check cPanel → Email Accounts. Use SMTP if `mail()` is disabled.

**Razorpay errors** → Verify Key ID + Secret are correct + currency is INR.

**Files won't open locally with `file://`** → Use XAMPP/localhost. PHP APIs need a server.
