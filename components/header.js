// WolfeWaveSignals - Modularer Header
// Einbinden: <div id="site-header"></div> + <script src="/components/header.js"></script>

(function() {
    // Aktuelle Seite ermitteln für Active-State
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const isIndexPage = (currentPage === '' || currentPage === 'index.html');

    // ==================== GLOBALE FUNKTIONEN ====================
    // Diese müssen SOFORT definiert werden, bevor onclick im HTML sie aufruft.
    // Auf Unterseiten leiten Login/Premium zur index.html weiter.
    
    window.toggleMobileMenu = function() {
        var menu = document.getElementById('wwsMobileMenu');
        if (!menu) return;
        if (menu.classList.contains('open')) {
            menu.classList.remove('open');
            document.body.style.overflow = '';
        } else {
            menu.classList.add('open');
            document.body.style.overflow = 'hidden';
        }
    };

    // Fallbacks für Funktionen die nur in index.html existieren
    if (typeof window.showLogin === 'undefined') {
        window.showLogin = function() {
            window.location.href = 'index.html#login';
        };
    }
    if (typeof window.showCheckout === 'undefined') {
        window.showCheckout = function() {
            window.location.href = 'index.html#premium';
        };
    }
    if (typeof window.handleLogout === 'undefined') {
        window.handleLogout = function() {
            window.location.href = 'index.html#logout';
        };
    }
    if (typeof window.showMyAlerts === 'undefined') {
        window.showMyAlerts = function() {
            window.location.href = 'index.html#alerts';
        };
    }
    if (typeof window.openTelegramConnect === 'undefined') {
        window.openTelegramConnect = function() {
            window.location.href = 'index.html#telegram';
        };
    }
    if (typeof window.manageSubscription === 'undefined') {
        window.manageSubscription = function() {
            window.location.href = 'index.html#subscription';
        };
    }
    
    // Header CSS - in <head> injizieren für maximale Kompatibilität
    const styleEl = document.createElement('style');
    styleEl.id = 'header-component-styles';
    styleEl.textContent = `
        /* ==================== HEADER STYLES - MODERN ==================== */
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');

        .site-header {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 1000;
            background: rgba(15, 23, 42, 0.85);
            backdrop-filter: blur(24px) saturate(180%);
            -webkit-backdrop-filter: blur(24px) saturate(180%);
            border-bottom: 1px solid rgba(255,255,255,0.06);
            padding: 0 32px;
            height: 64px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        }

        .header-logo {
            display: flex;
            align-items: center;
            gap: 12px;
            text-decoration: none;
            color: #fff;
            font-size: 19px;
            font-weight: 700;
            letter-spacing: -0.3px;
        }

        .header-logo img {
            width: 36px;
            height: 36px;
        }

        .header-logo .text-green {
            color: #f59e0b;
        }

        /* Navigation */
        .header-nav {
            display: flex;
            align-items: center;
            gap: 2px;
        }

        .nav-link {
            color: rgba(255,255,255,0.6);
            text-decoration: none;
            padding: 8px 18px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
        }

        .nav-link::after {
            content: '';
            position: absolute;
            bottom: 0;
            left: 50%;
            transform: translateX(-50%) scaleX(0);
            width: 20px;
            height: 2px;
            background: #f59e0b;
            border-radius: 1px;
            transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
        }

        .nav-link:hover {
            color: #fff;
            background: rgba(255,255,255,0.06);
        }

        .nav-link:hover::after {
            transform: translateX(-50%) scaleX(1);
        }

        .nav-link.active {
            color: #f59e0b;
        }

        .nav-link.active::after {
            transform: translateX(-50%) scaleX(1);
        }

        /* Dropdown */
        .nav-dropdown {
            position: relative;
        }

        .nav-dropdown-toggle {
            display: flex;
            align-items: center;
            gap: 6px;
            cursor: pointer;
            color: rgba(255,255,255,0.6);
            padding: 8px 18px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
            border: none;
            background: none;
        }

        .nav-dropdown-toggle:hover {
            color: #fff;
            background: rgba(255,255,255,0.06);
        }

        .nav-dropdown-toggle.active {
            color: #f59e0b;
        }

        .nav-dropdown-toggle svg {
            width: 10px;
            height: 10px;
            opacity: 0.5;
            transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
        }

        .nav-dropdown:hover .nav-dropdown-toggle svg {
            transform: rotate(180deg);
            opacity: 1;
        }

        .nav-dropdown-menu {
            position: absolute;
            top: 100%;
            left: 50%;
            transform: translateX(-50%) translateY(12px);
            min-width: 200px;
            background: rgba(20, 30, 52, 0.95);
            backdrop-filter: blur(20px) saturate(180%);
            -webkit-backdrop-filter: blur(20px) saturate(180%);
            border: 1px solid rgba(255,255,255,0.08);
            border-radius: 14px;
            padding: 6px;
            opacity: 0;
            visibility: hidden;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 20px 60px rgba(0,0,0,0.4), 0 0 0 1px rgba(255,255,255,0.05);
        }

        .nav-dropdown:hover .nav-dropdown-menu {
            opacity: 1;
            visibility: visible;
            transform: translateX(-50%) translateY(6px);
        }

        /* Language dropdown uses click, not hover - controlled via JS */
        #langMenu {
            opacity: 0;
            visibility: hidden;
            transform: translateX(-50%) translateY(12px);
        }

        .nav-dropdown-item {
            display: block;
            color: rgba(255,255,255,0.65);
            text-decoration: none;
            padding: 10px 16px;
            border-radius: 10px;
            font-size: 13.5px;
            font-weight: 500;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            letter-spacing: 0.1px;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
            cursor: pointer;
        }

        .nav-dropdown-item:hover {
            color: #fff;
            background: rgba(255,255,255,0.08);
        }

        .nav-dropdown-item.active {
            color: #f59e0b;
            background: rgba(245, 158, 11, 0.08);
        }

        /* Header Actions */
        .header-actions {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .header-btn {
            padding: 9px 20px;
            border-radius: 10px;
            font-size: 13px;
            font-weight: 600;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            letter-spacing: 0.2px;
            cursor: pointer;
            transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
            border: none;
            text-decoration: none;
        }

        .header-btn-outline {
            background: rgba(255,255,255,0.06);
            border: 1px solid rgba(255,255,255,0.12);
            color: #fff;
        }

        .header-btn-outline:hover {
            background: rgba(255,255,255,0.12);
            border-color: rgba(255,255,255,0.2);
        }

        .header-btn-primary {
            background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
            color: #fff;
            font-weight: 700;
            box-shadow: 0 2px 12px rgba(245, 158, 11, 0.25);
        }

        .header-btn-primary:hover {
            background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
            transform: translateY(-1px);
            box-shadow: 0 4px 20px rgba(245, 158, 11, 0.35);
        }

        /* User Menu (eingeloggt) */
        .header-user-container {
            position: relative;
        }

        .header-user {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 5px 10px 5px 5px;
            background: rgba(255,255,255,0.05);
            border: 1px solid rgba(255,255,255,0.08);
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
        }

        .header-user:hover {
            background: rgba(255,255,255,0.1);
            border-color: rgba(255,255,255,0.15);
        }

        .header-user-avatar {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            font-weight: 700;
            font-size: 13px;
            font-family: 'Inter', sans-serif;
        }

        .header-user-info {
            display: flex;
            flex-direction: column;
        }

        .header-user-email {
            font-size: 13px;
            font-weight: 500;
            font-family: 'Inter', sans-serif;
            color: #fff;
            max-width: 150px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .header-user-badge {
            font-size: 10px;
            color: #f59e0b;
            text-transform: uppercase;
            font-weight: 700;
            font-family: 'Inter', sans-serif;
            letter-spacing: 0.8px;
        }

        /* User Dropdown */
        .header-user-dropdown {
            position: absolute;
            top: 100%;
            right: 0;
            min-width: 240px;
            background: rgba(20, 30, 52, 0.95);
            backdrop-filter: blur(20px) saturate(180%);
            -webkit-backdrop-filter: blur(20px) saturate(180%);
            border: 1px solid rgba(255,255,255,0.08);
            border-radius: 14px;
            padding: 6px;
            margin-top: 8px;
            opacity: 0;
            visibility: hidden;
            transform: translateY(12px);
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 20px 60px rgba(0,0,0,0.4), 0 0 0 1px rgba(255,255,255,0.05);
            z-index: 1001;
        }

        .header-user-container:hover .header-user-dropdown,
        .header-user-container.open .header-user-dropdown {
            opacity: 1;
            visibility: visible;
            transform: translateY(0);
        }

        .header-dropdown-item {
            display: flex;
            align-items: center;
            gap: 10px;
            color: rgba(255,255,255,0.65);
            text-decoration: none;
            padding: 11px 14px;
            border-radius: 10px;
            font-size: 13.5px;
            font-weight: 500;
            font-family: 'Inter', sans-serif;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
            cursor: pointer;
        }

        .header-dropdown-item:hover {
            color: #fff;
            background: rgba(255,255,255,0.08);
        }

        .header-dropdown-divider {
            height: 1px;
            background: rgba(255,255,255,0.06);
            margin: 4px 8px;
        }

        /* Mobile Menu */
        .header-burger {
            display: none;
            flex-direction: column;
            gap: 5px;
            padding: 14px 10px;
            background: none;
            border: none;
            cursor: pointer;
            z-index: 1002;
            -webkit-tap-highlight-color: transparent;
            touch-action: manipulation;
            position: relative;
            min-width: 44px;
            min-height: 44px;
            align-items: center;
            justify-content: center;
        }

        .header-burger span {
            display: block;
            width: 22px;
            height: 2px;
            background: #fff;
            border-radius: 2px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            pointer-events: none;
        }

        .wws-mobile-menu {
            display: none;
            position: fixed;
            top: 64px;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(15, 23, 42, 0.98);
            backdrop-filter: blur(20px);
            padding: 16px;
            z-index: 1001;
            overflow-y: auto;
            -webkit-overflow-scrolling: touch;
        }

        .wws-mobile-menu.open {
            display: block !important;
        }

        .wws-mobile-nav-link {
            display: block;
            color: rgba(255,255,255,0.6);
            text-decoration: none;
            padding: 14px 20px;
            font-size: 14px;
            font-weight: 600;
            font-family: 'Inter', sans-serif;
            text-transform: uppercase;
            letter-spacing: 0.6px;
            border-bottom: 1px solid rgba(255,255,255,0.06);
            transition: all 0.2s;
        }

        .wws-mobile-nav-link:hover,
        .wws-mobile-nav-link.active {
            color: #f59e0b;
        }

        .wws-mobile-nav-section {
            color: rgba(255,255,255,0.35);
            font-size: 11px;
            text-transform: uppercase;
            padding: 24px 20px 8px;
            letter-spacing: 1.5px;
            font-weight: 700;
            font-family: 'Inter', sans-serif;
        }

        .wws-mobile-header-actions {
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 10px;
        }

        .wws-mobile-header-actions .header-btn {
            width: 100%;
            text-align: center;
            padding: 14px 20px;
        }

        /* Responsive */
        @media (max-width: 900px) {
            .header-nav {
                display: none !important;
            }

            .header-actions {
                display: none !important;
            }

            .header-burger {
                display: flex !important;
                visibility: visible !important;
                opacity: 1 !important;
                pointer-events: auto !important;
            }
        }

        /* Override alte Seiten-Styles */
        .header:not(.site-header) {
            display: none !important;
        }

        /* Body Padding für fixed Header */
        body {
            padding-top: 64px;
        }
    `;
    document.head.appendChild(styleEl);

    // Prüfe ob Seite aktiv ist
    function isActive(page) {
        if (page === 'index.html' && (currentPage === '' || currentPage === 'index.html')) {
            return 'active';
        }
        return currentPage === page ? 'active' : '';
    }

    // Prüfe ob eine der Lernen-Seiten aktiv ist
    function isLernenActive() {
        const lernenPages = ['wolfewaves.html', 'scanner-erklaerung.html', 'maerkte.html', 'faq.html'];
        return lernenPages.includes(currentPage);
    }

    // Header HTML (ohne CSS - das ist jetzt im <head>)
    const headerHTML = `
        <header class="site-header">
            <a href="index.html" class="header-logo">
                <img src="/images/Wolf.png" alt="Wolf Logo">
                <span>Wolfe<span class="text-green">Wave</span>Signals</span>
            </a>

            <nav class="header-nav">
                <a href="index.html" class="nav-link ${isActive('index.html')}">Signale</a>
                
                <div class="nav-dropdown">
                    <button class="nav-dropdown-toggle ${isLernenActive() ? 'active' : ''}">
                        Lernen
                        <svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M2 4l4 4 4-4"/>
                        </svg>
                    </button>
                    <div class="nav-dropdown-menu">
                        <a href="wolfewaves.html" class="nav-dropdown-item ${isActive('wolfewaves.html')}">📖 Tutorial</a>
                        <a href="scanner-erklaerung.html" class="nav-dropdown-item ${isActive('scanner-erklaerung.html')}">🔍 Scanner</a>
                        <a href="maerkte.html" class="nav-dropdown-item ${isActive('maerkte.html')}">🌍 Märkte</a>
                        <a href="faq.html" class="nav-dropdown-item ${isActive('faq.html')}">❓ FAQ</a>
                    </div>
                </div>

                <a href="performance.html" class="nav-link ${isActive('performance.html')}">📊 Performance</a>
                <a href="dashboard.html" class="nav-link ${isActive('dashboard.html')}">📈 Dashboard</a>
                <a href="ueber-mich.html" class="nav-link ${isActive('ueber-mich.html')}">👤 Über mich</a>

                <!-- Language Selector -->
                <div class="nav-dropdown notranslate" id="langDropdown" translate="no">
                    <button class="nav-dropdown-toggle" id="langToggle" onclick="toggleLangDropdown(event)">
                        🌐 <span id="currentLangText">DE</span>
                        <svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M2 4l4 4 4-4"/>
                        </svg>
                    </button>
                    <div class="nav-dropdown-menu notranslate" id="langMenu" style="min-width: 140px;" translate="no">
                        <div class="nav-dropdown-item" onclick="selectLanguage('de', 'DE')">🇩🇪 Deutsch</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('en', 'EN')">🇬🇧 English</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('es', 'ES')">🇪🇸 Español</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('fr', 'FR')">🇫🇷 Français</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('it', 'IT')">🇮🇹 Italiano</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('pt', 'PT')">🇵🇹 Português</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('ru', 'RU')">🇷🇺 Русский</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('zh-CN', '中文')">🇨🇳 中文</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('ja', '日本')">🇯🇵 日本語</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('ko', '한국')">🇰🇷 한국어</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('ar', 'AR')">🇸🇦 العربية</div>
                        <div class="nav-dropdown-item" onclick="selectLanguage('tr', 'TR')">🇹🇷 Türkçe</div>
                    </div>
                </div>
            </nav>

            <div class="header-actions" id="headerActions">
                <button class="header-btn header-btn-outline" onclick="showLogin()">Login</button>
                <button class="header-btn header-btn-primary" onclick="showCheckout()">Premium 9,99€</button>
            </div>

            <button class="header-burger" onclick="toggleMobileMenu()">
                <span></span>
                <span></span>
                <span></span>
            </button>
        </header>

        <div class="wws-mobile-menu" id="wwsMobileMenu">
            <div class="wws-mobile-nav-section">Navigation</div>
            <a href="index.html" class="wws-mobile-nav-link ${isActive('index.html')}">🏠 Signale</a>
            <a href="performance.html" class="wws-mobile-nav-link ${isActive('performance.html')}">📊 Performance</a>
            <a href="dashboard.html" class="wws-mobile-nav-link ${isActive('dashboard.html')}">📈 Dashboard</a>
            <a href="ueber-mich.html" class="wws-mobile-nav-link ${isActive('ueber-mich.html')}">👤 Über mich</a>
            
            <div class="wws-mobile-nav-section">Lernen</div>
            <a href="wolfewaves.html" class="wws-mobile-nav-link ${isActive('wolfewaves.html')}">📖 Tutorial</a>
            <a href="scanner-erklaerung.html" class="wws-mobile-nav-link ${isActive('scanner-erklaerung.html')}">🔍 Scanner</a>
            <a href="maerkte.html" class="wws-mobile-nav-link ${isActive('maerkte.html')}">🌍 Märkte</a>
            <a href="faq.html" class="wws-mobile-nav-link ${isActive('faq.html')}">❓ FAQ</a>

            <div class="wws-mobile-nav-section">🌐 Sprache / Language</div>
            <select id="mobileLangSelector" onchange="selectLanguageFromMobile(this)" style="width: calc(100% - 40px); margin: 0 20px 20px; padding: 12px; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; color: #fff; font-size: 14px;">
                <option value="de" data-label="DE">🇩🇪 Deutsch</option>
                <option value="en" data-label="EN">🇬🇧 English</option>
                <option value="es" data-label="ES">🇪🇸 Español</option>
                <option value="fr" data-label="FR">🇫🇷 Français</option>
                <option value="it" data-label="IT">🇮🇹 Italiano</option>
                <option value="pt" data-label="PT">🇵🇹 Português</option>
                <option value="ru" data-label="RU">🇷🇺 Русский</option>
                <option value="zh-CN" data-label="中文">🇨🇳 中文</option>
                <option value="ja" data-label="日本">🇯🇵 日本語</option>
                <option value="ko" data-label="한국">🇰🇷 한국어</option>
                <option value="ar" data-label="AR">🇸🇦 العربية</option>
                <option value="tr" data-label="TR">🇹🇷 Türkçe</option>
            </select>

            <div class="wws-mobile-header-actions" id="wwsMobileHeaderActions">
                <button class="header-btn header-btn-outline" onclick="toggleMobileMenu(); showLogin();">Login</button>
                <button class="header-btn header-btn-primary" onclick="toggleMobileMenu(); showCheckout();">Premium 9,99€/Monat</button>
            </div>
        </div>
    `;

    // Header einfügen
    const headerContainer = document.getElementById('site-header');
    if (headerContainer) {
        headerContainer.innerHTML = headerHTML;
    }

    // Schließe Menü wenn Link geklickt wird
    document.addEventListener('click', function(e) {
        if (e.target.classList && e.target.classList.contains('wws-mobile-nav-link')) {
            var menu = document.getElementById('wwsMobileMenu');
            if (menu) {
                menu.classList.remove('open');
                document.body.style.overflow = '';
            }
        }
    });

    // Header für eingeloggten User aktualisieren
    window.updateHeaderForUser = function(user, isSubscribed, isAdmin) {
        const actions = document.getElementById('headerActions');
        const mobileActions = document.getElementById('wwsMobileHeaderActions');
        
        if (!user) {
            // Ausgeloggt
            const guestHTML = `
                <button class="header-btn header-btn-outline" onclick="showLogin()">Login</button>
                <button class="header-btn header-btn-primary" onclick="showCheckout()">Premium 9,99€</button>
            `;
            if (actions) actions.innerHTML = guestHTML;
            if (mobileActions) {
                mobileActions.innerHTML = `
                    <button class="header-btn header-btn-outline" onclick="toggleMobileMenu(); showLogin();">Login</button>
                    <button class="header-btn header-btn-primary" onclick="toggleMobileMenu(); showCheckout();">Premium 9,99€/Monat</button>
                `;
            }
            return;
        }

        // Eingeloggt
        const initial = user.email ? user.email.charAt(0).toUpperCase() : 'U';
        const badge = isAdmin ? 'Admin' : (isSubscribed ? 'Premium' : 'Free');
        
        const userHTML = `
            <div class="header-user-container">
                <div class="header-user">
                    <div class="header-user-avatar">${initial}</div>
                    <div class="header-user-info">
                        <span class="header-user-email">${user.email}</span>
                        <span class="header-user-badge">${badge}</span>
                    </div>
                </div>
                <div class="header-user-dropdown">
                    ${(isSubscribed || isAdmin) ? '<div class="header-dropdown-item" onclick="showMyAlerts()">🔔 Meine Alarme</div>' : ''}
                    ${(isSubscribed || isAdmin) ? '<div class="header-dropdown-item" onclick="openTelegramConnect()">📱 Telegram verbinden</div>' : ''}
                    ${(isSubscribed || isAdmin) ? '<div class="header-dropdown-divider"></div>' : ''}
                    ${isSubscribed ? '<div class="header-dropdown-item" onclick="manageSubscription()">💳 Abo verwalten</div>' : '<div class="header-dropdown-item" onclick="showCheckout()">⭐ Premium werden</div>'}
                    <div class="header-dropdown-divider"></div>
                    <div class="header-dropdown-item" onclick="handleLogout()">🚪 Ausloggen</div>
                </div>
            </div>
        `;
        
        if (actions) actions.innerHTML = userHTML;
        
        // Mobile
        const mobileUserHTML = `
            <div style="padding: 16px; background: rgba(255,255,255,0.08); border-radius: 12px; margin-bottom: 12px;">
                <div style="display: flex; align-items: center; gap: 12px;">
                    <div style="width: 40px; height: 40px; border-radius: 50%; background: #f59e0b; display: flex; align-items: center; justify-content: center; font-weight: 700; color: #1a2744;">${initial}</div>
                    <div>
                        <div style="font-size: 14px; color: #fff;">${user.email}</div>
                        <div style="font-size: 12px; color: #f59e0b; margin-top: 2px;">${badge}</div>
                    </div>
                </div>
            </div>
            ${(isSubscribed || isAdmin) ? '<button class="header-btn header-btn-outline" onclick="toggleMobileMenu(); showMyAlerts();" style="width: 100%; margin-bottom: 8px;">🔔 Meine Alarme</button>' : ''}
            ${(isSubscribed || isAdmin) ? '<button class="header-btn header-btn-outline" onclick="toggleMobileMenu(); openTelegramConnect();" style="width: 100%; margin-bottom: 8px;">📱 Telegram verbinden</button>' : ''}
            ${isSubscribed ? '<button class="header-btn header-btn-outline" onclick="toggleMobileMenu(); manageSubscription();" style="width: 100%; margin-bottom: 8px;">💳 Abo verwalten</button>' : '<button class="header-btn header-btn-primary" onclick="toggleMobileMenu(); showCheckout();" style="width: 100%; margin-bottom: 8px;">⭐ Premium werden</button>'}
            <button class="header-btn header-btn-outline" onclick="toggleMobileMenu(); handleLogout();" style="width: 100%;">🚪 Ausloggen</button>
        `;
        if (mobileActions) mobileActions.innerHTML = mobileUserHTML;
    };

    // ==================== LANGUAGE FUNCTIONS ====================
    
    // Google Translate changeLanguage function (if not already defined)
    if (typeof window.changeLanguage === 'undefined') {
        window.changeLanguage = function(lang) {
            // Set Google Translate cookie
            var domain = window.location.hostname;
            document.cookie = "googtrans=/de/" + lang + "; path=/; domain=" + domain;
            document.cookie = "googtrans=/de/" + lang + "; path=/";
            
            // Reload to apply translation
            window.location.reload();
        };
    }
    
    // Toggle Language Dropdown (Click statt Hover)
    window.toggleLangDropdown = function(event) {
        event.stopPropagation();
        const dropdown = document.getElementById('langDropdown');
        const menu = document.getElementById('langMenu');

        if (menu.style.opacity === '1') {
            menu.style.opacity = '0';
            menu.style.visibility = 'hidden';
            menu.style.transform = 'translateX(-50%) translateY(12px)';
        } else {
            menu.style.opacity = '1';
            menu.style.visibility = 'visible';
            menu.style.transform = 'translateX(-50%) translateY(6px)';
        }
    };
    
    // Close dropdown when clicking outside
    document.addEventListener('click', function(e) {
        const menu = document.getElementById('langMenu');
        const dropdown = document.getElementById('langDropdown');
        if (menu && dropdown && !dropdown.contains(e.target)) {
            menu.style.opacity = '0';
            menu.style.visibility = 'hidden';
            menu.style.transform = 'translateX(-50%) translateY(12px)';
        }
    });
    
    // Select Language
    window.selectLanguage = function(langCode, langLabel) {
        // Update display
        const langText = document.getElementById('currentLangText');
        if (langText) langText.textContent = langLabel;
        
        // Update mobile selector
        const mobileSelector = document.getElementById('mobileLangSelector');
        if (mobileSelector) mobileSelector.value = langCode;
        
        // Close dropdown
        const menu = document.getElementById('langMenu');
        if (menu) {
            menu.style.opacity = '0';
            menu.style.visibility = 'hidden';
            menu.style.transform = 'translateX(-50%) translateY(12px)';
        }
        
        // Get current saved language
        const currentLang = localStorage.getItem('selectedLanguage') || 'de';
        
        // Save to localStorage
        localStorage.setItem('selectedLanguage', langCode);
        localStorage.setItem('selectedLanguageLabel', langLabel);
        
        // Only reload if language actually changed
        if (langCode !== currentLang) {
            // Set Google Translate cookie
            var domain = window.location.hostname;
            if (langCode === 'de') {
                // Reset to German - clear cookies
                document.cookie = "googtrans=; path=/; domain=" + domain + "; expires=Thu, 01 Jan 1970 00:00:00 GMT";
                document.cookie = "googtrans=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT";
            } else {
                document.cookie = "googtrans=/de/" + langCode + "; path=/; domain=" + domain;
                document.cookie = "googtrans=/de/" + langCode + "; path=/";
            }
            window.location.reload();
        }
    };
    
    // Select from Mobile
    window.selectLanguageFromMobile = function(select) {
        const langCode = select.value;
        const option = select.options[select.selectedIndex];
        const langLabel = option.getAttribute('data-label') || langCode.toUpperCase();
        
        // Use the same logic as desktop
        selectLanguage(langCode, langLabel);
    };
    
    // Restore saved language on load
    function restoreSavedLanguage() {
        const savedLang = localStorage.getItem('selectedLanguage') || 'de';
        const savedLabel = localStorage.getItem('selectedLanguageLabel') || 'DE';
        
        // Update header text
        const langText = document.getElementById('currentLangText');
        if (langText) langText.textContent = savedLabel;
        
        // Update mobile selector
        const mobileSelector = document.getElementById('mobileLangSelector');
        if (mobileSelector) mobileSelector.value = savedLang;
    }
    
    // Protect language display from Google Translate changes
    function protectLanguageDisplay() {
        const savedLabel = localStorage.getItem('selectedLanguageLabel') || 'DE';
        const langText = document.getElementById('currentLangText');
        if (langText && langText.textContent !== savedLabel) {
            langText.textContent = savedLabel;
        }
    }
    
    // Run on load with multiple retries to fight Google Translate
    setTimeout(restoreSavedLanguage, 50);
    setTimeout(protectLanguageDisplay, 300);
    setTimeout(protectLanguageDisplay, 600);
    setTimeout(protectLanguageDisplay, 1000);
    setTimeout(protectLanguageDisplay, 2000);
    setTimeout(protectLanguageDisplay, 3000);

})();
