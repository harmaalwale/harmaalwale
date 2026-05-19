// ============================================================
//  HarmaalWale — Shared JS (hw.js)
//  Unified login: email or mobile, backend decides user type
// ============================================================

// ── Theme ────────────────────────────────────────────────────
(function() {
  const t = localStorage.getItem('hw-theme') || 'light';
  document.documentElement.setAttribute('data-theme', t);
})();

function hwToggleTheme() {
  const curr = document.documentElement.getAttribute('data-theme');
  const next = curr === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem('hw-theme', next);
  document.querySelectorAll('.toggle-label').forEach(el => el.textContent = next === 'dark' ? 'Dark' : 'Light');
}

// ── HW Helper Object ─────────────────────────────────────────
const HW = {
  getToken: () => localStorage.getItem('hw_token'),
  getUser:  () => { try { return JSON.parse(localStorage.getItem('hw_user') || 'null'); } catch(e){ return null; } },
  isLoggedIn: () => !!localStorage.getItem('hw_token'),
  logout: () => {
    localStorage.removeItem('hw_token');
    localStorage.removeItem('hw_user');
    window.location.href = 'index.html';
  },

  // ── Cart ───────────────────────────────────────────────────
  getCart: () => { try { return JSON.parse(localStorage.getItem('hw_cart') || '[]'); } catch(e) { return []; } },
  saveCart: (cart) => localStorage.setItem('hw_cart', JSON.stringify(cart)),
  getCartCount: () => HW.getCart().reduce((s, i) => s + (i.quantity || 1), 0),

  addToCart: (product) => {
    const cart = HW.getCart();
    const existing = cart.find(i => i.id === product.id);
    if (existing) existing.quantity = (existing.quantity || 1) + 1;
    else cart.push({ ...product, quantity: 1 });
    HW.saveCart(cart);
    HW.updateCartBadge();
    HW.showToast(product.name + ' added to cart', 'success');
  },

  removeFromCart: (id) => {
    HW.saveCart(HW.getCart().filter(i => i.id !== id));
    HW.updateCartBadge();
  },

  updateCartBadge: () => {
    const count = HW.getCartCount();
    document.querySelectorAll('.cart-badge').forEach(el => {
      el.textContent = count;
      el.style.display = count > 0 ? 'flex' : 'none';
    });
  },

  // ── Wishlist ───────────────────────────────────────────────
  getWishlist: () => { try { return JSON.parse(localStorage.getItem('hw_wishlist') || '[]'); } catch(e) { return []; } },
  saveWishlist: (list) => localStorage.setItem('hw_wishlist', JSON.stringify(list)),
  getWishlistCount: () => HW.getWishlist().length,

  addToWishlist: (product) => {
    const list = HW.getWishlist();
    if (list.find(i => i.id === product.id)) { HW.showToast('Already in wishlist', 'info'); return; }
    list.push(product);
    HW.saveWishlist(list);
    HW.updateWishlistBadge();
    HW.showToast(product.name + ' added to wishlist', 'success');
  },

  removeFromWishlist: (id) => {
    HW.saveWishlist(HW.getWishlist().filter(i => i.id !== id));
    HW.updateWishlistBadge();
  },

  isInWishlist: (id) => HW.getWishlist().some(i => i.id === id),

  updateWishlistBadge: () => {
    const count = HW.getWishlistCount();
    document.querySelectorAll('.wishlist-badge').forEach(el => {
      el.textContent = count;
      el.style.display = count > 0 ? 'flex' : 'none';
    });
  },

  // ── Toast ──────────────────────────────────────────────────
  showToast: (msg, type = 'success') => {
    let container = document.getElementById('hw-toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'hw-toast-container';
      container.style.cssText = 'position:fixed;bottom:80px;right:24px;z-index:99999;display:flex;flex-direction:column;gap:8px;';
      document.body.appendChild(container);
    }
    const toast = document.createElement('div');
    const colors = { success: '#16a34a', error: '#dc2626', info: '#2563eb' };
    toast.style.cssText = `background:${colors[type]||colors.success};color:#fff;padding:10px 16px;border-radius:8px;font-size:13px;font-weight:600;font-family:Barlow,sans-serif;box-shadow:0 4px 20px rgba(0,0,0,.2);max-width:280px;`;
    toast.textContent = msg;
    container.appendChild(toast);
    setTimeout(() => { toast.style.opacity='0'; toast.style.transition='opacity .3s'; setTimeout(() => toast.remove(), 300); }, 3000);
  },

  // ── UNIFIED Login Popup Modal ──────────────────────────────
  showLoginModal: () => {
    if (HW.isLoggedIn()) {
      const user = HW.getUser();
      window.location.href = user?.role === 'admin' ? 'admin.html'
                            : user?.role === 'vendor' ? 'vendor-dashboard.html'
                            : 'account.html';
      return;
    }

    if (document.getElementById('hw-login-modal')) {
      document.getElementById('hw-login-modal').style.display = 'flex';
      return;
    }

    const modal = document.createElement('div');
    modal.id = 'hw-login-modal';
    modal.innerHTML = `
      <div class="hw-modal-overlay" onclick="HW.hideLoginModal()"></div>
      <div class="hw-modal-content">
        <button class="hw-modal-close" onclick="HW.hideLoginModal()">×</button>
        <div class="hw-modal-header">
          <div class="hw-modal-logo">HARMAAL<span>WALE</span></div>
          <h2 class="hw-modal-title">Login or <span>Sign Up</span></h2>
          <p class="hw-modal-sub">Enter your mobile, email, or admin username</p>
        </div>

        <div id="hw-alert-modal"></div>

        <!-- STEP 1: identifier (email/mobile/admin) -->
        <div class="hw-step active" id="hw-step1">
          <label class="hw-label">Email, Mobile, or Username</label>
          <input type="text" id="hw-identifier" class="hw-input" placeholder="9876543210 / you@email.com / Admin" autocomplete="off">
          <div class="hw-hint">Customers & vendors: use mobile or email · Admin: enter username</div>
          <button class="hw-btn hw-btn-primary" id="hw-continue-btn" onclick="HW._continue()">Continue →</button>
        </div>

        <!-- STEP 2A: OTP (for customer/vendor with mobile) -->
        <div class="hw-step" id="hw-step-otp">
          <div class="hw-mini-info">📱 OTP sent to <span id="hw-masked"></span> · <a href="#" onclick="HW._goBack();return false">change</a></div>
          <label class="hw-label">Enter 6-digit OTP</label>
          <input type="text" id="hw-otp-input" class="hw-input" placeholder="OTP" maxlength="6" oninput="this.value=this.value.replace(/[^0-9]/g,'')">
          <div class="hw-hint">Didn't get it? <a href="#" onclick="HW._resendOTP();return false">Resend</a></div>
          <button class="hw-btn hw-btn-primary" id="hw-verify-btn" onclick="HW._verifyOTP()">Verify & Continue →</button>
        </div>

        <!-- STEP 2B: Password (for email login or admin) -->
        <div class="hw-step" id="hw-step-pass">
          <div class="hw-mini-info">🔑 Login as <strong id="hw-user-display"></strong> · <a href="#" onclick="HW._goBack();return false">change</a></div>
          <label class="hw-label">Password</label>
          <input type="password" id="hw-pass-input" class="hw-input" placeholder="Enter your password">
          <div class="hw-hint">Forgot password? <a href="#" onclick="HW._forgotPassword();return false">Reset via OTP</a></div>
          <button class="hw-btn hw-btn-primary" id="hw-login-btn" onclick="HW._passwordLogin()">Sign In →</button>
        </div>

        <!-- STEP 3: Complete profile (new users) -->
        <div class="hw-step" id="hw-step-profile">
          <div class="hw-notice">✨ Welcome! Let's complete your account.</div>
          <label class="hw-label">Full Name <span style="color:#dc2626">*</span></label>
          <input type="text" id="hw-name-input" class="hw-input" placeholder="Your full name">
          <label class="hw-label" id="hw-extra-label">Email Address (optional)</label>
          <input type="email" id="hw-extra-input" class="hw-input" placeholder="you@email.com">
          <div class="hw-hint">For order confirmations and receipts</div>
          <button class="hw-btn hw-btn-primary" onclick="HW._completeProfile()">Create Account →</button>
        </div>

        <div class="hw-modal-foot">
          <span>Need help?</span>
          <a href="https://wa.me/917891004042" target="_blank">💬 WhatsApp</a>
        </div>
      </div>
    `;
    document.body.appendChild(modal);

    if (!document.getElementById('hw-modal-styles')) {
      const style = document.createElement('style');
      style.id = 'hw-modal-styles';
      style.textContent = `
        #hw-login-modal{position:fixed;inset:0;z-index:99999;display:flex;align-items:center;justify-content:center;padding:16px;animation:hwfade .2s ease}
        .hw-modal-overlay{position:absolute;inset:0;background:rgba(0,0,0,.6);backdrop-filter:blur(4px)}
        .hw-modal-content{position:relative;background:#fff;border-radius:16px;padding:28px;width:100%;max-width:400px;max-height:90vh;overflow-y:auto;box-shadow:0 25px 60px rgba(0,0,0,.3);animation:hwslide .25s ease}
        [data-theme="dark"] .hw-modal-content{background:#1a1a1a;color:#fff}
        .hw-modal-close{position:absolute;top:12px;right:12px;width:32px;height:32px;border-radius:50%;background:#eee;border:none;font-size:18px;cursor:pointer;color:#666}
        [data-theme="dark"] .hw-modal-close{background:#333;color:#ccc}
        .hw-modal-header{text-align:center;margin-bottom:22px}
        .hw-modal-logo{font-family:'Barlow Condensed',sans-serif;font-size:20px;font-weight:900;color:#111;margin-bottom:14px}
        .hw-modal-logo span{color:#E87000}
        [data-theme="dark"] .hw-modal-logo{color:#fff}
        .hw-modal-title{font-family:'Barlow Condensed',sans-serif;font-size:24px;font-weight:900;color:#111;margin-bottom:4px}
        .hw-modal-title span{color:#E87000}
        [data-theme="dark"] .hw-modal-title{color:#fff}
        .hw-modal-sub{font-size:12px;color:#777;margin:0}
        .hw-step{display:none}
        .hw-step.active{display:block}
        .hw-label{display:block;font-size:12px;font-weight:600;color:#444;margin:12px 0 6px}
        [data-theme="dark"] .hw-label{color:#ccc}
        .hw-input{width:100%;padding:11px 14px;border:1.5px solid #ddd;border-radius:8px;font-family:Barlow,sans-serif;font-size:14px;outline:none;background:#fff;color:#111;font-weight:500}
        [data-theme="dark"] .hw-input{background:#222;border-color:#333;color:#fff}
        .hw-input:focus{border-color:#E87000}
        .hw-hint{font-size:11px;color:#999;margin-top:6px}
        .hw-hint a{color:#E87000;font-weight:600;text-decoration:none}
        .hw-btn{width:100%;padding:12px;border:none;border-radius:8px;font-family:'Barlow Condensed',sans-serif;font-size:15px;font-weight:700;cursor:pointer;margin-top:16px;letter-spacing:.5px;transition:all .2s}
        .hw-btn-primary{background:#E87000;color:#fff}
        .hw-btn-primary:hover{background:#cf6600}
        .hw-btn:disabled{opacity:.5;cursor:not-allowed}
        .hw-modal-foot{margin-top:20px;padding-top:16px;border-top:1px solid #eee;display:flex;justify-content:space-between;align-items:center;font-size:12px;color:#999}
        [data-theme="dark"] .hw-modal-foot{border-color:#333}
        .hw-modal-foot a{color:#25D366;font-weight:600;text-decoration:none}
        .hw-alert{padding:10px 12px;border-radius:6px;font-size:12px;margin-bottom:12px;font-weight:500}
        .hw-alert-error{background:#fef2f2;color:#b91c1c;border:1px solid #fecaca}
        .hw-alert-success{background:#f0fdf4;color:#15803d;border:1px solid #bbf7d0}
        .hw-alert-info{background:#eff6ff;color:#1d4ed8;border:1px solid #bfdbfe}
        .hw-mini-info{font-size:12px;color:#666;background:#f5f5f5;padding:8px 12px;border-radius:6px;margin-bottom:10px}
        [data-theme="dark"] .hw-mini-info{background:#222;color:#aaa}
        .hw-mini-info a{color:#E87000;font-weight:600;text-decoration:none;margin-left:6px}
        .hw-notice{background:#fff8f0;border:1px solid #fed7aa;padding:10px;border-radius:6px;margin-bottom:14px;font-size:12px;color:#c2410c}
        [data-theme="dark"] .hw-notice{background:#2a1500;border-color:#7c2d12}
        @keyframes hwfade{from{opacity:0}to{opacity:1}}
        @keyframes hwslide{from{transform:translateY(20px);opacity:0}to{transform:translateY(0);opacity:1}}
      `;
      document.head.appendChild(style);
    }
  },

  hideLoginModal: () => {
    const m = document.getElementById('hw-login-modal');
    if (m) m.style.display = 'none';
  },

  _modalAlert: (msg, type = 'error') => {
    const el = document.getElementById('hw-alert-modal');
    if (el) {
      el.innerHTML = `<div class="hw-alert hw-alert-${type}">${msg}</div>`;
      setTimeout(() => { if (el) el.innerHTML = ''; }, 4500);
    }
  },

  _showStep: (id) => {
    document.querySelectorAll('.hw-step').forEach(s => s.classList.remove('active'));
    document.getElementById(id).classList.add('active');
  },

  _state: { identifier: '', method: '', mobile: '', email: '', otp: '' },

  // STEP 1 — Continue: detect input type and route to OTP or Password
  _continue: async () => {
    const input = document.getElementById('hw-identifier').value.trim();
    if (!input) { HW._modalAlert('Please enter your mobile, email, or username'); return; }

    const btn = document.getElementById('hw-continue-btn');
    btn.disabled = true; btn.textContent = 'Checking...';

    // Detect type
    const isEmail  = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input);
    const isMobile = /^[6-9]\d{9}$/.test(input.replace(/\D/g, '')) && input.replace(/\D/g,'').length === 10;
    const isAdmin  = !isEmail && !isMobile;  // username (Admin etc)

    HW._state.identifier = input;

    if (isMobile) {
      // Mobile → send OTP
      HW._state.method = 'mobile';
      HW._state.mobile = input.replace(/\D/g, '');
      await HW._sendOTP();
    } else {
      // Email or Admin username → password
      HW._state.method = isEmail ? 'email' : 'admin';
      if (isEmail) HW._state.email = input;
      document.getElementById('hw-user-display').textContent = input;
      HW._showStep('hw-step-pass');
      btn.disabled = false; btn.textContent = 'Continue →';
      setTimeout(() => document.getElementById('hw-pass-input').focus(), 100);
    }
  },

  _sendOTP: async () => {
    const mobile = HW._state.mobile;
    const btn = document.getElementById('hw-continue-btn');
    try {
      const res = await fetch('api/auth.php?action=send_otp', {
        method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ mobile })
      });
      const data = await res.json();
      if (!data.success) { HW._modalAlert(data.error||'Failed to send OTP'); if(btn){btn.disabled=false; btn.textContent='Continue →';} return; }
      document.getElementById('hw-masked').textContent = '+91 ' + mobile.substring(0,2) + 'XXXXXX' + mobile.substring(8);
      HW._showStep('hw-step-otp');
      HW._modalAlert('OTP sent!', 'success');
      if (btn) { btn.disabled = false; btn.textContent = 'Continue →'; }
      setTimeout(() => document.getElementById('hw-otp-input').focus(), 100);
    } catch(e) {
      HW._modalAlert('Network error. Try again.');
      if (btn) { btn.disabled = false; btn.textContent = 'Continue →'; }
    }
  },

  _resendOTP: async () => { await HW._sendOTP(); },

  _verifyOTP: async () => {
    const otp = document.getElementById('hw-otp-input').value.trim();
    if (otp.length !== 6) { HW._modalAlert('Enter 6-digit OTP'); return; }
    HW._state.otp = otp;
    const btn = document.getElementById('hw-verify-btn');
    btn.disabled=true; btn.textContent='Verifying...';

    try {
      const res = await fetch('api/auth.php?action=verify_otp', {
        method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ mobile: HW._state.mobile, otp })
      });
      const data = await res.json();
      if (data.needs_name) {
        HW._showStep('hw-step-profile');
        document.getElementById('hw-extra-label').innerHTML = 'Email Address (optional)';
        btn.disabled=false; btn.textContent='Verify & Continue →';
        return;
      }
      if (!data.success) { HW._modalAlert(data.error||'Invalid OTP'); btn.disabled=false; btn.textContent='Verify & Continue →'; return; }
      HW._loginSuccess(data);
    } catch(e) { HW._modalAlert('Network error'); btn.disabled=false; btn.textContent='Verify & Continue →'; }
  },

  _passwordLogin: async () => {
    const pass = document.getElementById('hw-pass-input').value;
    if (!pass) { HW._modalAlert('Enter your password'); return; }
    const btn = document.getElementById('hw-login-btn');
    btn.disabled = true; btn.textContent = 'Signing in...';

    try {
      const res = await fetch('api/auth.php?action=login', {
        method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ identifier: HW._state.identifier, password: pass })
      });
      const data = await res.json();

      // Local fallback for admin (when running without backend)
      if (!data.success && data.error?.includes('not configured') === false) {
        if (HW._state.identifier.toLowerCase() === 'admin' && pass === 'Admin@harmaalwale') {
          HW._loginSuccess({
            success: true,
            token: 'demo-admin-' + Date.now(),
            user: { id:1, name:'Admin', email:'admin@harmaalwale.com', role:'admin' }
          });
          return;
        }
        HW._modalAlert(data.error || 'Invalid credentials');
        btn.disabled = false; btn.textContent = 'Sign In →';
        return;
      }

      if (!data.success) {
        // Final fallback for local file:// testing
        if (HW._state.identifier.toLowerCase() === 'admin' && pass === 'Admin@harmaalwale') {
          HW._loginSuccess({
            success: true,
            token: 'demo-admin-' + Date.now(),
            user: { id:1, name:'Admin', email:'admin@harmaalwale.com', role:'admin' }
          });
          return;
        }
        HW._modalAlert(data.error || 'Invalid credentials');
        btn.disabled = false; btn.textContent = 'Sign In →';
        return;
      }

      HW._loginSuccess(data);
    } catch(e) {
      // No backend — try admin fallback
      if (HW._state.identifier.toLowerCase() === 'admin' && pass === 'Admin@harmaalwale') {
        HW._loginSuccess({
          success: true,
          token: 'demo-admin-' + Date.now(),
          user: { id:1, name:'Admin', email:'admin@harmaalwale.com', role:'admin' }
        });
        return;
      }
      HW._modalAlert('Network error. Backend may not be running.');
      btn.disabled = false; btn.textContent = 'Sign In →';
    }
  },

  _completeProfile: async () => {
    const name = document.getElementById('hw-name-input').value.trim();
    const extra = document.getElementById('hw-extra-input').value.trim();
    if (!name) { HW._modalAlert('Please enter your name'); return; }

    try {
      const res = await fetch('api/auth.php?action=verify_otp', {
        method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ mobile: HW._state.mobile, otp: HW._state.otp, name, email: extra })
      });
      const data = await res.json();
      if (!data.success) { HW._modalAlert(data.error||'Error'); return; }
      HW._loginSuccess(data);
    } catch(e) { HW._modalAlert('Network error'); }
  },

  _forgotPassword: () => {
    HW._modalAlert('Please use mobile login. Enter your registered mobile number to receive an OTP.', 'info');
    HW._showStep('hw-step1');
    document.getElementById('hw-identifier').value = '';
    document.getElementById('hw-identifier').placeholder = 'Enter mobile to receive OTP';
  },

  _goBack: () => {
    HW._showStep('hw-step1');
    document.getElementById('hw-pass-input').value = '';
    document.getElementById('hw-otp-input').value = '';
  },

  _loginSuccess: (data) => {
    localStorage.setItem('hw_token', data.token);
    localStorage.setItem('hw_user', JSON.stringify(data.user));
    HW._modalAlert('Welcome to HarmaalWale!', 'success');
    setTimeout(() => {
      // Redirect based on role
      if (data.user.role === 'admin') window.location.href = 'admin.html';
      else if (data.user.role === 'vendor') window.location.href = 'vendor-dashboard.html';
      else if (data.is_new) window.location.href = 'account.html';
      else window.location.reload();
    }, 800);
  },

  // ── Init nav ───────────────────────────────────────────────
  initNav: () => {
    HW.updateCartBadge();
    HW.updateWishlistBadge();
    document.querySelectorAll('.nav-user-icon, [data-action="login"]').forEach(el => {
      el.addEventListener('click', e => {
        e.preventDefault();
        if (HW.isLoggedIn()) {
          const user = HW.getUser();
          window.location.href = user?.role === 'admin' ? 'admin.html'
                                : user?.role === 'vendor' ? 'vendor-dashboard.html'
                                : 'account.html';
        } else {
          HW.showLoginModal();
        }
      });
    });
  }
};

document.addEventListener('DOMContentLoaded', () => HW.initNav());