#!/bin/bash
# =============================================================
# HarmaalWale — Deploy Script
# Pushes simultaneously to:
#   1. GitHub  (git push)
#   2. cPanel  (rsync over SSH)
# =============================================================

set -euo pipefail

# ── Load config ───────────────────────────────────────────────
if [ ! -f ".env" ]; then
  echo "❌ .env not found. Copy .env.example → .env and fill values."
  exit 1
fi
export $(grep -v '^#' .env | grep -v '^$' | xargs)

: "${GIT_BRANCH:=main}"
: "${SSH_HOST:?Set SSH_HOST in .env}"
: "${SSH_USER:?Set SSH_USER in .env}"
: "${SSH_PORT:=22}"
: "${SSH_REMOTE_PATH:?Set SSH_REMOTE_PATH in .env}"
: "${SSH_KEY:?Set SSH_KEY (path to private key) in .env}"

LOG_DIR=".deploy_logs"
mkdir -p "$LOG_DIR"

GIT_LOG="$LOG_DIR/git.log"
SSH_LOG="$LOG_DIR/ssh.log"

# ── Excludes ──────────────────────────────────────────────────
RSYNC_EXCLUDES=(
  "--exclude=.git"
  "--exclude=.env"
  "--exclude=.env.*"
  "--exclude=deploy.sh"
  "--exclude=DEPLOY.md"
  "--exclude=SETUP.md"
  "--exclude=nginx.conf"
  "--exclude=schema.sql"
  "--exclude=node_modules"
  "--exclude=.deploy_logs"
  "--exclude=*.7z"
  "--exclude=*.zip"
)

# ── Banner ────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   HarmaalWale — Deploy                   ║"
echo "║   GitHub + cPanel  (parallel)            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Git commit ────────────────────────────────────────────────
git add -A
if git diff --cached --quiet; then
  echo "ℹ️  Nothing new to commit."
else
  COMMIT_MSG="${1:-deploy: $(date '+%Y-%m-%d %H:%M:%S')}"
  git commit -m "$COMMIT_MSG"
  echo "📝 Committed: $COMMIT_MSG"
fi

# ── Launch both in parallel ───────────────────────────────────
echo ""
echo "🚀 Pushing to GitHub and cPanel simultaneously..."
echo ""

# -- Job 1: GitHub push
(
  git push origin "$GIT_BRANCH" > "$GIT_LOG" 2>&1
  echo $? > "$LOG_DIR/git.exit"
) &
GIT_PID=$!

# -- Job 2: cPanel via rsync over SSH
(
  rsync -az --delete \
    -e "ssh -p ${SSH_PORT} -i ${SSH_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=15" \
    "${RSYNC_EXCLUDES[@]}" \
    ./ "${SSH_USER}@${SSH_HOST}:${SSH_REMOTE_PATH}/" \
    > "$SSH_LOG" 2>&1
  echo $? > "$LOG_DIR/ssh.exit"
) &
SSH_PID=$!

# ── Spinner while both run ────────────────────────────────────
spin=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
i=0
while kill -0 $GIT_PID 2>/dev/null || kill -0 $SSH_PID 2>/dev/null; do
  kill -0 $GIT_PID 2>/dev/null && G="🔄 GitHub: running" || G="✅ GitHub: done   "
  kill -0 $SSH_PID 2>/dev/null && S="🔄 cPanel: running" || S="✅ cPanel: done   "
  printf "\r  %s  %s  %s" "${spin[$((i % 10))]}" "$G" "$S"
  sleep 0.2
  i=$((i+1))
done
printf "\r%70s\r" " "

wait $GIT_PID 2>/dev/null || true
wait $SSH_PID 2>/dev/null || true

# ── Results ───────────────────────────────────────────────────
GIT_EXIT=$(cat "$LOG_DIR/git.exit" 2>/dev/null || echo "1")
SSH_EXIT=$(cat "$LOG_DIR/ssh.exit" 2>/dev/null || echo "1")

echo "──────────────────────────────────────────"
[ "$GIT_EXIT" = "0" ] && echo "  ✅ GitHub  → pushed successfully" || { echo "  ❌ GitHub  → FAILED"; cat "$GIT_LOG"; }
[ "$SSH_EXIT" = "0" ] && echo "  ✅ cPanel  → deployed via SSH"    || { echo "  ❌ cPanel  → FAILED"; cat "$SSH_LOG"; }
echo "──────────────────────────────────────────"

[ "$GIT_EXIT" != "0" ] || [ "$SSH_EXIT" != "0" ] && { echo ""; echo "⚠️  Check logs in $LOG_DIR/"; exit 1; }

echo ""
echo "  🌐 Live → https://harmaalwale.com"
echo ""
