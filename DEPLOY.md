# HarmaalWale — Deploy Guide

## Flow
```
Your PC
  ├──► GitHub  (git push)          ┐
  └──► cPanel  (rsync over SSH)    ┘  run in parallel
```

---

## One-Time Setup (do this once)

### 1. Generate SSH Key
Open **Git Bash** and run:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/harmaalwale_deploy -C "harmaalwale"
```
Press Enter twice (no passphrase needed).

### 2. Add Key to cPanel
```bash
cat ~/.ssh/harmaalwale_deploy.pub
```
Copy the output, then:
- cPanel → **SSH Access** → **Manage SSH Keys** → **Import Key**
- Paste → **Import** → **Authorize**

### 3. Test SSH
```bash
ssh -i ~/.ssh/harmaalwale_deploy -p 22 harmakko@harmaalwale.com
```
Should log in. Type `exit` to leave.

### 4. Create .env
```bash
cp .env.example .env
```
`.env` is already prefilled with your details. No changes needed unless SSH key path differs.

### 5. Set Git Remote
```bash
git remote set-url origin https://github.com/harmaalwale/harmaalwale.git
```

### 6. Run Database Schema
- cPanel → **phpMyAdmin**
- Select `harmakko_hw_customer` database
- Click **SQL** tab
- Open `schema.sql`, copy all, paste → **Go**

### 7. Set Email Password
- Open `api/config.php`
- Find `YOUR_NOREPLY_EMAIL_PASSWORD`
- Replace with password of `noreply@harmaalwale.com`

---

## Deploy (every time)

**Windows** — double-click `deploy.bat`

**Mac/Linux/Git Bash:**
```bash
./deploy.sh
```

With custom message:
```bash
./deploy.sh "fix: updated homepage"
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Permission denied (publickey)` | Redo Step 2 |
| `Port 22 refused` | Script auto-tries port 2222 |
| `main branch not found` | Script auto-renames master→main |
| `CRLF warnings` | Normal on Windows, safe to ignore |
