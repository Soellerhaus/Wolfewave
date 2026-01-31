// WolfeWaveSignals - Modularer Header
// Einbinden: <div id="site-header"></div> + <script src="/components/header.js"></script>

(function() {
    // Aktuelle Seite ermitteln für Active-State
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    
    // Header CSS
    const headerStyles = `
        <style>
        /* ==================== HEADER STYLES ==================== */
        .site-header {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 1000;
            background: rgba(10, 10, 10, 0.95);
            backdrop-filter: blur(20px);
            border-bottom: 1px solid var(--border-color, rgba(255,255,255,0.1));
            padding: 0 24px;
            height: 70px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .header-logo {
            display: flex;
            align-items: center;
            gap: 12px;
            text-decoration: none;
            color: #fff;
            font-size: 20px;
            font-weight: 700;
        }

        .header-logo img {
            width: 42px;
            height: 42px;
        }

        .header-logo .text-green {
            color: var(--accent-green, #00ff88);
        }

        /* Navigation */
        .header-nav {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .nav-link {
            color: rgba(255,255,255,0.7);
            text-decoration: none;
            padding: 10px 16px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.2s;
        }

        .nav-link:hover {
            color: #fff;
            background: rgba(255,255,255,0.1);
        }

        .nav-link.active {
            color: var(--accent-green, #00ff88);
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
            color: rgba(255,255,255,0.7);
            padding: 10px 16px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.2s;
            border: none;
            background: none;
        }

        .nav-dropdown-toggle:hover {
            color: #fff;
            background: rgba(255,255,255,0.1);
        }

        .nav-dropdown-toggle svg {
            width: 12px;
            height: 12px;
            transition: transform 0.2s;
        }

        .nav-dropdown:hover .nav-dropdown-toggle svg {
            transform: rotate(180deg);
        }

        .nav-dropdown-menu {
            position: absolute;
            top: 100%;
            left: 0;
            min-width: 180px;
            background: rgba(20, 20, 20, 0.98);
            border: 1px solid var(--border-color, rgba(255,255,255,0.1));
            border-radius: 12px;
            padding: 8px;
            opacity: 0;
            visibility: hidden;
            transform: translateY(10px);
            transition: all 0.2s;
            box-shadow: 0 10px 40px rgba(0,0,0,0.5);
        }

        .nav-dropdown:hover .nav-dropdown-menu {
            opacity: 1;
            visibility: visible;
            transform: translateY(4px);
        }

        /* Language dropdown uses click, not hover - controlled via JS */
        #langMenu {
            opacity: 0;
            visibility: hidden;
            transform: translateY(10px);
        }

        .nav-dropdown-item {
            display: block;
            color: rgba(255,255,255,0.7);
            text-decoration: none;
            padding: 10px 14px;
            border-radius: 8px;
            font-size: 14px;
            transition: all 0.2s;
        }

        .nav-dropdown-item:hover {
            color: #fff;
            background: rgba(255,255,255,0.1);
        }

        .nav-dropdown-item.active {
            color: var(--accent-green, #00ff88);
        }

        /* Header Actions */
        .header-actions {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .header-btn {
            padding: 10px 20px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            border: none;
            text-decoration: none;
        }

        .header-btn-outline {
            background: transparent;
            border: 1px solid var(--border-color, rgba(255,255,255,0.2));
            color: #fff;
        }

        .header-btn-outline:hover {
            background: rgba(255,255,255,0.1);
        }

        .header-btn-primary {
            background: var(--accent-green, #00ff88);
            color: #000;
        }

        .header-btn-primary:hover {
            background: #00cc6a;
            transform: translateY(-1px);
        }

        /* User Menu (eingeloggt) */
        .header-user-container {
            position: relative;
        }

        .header-user {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 6px 12px;
            background: rgba(255,255,255,0.05);
            border-radius: 8px;
            cursor: pointer;
        }

        .header-user:hover {
            background: rgba(255,255,255,0.1);
        }

        .header-user-avatar {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background: var(--accent-green, #00ff88);
            display: flex;
            align-items: center;
            justify-content: center;
            color: #000;
            font-weight: 700;
            font-size: 14px;
        }

        .header-user-info {
            display: flex;
            flex-direction: column;
        }

        .header-user-email {
            font-size: 13px;
            color: #fff;
            max-width: 150px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .header-user-badge {
            font-size: 10px;
            color: var(--accent-green, #00ff88);
            text-transform: uppercase;
            font-weight: 600;
        }

        /* User Dropdown */
        .header-user-dropdown {
            position: absolute;
            top: 100%;
            right: 0;
            min-width: 220px;
            background: rgba(20, 20, 20, 0.98);
            border: 1px solid var(--border-color, rgba(255,255,255,0.1));
            border-radius: 12px;
            padding: 8px;
            margin-top: 8px;
            opacity: 0;
            visibility: hidden;
            transform: translateY(10px);
            transition: all 0.2s;
            box-shadow: 0 10px 40px rgba(0,0,0,0.5);
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
            color: rgba(255,255,255,0.8);
            text-decoration: none;
            padding: 12px 14px;
            border-radius: 8px;
            font-size: 14px;
            transition: all 0.2s;
            cursor: pointer;
        }

        .header-dropdown-item:hover {
            color: #fff;
            background: rgba(255,255,255,0.1);
        }

        .header-dropdown-divider {
            height: 1px;
            background: var(--border-color, rgba(255,255,255,0.1));
            margin: 8px 0;
        }

        /* Mobile Menu */
        .header-burger {
            display: none;
            flex-direction: column;
            gap: 5px;
            padding: 10px;
            background: none;
            border: none;
            cursor: pointer;
        }

        .header-burger span {
            width: 24px;
            height: 2px;
            background: #fff;
            border-radius: 2px;
            transition: all 0.3s;
        }

        .mobile-menu {
            display: none;
            position: fixed;
            top: 70px;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(10, 10, 10, 0.98);
            padding: 20px;
            z-index: 999;
            overflow-y: auto;
        }

        .mobile-menu.open {
            display: block;
        }

        .mobile-nav-link {
            display: block;
            color: rgba(255,255,255,0.8);
            text-decoration: none;
            padding: 16px 20px;
            font-size: 16px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }

        .mobile-nav-link:hover,
        .mobile-nav-link.active {
            color: var(--accent-green, #00ff88);
        }

        .mobile-nav-section {
            color: rgba(255,255,255,0.5);
            font-size: 12px;
            text-transform: uppercase;
            padding: 20px 20px 10px;
            letter-spacing: 1px;
        }

        .mobile-header-actions {
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 12px;
        }

        .mobile-header-actions .header-btn {
            width: 100%;
            text-align: center;
            padding: 14px 20px;
        }

        /* Responsive */
        @media (max-width: 900px) {
            .header-nav {
                display: none;
            }
            
            .header-actions {
                display: none;
            }

            .header-burger {
                display: flex;
            }
        }

        /* Body Padding für fixed Header */
        body {
            padding-top: 70px;
        }
        </style>
    `;

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

    // Header HTML
    const headerHTML = `
        ${headerStyles}
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

        <div class="mobile-menu" id="mobileMenu">
            <div class="mobile-nav-section">Navigation</div>
            <a href="index.html" class="mobile-nav-link ${isActive('index.html')}">🏠 Signale</a>
            <a href="performance.html" class="mobile-nav-link ${isActive('performance.html')}">📊 Performance</a>
            
            <div class="mobile-nav-section">Lernen</div>
            <a href="wolfewaves.html" class="mobile-nav-link ${isActive('wolfewaves.html')}">📖 Tutorial</a>
            <a href="scanner-erklaerung.html" class="mobile-nav-link ${isActive('scanner-erklaerung.html')}">🔍 Scanner</a>
            <a href="maerkte.html" class="mobile-nav-link ${isActive('maerkte.html')}">🌍 Märkte</a>
            <a href="faq.html" class="mobile-nav-link ${isActive('faq.html')}">❓ FAQ</a>

            <div class="mobile-nav-section">🌐 Sprache / Language</div>
            <select id="mobileLangSelector" onchange="selectLanguageFromMobile(this)" style="width: calc(100% - 40px); margin: 0 20px 20px; padding: 12px; background: rgba(255,255,255,0.05); border: 1px solid var(--border-color, rgba(255,255,255,0.1)); border-radius: 8px; color: #fff; font-size: 14px;">
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

            <div class="mobile-header-actions" id="mobileHeaderActions">
                <button class="header-btn header-btn-outline" onclick="showLogin()">Login</button>
                <button class="header-btn header-btn-primary" onclick="showCheckout()">Premium 9,99€/Monat</button>
            </div>
        </div>
    `;

    // Header einfügen
    const headerContainer = document.getElementById('site-header');
    if (headerContainer) {
        headerContainer.innerHTML = headerHTML;
    }

    // Mobile Menu Toggle
    window.toggleMobileMenu = function() {
        const menu = document.getElementById('mobileMenu');
        menu.classList.toggle('open');
        document.body.style.overflow = menu.classList.contains('open') ? 'hidden' : '';
    };

    // Header für eingeloggten User aktualisieren
    window.updateHeaderForUser = function(user, isSubscribed, isAdmin) {
        const actions = document.getElementById('headerActions');
        const mobileActions = document.getElementById('mobileHeaderActions');
        
        if (!user) {
            // Ausgeloggt
            const guestHTML = `
                <button class="header-btn header-btn-outline" onclick="showLogin()">Login</button>
                <button class="header-btn header-btn-primary" onclick="showCheckout()">Premium 9,99€</button>
            `;
            if (actions) actions.innerHTML = guestHTML;
            if (mobileActions) {
                mobileActions.innerHTML = `
                    <button class="header-btn header-btn-outline" onclick="showLogin()">Login</button>
                    <button class="header-btn header-btn-primary" onclick="showCheckout()">Premium 9,99€/Monat</button>
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
            <div style="padding: 16px; background: rgba(255,255,255,0.05); border-radius: 12px; margin-bottom: 12px;">
                <div style="display: flex; align-items: center; gap: 12px;">
                    <div style="width: 40px; height: 40px; border-radius: 50%; background: var(--accent-green); display: flex; align-items: center; justify-content: center; font-weight: 700; color: #000;">${initial}</div>
                    <div>
                        <div style="font-size: 14px; color: #fff;">${user.email}</div>
                        <div style="font-size: 12px; color: var(--accent-green); margin-top: 2px;">${badge}</div>
                    </div>
                </div>
            </div>
            ${(isSubscribed || isAdmin) ? '<button class="header-btn header-btn-outline" onclick="showMyAlerts()" style="width: 100%; margin-bottom: 8px;">🔔 Meine Alarme</button>' : ''}
            ${(isSubscribed || isAdmin) ? '<button class="header-btn header-btn-outline" onclick="openTelegramConnect()" style="width: 100%; margin-bottom: 8px;">📱 Telegram verbinden</button>' : ''}
            ${isSubscribed ? '<button class="header-btn header-btn-outline" onclick="manageSubscription()" style="width: 100%; margin-bottom: 8px;">💳 Abo verwalten</button>' : '<button class="header-btn header-btn-primary" onclick="showCheckout()" style="width: 100%; margin-bottom: 8px;">⭐ Premium werden</button>'}
            <button class="header-btn header-btn-outline" onclick="handleLogout()" style="width: 100%;">🚪 Ausloggen</button>
        `;
        if (mobileActions) mobileActions.innerHTML = mobileUserHTML;
    };

    // ==================== LANGUAGE FUNCTIONS ====================
    
    // Toggle Language Dropdown (Click statt Hover)
    window.toggleLangDropdown = function(event) {
        event.stopPropagation();
        const dropdown = document.getElementById('langDropdown');
        const menu = document.getElementById('langMenu');
        
        if (menu.style.opacity === '1') {
            menu.style.opacity = '0';
            menu.style.visibility = 'hidden';
            menu.style.transform = 'translateY(10px)';
        } else {
            menu.style.opacity = '1';
            menu.style.visibility = 'visible';
            menu.style.transform = 'translateY(4px)';
        }
    };
    
    // Close dropdown when clicking outside
    document.addEventListener('click', function(e) {
        const menu = document.getElementById('langMenu');
        const dropdown = document.getElementById('langDropdown');
        if (menu && dropdown && !dropdown.contains(e.target)) {
            menu.style.opacity = '0';
            menu.style.visibility = 'hidden';
            menu.style.transform = 'translateY(10px)';
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
            menu.style.transform = 'translateY(10px)';
        }
        
        // Save to localStorage
        localStorage.setItem('selectedLanguage', langCode);
        localStorage.setItem('selectedLanguageLabel', langLabel);
        
        // Call the actual translation function if it exists
        if (typeof changeLanguage === 'function') {
            changeLanguage(langCode);
        }
    };
    
    // Select from Mobile
    window.selectLanguageFromMobile = function(select) {
        const langCode = select.value;
        const option = select.options[select.selectedIndex];
        const langLabel = option.getAttribute('data-label') || langCode.toUpperCase();
        
        // Update header display
        const langText = document.getElementById('currentLangText');
        if (langText) langText.textContent = langLabel;
        
        // Save to localStorage
        localStorage.setItem('selectedLanguage', langCode);
        localStorage.setItem('selectedLanguageLabel', langLabel);
        
        // Call the actual translation function if it exists
        if (typeof changeLanguage === 'function') {
            changeLanguage(langCode);
        }
    };
    
    // Restore saved language on load
    function restoreSavedLanguage() {
        const savedLang = localStorage.getItem('selectedLanguage');
        const savedLabel = localStorage.getItem('selectedLanguageLabel');
        
        if (savedLang && savedLabel) {
            // Update header text
            const langText = document.getElementById('currentLangText');
            if (langText) langText.textContent = savedLabel;
            
            // Update mobile selector
            const mobileSelector = document.getElementById('mobileLangSelector');
            if (mobileSelector) mobileSelector.value = savedLang;
            
            // If not German, trigger translation
            if (savedLang !== 'de' && typeof changeLanguage === 'function') {
                changeLanguage(savedLang);
            }
        }
    }
    
    // Protect language display from Google Translate changes
    function protectLanguageDisplay() {
        const savedLabel = localStorage.getItem('selectedLanguageLabel');
        if (savedLabel) {
            const langText = document.getElementById('currentLangText');
            if (langText && langText.textContent !== savedLabel) {
                langText.textContent = savedLabel;
            }
        }
    }
    
    // Run on load with multiple retries
    setTimeout(restoreSavedLanguage, 100);
    setTimeout(protectLanguageDisplay, 500);
    setTimeout(protectLanguageDisplay, 1000);
    setTimeout(protectLanguageDisplay, 2000);
    
    // Also watch for changes
    const observer = new MutationObserver(function(mutations) {
        protectLanguageDisplay();
    });
    
    setTimeout(function() {
        const langText = document.getElementById('currentLangText');
        if (langText) {
            observer.observe(langText, { childList: true, characterData: true, subtree: true });
        }
    }, 200);

})();
