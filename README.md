# WolfeWaveSignals

Professionelle Wolfe Wave Trading-Signale für DAX, NASDAQ, Forex und Krypto.

## Überblick

WolfeWaveSignals ist eine Web-Plattform, die automatisch erkannte Wolfe Wave Chartmuster als Trading-Signale bereitstellt. Jedes Signal enthält:

- Entry-Preis
- Stop-Loss (SL)
- Take-Profit Ziele (TP1, TP2, TP3)
- Chart-Screenshot

## Projektstruktur

```
Wolfewave/
├── index.html          # Hauptseite mit Signal-Dashboard
├── maerkte.html        # Marktübersicht
├── wolfewaves.html     # Erklärung der Wolfe Wave Strategie
├── api/
│   └── upload-signal.js    # Vercel Serverless Function für Signal-Upload
├── images/             # Bilder und Assets
├── agb.html           # Allgemeine Geschäftsbedingungen
├── datenschutz.html   # Datenschutzerklärung
├── impressum.html     # Impressum
├── widerruf.html      # Widerrufsbelehrung
├── robots.txt         # SEO Crawler-Anweisungen
├── sitemap.xml        # SEO Sitemap
└── site.webmanifest   # PWA Manifest
```

## Tech-Stack

- **Frontend**: Vanilla HTML/CSS/JavaScript
- **Backend**: Vercel Serverless Functions
- **Datenbank**: Supabase (PostgreSQL)
- **Storage**: Supabase Storage (für Chart-Screenshots)

## Lokale Entwicklung

```bash
# Dependencies installieren
npm install

# Für lokale Entwicklung mit Vercel CLI
npx vercel dev
```

## Umgebungsvariablen

Für die API wird folgende Umgebungsvariable benötigt:

```
SUPABASE_SERVICE_KEY=your_service_key_here
```

Diese muss in Vercel unter Project Settings → Environment Variables konfiguriert werden.

## API Endpunkte

### POST /api/upload-signal

Lädt ein neues Trading-Signal hoch oder aktualisiert ein bestehendes.

**Request Body:**
```json
{
  "wedgeId": "unique-id",
  "symbol": "EURUSD",
  "symbolName": "Euro/US Dollar",
  "market": "FOREX",
  "timeframe": "H1",
  "direction": "LONG",
  "entry": "1.0850",
  "sl": "1.0800",
  "tp1": "1.0900",
  "tp2": "1.0950",
  "tp3": "1.1000",
  "imageBase64": "base64-encoded-image"
}
```

## Deployment

Die Website wird über Vercel deployed. Push zu `main` triggert automatisches Deployment.

## Lizenz

Proprietär - Alle Rechte vorbehalten.
