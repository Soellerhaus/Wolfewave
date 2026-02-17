// WolfeWaveSignals - Modularer Footer
// Einbinden: <div id="site-footer"></div> + <script src="/components/footer.js"></script>

(function() {
    const currentYear = new Date().getFullYear();
    
    const footerHTML = `
        <style>
        /* ==================== FOOTER STYLES ==================== */
        .site-footer {
            background: #1a2744;
            border-top: 1px solid rgba(255,255,255,0.08);
            padding: 60px 24px 30px;
            margin-top: 60px;
        }

        .footer-content {
            max-width: 1200px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: 2fr 1fr 1fr 1fr;
            gap: 40px;
        }

        .footer-brand {
            display: flex;
            flex-direction: column;
            gap: 16px;
        }

        .footer-logo {
            display: flex;
            align-items: center;
            gap: 12px;
            font-size: 20px;
            font-weight: 700;
            color: #fff;
        }

        .footer-logo img {
            width: 40px;
            height: 40px;
        }

        .footer-logo .text-green {
            color: #f59e0b;
        }

        .footer-description {
            color: #94a3b8;
            font-size: 14px;
            line-height: 1.6;
            max-width: 300px;
        }

        .footer-section h4 {
            color: #e2e8f0;
            font-size: 14px;
            font-weight: 600;
            margin-bottom: 16px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .footer-links {
            display: flex;
            flex-direction: column;
            gap: 10px;
        }

        .footer-link {
            color: #94a3b8;
            text-decoration: none;
            font-size: 14px;
            transition: color 0.2s;
        }

        .footer-link:hover {
            color: #f59e0b;
        }

        .footer-bottom {
            max-width: 1200px;
            margin: 40px auto 0;
            padding-top: 30px;
            border-top: 1px solid rgba(255,255,255,0.1);
        }

        .footer-copyright {
            color: #94a3b8;
            font-size: 13px;
            text-align: center;
            margin-bottom: 16px;
        }

        .footer-disclaimer {
            color: #64748b;
            font-size: 12px;
            text-align: center;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
        }

        /* Responsive */
        @media (max-width: 768px) {
            .footer-content {
                grid-template-columns: 1fr 1fr;
                gap: 30px;
            }

            .footer-brand {
                grid-column: 1 / -1;
            }
        }

        @media (max-width: 480px) {
            .footer-content {
                grid-template-columns: 1fr;
            }
        }
        </style>

        <footer class="site-footer">
            <div class="footer-content">
                <div class="footer-brand">
                    <div class="footer-logo">
                        <img src="/images/Wolf.png" alt="WolfeWaveSignals">
                        <span>Wolfe<span class="text-green">Wave</span>Signals</span>
                    </div>
                    <p class="footer-description">
                        Professionelle Trading-Signale basierend auf dem Wolfe Wave Pattern für DAX, NASDAQ, Forex und Krypto.
                    </p>
                </div>

                <div class="footer-section">
                    <h4>Navigation</h4>
                    <div class="footer-links">
                        <a href="index.html" class="footer-link">Startseite</a>
                        <a href="wolfewaves.html" class="footer-link">Was sind Wolfe Waves?</a>
                        <a href="maerkte.html" class="footer-link">Märkte</a>
                        <a href="performance.html" class="footer-link">Performance</a>
                        <a href="ueber-mich.html" class="footer-link">Über mich</a>
                    </div>
                </div>

                <div class="footer-section">
                    <h4>Community</h4>
                    <div class="footer-links">
                        <a href="https://t.me/wolfewavesignals" target="_blank" rel="noopener" class="footer-link">📱 Telegram Kanal</a>
                    </div>
                </div>

                <div class="footer-section">
                    <h4>Rechtliches</h4>
                    <div class="footer-links">
                        <a href="impressum.html" class="footer-link">Impressum</a>
                        <a href="datenschutz.html" class="footer-link">Datenschutz</a>
                        <a href="agb.html" class="footer-link">AGB</a>
                        <a href="widerruf.html" class="footer-link">Widerruf</a>
                    </div>
                </div>
            </div>

            <div class="footer-bottom">
                <p class="footer-copyright">
                    \u00A9 ${currentYear} wolfewavesignals.com \u2013 Trading-Signale für professionelle Händler
                </p>
                <p class="footer-disclaimer">
                    \u26A0\uFE0F Risikohinweis: Der Handel mit Finanzinstrumenten ist mit erheblichen Risiken verbunden und kann zum Totalverlust des eingesetzten Kapitals führen. Vergangene Ergebnisse garantieren keine zukünftigen Gewinne. Diese Website stellt keine Anlageberatung dar.
                </p>
            </div>
        </footer>
    `;

    // Footer einfügen
    const footerContainer = document.getElementById('site-footer');
    if (footerContainer) {
        footerContainer.innerHTML = footerHTML;
    }

})();
