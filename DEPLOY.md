# HarmaalWale — Deploy Setup

## How It Works

```
Your Local Machine
      │
      ├──► GitHub  (git push origin main)       ┐
      │                                          ├── run in parallel
      └──► cPanel  (rsync over SSH)             ┘
```

Both run at the same time. One command does everything.

---

## One-Time Setup

### 1. Generate SSH key pair

```bash
ssh-keygen -t ed25519 -f ~/.ssh/harmaalwale_deploy -C "harmaalwale-deploy"
```

This creates two files:
- `~/.ssh/harmaalwale_deploy` → private key (stays on your machine)
- `~/.ssh/harmaalwale_deploy.pub` → public key (goes to cPanel)

### 2. Add public key to cPanel

1. cPanel → **SSH Access** → **Manage SSH Keys** → **Import Key**
2. Paste contents of `~/.ssh/harmaalwale_deploy.pub`
3. Click **Authorize** next to the imported key

### 3. Set up `.env`

```bash
cp .env.example .env
```

Fill in your values:

| Variable | Where to find it |
|----------|-----------------|
| `SSH_HOST` | Your domain, e.g. `harmaalwale.com` |
| `SSH_USER` | cPanel username (top-right in cPanel) |
| `SSH_PORT` | Usually `22`. Some hosts use `2222` |
| `SSH_REMOTE_PATH` | `/home/username/public_html` |
| `SSH_KEY` | Path to private key: `~/.ssh/harmaalwale_deploy` |

### 4. Test SSH connection

```bash
ssh -i ~/.ssh/harmaalwale_deploy -p 22 username@harmaalwale.com
```

Should log into cPanel server. Type `exit` to leave.

### 5. Initialize git (first time only)

```bash
git init
git remote add origin https://github.com/YOURUSERNAME/harmaalwale.git
git add -A
git commit -m "initial"
git push -u origin main
```

### 6. Make deploy script executable

```bash
chmod +x deploy.sh
```

---

## Deploy

```bash
./deploy.sh
```

Optional — custom commit message:

```bash
./deploy.sh "fix: updated homepage banner"
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Permission denied (publickey)` | Run step 2 again — key not authorized in cPanel |
| `rsync: command not found` | `sudo apt install rsync` or `brew install rsync` |
| `ssh: connect to host port 22: Connection refused` | Try `SSH_PORT=2222` in `.env` |
| `git push` asks for password | Set up git credential manager or use SSH remote URL |
