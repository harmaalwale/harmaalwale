#!/bin/bash
# ═══════════════════════════════════════════════════
#  HarmaalWale — Deploy Script
#  Pushes simultaneously to GitHub + cPanel via SSH
#  Run from Git Bash on Windows or Terminal on Mac/Linux
# ═══════════════════════════════════════════════════

set -euo pipefail

if [ ! -f ".env" ]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill values."
  exit 1
fi
export $(grep -v '^#' .env | grep -v '^$' | xargs)

: "${SSH_HOST:=harmaalwale.com}"
: "${SSH_USER:=harmakko}"
: "${SSH_PORT:=22}"
: "${SSH_REMOTE_PATH:=/home1/harmakko/public_html}"
: "${SSH_KEY:=$HOME/.ssh/harmaalwale_deploy}"
: "${GIT_BRANCH:=main}"

LOG_DIR=".deploy_logs"
mkdir -p "$LOG_DIR"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   HarmaalWale — Deploy                   ║"
echo "║   GitHub + cPanel  (parallel)            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Fix branch name (master → main) ─────────────────────────
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")
if [ "$CURRENT_BRANCH" = "master" ]; then
  echo "↪ Renaming branch: master → main"
  git branch -m master main
  git push origin -u main 2>/dev/null || true
  CURRENT_BRANCH="main"
fi

# ── Git commit ───────────────────────────────────────────────
git add -A
if git diff --cached --quiet; then
  echo "ℹ  Nothing new to commit."
else
  MSG="${1:-deploy: $(date '+%Y-%m-%d %H:%M:%S')}"
  git commit -m "$MSG"
  echo "✏  Committed: $MSG"
fi

echo ""
echo "🚀 Pushing GitHub + cPanel simultaneously..."
echo ""

# ── Job 1: GitHub ────────────────────────────────────────────
(
  git push origin "$GIT_BRANCH" > "$LOG_DIR/git.log" 2>&1
  echo $? > "$LOG_DIR/git.exit"
) &
GIT_PID=$!

# ── Job 2: cPanel — SSH into server, git pull from GitHub ────
# No rsync needed — works on Windows Git Bash out of the box

REPO_DIR="/home1/harmakko/harmaalwale_repo"
DEPLOY_DIR="${SSH_REMOTE_PATH}"
GITHUB_REPO="https://github.com/harmaalwale/harmaalwale.git"

try_deploy() {
  local PORT=$1
  ssh -i "${SSH_KEY}" -p "$PORT" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    "${SSH_USER}@${SSH_HOST}" bash << REMOTE
      set -e
      # Clone repo if first time, otherwise pull latest
      if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR"
        git fetch origin
        git reset --hard origin/main
      else
        mkdir -p "$REPO_DIR"
        git clone "$GITHUB_REPO" "$REPO_DIR"
      fi

      # Copy files to public_html (exclude sensitive/deploy files)
      rsync -a --delete \
        --exclude='.git' \
        --exclude='deploy.sh' \
        --exclude='deploy.bat' \
        --exclude='Deploy HarmaalWale.bat' \
        --exclude='DEPLOY.md' \
        --exclude='SETUP.md' \
        --exclude='nginx.conf' \
        --exclude='schema.sql' \
        --exclude='.env*' \
        --exclude='*.bak' \
        "$REPO_DIR/" "$DEPLOY_DIR/"

      echo "Deploy complete on server"
REMOTE
}

(
  try_deploy 22 > "$LOG_DIR/ssh.log" 2>&1
  if [ $? -ne 0 ]; then
    echo "Port 22 failed, trying 2222..." >> "$LOG_DIR/ssh.log"
    try_deploy 2222 >> "$LOG_DIR/ssh.log" 2>&1
  fi
  echo $? > "$LOG_DIR/ssh.exit"
) &
SSH_PID=$!

# ── Spinner ──────────────────────────────────────────────────
spin=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
i=0
while kill -0 $GIT_PID 2>/dev/null || kill -0 $SSH_PID 2>/dev/null; do
  kill -0 $GIT_PID 2>/dev/null && G="⏳ GitHub: running" || G="✅ GitHub: done   "
  kill -0 $SSH_PID 2>/dev/null && S="⏳ cPanel: running" || S="✅ cPanel: done   "
  printf "\r  %s  %s  %s" "${spin[$((i % 10))]}" "$G" "$S"
  sleep 0.2; i=$((i+1))
done
printf "\r%70s\r" " "
wait $GIT_PID 2>/dev/null || true
wait $SSH_PID 2>/dev/null || true

# ── Results ──────────────────────────────────────────────────
GIT_EXIT=$(cat "$LOG_DIR/git.exit" 2>/dev/null || echo "1")
SSH_EXIT=$(cat "$LOG_DIR/ssh.exit" 2>/dev/null || echo "1")

echo "──────────────────────────────────────────────"
[ "$GIT_EXIT" = "0" ] && echo "  ✅ GitHub  → https://github.com/harmaalwale/harmaalwale" || { echo "  ❌ GitHub  → FAILED"; cat "$LOG_DIR/git.log"; }
[ "$SSH_EXIT" = "0" ] && echo "  ✅ cPanel  → deployed to /home1/harmakko/public_html"   || { echo "  ❌ cPanel  → FAILED"; cat "$LOG_DIR/ssh.log"; }
echo "──────────────────────────────────────────────"

[ "$GIT_EXIT" != "0" ] || [ "$SSH_EXIT" != "0" ] && { echo ""; echo "⚠  One or more failed. Check .deploy_logs/"; exit 1; }

echo ""
echo "  🌐 Live → https://harmaalwale.com"
echo ""
