HARMAALWALE DEPLOYMENT SCRIPTS - COMPLETE GUIDE
================================================================

✅ FIXED ISSUES:
1. Window no longer auto-closes
2. Window asks for input to close (type 'x' then press Enter)
3. Created two batch files with different purposes
4. Full logging and status tracking

================================================================
FILE 1: deploy.bat
================================================================
PURPOSE: Deploy only CHANGED files to GitHub + cPanel

FEATURES:
- Only uploads files you've modified
- Detects changes automatically
- Pushes to GitHub first
- Then uploads to cPanel
- Sets correct permissions (644)
- Creates deployment log
- Window stays open until you type 'x'

USAGE:
1. Double-click deploy.bat
2. It shows all changed files
3. Pushes to GitHub
4. Uploads to cPanel
5. Creates log at: deploy-log.json
6. Window stays open - type 'x' to close

WHAT IT UPLOADS:
- login.html (if changed)
- test.html (if changed)
- config.php (if changed)
- auth.php (if changed)

================================================================
FILE 2: refresh.bat (NEW)
================================================================
PURPOSE: Full refresh - uploads ALL files + clears cache

FEATURES:
- Forces push of ALL files (not just changed)
- Clears browser cache on server
- Updates CSS/JS files
- Good for fixing cache issues
- Complete system refresh

USAGE:
1. Double-click refresh.bat
2. Uploads ALL files to cPanel
3. Clears server cache
4. Creates refresh log
5. Type 'x' to close

WHAT IT UPLOADS:
- All HTML files
- All PHP files
- CSS files
- JS files
- Everything gets updated

USE WHEN:
- Changes not showing on live site
- Browser caching issues
- Need complete fresh deployment
- Cache problems

================================================================
SETUP (One-time only)
================================================================

Already completed:
✓ SSH keys setup
✓ config.php configured
✓ auth.php deployed
✓ Database migrations done

No additional setup needed - files ready to use!

================================================================
LOCATION
================================================================
Both files go in:
D:\Working Data\harmaalwale_v3\

deploy.bat ← Replace your current one
refresh.bat ← Add this new file

================================================================
HOW TO USE
================================================================

For daily work (changed files only):
  Double-click: deploy.bat

For full refresh (all files + clear cache):
  Double-click: refresh.bat

Window behavior:
  - Stays open after deployment
  - Type 'x' and press ENTER to close
  - Shows all status messages
  - Shows any errors clearly

================================================================
LOGS
================================================================

deploy.bat creates: deploy-log.json
  - Shows last deployment time
  - Lists all files uploaded
  - Shows GitHub & cPanel status

refresh.bat creates: refresh-log.json
  - Shows refresh time
  - Count of files uploaded
  - Cache clear confirmation

View logs at: https://harmaalwale.com/test.html

================================================================
TROUBLESHOOTING
================================================================

If window still closes too fast:
  1. Right-click deploy.bat
  2. Choose "Edit"
  3. Find: :KEEP_OPEN section
  4. It has a loop that waits for input
  5. Type 'x' to close

If upload fails:
  1. Check SSH key: %USERPROFILE%\.ssh\id_rsa
  2. Check cPanel credentials in script
  3. Check internet connection
  4. Check file permissions on local machine

If "No changes" appears:
  1. Edit a file in D:\Working Data\harmaalwale_v3\
  2. Save the file
  3. Run deploy.bat again
  4. It will detect the changes

================================================================
IMPORTANT NOTES
================================================================

1. Always use deploy.bat for normal work
   - Faster (only changed files)
   - Safer (you control what uploads)

2. Use refresh.bat only when needed
   - When changes aren't showing
   - When cache is stuck
   - For complete system refresh

3. Both files need SSH key:
   - Must be at: C:\Users\[YOUR_USERNAME]\.ssh\id_rsa
   - Generated during setup

4. Window must stay open:
   - DON'T CLOSE while showing status
   - Wait for "type 'x'" message
   - Then type 'x' and press ENTER

================================================================
WHAT'S NEW IN THIS VERSION
================================================================

✅ Window stays open indefinitely
✅ Uses input loop (type 'x' to close)
✅ No timeout/auto-close issues
✅ New refresh.bat for full deployment
✅ Simplified logging
✅ Better error handling
✅ Clear status messages

================================================================
QUICK REFERENCE
================================================================

deploy.bat   → For daily changes
refresh.bat  → For cache/full refresh
Type 'x'     → To close window
View logs    → https://harmaalwale.com/test.html

================================================================
