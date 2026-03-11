// WolfeWaveSignals Footer v2 - Kostenlos, kein Login
// Einbinden: <div id="site-footer"></div> + <script src="/components/footer.js"></script>

(function() {
  const footerHTML = `
  <style>
  .site-footer {
    border-top: 1px solid var(--header-border, rgba(255,255,255,0.06));
    padding: 40px 24px 24px;
    margin-top: 80px;
  }
  .footer-inner {
    max-width: 1280px; margin: 0 auto;
    display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 40px;
  }
  .footer-brand p { color: var(--nav-text, #94a3b8); font-size: 14px; line-height: 1.6; max-width: 320px; }
  .footer-section h4 {
    color: var(--nav-hover, #f1f5f9); font-size: 13px; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px;
  }
  .footer-links { display: flex; flex-direction: column; gap: 8px; }
  .footer-links a {
    color: var(--nav-text, #94a3b8); text-decoration: none; font-size: 14px; transition: color 0.2s;
  }
  .footer-links a:hover { color: var(--nav-active, #10b981); }
  .footer-bottom {
    max-width: 1280px; margin: 32px auto 0; padding-top: 24px;
    border-top: 1px solid var(--header-border, rgba(255,255,255,0.06));
    text-align: center;
  }
  .footer-copy { color: var(--nav-text, #94a3b8); font-size: 12px; margin-bottom: 12px; }
  .footer-disclaimer {
    color: var(--nav-text, #94a3b8); font-size: 11px; opacity: 0.6;
    max-width: 700px; margin: 0 auto; line-height: 1.6;
  }
  @media (max-width: 768px) {
    .footer-inner { grid-template-columns: 1fr; gap: 24px; }
  }
  </style>
  <footer class="site-footer">
    <div class="footer-inner">
      <div class="footer-brand">
        <p>Automatisierte Wolfe Wave Signale fuer DAX, NASDAQ, NYSE, Forex und Krypto. 100% kostenlos, keine Registrierung noetig.</p>
      </div>
      <div class="footer-section">
        <h4>Navigation</h4>
        <div class="footer-links">
          <a href="/signale.html">Signale</a>
          <a href="/performance.html">Performance</a>
          <a href="/dashboard.html">Dashboard</a>
          <a href="/aktienscanner.html">Aktienscanner</a>
          <a href="/wolfewaves.html">Wolfe Waves lernen</a>
          <a href="/about.html">Ueber mich</a>
        </div>
      </div>
      <div class="footer-section">
        <h4>Rechtliches</h4>
        <div class="footer-links">
          <a href="/impressum.html">Impressum</a>
          <a href="/datenschutz.html">Datenschutz</a>
          <a href="/agb.html">AGB</a>
          <a href="/widerruf.html">Widerruf</a>
          <a href="mailto:mail@wolfewavesignals.com">Kontakt</a>
        </div>
      </div>
    </div>
    <div class="footer-bottom">
      <p class="footer-copy">&copy; ${new Date().getFullYear()} WolfeWaveSignals. Alle Rechte vorbehalten.</p>
      <p class="footer-disclaimer">
        Risikohinweis: Der Handel mit Finanzinstrumenten ist mit erheblichen Risiken verbunden.
        Vergangene Ergebnisse sind kein Indikator fuer zukuenftige Performance.
        Handel nur mit Kapital, dessen Verlust du dir leisten kannst.
        Diese Website stellt keine Anlageberatung dar.
      </p>
    </div>
  </footer>`;

  const container = document.getElementById('site-footer');
  if (container) container.innerHTML = footerHTML;
})();
