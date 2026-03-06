// WolfeWaveSignals Cookie-Consent + Google Analytics (DSGVO-konform)
// Einbinden: <script src="/components/cookie-consent.js"></script>

(function() {
    var GA_ID = 'G-F3BQLK365X';

    function loadGA() {
        if (document.getElementById('ga-script')) return;
        var script = document.createElement('script');
        script.id = 'ga-script';
        script.async = true;
        script.src = 'https://www.googletagmanager.com/gtag/js?id=' + GA_ID;
        document.head.appendChild(script);
        script.onload = function() {
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            window.gtag = gtag;
            gtag('js', new Date());
            gtag('config', GA_ID, { anonymize_ip: true });
        };
    }

    // Check existing consent
    var consent = localStorage.getItem('cookieConsent');
    if (consent === 'all') {
        loadGA();
        return;
    }
    if (consent === 'essential') return;

    // Inject banner styles + HTML
    var style = document.createElement('style');
    style.textContent = [
        '.cookie-banner{position:fixed;bottom:0;left:0;right:0;z-index:99999;',
        'background:var(--bg-card,#1e293b);border-top:1px solid var(--border,rgba(255,255,255,0.08));',
        'padding:16px 24px;display:flex;align-items:center;justify-content:center;gap:16px;flex-wrap:wrap;',
        'box-shadow:0 -4px 20px rgba(0,0,0,0.3);font-family:"Space Grotesk",system-ui,sans-serif;}',
        '.cookie-banner p{color:var(--text-secondary,#94a3b8);font-size:14px;margin:0;max-width:600px;line-height:1.5;}',
        '.cookie-banner a{color:var(--accent,#10b981);text-decoration:underline;}',
        '.cookie-banner .cb-buttons{display:flex;gap:8px;flex-shrink:0;}',
        '.cookie-banner button{border:none;border-radius:8px;padding:8px 20px;font-size:13px;font-weight:600;cursor:pointer;',
        'font-family:inherit;transition:opacity 0.2s;}',
        '.cookie-banner button:hover{opacity:0.85;}',
        '.cb-accept{background:var(--accent,#10b981);color:#fff;}',
        '.cb-essential{background:transparent;color:var(--text-secondary,#94a3b8);border:1px solid var(--border,rgba(255,255,255,0.1));}'
    ].join('');
    document.head.appendChild(style);

    var banner = document.createElement('div');
    banner.className = 'cookie-banner';
    banner.innerHTML =
        '<p>Wir nutzen Cookies fuer die Webanalyse (Google Analytics). ' +
        '<a href="/datenschutz.html">Mehr erfahren</a></p>' +
        '<div class="cb-buttons">' +
        '<button class="cb-essential" id="cb-essential">Nur notwendige</button>' +
        '<button class="cb-accept" id="cb-accept">Alle akzeptieren</button>' +
        '</div>';

    function showBanner() {
        document.body.appendChild(banner);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', showBanner);
    } else {
        showBanner();
    }

    document.addEventListener('click', function(e) {
        if (e.target.id === 'cb-accept') {
            localStorage.setItem('cookieConsent', 'all');
            loadGA();
            banner.remove();
        } else if (e.target.id === 'cb-essential') {
            localStorage.setItem('cookieConsent', 'essential');
            banner.remove();
        }
    });
})();
