// WolfeWaveSignals Header v2 - Kostenlos, kein Login
// Einbinden: <div id="site-header"></div> + <script src="/components/header.js"></script>

(function() {
  const headerHTML = `
  <style>
  :root {
    --header-bg: rgba(15, 23, 42, 0.95);
    --header-border: rgba(255,255,255,0.06);
    --nav-text: #94a3b8;
    --nav-active: #10b981;
    --nav-hover: #f1f5f9;
  }
  [data-theme="light"] {
    --header-bg: rgba(255, 255, 255, 0.95);
    --header-border: rgba(0,0,0,0.08);
    --nav-text: #64748b;
    --nav-hover: #1e293b;
  }
  .site-header {
    position: fixed; top: 0; left: 0; right: 0; z-index: 1000;
    background: var(--header-bg);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--header-border);
    transition: all 0.3s;
  }
  .header-inner {
    max-width: 1280px; margin: 0 auto;
    display: flex; align-items: center; justify-content: space-between;
    padding: 0 24px; height: 64px;
  }
  .logo { display: flex; align-items: center; gap: 10px; text-decoration: none; }
  .logo img { width: 32px; height: 32px; }
  .logo-text { font-size: 18px; font-weight: 700; color: var(--nav-hover); letter-spacing: -0.3px; }
  .logo-highlight { color: var(--nav-active); }
  .nav-links { display: flex; align-items: center; gap: 8px; }
  .nav-link {
    padding: 8px 14px; border-radius: 8px; font-size: 14px; font-weight: 500;
    color: var(--nav-text); text-decoration: none; transition: all 0.2s;
    background: none; border: none; cursor: pointer; font-family: inherit;
  }
  .nav-link:hover { color: var(--nav-hover); background: rgba(255,255,255,0.05); }
  [data-theme="light"] .nav-link:hover { background: rgba(0,0,0,0.04); }
  .nav-link.active { color: var(--nav-active); }
  .nav-dropdown { position: relative; }
  .nav-dropdown-menu {
    display: none; position: absolute; top: 100%; left: 0;
    background: var(--header-bg); border: 1px solid var(--header-border);
    border-radius: 12px; padding: 8px; min-width: 220px;
    box-shadow: 0 8px 32px rgba(0,0,0,0.3);
  }
  .nav-dropdown:hover .nav-dropdown-menu { display: block; }
  .dropdown-item {
    display: block; padding: 10px 14px; border-radius: 8px;
    color: var(--nav-text); text-decoration: none; font-size: 14px;
    transition: all 0.2s;
  }
  .dropdown-item:hover { color: var(--nav-hover); background: rgba(255,255,255,0.05); }
  [data-theme="light"] .dropdown-item:hover { background: rgba(0,0,0,0.04); }
  .header-actions { display: flex; align-items: center; gap: 8px; }
  .theme-toggle {
    width: 40px; height: 40px; border-radius: 10px;
    background: none; border: 1px solid var(--header-border);
    color: var(--nav-text); cursor: pointer; display: flex;
    align-items: center; justify-content: center; transition: all 0.2s;
  }
  .theme-toggle:hover { color: var(--nav-hover); border-color: var(--nav-text); }
  [data-theme="dark"] .icon-sun { display: none; }
  [data-theme="light"] .icon-moon { display: none; }
  .burger {
    display: none; width: 40px; height: 40px; border-radius: 10px;
    background: none; border: 1px solid var(--header-border);
    cursor: pointer; flex-direction: column; align-items: center;
    justify-content: center; gap: 5px; padding: 0;
  }
  .burger span {
    display: block; width: 18px; height: 2px;
    background: var(--nav-text); border-radius: 2px; transition: all 0.3s;
  }
  .burger.open span:nth-child(1) { transform: rotate(45deg) translate(5px, 5px); }
  .burger.open span:nth-child(2) { opacity: 0; }
  .burger.open span:nth-child(3) { transform: rotate(-45deg) translate(5px, -5px); }
  body.mobile-nav-open { overflow: hidden; }
  @media (max-width: 768px) {
    .burger { display: flex; }
    .nav-links {
      display: none; position: fixed; top: 64px; left: 0; right: 0; bottom: 0;
      flex-direction: column; background: var(--header-bg);
      padding: 24px; gap: 4px; overflow-y: auto; z-index: 999;
    }
    .nav-links.open { display: flex; }
    .nav-link { padding: 12px 16px; font-size: 16px; width: 100%; }
    .nav-dropdown { width: 100%; }
    .nav-dropdown-btn { width: 100%; display: flex; justify-content: space-between; align-items: center; }
    .nav-dropdown-menu {
      position: static; box-shadow: none; border: none;
      padding: 0 0 0 16px; display: none;
    }
    .nav-dropdown.mobile-open .nav-dropdown-menu { display: block; }
    .dropdown-item { padding: 12px 16px; font-size: 15px; }
  }
  </style>
  <header class="site-header">
    <div class="header-inner">
      <a href="/" class="logo">
        <img src="/images/Wolf.png" alt="WolfeWaveSignals" width="32" height="32">
        <span class="logo-text">Wolfe<span class="logo-highlight">Wave</span>Signals</span>
      </a>
      <nav class="nav-links" id="nav-links">
        <a href="/signale.html" class="nav-link">Signale</a>
        <a href="/performance.html" class="nav-link">Performance</a>
        <a href="/dashboard.html" class="nav-link">Dashboard</a>
        <div class="nav-dropdown">
          <button class="nav-link nav-dropdown-btn" onclick="this.parentElement.classList.toggle('mobile-open')">Lernen
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M3 5L6 8L9 5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
          </button>
          <div class="nav-dropdown-menu">
            <a href="/wolfewaves.html" class="dropdown-item">Was sind Wolfe Waves?</a>
            <a href="/scanner-erklaerung.html" class="dropdown-item">So funktioniert der Scanner</a>
            <a href="/maerkte.html" class="dropdown-item">Scanner Universum</a>
            <a href="/faq.html" class="dropdown-item">FAQ</a>
          </div>
        </div>
        <a href="/about.html" class="nav-link">Ueber mich</a>
      </nav>
      <div class="header-actions">
        <button class="theme-toggle" id="theme-toggle" title="Dark/Light Mode">
          <svg class="icon-sun" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
          <svg class="icon-moon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg>
        </button>
        <button class="burger" id="burger" aria-label="Menu">
          <span></span><span></span><span></span>
        </button>
      </div>
    </div>
  </header>`;

  const container = document.getElementById('site-header');
  if (container) container.innerHTML = headerHTML;

  // Theme toggle
  const saved = localStorage.getItem('wws-theme') || 'dark';
  document.documentElement.setAttribute('data-theme', saved);
  document.getElementById('theme-toggle')?.addEventListener('click', () => {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('wws-theme', next);
  });

  // Burger menu
  document.getElementById('burger')?.addEventListener('click', function() {
    const nav = document.getElementById('nav-links');
    if (nav) nav.classList.toggle('open');
    this.classList.toggle('open');
    document.body.classList.toggle('mobile-nav-open');
  });

  // Close mobile nav on link click
  function closeMobileNav() {
    document.getElementById('nav-links')?.classList.remove('open');
    document.getElementById('burger')?.classList.remove('open');
    document.body.classList.remove('mobile-nav-open');
  }
  document.querySelectorAll('#nav-links a').forEach(a => {
    a.addEventListener('click', closeMobileNav);
  });

  // Active page detection
  const path = window.location.pathname;
  document.querySelectorAll('.nav-link[href], .dropdown-item[href]').forEach(link => {
    const href = link.getAttribute('href');
    if (href === '/' && (path === '/' || path === '/index.html')) {
      link.classList.add('active');
    } else if (href !== '/' && path.includes(href.replace('.html', ''))) {
      link.classList.add('active');
    }
  });
})();
