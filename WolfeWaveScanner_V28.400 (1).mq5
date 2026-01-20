//+------------------------------------------------------------------+
//|                                      WolfeWaveScanner_V28.4.mq5 |
//|          V28.4: TP1/TP2/TP3 ALL count as SUCCESS                 |
//|                 + Filter: Reject oversized candles (>75%)        |
//|                 + Filter: EPA max 1.5x pattern duration          |
//|                 + Fix: Image interval check for Active signals   |
//|                 + Fix: Prevent ACTIVE->PENDING downgrade!        |
//|          V28.3: Fixed EPA expiry check for old signals           |
//|          V28.1: Fixed timezone - uses UTC for scanned_at         |
//|          V28: English texts, bigger copyright watermark          |
//+------------------------------------------------------------------+
#property copyright "Wolfe Wave Scanner"
#property version   "28.4"
#property description "V28.4: Prevents ACTIVE->PENDING flip-flop"

//--- Input Parameter
input group "======= Supabase Settings ======="
input string   InpSupabaseUrl = "https://ufqglmqiuyasszieprsr.supabase.co";
input string   InpSupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmcWdsbXFpdXlhc3N6aWVwcnNyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODM4MDM0NCwiZXhwIjoyMDgzOTU2MzQ0fQ.6R7biU4ffa3S6AVhOxRsrDOLlmtWUrC-uJh2FYevVQU";

input group "======= Scanner ======="
input int      InpScanIntervalMin = 15;
input int      InpMaxSymbols      = 0;
input int      InpScanBars        = 200;

input group "======= Timeframes ======="
input bool     InpScanM5          = true;
input bool     InpScanM15         = true;
input bool     InpScanH1          = true;
input bool     InpScanH4          = true;
input bool     InpScanD1          = true;
input bool     InpScanW1          = true;

input group "======= ZigZag ======="
input int      InpZZDepth         = 12;
input int      InpZZDeviation     = 5;

input group "======= Wolfe Rules ======="
input int      InpMinBarsBetween  = 3;
input int      InpMaxBarsPattern  = 200;
input int      InpMaxBarsP5       = 10;
input double   InpMinConvergenceAngle = 0.5;  // Min angle between wedge lines (degrees)
input double   InpMinPatternHeightPct = 2.0;  // Min pattern height as % of price
input double   InpMaxCandleSizePct = 75.0;    // V28.4: Max single candle size as % of pattern height
input double   InpMaxEPADistanceMult = 1.5;   // V28.4: EPA max distance as multiple of pattern duration

input group "======= Entry & Risk ======="
input double   InpSLPercent       = 5.0;            // SL in % vom Entry
input int      InpBarsAfterEPA    = 0;              // Kerzen nach EPA bis Inaktiv (0 = sofort bei EPA)

input group "======= Success Tracking ======="
input bool     InpEnableTracking  = true;
input int      InpMaxTrackingBars = 500;

input group "======= Output ======="
input bool     InpDebugMode       = true;

//--- Strukturen
struct ZZPoint
{
   int      bar;
   double   price;
   datetime time;
   bool     isHigh;
};

struct WolfeWave
{
   string   symbol;
   ENUM_TIMEFRAMES timeframe;
   ZZPoint  p1, p2, p3, p4, p5;
   bool     isBullish;
   datetime epaTime;
   double   epaPrice;
   // Linie 1-3 Parameter fuer Durchbruchspruefung
   double   line13_slope;
   double   line13_intercept;
};

//--- Struktur fuer PENDING Signale (warten auf Durchbruch)
struct PendingSignal
{
   string   wedgeId;
   string   symbol;
   ENUM_TIMEFRAMES timeframe;
   bool     isBullish;
   ZZPoint  p1, p2, p3, p4, p5;
   datetime epaTime;
   double   epaPrice;
   double   line13_slope;
   double   line13_intercept;
   string   market;
   string   imagePath;        // Bild ohne TPs
   datetime p5Time;           // Wann P5 erkannt wurde
   bool     waitingForBreakout;
};

//--- Struktur fuer ACTIVE Trades (nach Durchbruch)
struct ActiveTrade
{
   string   wedgeId;
   string   symbol;
   ENUM_TIMEFRAMES timeframe;
   bool     isBullish;
   double   entryPrice;
   double   slPrice;
   double   tp1Price;
   double   tp2Price;
   double   tp3Price;
   datetime entryTime;
   string   market;
   string   imagePath;        // Bild MIT TPs
   bool     tp1Hit;
   bool     tp2Hit;
   bool     tp3Hit;
   bool     slHit;
   int      barsTracked;
   // Original Keil-Daten fuer Bild
   ZZPoint  p1, p2, p3, p4, p5;
   datetime epaTime;
   double   epaPrice;
};

//--- Globale Variablen
datetime g_lastScanTime = 0;
int g_patternsFound = 0;
string g_foundPatterns[];
int g_maxStoredPatterns = 500;

//--- Arrays
PendingSignal g_pendingSignals[];
ActiveTrade g_activeTrades[];

//--- Statistik
int g_successCount = 0;
int g_partialCount = 0;
int g_failedCount = 0;
int g_expiredCount = 0;

//+------------------------------------------------------------------+
// ZEITSTEMPEL FUNKTIONEN
//+------------------------------------------------------------------+
string GetFormattedDateTime(datetime dt)
{
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   return StringFormat("%02d.%02d.%04d %02d:%02d", 
                       mdt.day, mdt.mon, mdt.year, mdt.hour, mdt.min);
}

string GetVersionTimestamp()
{
   MqlDateTime mdt;
   TimeToStruct(TimeGMT(), mdt);  // V28.1: UTC statt Broker-Zeit
   return StringFormat("%04d%02d%02d_%02d%02d%02d", 
                       mdt.year, mdt.mon, mdt.day, mdt.hour, mdt.min, mdt.sec);
}

//+------------------------------------------------------------------+
// V28.1: ISO 8601 UTC Timestamp für Datenbank
// Format: 2026-01-19T07:50:00Z (Z = UTC)
//+------------------------------------------------------------------+
string GetISODateTimeUTC()
{
   MqlDateTime mdt;
   TimeToStruct(TimeGMT(), mdt);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ", 
                       mdt.year, mdt.mon, mdt.day, mdt.hour, mdt.min, mdt.sec);
}

// Für entry_time (ohne Sekunden)
string GetISODateTimeUTCShort()
{
   MqlDateTime mdt;
   TimeToStruct(TimeGMT(), mdt);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:00Z", 
                       mdt.year, mdt.mon, mdt.day, mdt.hour, mdt.min);
}

// Konvertiere eine datetime zu ISO Format (für Chart-Zeiten)
string DatetimeToISO(datetime dt)
{
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:00", 
                       mdt.year, mdt.mon, mdt.day, mdt.hour, mdt.min);
}

//+------------------------------------------------------------------+
// BILD IN HISTORIE SPEICHERN (signal_images Tabelle)
//+------------------------------------------------------------------+
void SaveImageToHistory(string wedgeId, string imageUrl)
{
   string versionTs = GetVersionTimestamp();
   
   string json = "{";
   json += "\"wedge_id\":\"" + wedgeId + "\"";
   json += ",\"image_url\":\"" + EscapeJSON(imageUrl) + "\"";
   json += ",\"scanned_at\":\"" + GetISODateTimeUTC() + "\"";  // V28.1: UTC ISO Format
   json += ",\"version\":\"" + versionTs + "\"";
   json += "}";
   
   string url = InpSupabaseUrl + "/rest/v1/signal_images";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char result[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   int res = WebRequest("POST", url, headers, 5000, postData, result, resultHeaders);
   
   if(res == 200 || res == 201 || res == 204)
      Print("[OK] Bild-Historie: ", wedgeId);
   else if(InpDebugMode)
      Print("[WARN] Bild-Historie nicht gespeichert: ", res);
}

//+------------------------------------------------------------------+
// V28.4 FIX: Prüfe ob Signal bereits ACTIVE in DB ist
// Verhindert Downgrade von ACTIVE -> PENDING
//+------------------------------------------------------------------+
bool IsSignalAlreadyActive(string wedgeId)
{
   string url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + wedgeId + "&select=status";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   
   char result[];
   string resultHeaders;
   uchar empty[];
   
   int res = WebRequest("GET", url, headers, 5000, empty, result, resultHeaders);
   
   if(res != 200) return false;
   
   string response = CharArrayToString(result);
   
   // Prüfe ob status "active" ist
   if(StringFind(response, "\"status\":\"active\"") >= 0)
   {
      if(InpDebugMode) Print("[CHECK] Signal ", wedgeId, " ist bereits ACTIVE in DB");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
// V28.1: IMAGE_PATH IN SIGNALS TABELLE UPDATEN (für Kachel-Anzeige)
//+------------------------------------------------------------------+
void UpdateSignalImagePath(string wedgeId, string imageUrl)
{
   string json = "{\"image_path\":\"" + EscapeJSON(imageUrl) + "\"}";
   
   string url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + wedgeId;
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char result[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   int res = WebRequest("PATCH", url, headers, 5000, postData, result, resultHeaders);
   
   if(res == 200 || res == 204)
      Print("[OK] Signal image_path aktualisiert: ", wedgeId);
   else if(InpDebugMode)
      Print("[WARN] Signal image_path Update fehlgeschlagen: ", res);
}

//+------------------------------------------------------------------+
// HANDELSZEITEN-PRUEFUNG - Nach Markt getrennt
//+------------------------------------------------------------------+
bool IsMarketOpen(string market)
{
   MqlDateTime dt;
   TimeGMT(dt);  // V28.2 FIX: UTC verwenden, nicht Broker-Zeit!
   
   int day = dt.day_of_week;   // 0=Sonntag, 1=Montag, ..., 6=Samstag
   int hour = dt.hour;
   int minute = dt.min;
   
   // CRYPTO - 24/7, aber Wochenende reduziert (optional trotzdem Bilder)
   if(market == "CRYPTO")
   {
      return true;  // Immer offen
   }
   
   // FOREX - Sonntag 22:00 UTC bis Freitag 22:00 UTC
   if(market == "FOREX")
   {
      // Samstag = geschlossen
      if(day == 6) return false;
      
      // Sonntag vor 22:00 = geschlossen
      if(day == 0 && hour < 22) return false;
      
      // Freitag nach 22:00 = geschlossen
      if(day == 5 && hour >= 22) return false;
      
      return true;
   }
   
   // DAX - Montag-Freitag 08:00-17:30 UTC (= 09:00-18:30 CET)
   if(market == "DAX")
   {
      // Wochenende = geschlossen
      if(day == 0 || day == 6) return false;
      
      // Vor 08:00 oder nach 17:30 = geschlossen
      if(hour < 8) return false;
      if(hour > 17 || (hour == 17 && minute > 30)) return false;
      
      return true;
   }
   
   // US-AKTIEN (NYSE, NASDAQ, SP500) - Montag-Freitag 14:30-21:00 UTC (= 9:30-16:00 EST)
   if(market == "NYSE" || market == "NASDAQ" || market == "SP500")
   {
      // Wochenende = geschlossen
      if(day == 0 || day == 6) return false;
      
      // Vor 14:30 oder nach 21:00 = geschlossen
      if(hour < 14 || (hour == 14 && minute < 30)) return false;
      if(hour >= 21) return false;
      
      return true;
   }
   
   // OTHER / Unbekannt - Standard: Mo-Fr
   if(day == 0 || day == 6) return false;
   
   return true;
}

//+------------------------------------------------------------------+
// BILD-UPDATE INTERVALL - Nur neues Bild wenn genug Zeit vergangen
//+------------------------------------------------------------------+
int GetImageUpdateIntervalSeconds(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_W1:  return 86400;    // 24 Stunden
      case PERIOD_D1:  return 43200;    // 12 Stunden
      case PERIOD_H4:  return 14400;    // 4 Stunden
      case PERIOD_H1:  return 3600;     // 1 Stunde
      case PERIOD_M15: return 1800;     // 30 Minuten
      case PERIOD_M5:  return 900;      // 15 Minuten
      default:         return 3600;     // Standard: 1 Stunde
   }
}

//+------------------------------------------------------------------+
// Prueft ob neues Bild noetig ist (basierend auf letztem Scan)
//+------------------------------------------------------------------+
bool ShouldCreateNewImage(string wedgeId, ENUM_TIMEFRAMES tf, string market)
{
   // NEU: Keine Bilder ausserhalb der Handelszeiten
   if(!IsMarketOpen(market))
   {
      if(InpDebugMode)
         Print("[IMG] Markt ", market, " geschlossen - kein neues Bild");
      return false;
   }
   
   // Hole letzten Scan-Zeitpunkt aus signal_images
   string url = InpSupabaseUrl + "/rest/v1/signal_images?wedge_id=eq." + wedgeId + 
                "&select=scanned_at&order=scanned_at.desc&limit=1";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   
   char result[];
   string resultHeaders;
   uchar empty[];
   
   int res = WebRequest("GET", url, headers, 5000, empty, result, resultHeaders);
   
   if(res != 200)
   {
      // Kein Eintrag oder Fehler -> neues Bild erstellen
      return true;
   }
   
   string response = CharArrayToString(result);
   
   // Leeres Array = kein Bild vorhanden
   if(response == "[]" || StringLen(response) < 20)
      return true;
   
   // Parse scanned_at aus Response (Format: "2026-01-16 15:30:00")
   string lastScanStr = ExtractJSONString(response, "scanned_at");
   if(lastScanStr == "")
      return true;
   
   // Konvertiere zu datetime (vereinfacht - nimmt nur Datum/Zeit Teil)
   // Format aus DB: "2026-01-16T15:30:00+00:00" oder "2026-01-16 15:30:00"
   StringReplace(lastScanStr, "T", " ");
   int plusPos = StringFind(lastScanStr, "+");
   if(plusPos > 0) lastScanStr = StringSubstr(lastScanStr, 0, plusPos);
   
   datetime lastScan = StringToTime(lastScanStr);
   if(lastScan == 0)
      return true;
   
   // V28.2 FIX: StringToTime() interpretiert als Broker-Zeit, aber DB speichert UTC!
   // Korrigiere um die Zeitzone-Differenz (TimeCurrent - TimeGMT = Broker-Offset)
   // Beispiel: DB hat 15:25 UTC, StringToTime liest als 15:25 Broker = 13:25 UTC (bei UTC+2)
   // Wir müssen den Offset ADDIEREN um die korrekte UTC Zeit zu bekommen
   int brokerOffsetSec = (int)(TimeCurrent() - TimeGMT());
   lastScan = lastScan + brokerOffsetSec;  // Konvertiere von "falsch interpretierter Broker-Zeit" zu korrekter UTC
   
   // Pruefe ob genug Zeit vergangen ist
   int interval = GetImageUpdateIntervalSeconds(tf);
   int elapsed = (int)(TimeGMT() - lastScan);  // V28.1: UTC vs UTC vergleichen!
   
   if(elapsed >= interval)
   {
      if(InpDebugMode)
         Print("[IMG] ", wedgeId, " - ", elapsed/60, " Min seit letztem Bild -> Neues Bild");
      return true;
   }
   else
   {
      if(InpDebugMode)
         Print("[IMG] ", wedgeId, " - ", elapsed/60, "/", interval/60, " Min -> Kein neues Bild");
      return false;
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   Print("============================================");
   Print("WOLFE WAVE SCANNER V28.2");
   Print("FIX: Bild-Intervall Timezone-Korrektur");
   Print("FIX: Entry nur bei geschlossener Kerze");
   Print("NEU: Zeitstempel im Chart + Bild-Historie");
   Print("     SL: ", InpSLPercent, "% vom Entry");
   Print("     EPA + ", InpBarsAfterEPA, " Kerzen = Expired");
   Print("============================================");
   
   EventSetTimer(60);
   
   // Lade pending und active Signals aus DB
   if(InpEnableTracking)
   {
      LoadPendingSignalsFromDB();
      LoadActiveTradesFromDB();
   }
   
   Print("Starte ersten Scan in 3 Sekunden...");
   Sleep(3000);
   PerformScan();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("Scanner beendet. Patterns: ", g_patternsFound);
   Print("Pending: ", ArraySize(g_pendingSignals), " | Active: ", ArraySize(g_activeTrades));
   Print("TP3: ", g_successCount, " | Partial: ", g_partialCount, " | Failed: ", g_failedCount, " | Expired: ", g_expiredCount);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   if(InpEnableTracking)
   {
      // 1. Pruefe pending Signale auf Durchbruch oder Expiry
      CheckPendingSignalsForBreakout();
      
      // 2. Pruefe active Trades auf TP/SL
      CheckActiveTradesForCompletion();
   }
   
   // 3. Normaler Scan
   if(TimeCurrent() - g_lastScanTime >= InpScanIntervalMin * 60)
      PerformScan();
   
   int mins = (int)((InpScanIntervalMin * 60 - (TimeCurrent() - g_lastScanTime)) / 60);
   Comment("Wolfe Scanner V27.23 | Patterns: ", g_patternsFound, 
           " | Pending: ", ArraySize(g_pendingSignals),
           " | Active: ", ArraySize(g_activeTrades),
           " | TP3: ", g_successCount, " | Partial: ", g_partialCount, " | Failed: ", g_failedCount,
           " | Naechster: ", mins, " Min | [S]=Scan [T]=Track [P]=Pending");
}

//+------------------------------------------------------------------+
// NEUE FUNKTION: Pruefe pending Signale auf Durchbruch
//+------------------------------------------------------------------+
void CheckPendingSignalsForBreakout()
{
   int count = ArraySize(g_pendingSignals);
   if(count == 0) return;
   
   for(int i = count - 1; i >= 0; i--)
   {
      PendingSignal sig = g_pendingSignals[i];
      
      // Hole aktuelle Kerzen
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(sig.symbol, sig.timeframe, 0, 10, rates) < 3) continue;
      
      // Aktuelle Zeit
      datetime currentTime = rates[0].time;
      
      // 1. EXPIRY CHECK: EPA + X Kerzen ueberschritten?
      // FIX V28.3: Bessere Fehlerbehandlung fuer EPA Check
      if(sig.epaTime > 0 && currentTime > sig.epaTime)
      {
         int barsAfterEPA = iBarShift(sig.symbol, sig.timeframe, sig.epaTime, false);
         
         // iBarShift gibt -1 bei Fehler zurueck
         // In diesem Fall: Wenn EPA in der Vergangenheit liegt, trotzdem als expired behandeln
         if(barsAfterEPA < 0)
         {
            Print("[INACTIVE] ", sig.wedgeId, " - EPA Check Fehler, aber EPA (", TimeToString(sig.epaTime), ") ist in der Vergangenheit");
            ExpirePendingSignal(sig);
            RemovePendingSignal(i);
            g_expiredCount++;
            continue;
         }
         
         if(barsAfterEPA >= InpBarsAfterEPA)
         {
            Print("[INACTIVE] ", sig.wedgeId, " - Keillinien-Kreuzung (EPA) ueberschritten (", barsAfterEPA, " Kerzen)");
            ExpirePendingSignal(sig);
            RemovePendingSignal(i);
            g_expiredCount++;
            continue;
         }
      }
      // FALLBACK: Wenn epaTime nicht gesetzt ist (alte Signale), pruefen ob P5 zu alt ist
      else if(sig.epaTime == 0 && sig.p5.time > 0)
      {
         int barsSinceP5 = iBarShift(sig.symbol, sig.timeframe, sig.p5.time, false);
         // Wenn P5 mehr als 50 Kerzen alt ist und kein Entry -> vermutlich abgelaufen
         if(barsSinceP5 > 50)
         {
            Print("[INACTIVE] ", sig.wedgeId, " - Kein EPA gesetzt und P5 ist ", barsSinceP5, " Kerzen alt");
            ExpirePendingSignal(sig);
            RemovePendingSignal(i);
            g_expiredCount++;
            continue;
         }
      }
      
      // Linien-Parameter fuer Two-Point-Form
      double p1_price = sig.p1.price;
      double p3_price = sig.p3.price;
      datetime t1 = sig.p1.time;
      datetime t3 = sig.p3.time;
      double timeDiff13 = (double)(t3 - t1);
      
      if(timeDiff13 == 0) continue;
      
      // 2. BREAKOUT CHECK: Pruefe ob Kerze die 1-3 Linie durchbrochen hat
      // V28.1 FIX: Nur GESCHLOSSENE Kerzen pruefen (ab Index 1, nicht 0!)
      // Entry = Kerze muss SCHLIESSEN ueber/unter der Linie, nicht nur beruehren!
      for(int b = 1; b < 5; b++)  // Start bei 1 = letzte geschlossene Kerze
      {
         datetime barTime = rates[b].time;
         
         // Berechne den Linien-Preis mit Two-Point-Form
         double linePrice = p1_price + (p3_price - p1_price) * ((double)(barTime - t1) / timeDiff13);
         
         double closePrice = rates[b].close;
         double openPrice = rates[b].open;
         
         bool breakoutDetected = false;
         
         if(sig.isBullish)
         {
            // BULLISH: Kerze muss UEBER der Linie SCHLIESSEN
            // Zusaetzlich: Close muss hoeher sein als Open (bullish candle) fuer Bestaetigung
            if(closePrice > linePrice && closePrice > openPrice)
            {
               breakoutDetected = true;
            }
         }
         else
         {
            // BEARISH: Kerze muss UNTER der Linie SCHLIESSEN
            // Zusaetzlich: Close muss tiefer sein als Open (bearish candle) fuer Bestaetigung
            if(closePrice < linePrice && closePrice < openPrice)
            {
               breakoutDetected = true;
            }
         }
         
         if(breakoutDetected)
         {
            Print("*** BREAKOUT DETECTED! ", sig.wedgeId, " ***");
            Print("    Entry (Linienpreis): ", DoubleToString(linePrice, 5));
            
            // Entry = Linienpreis (exakter Durchbruchspunkt)
            double entryPrice = linePrice;
            ActivatePendingSignal(sig, entryPrice, rates[b].time);
            RemovePendingSignal(i);
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
// Pending Signal aktivieren (Durchbruch erfolgt)
//+------------------------------------------------------------------+
void ActivatePendingSignal(PendingSignal &sig, double entryPrice, datetime entryTime)
{
   Print("========================================");
   Print("ENTRY AKTIVIERT: ", sig.wedgeId);
   Print("Entry: ", entryPrice, " | Time: ", TimeToString(entryTime));
   Print("========================================");
   
   // Berechne SL und TPs
   double slPrice, tp1Price, tp2Price, tp3Price;
   
   // TP3 basierend auf Linie 1-4 (gruene Linie)
   double slope14 = (sig.p4.price - sig.p1.price) / (double)(sig.p4.time - sig.p1.time);
   int keilDauer = (int)(sig.p5.time - sig.p1.time);
   datetime greenEnd = sig.p5.time + keilDauer;
   double tp3OnLine = sig.p1.price + slope14 * (double)(greenEnd - sig.p1.time);
   
   if(sig.isBullish)
   {
      // BULLISH: SL unter Entry, TPs ÃœBER Entry
      slPrice = entryPrice * (1.0 - InpSLPercent / 100.0);
      
      // Validierung: TP3 muss ÃœBER Entry sein
      if(tp3OnLine <= entryPrice)
      {
         tp3OnLine = entryPrice + (entryPrice - slPrice) * 3.0;
         Print("[WARN] TP3 korrigiert fuer BULLISH: ", tp3OnLine);
      }
      
      double tpRange = tp3OnLine - entryPrice;
      tp1Price = entryPrice + tpRange * 0.33;
      tp2Price = entryPrice + tpRange * 0.66;
      tp3Price = tp3OnLine;
   }
   else
   {
      // BEARISH: SL ÃœBER Entry, TPs UNTER Entry
      slPrice = entryPrice * (1.0 + InpSLPercent / 100.0);
      
      // Validierung: TP3 muss UNTER Entry sein
      if(tp3OnLine >= entryPrice)
      {
         tp3OnLine = entryPrice - (slPrice - entryPrice) * 3.0;
         Print("[WARN] TP3 korrigiert fuer BEARISH: ", tp3OnLine);
      }
      
      double tpRange = entryPrice - tp3OnLine;
      tp1Price = entryPrice - tpRange * 0.33;
      tp2Price = entryPrice - tpRange * 0.66;
      tp3Price = tp3OnLine;
   }
   
   // Validierung ausgeben
   if(sig.isBullish)
   {
      if(tp1Price <= entryPrice || tp2Price <= tp1Price || tp3Price <= tp2Price)
         Print("[ERROR] Ungueltige TPs BULLISH!");
   }
   else
   {
      if(tp1Price >= entryPrice || tp2Price >= tp1Price || tp3Price >= tp2Price)
         Print("[ERROR] Ungueltige TPs BEARISH!");
   }
   
   Print("SL: ", slPrice, " | TP1: ", tp1Price, " | TP2: ", tp2Price, " | TP3: ", tp3Price);
   
   // ActiveTrade erstellen
   ActiveTrade trade;
   trade.wedgeId = sig.wedgeId;
   trade.symbol = sig.symbol;
   trade.timeframe = sig.timeframe;
   trade.isBullish = sig.isBullish;
   trade.entryPrice = entryPrice;
   trade.slPrice = slPrice;
   trade.tp1Price = tp1Price;
   trade.tp2Price = tp2Price;
   trade.tp3Price = tp3Price;
   trade.entryTime = entryTime;
   trade.market = sig.market;
   trade.tp1Hit = false;
   trade.tp2Hit = false;
   trade.tp3Hit = false;
   trade.slHit = false;
   trade.barsTracked = 0;
   trade.p1 = sig.p1;
   trade.p2 = sig.p2;
   trade.p3 = sig.p3;
   trade.p4 = sig.p4;
   trade.p5 = sig.p5;
   trade.epaTime = sig.epaTime;
   trade.epaPrice = sig.epaPrice;
   
   // NEUES Bild erstellen MIT TPs
   string newImagePath = CreateActiveTradeImage(trade);
   trade.imagePath = newImagePath;
   
   // In Array speichern
   int size = ArraySize(g_activeTrades);
   ArrayResize(g_activeTrades, size + 1);
   g_activeTrades[size] = trade;
   
   // DB Update: Status "active" + alle Trade-Daten
   UpdateSignalToActive(trade);
}

//+------------------------------------------------------------------+
// Neues Bild erstellen fuer aktiven Trade (MIT TPs)
//+------------------------------------------------------------------+
string CreateActiveTradeImage(ActiveTrade &trade)
{
   long chartId = ChartOpen(trade.symbol, trade.timeframe);
   if(chartId == 0) 
   {
      Print("Chart Error!");
      return "";
   }
   
   // Chart Setup
   SetupChartStyle(chartId);
   
   // Navigiere zum Pattern
   int patternStart = iBarShift(trade.symbol, trade.timeframe, trade.p1.time, false);
   int shift = patternStart - 10;
   if(shift < 0) shift = 0;
   ChartNavigate(chartId, CHART_END, -shift);
   Sleep(300);
   
   // Zeichne Pattern MIT TPs
   DrawPatternWithTPs(chartId, trade);
   ChartRedraw(chartId);
   Sleep(500);
   
   // Screenshot
   string symbolClean = trade.symbol;
   StringReplace(symbolClean, ".", "");
   StringReplace(symbolClean, "/", "");
   
   string tfStr = TFToString(trade.timeframe);
   
   // NEU: Versionierter Dateiname fuer Bild-Historie
   string versionTs = GetVersionTimestamp();
   string versionedFile = trade.wedgeId + "_ACTIVE_v" + versionTs + ".png";
   string tempFile = versionedFile;
   
   if(!ChartScreenShot(chartId, tempFile, 1920, 1080, ALIGN_RIGHT))
   {
      Print("Screenshot Error!");
      ChartClose(chartId);
      return "";
   }
   Sleep(300);
   
   // Upload mit versioniertem Pfad
   string imagePath = trade.market + "/" + tfStr + "/" + versionedFile;
   bool uploadOk = UploadImageToSupabase(tempFile, imagePath);
   
   string imageUrl = "";
   if(uploadOk)
   {
      imageUrl = InpSupabaseUrl + "/storage/v1/object/public/signals/" + imagePath;
      Print("[OK] Neues Bild mit TPs: ", imagePath);
      
      // NEU: Bild in Historie speichern fuer Slider
      SaveImageToHistory(trade.wedgeId, imageUrl);
      
      // V28.1: Auch image_path in signals Tabelle updaten (für Kachel-Anzeige)
      UpdateSignalImagePath(trade.wedgeId, imageUrl);
   }
   
   FileDelete(tempFile);
   ChartClose(chartId);
   
   return imageUrl;
}

//+------------------------------------------------------------------+
// Pattern MIT TPs zeichnen (fuer aktive Trades)
//+------------------------------------------------------------------+
void DrawPatternWithTPs(long chartId, ActiveTrade &trade)
{
   string prefix = "WW_" + trade.symbol + "_";
   
   int keilDauer = (int)(trade.p5.time - trade.p1.time);
   datetime greenLineEnd = trade.p5.time + keilDauer;
   
   // Berechne greenEndPrice fuer TP3 Label
   double slope14 = (trade.p4.price - trade.p1.price) / (double)(trade.p4.time - trade.p1.time);
   double greenEndPrice = trade.p1.price + slope14 * (double)(greenLineEnd - trade.p1.time);
   
   // Keil-Linien
   ObjectCreate(chartId, prefix+"L13", OBJ_TREND, 0, trade.p1.time, trade.p1.price, trade.p3.time, trade.p3.price);
   ObjectSetInteger(chartId, prefix+"L13", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"L13", OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartId, prefix+"L13", OBJPROP_RAY_RIGHT, true);
   
   ObjectCreate(chartId, prefix+"L24", OBJ_TREND, 0, trade.p2.time, trade.p2.price, trade.p4.time, trade.p4.price);
   ObjectSetInteger(chartId, prefix+"L24", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"L24", OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartId, prefix+"L24", OBJPROP_RAY_RIGHT, true);
   
   // FIX 3: Gruene Linie direkt von P1 durch P4 (mit RAY_RIGHT fuer Verlaengerung)
   ObjectCreate(chartId, prefix+"L14", OBJ_TREND, 0, trade.p1.time, trade.p1.price, trade.p4.time, trade.p4.price);
   ObjectSetInteger(chartId, prefix+"L14", OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(chartId, prefix+"L14", OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartId, prefix+"L14", OBJPROP_RAY_RIGHT, true);
   
   // Punkt-Labels
   ObjectCreate(chartId, prefix+"P1", OBJ_TEXT, 0, trade.p1.time, trade.p1.price);
   ObjectSetString(chartId, prefix+"P1", OBJPROP_TEXT, " 1");
   ObjectSetInteger(chartId, prefix+"P1", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"P1", OBJPROP_FONTSIZE, 12);
   
   ObjectCreate(chartId, prefix+"P2", OBJ_TEXT, 0, trade.p2.time, trade.p2.price);
   ObjectSetString(chartId, prefix+"P2", OBJPROP_TEXT, " 2");
   ObjectSetInteger(chartId, prefix+"P2", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"P2", OBJPROP_FONTSIZE, 12);
   
   ObjectCreate(chartId, prefix+"P3", OBJ_TEXT, 0, trade.p3.time, trade.p3.price);
   ObjectSetString(chartId, prefix+"P3", OBJPROP_TEXT, " 3");
   ObjectSetInteger(chartId, prefix+"P3", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"P3", OBJPROP_FONTSIZE, 12);
   
   ObjectCreate(chartId, prefix+"P4", OBJ_TEXT, 0, trade.p4.time, trade.p4.price);
   ObjectSetString(chartId, prefix+"P4", OBJPROP_TEXT, " 4");
   ObjectSetInteger(chartId, prefix+"P4", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"P4", OBJPROP_FONTSIZE, 12);
   
   ObjectCreate(chartId, prefix+"P5", OBJ_TEXT, 0, trade.p5.time, trade.p5.price);
   ObjectSetString(chartId, prefix+"P5", OBJPROP_TEXT, " 5");
   ObjectSetInteger(chartId, prefix+"P5", OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(chartId, prefix+"P5", OBJPROP_FONTSIZE, 12);
   
   // Titel
   string titel = (trade.isBullish ? "BULLISH" : "BEARISH") + " " + TFToString(trade.timeframe) + " - ACTIVE";
   ObjectCreate(chartId, prefix+"Titel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_YDISTANCE, 25);
   ObjectSetString(chartId, prefix+"Titel", OBJPROP_TEXT, titel);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_COLOR, trade.isBullish ? clrGreen : clrRed);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_FONTSIZE, 16);
   
   // Symbol Name
   string symbolName = SymbolInfoString(trade.symbol, SYMBOL_DESCRIPTION);
   if(symbolName == "") symbolName = trade.symbol;
   ObjectCreate(chartId, prefix+"SymbolName", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_YDISTANCE, 48);
   ObjectSetString(chartId, prefix+"SymbolName", OBJPROP_TEXT, symbolName);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_FONTSIZE, 16);
   
   // Copyright - BIGGER with copyright symbol
   ObjectCreate(chartId, prefix+"Copyright", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_YDISTANCE, 35);  // V28.2 fix
   ObjectSetString(chartId, prefix+"Copyright", OBJPROP_TEXT, "© wolfewavesignals.com");
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_FONTSIZE, 14);
   
   // === SCAN TIMESTAMP (Bottom left, above Copyright) ===
   string scanTime = GetFormattedDateTime(TimeCurrent());
   ObjectCreate(chartId, prefix+"ScanTime", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_YDISTANCE, 70);  // V28.2 fix
   ObjectSetString(chartId, prefix+"ScanTime", OBJPROP_TEXT, "Scan: " + scanTime);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_FONTSIZE, 10);
   
   // === NEU: ENTRY ZEITPUNKT (Unten links, Ã¼ber Scan-Zeit) ===
   string entryTime = GetFormattedDateTime(trade.entryTime);
   ObjectCreate(chartId, prefix+"EntryTimeLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"EntryTimeLabel", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(chartId, prefix+"EntryTimeLabel", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"EntryTimeLabel", OBJPROP_YDISTANCE, 88);  // V28.2 fix
   ObjectSetString(chartId, prefix+"EntryTimeLabel", OBJPROP_TEXT, "Entry: " + entryTime);
   ObjectSetInteger(chartId, prefix+"EntryTimeLabel", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(chartId, prefix+"EntryTimeLabel", OBJPROP_FONTSIZE, 10);
   
   // === ENTRY, SL, TPs ZEICHNEN ===
   int periodSec = PeriodSeconds(trade.timeframe);
   datetime lineEnd = trade.entryTime + periodSec * 20;
   
   // Entry Linie (blau)
   ObjectCreate(chartId, prefix+"EntryLine", OBJ_TREND, 0, trade.entryTime, trade.entryPrice, lineEnd, trade.entryPrice);
   ObjectSetInteger(chartId, prefix+"EntryLine", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(chartId, prefix+"EntryLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartId, prefix+"EntryLine", OBJPROP_STYLE, STYLE_SOLID);
   
   ObjectCreate(chartId, prefix+"EntryLabel", OBJ_TEXT, 0, lineEnd, trade.entryPrice);
   ObjectSetString(chartId, prefix+"EntryLabel", OBJPROP_TEXT, " ENTRY " + DoubleToString(trade.entryPrice, 2));
   ObjectSetInteger(chartId, prefix+"EntryLabel", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(chartId, prefix+"EntryLabel", OBJPROP_FONTSIZE, 10);
   
   // SL Linie (rot)
   ObjectCreate(chartId, prefix+"SLLine", OBJ_TREND, 0, trade.entryTime, trade.slPrice, lineEnd, trade.slPrice);
   ObjectSetInteger(chartId, prefix+"SLLine", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"SLLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartId, prefix+"SLLine", OBJPROP_STYLE, STYLE_DASH);
   
   ObjectCreate(chartId, prefix+"SLLabel", OBJ_TEXT, 0, lineEnd, trade.slPrice);
   ObjectSetString(chartId, prefix+"SLLabel", OBJPROP_TEXT, " SL " + DoubleToString(trade.slPrice, 2));
   ObjectSetInteger(chartId, prefix+"SLLabel", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"SLLabel", OBJPROP_FONTSIZE, 10);
   
   // TP1 Linie (hellgruen)
   ObjectCreate(chartId, prefix+"TP1Line", OBJ_TREND, 0, trade.entryTime, trade.tp1Price, greenLineEnd, trade.tp1Price);
   ObjectSetInteger(chartId, prefix+"TP1Line", OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(chartId, prefix+"TP1Line", OBJPROP_STYLE, STYLE_DOT);
   
   ObjectCreate(chartId, prefix+"TP1Label", OBJ_TEXT, 0, greenLineEnd, trade.tp1Price);
   ObjectSetString(chartId, prefix+"TP1Label", OBJPROP_TEXT, " TP1");
   ObjectSetInteger(chartId, prefix+"TP1Label", OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(chartId, prefix+"TP1Label", OBJPROP_FONTSIZE, 10);
   
   // TP2 Linie (gruen)
   ObjectCreate(chartId, prefix+"TP2Line", OBJ_TREND, 0, trade.entryTime, trade.tp2Price, greenLineEnd, trade.tp2Price);
   ObjectSetInteger(chartId, prefix+"TP2Line", OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(chartId, prefix+"TP2Line", OBJPROP_STYLE, STYLE_DOT);
   
   ObjectCreate(chartId, prefix+"TP2Label", OBJ_TEXT, 0, greenLineEnd, trade.tp2Price);
   ObjectSetString(chartId, prefix+"TP2Label", OBJPROP_TEXT, " TP2");
   ObjectSetInteger(chartId, prefix+"TP2Label", OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(chartId, prefix+"TP2Label", OBJPROP_FONTSIZE, 10);
   
   // TP3 = Gruene Linie (1-4 Linie) - kein separates horizontales Level!
   // Die gruene Linie ist bereits gezeichnet als L14
   // Add label to clarify that the green line is TP3
   ObjectCreate(chartId, prefix+"TP3Label", OBJ_TEXT, 0, greenLineEnd, greenEndPrice);
   ObjectSetString(chartId, prefix+"TP3Label", OBJPROP_TEXT, " TP3 (EPA Line)");
   ObjectSetInteger(chartId, prefix+"TP3Label", OBJPROP_COLOR, clrDarkGreen);
   ObjectSetInteger(chartId, prefix+"TP3Label", OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
// Pattern OHNE TPs zeichnen (fuer pending Signale)
//+------------------------------------------------------------------+
void DrawPatternPendingOnly(long chartId, WolfeWave &wave)
{
   string prefix = "WW_" + wave.symbol + "_";
   
   // Keil-Linien
   ObjectCreate(chartId, prefix+"L13", OBJ_TREND, 0, wave.p1.time, wave.p1.price, wave.p3.time, wave.p3.price);
   ObjectSetInteger(chartId, prefix+"L13", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"L13", OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartId, prefix+"L13", OBJPROP_RAY_RIGHT, true);
   
   ObjectCreate(chartId, prefix+"L24", OBJ_TREND, 0, wave.p2.time, wave.p2.price, wave.p4.time, wave.p4.price);
   ObjectSetInteger(chartId, prefix+"L24", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"L24", OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartId, prefix+"L24", OBJPROP_RAY_RIGHT, true);
   
   // FIX 3: Gruene Linie direkt von P1 durch P4 (mit RAY_RIGHT fuer Verlaengerung)
   ObjectCreate(chartId, prefix+"L14", OBJ_TREND, 0, wave.p1.time, wave.p1.price, wave.p4.time, wave.p4.price);
   ObjectSetInteger(chartId, prefix+"L14", OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(chartId, prefix+"L14", OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartId, prefix+"L14", OBJPROP_RAY_RIGHT, true);
   
   // Punkt-Labels
   ObjectCreate(chartId, prefix+"P1", OBJ_TEXT, 0, wave.p1.time, wave.p1.price);
   ObjectSetString(chartId, prefix+"P1", OBJPROP_TEXT, " 1");
   ObjectSetInteger(chartId, prefix+"P1", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"P1", OBJPROP_FONTSIZE, 12);
   
   ObjectCreate(chartId, prefix+"P2", OBJ_TEXT, 0, wave.p2.time, wave.p2.price);
   ObjectSetString(chartId, prefix+"P2", OBJPROP_TEXT, " 2");
   ObjectSetInteger(chartId, prefix+"P2", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"P2", OBJPROP_FONTSIZE, 12);
   
   ObjectCreate(chartId, prefix+"P3", OBJ_TEXT, 0, wave.p3.time, wave.p3.price);
   ObjectSetString(chartId, prefix+"P3", OBJPROP_TEXT, " 3");
   ObjectSetInteger(chartId, prefix+"P3", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"P3", OBJPROP_FONTSIZE, 12);
   
   ObjectCreate(chartId, prefix+"P4", OBJ_TEXT, 0, wave.p4.time, wave.p4.price);
   ObjectSetString(chartId, prefix+"P4", OBJPROP_TEXT, " 4");
   ObjectSetInteger(chartId, prefix+"P4", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartId, prefix+"P4", OBJPROP_FONTSIZE, 12);
   
   ObjectCreate(chartId, prefix+"P5", OBJ_TEXT, 0, wave.p5.time, wave.p5.price);
   ObjectSetString(chartId, prefix+"P5", OBJPROP_TEXT, " 5");
   ObjectSetInteger(chartId, prefix+"P5", OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(chartId, prefix+"P5", OBJPROP_FONTSIZE, 12);
   
   // Titel - PENDING
   string titel = (wave.isBullish ? "BULLISH" : "BEARISH") + " " + TFToString(wave.timeframe) + " - SWEET ZONE";
   ObjectCreate(chartId, prefix+"Titel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_YDISTANCE, 25);
   ObjectSetString(chartId, prefix+"Titel", OBJPROP_TEXT, titel);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(chartId, prefix+"Titel", OBJPROP_FONTSIZE, 16);
   
   // Symbol Name
   string symbolName = SymbolInfoString(wave.symbol, SYMBOL_DESCRIPTION);
   if(symbolName == "") symbolName = wave.symbol;
   ObjectCreate(chartId, prefix+"SymbolName", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_YDISTANCE, 48);
   ObjectSetString(chartId, prefix+"SymbolName", OBJPROP_TEXT, symbolName);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(chartId, prefix+"SymbolName", OBJPROP_FONTSIZE, 16);
   
   // Hint: Waiting for breakout
   ObjectCreate(chartId, prefix+"WaitText", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"WaitText", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, prefix+"WaitText", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"WaitText", OBJPROP_YDISTANCE, 95);  // V28.2 fix
   ObjectSetString(chartId, prefix+"WaitText", OBJPROP_TEXT, "Waiting for 1-3 line breakout...");
   ObjectSetInteger(chartId, prefix+"WaitText", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(chartId, prefix+"WaitText", OBJPROP_FONTSIZE, 11);
   
   // Copyright - BIGGER with copyright symbol
   ObjectCreate(chartId, prefix+"Copyright", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_YDISTANCE, 35);  // V28.2 fix
   ObjectSetString(chartId, prefix+"Copyright", OBJPROP_TEXT, "© wolfewavesignals.com");
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(chartId, prefix+"Copyright", OBJPROP_FONTSIZE, 14);
   
   // === SCAN TIMESTAMP (Bottom left, above Copyright) ===
   string scanTime = GetFormattedDateTime(TimeCurrent());
   ObjectCreate(chartId, prefix+"ScanTime", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_YDISTANCE, 70);  // V28.2 fix
   ObjectSetString(chartId, prefix+"ScanTime", OBJPROP_TEXT, "Scan: " + scanTime);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(chartId, prefix+"ScanTime", OBJPROP_FONTSIZE, 10);
   
   // === NEU: P5 ZEITPUNKT (Unten links, Ã¼ber Scan-Zeit) ===
   string p5Time = GetFormattedDateTime(wave.p5.time);
   ObjectCreate(chartId, prefix+"P5TimeLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chartId, prefix+"P5TimeLabel", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(chartId, prefix+"P5TimeLabel", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartId, prefix+"P5TimeLabel", OBJPROP_YDISTANCE, 88);  // V28.2 fix
   ObjectSetString(chartId, prefix+"P5TimeLabel", OBJPROP_TEXT, "P5: " + p5Time);
   ObjectSetInteger(chartId, prefix+"P5TimeLabel", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(chartId, prefix+"P5TimeLabel", OBJPROP_FONTSIZE, 10);
   
   // KEINE Entry, SL, TP Linien!
}

//+------------------------------------------------------------------+
// Pending Signal auf Expired setzen
//+------------------------------------------------------------------+
void ExpirePendingSignal(PendingSignal &sig)
{
   string url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + sig.wedgeId;
   
   string json = "{\"status\":\"inactive\"}";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char result[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   int res = WebRequest("PATCH", url, headers, 5000, postData, result, resultHeaders);
   
   if(res == 200 || res == 201 || res == 204)
      Print("[INACTIVE] Signal deaktiviert: ", sig.wedgeId);
   else
      Print("[ERROR] Inactive Update: ", res);
}

//+------------------------------------------------------------------+
// Signal in DB auf Active setzen mit Entry-Daten
//+------------------------------------------------------------------+
void UpdateSignalToActive(ActiveTrade &trade)
{
   double slPct = ((trade.slPrice - trade.entryPrice) / trade.entryPrice) * 100;
   double tp1Pct = ((trade.tp1Price - trade.entryPrice) / trade.entryPrice) * 100;
   double tp2Pct = ((trade.tp2Price - trade.entryPrice) / trade.entryPrice) * 100;
   double tp3Pct = ((trade.tp3Price - trade.entryPrice) / trade.entryPrice) * 100;
   
   // NEU V27.28: R/R basierend auf TP3
   double risk = MathAbs(trade.entryPrice - trade.slPrice);
   double reward = MathAbs(trade.tp3Price - trade.entryPrice);  // TP3!
   double rr = (risk > 0) ? NormalizeDouble(reward / risk, 1) : 0;
   
   string json = "{";
   json += "\"status\":\"active\"";
   json += ",\"entry\":" + DoubleToString(trade.entryPrice, 6);
   json += ",\"entry_time\":\"" + DatetimeToISO(trade.entryTime) + "\"";  // V28.1: ISO Format
   json += ",\"sl\":" + DoubleToString(trade.slPrice, 6);
   json += ",\"tp1\":" + DoubleToString(trade.tp1Price, 6);
   json += ",\"tp2\":" + DoubleToString(trade.tp2Price, 6);
   json += ",\"tp3\":" + DoubleToString(trade.tp3Price, 6);
   json += ",\"sl_pct\":" + DoubleToString(slPct, 2);
   json += ",\"tp1_pct\":" + DoubleToString(tp1Pct, 2);
   json += ",\"tp2_pct\":" + DoubleToString(tp2Pct, 2);
   json += ",\"tp3_pct\":" + DoubleToString(tp3Pct, 2);
   json += ",\"rr\":" + DoubleToString(rr, 2);
   json += ",\"image_path\":\"" + EscapeJSON(trade.imagePath) + "\"";
   json += ",\"tp1_hit\":false";
   json += ",\"tp2_hit\":false";
   json += ",\"tp3_hit\":false";
   json += ",\"sl_hit\":false";
   json += "}";
   
   string url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + trade.wedgeId;
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char result[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   int res = WebRequest("PATCH", url, headers, 5000, postData, result, resultHeaders);
   
   if(res == 200 || res == 201 || res == 204)
      Print("[OK] Signal aktiviert in DB: ", trade.wedgeId);
   else
      Print("[ERROR] DB Update: ", res);
}

//+------------------------------------------------------------------+
// Pending Signal aus Array entfernen
//+------------------------------------------------------------------+
void RemovePendingSignal(int index)
{
   int size = ArraySize(g_pendingSignals);
   for(int j = index; j < size - 1; j++)
      g_pendingSignals[j] = g_pendingSignals[j + 1];
   ArrayResize(g_pendingSignals, size - 1);
}

//+------------------------------------------------------------------+
// Chart Style Setup
//+------------------------------------------------------------------+
void SetupChartStyle(long chartId)
{
   ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(chartId, CHART_SHOW_GRID, false);
   ChartSetInteger(chartId, CHART_AUTOSCROLL, false);
   ChartSetInteger(chartId, CHART_SHIFT, true);
   ChartSetDouble(chartId, CHART_SHIFT_SIZE, 30.0);
   ChartSetInteger(chartId, CHART_SHOW_VOLUMES, CHART_VOLUME_HIDE);
   ChartSetInteger(chartId, CHART_SCALE, 3);
   
   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, clrWhite);
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(chartId, CHART_COLOR_GRID, clrWhite);
   
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, clrWhite);
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP, clrBlack);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, clrBlack);
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, clrBlack);
   
   ChartSetInteger(chartId, CHART_COLOR_CHART_LINE, clrBlack);
   ChartSetInteger(chartId, CHART_COLOR_ASK, clrNONE);
   ChartSetInteger(chartId, CHART_COLOR_BID, clrNONE);
   ChartSetInteger(chartId, CHART_COLOR_LAST, clrNONE);
   ChartSetInteger(chartId, CHART_COLOR_STOP_LEVEL, clrNONE);
   ChartSetInteger(chartId, CHART_SHOW_OHLC, false);
   ChartSetInteger(chartId, CHART_SHOW_ASK_LINE, false);
   ChartSetInteger(chartId, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(chartId, CHART_SHOW_LAST_LINE, false);
   ChartSetInteger(chartId, CHART_SHOW_TRADE_LEVELS, false);
   
   ChartRedraw(chartId);
   Sleep(200);
}

//+------------------------------------------------------------------+
// Lade Pending Signals aus DB
//+------------------------------------------------------------------+
void LoadPendingSignalsFromDB()
{
   Print("Lade pending Signals aus Datenbank...");
   
   string url = InpSupabaseUrl + "/rest/v1/signals?status=eq.pending&select=*";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   
   char result[];
   string resultHeaders;
   uchar empty[];
   
   int res = WebRequest("GET", url, headers, 5000, empty, result, resultHeaders);
   
   if(res == 200)
   {
      string response = CharArrayToString(result);
      ParsePendingSignalsJSON(response);
      Print("[OK] ", ArraySize(g_pendingSignals), " pending Signals geladen");
   }
   else
   {
      Print("[ERROR] Konnte pending Signals nicht laden: ", res);
   }
}

//+------------------------------------------------------------------+
// Lade Active Trades aus DB
//+------------------------------------------------------------------+
void LoadActiveTradesFromDB()
{
   Print("Lade active Trades aus Datenbank...");
   
   string url = InpSupabaseUrl + "/rest/v1/signals?status=eq.active&select=*";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   
   char result[];
   string resultHeaders;
   uchar empty[];
   
   int res = WebRequest("GET", url, headers, 5000, empty, result, resultHeaders);
   
   if(res == 200)
   {
      string response = CharArrayToString(result);
      ParseActiveTradesJSON(response);
      Print("[OK] ", ArraySize(g_activeTrades), " active Trades geladen");
   }
   else
   {
      Print("[ERROR] Konnte active Trades nicht laden: ", res);
   }
}

//+------------------------------------------------------------------+
// Parse Pending Signals JSON
//+------------------------------------------------------------------+
void ParsePendingSignalsJSON(string json)
{
   ArrayResize(g_pendingSignals, 0);
   
   int pos = 0;
   while(true)
   {
      int objStart = StringFind(json, "{", pos);
      if(objStart < 0) break;
      
      int objEnd = StringFind(json, "}", objStart);
      if(objEnd < 0) break;
      
      string obj = StringSubstr(json, objStart, objEnd - objStart + 1);
      
      PendingSignal sig;
      sig.wedgeId = ExtractJSONString(obj, "wedge_id");
      sig.symbol = ExtractJSONString(obj, "symbol");
      sig.market = ExtractJSONString(obj, "market");
      sig.imagePath = ExtractJSONString(obj, "image_path");
      
      string tfStr = ExtractJSONString(obj, "timeframe");
      sig.timeframe = StringToTimeframe(tfStr);
      
      string direction = ExtractJSONString(obj, "direction");
      sig.isBullish = (direction == "BULLISH");
      
      sig.p1.price = ExtractJSONDouble(obj, "p1_price");
      sig.p3.price = ExtractJSONDouble(obj, "p3_price");
      sig.p5.price = ExtractJSONDouble(obj, "p5_price");
      
      // Berechne Linie 1-3 Parameter
      sig.p1.time = StringToTime(ExtractJSONString(obj, "p1_time"));
      sig.p3.time = StringToTime(ExtractJSONString(obj, "p3_time"));
      sig.p5.time = StringToTime(ExtractJSONString(obj, "p5_time"));
      
      if(sig.p3.time != sig.p1.time)
      {
         sig.line13_slope = (sig.p3.price - sig.p1.price) / (double)(sig.p3.time - sig.p1.time);
         sig.line13_intercept = sig.p1.price - sig.line13_slope * (double)sig.p1.time;
      }
      
      // EPA Time
      string epaStr = ExtractJSONString(obj, "epa_time");
      if(epaStr != "") 
      {
         sig.epaTime = StringToTime(epaStr);
      }
      else
      {
         sig.epaTime = 0;  // Explizit auf 0 setzen wenn nicht vorhanden
         if(InpDebugMode) Print("[WARN] Signal ", sig.wedgeId, " hat kein epa_time in DB!");
      }
      
      sig.waitingForBreakout = true;
      
      if(sig.wedgeId != "" && sig.symbol != "")
      {
         int size = ArraySize(g_pendingSignals);
         ArrayResize(g_pendingSignals, size + 1);
         g_pendingSignals[size] = sig;
      }
      
      pos = objEnd + 1;
   }
}

//+------------------------------------------------------------------+
// Parse Active Trades JSON
//+------------------------------------------------------------------+
void ParseActiveTradesJSON(string json)
{
   ArrayResize(g_activeTrades, 0);
   
   int pos = 0;
   while(true)
   {
      int objStart = StringFind(json, "{", pos);
      if(objStart < 0) break;
      
      int objEnd = StringFind(json, "}", objStart);
      if(objEnd < 0) break;
      
      string obj = StringSubstr(json, objStart, objEnd - objStart + 1);
      
      ActiveTrade trade;
      trade.wedgeId = ExtractJSONString(obj, "wedge_id");
      trade.symbol = ExtractJSONString(obj, "symbol");
      trade.market = ExtractJSONString(obj, "market");
      trade.imagePath = ExtractJSONString(obj, "image_path");
      
      string tfStr = ExtractJSONString(obj, "timeframe");
      trade.timeframe = StringToTimeframe(tfStr);
      
      string direction = ExtractJSONString(obj, "direction");
      trade.isBullish = (direction == "BULLISH");
      
      trade.entryPrice = ExtractJSONDouble(obj, "entry");
      trade.slPrice = ExtractJSONDouble(obj, "sl");
      trade.tp1Price = ExtractJSONDouble(obj, "tp1");
      trade.tp2Price = ExtractJSONDouble(obj, "tp2");
      trade.tp3Price = ExtractJSONDouble(obj, "tp3");
      
      string entryTimeStr = ExtractJSONString(obj, "entry_time");
      if(entryTimeStr != "") trade.entryTime = StringToTime(entryTimeStr);
      
      trade.tp1Hit = ExtractJSONBool(obj, "tp1_hit");
      trade.tp2Hit = ExtractJSONBool(obj, "tp2_hit");
      trade.tp3Hit = ExtractJSONBool(obj, "tp3_hit");
      trade.slHit = ExtractJSONBool(obj, "sl_hit");
      trade.barsTracked = 0;
      
      if(trade.wedgeId != "" && trade.symbol != "" && trade.entryPrice > 0)
      {
         int size = ArraySize(g_activeTrades);
         ArrayResize(g_activeTrades, size + 1);
         g_activeTrades[size] = trade;
      }
      
      pos = objEnd + 1;
   }
}

//+------------------------------------------------------------------+
string ExtractJSONString(string json, string key)
{
   string search = "\"" + key + "\":\"";
   int start = StringFind(json, search);
   if(start < 0) return "";
   
   start += StringLen(search);
   int end = StringFind(json, "\"", start);
   if(end < 0) return "";
   
   return StringSubstr(json, start, end - start);
}

//+------------------------------------------------------------------+
double ExtractJSONDouble(string json, string key)
{
   string search = "\"" + key + "\":";
   int start = StringFind(json, search);
   if(start < 0) return 0;
   
   start += StringLen(search);
   
   int end = start;
   while(end < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, end);
      if(ch == ',' || ch == '}' || ch == ' ' || ch == '\n' || ch == '\r')
         break;
      end++;
   }
   
   string numStr = StringSubstr(json, start, end - start);
   return StringToDouble(numStr);
}

//+------------------------------------------------------------------+
bool ExtractJSONBool(string json, string key)
{
   string search = "\"" + key + "\":";
   int start = StringFind(json, search);
   if(start < 0) return false;
   
   start += StringLen(search);
   string value = StringSubstr(json, start, 5);
   return (StringFind(value, "true") >= 0);
}

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES StringToTimeframe(string tf)
{
   if(tf == "M5")  return PERIOD_M5;
   if(tf == "M15") return PERIOD_M15;
   if(tf == "H1")  return PERIOD_H1;
   if(tf == "H4")  return PERIOD_H4;
   if(tf == "D1")  return PERIOD_D1;
   if(tf == "W1")  return PERIOD_W1;
   return PERIOD_H1;
}

//+------------------------------------------------------------------+
string TFToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      default: return EnumToString(tf);
   }
}

//+------------------------------------------------------------------+
// Pruefe Active Trades auf TP/SL
// FIX V27.25: TP3 wird DYNAMISCH auf der gruenen Linie (1-4 Linie) berechnet!
// Die gruene Linie hat eine Steigung - TP3 ist KEIN fester horizontaler Preis!
//+------------------------------------------------------------------+
void CheckActiveTradesForCompletion()
{
   int count = ArraySize(g_activeTrades);
   if(count == 0) return;
   
   for(int i = count - 1; i >= 0; i--)
   {
      ActiveTrade trade = g_activeTrades[i];
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      
      int barsSinceEntry = iBarShift(trade.symbol, trade.timeframe, trade.entryTime, false);
      if(barsSinceEntry < 0) barsSinceEntry = 0;
      
      // Nur Bars seit Entry holen (+2 fuer Sicherheit)
      int barsToCheck = MathMin(barsSinceEntry + 2, InpMaxTrackingBars);
      
      if(CopyRates(trade.symbol, trade.timeframe, 0, barsToCheck, rates) < 2) continue;
      
      trade.barsTracked = barsSinceEntry;
      
      string result = "";
      bool isCompleted = false;
      
      // Zeitpunkte speichern WANN jedes Level erreicht wurde
      datetime tp1Time = 0, tp2Time = 0, tp3Time = 0, slTime = 0;
      
      // === GRUENE LINIE (1-4 Linie) Parameter fuer dynamische TP3-Berechnung ===
      // TP3 ist der Schnittpunkt mit der gruenen Linie, die eine STEIGUNG hat!
      double slope14 = 0;
      double timeDiff14 = (double)(trade.p4.time - trade.p1.time);
      if(timeDiff14 != 0)
      {
         slope14 = (trade.p4.price - trade.p1.price) / timeDiff14;
      }
      
      // DEBUG: Zeige TP/SL Preise
      if(InpDebugMode && barsSinceEntry < 3)
      {
         Print("[TRACK] ", trade.wedgeId, " Entry:", trade.entryPrice, 
               " SL:", trade.slPrice, " TP1:", trade.tp1Price, 
               " TP2:", trade.tp2Price, " TP3(fixed):", trade.tp3Price);
         Print("   Gruene Linie: P1=", trade.p1.price, " P4=", trade.p4.price, " slope=", slope14);
      }
      
      // Von aeltester zu neuester Kerze iterieren
      for(int b = ArraySize(rates) - 1; b >= 0; b--)
      {
         // KRITISCH: NUR Kerzen NACH dem Entry pruefen!
         if(rates[b].time <= trade.entryTime) continue;
         
         double highPrice = rates[b].high;
         double lowPrice = rates[b].low;
         datetime barTime = rates[b].time;
         
         // === DYNAMISCHE TP3 BERECHNUNG ===
         // TP3 ist der aktuelle Preis auf der gruenen Linie zu diesem Zeitpunkt!
         double tp3Dynamic = trade.p1.price + slope14 * (double)(barTime - trade.p1.time);
         
         if(trade.isBullish)
         {
            // BULLISH: Preis soll STEIGEN
            // TPs sind ÃœBER Entry, SL ist UNTER Entry
            if(trade.tp1Price > trade.entryPrice && highPrice >= trade.tp1Price && tp1Time == 0)
               tp1Time = barTime;
            if(trade.tp2Price > trade.entryPrice && highPrice >= trade.tp2Price && tp2Time == 0)
               tp2Time = barTime;
            
            // TP3: Preis muss die gruene Linie von UNTEN nach OBEN durchbrechen
            // tp3Dynamic muss UEBER dem Entry sein (sonst macht es keinen Sinn)
            if(tp3Dynamic > trade.entryPrice && highPrice >= tp3Dynamic && tp3Time == 0)
            {
               tp3Time = barTime;
               if(InpDebugMode) Print("[TP3] BULLISH erreicht @ ", barTime, " | High=", highPrice, " >= GrueneLinie=", tp3Dynamic);
            }
            
            if(trade.slPrice < trade.entryPrice && lowPrice <= trade.slPrice && slTime == 0)
               slTime = barTime;
         }
         else
         {
            // BEARISH: Preis soll FALLEN
            // TPs sind UNTER Entry, SL ist ÃœBER Entry
            if(trade.tp1Price < trade.entryPrice && lowPrice <= trade.tp1Price && tp1Time == 0)
               tp1Time = barTime;
            if(trade.tp2Price < trade.entryPrice && lowPrice <= trade.tp2Price && tp2Time == 0)
               tp2Time = barTime;
            
            // TP3: Preis muss die gruene Linie von OBEN nach UNTEN durchbrechen
            // tp3Dynamic muss UNTER dem Entry sein (sonst macht es keinen Sinn)
            if(tp3Dynamic < trade.entryPrice && lowPrice <= tp3Dynamic && tp3Time == 0)
            {
               tp3Time = barTime;
               if(InpDebugMode) Print("[TP3] BEARISH erreicht @ ", barTime, " | Low=", lowPrice, " <= GrueneLinie=", tp3Dynamic);
            }
            
            if(trade.slPrice > trade.entryPrice && highPrice >= trade.slPrice && slTime == 0)
               slTime = barTime;
         }
      }
      
      // NEU: Flags setzen basierend auf Zeitpunkten
      trade.tp1Hit = (tp1Time > 0);
      trade.tp2Hit = (tp2Time > 0);
      trade.tp3Hit = (tp3Time > 0);
      trade.slHit = (slTime > 0);
      
      // NEU: REIHENFOLGE pruefen - was kam ZUERST?
      // TP3 hat Prioritaet - wenn TP3 erreicht = ERFOLG (egal ob SL danach)
      if(trade.tp3Hit)
      {
         // TP3 erreicht - aber nur als Erfolg wenn es VOR dem SL war oder SL nie erreicht
         if(slTime == 0 || tp3Time <= slTime)
         {
            result = "TP3_HIT";
            isCompleted = true;
            Print("*** ", trade.symbol, " TP3 erreicht @ ", TimeToString(tp3Time), " ***");
         }
         else
         {
            // SL war VORHER - pruefen ob TP1/TP2 vorher war
            if(tp2Time > 0 && tp2Time < slTime)
            {
               result = "TP2_HIT";  // V28.3: Spezifisches Result
               isCompleted = true;
               Print("*** ", trade.symbol, " TP2 erreicht @ ", TimeToString(tp2Time), " (SL danach) ***");
            }
            else if(tp1Time > 0 && tp1Time < slTime)
            {
               result = "TP1_HIT";  // V28.3: Spezifisches Result
               isCompleted = true;
               Print("*** ", trade.symbol, " TP1 erreicht @ ", TimeToString(tp1Time), " (SL danach) ***");
            }
            else
            {
               result = "SL_HIT";
               isCompleted = true;
               Print("[TRACK] ", trade.symbol, " SL @ ", TimeToString(slTime));
            }
         }
      }
      else if(trade.slHit)
      {
         // SL erreicht aber kein TP3 - pruefen ob TP1/TP2 VORHER war
         if(tp2Time > 0 && tp2Time < slTime)
         {
            result = "TP2_HIT";  // V28.3: Spezifisches Result
            isCompleted = true;
            Print("*** ", trade.symbol, " TP2 erreicht @ ", TimeToString(tp2Time), " (SL danach) ***");
         }
         else if(tp1Time > 0 && tp1Time < slTime)
         {
            result = "TP1_HIT";  // V28.3: Spezifisches Result
            isCompleted = true;
            Print("*** ", trade.symbol, " TP1 erreicht @ ", TimeToString(tp1Time), " (SL danach) ***");
         }
         else
         {
            result = "SL_HIT";
            isCompleted = true;
            Print("[TRACK] ", trade.symbol, " SL @ ", TimeToString(slTime));
         }
      }
      else if(trade.barsTracked >= InpMaxTrackingBars)
      {
         // Timeout - kein TP3 und kein SL
         if(trade.tp2Hit)
            result = "TP2_HIT";  // V28.3: Spezifisches Result
         else if(trade.tp1Hit)
            result = "TP1_HIT";  // V28.3: Spezifisches Result
         else
            result = "EXPIRED";
         isCompleted = true;
         Print("[TRACK] ", trade.symbol, " TIMEOUT nach ", trade.barsTracked, " Bars - Result: ", result);
      }
      
      // NEU: Debug-Log fuer Validierung
      if(InpDebugMode && (trade.tp1Hit || trade.tp2Hit || trade.slHit))
      {
         Print("[DEBUG] ", trade.symbol, 
               " TP1:", (tp1Time > 0 ? TimeToString(tp1Time, TIME_MINUTES) : "-"),
               " TP2:", (tp2Time > 0 ? TimeToString(tp2Time, TIME_MINUTES) : "-"),
               " TP3:", (tp3Time > 0 ? TimeToString(tp3Time, TIME_MINUTES) : "-"),
               " SL:", (slTime > 0 ? TimeToString(slTime, TIME_MINUTES) : "-"));
      }
      
      // Nur TP Status updaten wenn noch nicht completed
      if(!isCompleted)
      {
         if(trade.tp1Hit) UpdateTradeStatus(trade.wedgeId, "tp1_hit", true);
         if(trade.tp2Hit) UpdateTradeStatus(trade.wedgeId, "tp2_hit", true);
      }
      
      if(isCompleted)
      {
         CompleteTradeWithResult(trade, result);
         
         for(int j = i; j < ArraySize(g_activeTrades) - 1; j++)
            g_activeTrades[j] = g_activeTrades[j + 1];
         ArrayResize(g_activeTrades, ArraySize(g_activeTrades) - 1);
      }
      else
      {
         g_activeTrades[i] = trade;
      }
   }
}

//+------------------------------------------------------------------+
void CompleteTradeWithResult(ActiveTrade &trade, string result)
{
   Print("");
   Print("========================================");
   Print("TRADE ABGESCHLOSSEN: ", trade.wedgeId);
   Print("Symbol: ", trade.symbol, " | Result: ", result);
   Print("========================================");
   
   // V28.3: TP1, TP2, TP3 zählen ALLE als Erfolg!
   // Erfolg = mindestens ein TP erreicht (egal ob danach SL)
   bool isTP3 = (result == "TP3_HIT");
   bool isTP2 = (result == "TP2_HIT" || (trade.tp2Hit && !trade.tp3Hit));
   bool isTP1 = (result == "TP1_HIT" || (trade.tp1Hit && !trade.tp2Hit && !trade.tp3Hit));
   bool isSuccess = (isTP3 || isTP2 || isTP1 || result == "PARTIAL_SUCCESS");
   bool isExpired = (result == "EXPIRED" && !trade.tp1Hit);  // Expired ohne TP = kein Erfolg
   bool isFailed = (result == "SL_HIT" && !trade.tp1Hit && !trade.tp2Hit && !trade.tp3Hit);
   
   if(isSuccess)
      g_successCount++;
   else if(isExpired)
      g_expiredCount++;
   else
      g_failedCount++;
   
   // Status für Datenbank
   string status = "";
   if(isTP3) 
      status = "success_tp3";
   else if(isTP2 || (trade.tp2Hit && result != "TP3_HIT")) 
      status = "success_tp2";
   else if(isTP1 || trade.tp1Hit) 
      status = "success_tp1";
   else if(result == "SL_HIT") 
      status = "failed_sl";
   else if(result == "EXPIRED") 
      status = "failed_expired";
   else
      status = "failed";
   
   UpdateTradeStatusFinal(trade.wedgeId, status, result, 
                          trade.tp1Hit, trade.tp2Hit, trade.tp3Hit, trade.slHit);
   
   // V28.3: result_folder = "success" für ALLE TP-Treffer
   string targetFolder;
   if(isSuccess)
      targetFolder = "success";
   else if(isExpired)
      targetFolder = "expired";
   else
      targetFolder = "failed";
   
   CopyImageToResultFolder(trade, targetFolder, result);
}

//+------------------------------------------------------------------+
void UpdateTradeStatus(string wedgeId, string field, bool value)
{
   string json = "{\"" + field + "\":" + (value ? "true" : "false") + "}";
   
   string url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + wedgeId;
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char result[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   WebRequest("PATCH", url, headers, 5000, postData, result, resultHeaders);
}

//+------------------------------------------------------------------+
void UpdateTradeStatusFinal(string wedgeId, string status, string result,
                            bool tp1, bool tp2, bool tp3, bool sl)
{
   string json = "{";
   json += "\"status\":\"" + status + "\"";
   json += ",\"result\":\"" + result + "\"";
   json += ",\"tp1_hit\":" + (tp1 ? "true" : "false");
   json += ",\"tp2_hit\":" + (tp2 ? "true" : "false");
   json += ",\"tp3_hit\":" + (tp3 ? "true" : "false");
   json += ",\"sl_hit\":" + (sl ? "true" : "false");
   json += ",\"completed_at\":\"" + GetISODateTimeUTC() + "\"";  // V28.1: UTC ISO Format
   json += "}";
   
   string url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + wedgeId;
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char resultData[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   int res = WebRequest("PATCH", url, headers, 5000, postData, resultData, resultHeaders);
   
   if(res == 200 || res == 201 || res == 204)
      Print("[OK] Status aktualisiert: ", wedgeId, " -> ", status);
   else
      Print("[ERROR] Status Update: ", res);
}

//+------------------------------------------------------------------+
void CopyImageToResultFolder(ActiveTrade &trade, string folder, string result)
{
   string tfStr = TFToString(trade.timeframe);
   
   string json = "{";
   json += "\"wedge_id\":\"" + trade.wedgeId + "\"";
   json += ",\"original_path\":\"" + EscapeJSON(trade.imagePath) + "\"";
   json += ",\"result_folder\":\"" + folder + "\"";
   json += ",\"result\":\"" + result + "\"";
   json += ",\"symbol\":\"" + EscapeJSON(trade.symbol) + "\"";
   json += ",\"market\":\"" + trade.market + "\"";
   json += ",\"timeframe\":\"" + tfStr + "\"";
   json += ",\"direction\":\"" + (trade.isBullish ? "BULLISH" : "BEARISH") + "\"";
   json += ",\"tp1_hit\":" + (trade.tp1Hit ? "true" : "false");
   json += ",\"tp2_hit\":" + (trade.tp2Hit ? "true" : "false");
   json += ",\"tp3_hit\":" + (trade.tp3Hit ? "true" : "false");
   json += ",\"sl_hit\":" + (trade.slHit ? "true" : "false");
   json += "}";
   
   string url = InpSupabaseUrl + "/rest/v1/completed_signals";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char resultData[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   int res = WebRequest("POST", url, headers, 5000, postData, resultData, resultHeaders);
   
   if(res == 200 || res == 201 || res == 204)
      Print("[OK] Completed Signal: ", folder, "/", trade.wedgeId);
   else
      Print("[ERROR] Completed Signal: ", res);
}

//+------------------------------------------------------------------+
string GetMarket(string symbol)
{
   // 1. INDICES: Symbole mit .c am Ende (Cash Indizes)
   if(StringFind(symbol, ".c") >= 0 || StringFind(symbol, "_c") >= 0)
   {
      // Spezifische Index-Erkennung
      if(StringFind(symbol, "DE40") >= 0 || StringFind(symbol, "GER40") >= 0 || StringFind(symbol, "DAX") >= 0)
         return "DAX";
      if(StringFind(symbol, "USTEC") >= 0 || StringFind(symbol, "US100") >= 0 || StringFind(symbol, "NAS100") >= 0)
         return "NASDAQ";
      // Alle anderen .c Indizes
      return "INDICES";
   }
   
   // 2. CRYPTO
   if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0 ||
      StringFind(symbol, "XRP") >= 0 || StringFind(symbol, "SOL") >= 0 ||
      StringFind(symbol, "ADA") >= 0 || StringFind(symbol, "DOGE") >= 0 ||
      StringFind(symbol, "BCH") >= 0 || StringFind(symbol, "LTC") >= 0 ||
      StringFind(symbol, "#") == 0)  // #Bitcoin, #Ethereum etc.
      return "CRYPTO";
   
   // 3. DAX (Deutsche Aktien mit .DE)
   if(StringFind(symbol, ".DE") >= 0)
      return "DAX";
   
   // 4. NASDAQ (Symbole mit .OQ)
   if(StringFind(symbol, ".OQ") >= 0)
      return "NASDAQ";
   
   // 5. NYSE (Symbole mit .N)
   if(StringFind(symbol, ".N") >= 0)
      return "NYSE";
   
   // 6. SP500 / US Aktien (typische US-Symbole ohne spezifische Endung)
   // Aktien haben meist 1-5 Buchstaben
   int len = StringLen(symbol);
   if(len >= 1 && len <= 5)
   {
      // Pruefen ob nur Grossbuchstaben (typisch fuer US-Aktien)
      bool isUSStock = true;
      for(int i = 0; i < len; i++)
      {
         ushort ch = StringGetCharacter(symbol, i);
         if(ch < 'A' || ch > 'Z')
         {
            isUSStock = false;
            break;
         }
      }
      if(isUSStock) return "SP500";
   }
   
   // 7. FOREX
   if(StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 ||
      StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0 ||
      StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "AUD") >= 0 ||
      StringFind(symbol, "NZD") >= 0 || StringFind(symbol, "CAD") >= 0)
   {
      if(len <= 7) return "FOREX";
   }
   
   return "OTHER";
}

//+------------------------------------------------------------------+
string GetPatternKey(WolfeWave &wave)
{
   return wave.symbol + "_" + TFToString(wave.timeframe) + "_" + 
          IntegerToString((long)wave.p1.time) + "_" +
          IntegerToString((long)wave.p4.time);
}

//+------------------------------------------------------------------+
bool IsPatternDuplicate(WolfeWave &wave)
{
   string key = GetPatternKey(wave);
   for(int i = 0; i < ArraySize(g_foundPatterns); i++)
      if(g_foundPatterns[i] == key) return true;
   return false;
}

//+------------------------------------------------------------------+
void AddPatternToHistory(WolfeWave &wave)
{
   string key = GetPatternKey(wave);
   int size = ArraySize(g_foundPatterns);
   
   if(size >= g_maxStoredPatterns)
   {
      for(int i = 0; i < size - 100; i++)
         g_foundPatterns[i] = g_foundPatterns[i + 100];
      ArrayResize(g_foundPatterns, size - 100);
      size = ArraySize(g_foundPatterns);
   }
   
   ArrayResize(g_foundPatterns, size + 1);
   g_foundPatterns[size] = key;
}

//+------------------------------------------------------------------+
string EscapeJSON(string text)
{
   string result = text;
   StringReplace(result, "\\", "\\\\");
   StringReplace(result, "\"", "\\\"");
   StringReplace(result, "\n", "\\n");
   StringReplace(result, "\r", "\\r");
   StringReplace(result, "\t", "\\t");
   return result;
}

//+------------------------------------------------------------------+
void PerformScan()
{
   Print("");
   Print("========== SCAN START ==========");
   g_lastScanTime = TimeCurrent();
   
   ENUM_TIMEFRAMES timeframes[];
   int tfCount = 0;
   
   if(InpScanM5)  { ArrayResize(timeframes, tfCount+1); timeframes[tfCount++] = PERIOD_M5; }
   if(InpScanM15) { ArrayResize(timeframes, tfCount+1); timeframes[tfCount++] = PERIOD_M15; }
   if(InpScanH1)  { ArrayResize(timeframes, tfCount+1); timeframes[tfCount++] = PERIOD_H1; }
   if(InpScanH4)  { ArrayResize(timeframes, tfCount+1); timeframes[tfCount++] = PERIOD_H4; }
   if(InpScanD1)  { ArrayResize(timeframes, tfCount+1); timeframes[tfCount++] = PERIOD_D1; }
   if(InpScanW1)  { ArrayResize(timeframes, tfCount+1); timeframes[tfCount++] = PERIOD_W1; }
   
   if(tfCount == 0) { Print("Kein Timeframe!"); return; }
   
   int totalSymbols = SymbolsTotal(true);
   int toScan = (InpMaxSymbols > 0) ? MathMin(InpMaxSymbols, totalSymbols) : totalSymbols;
   
   Print("Scanne ", toScan, " Symbole x ", tfCount, " TFs...");
   
   int foundThisScan = 0;
   
   for(int s = 0; s < toScan; s++)
   {
      string symbol = SymbolName(s, true);
      if(!SymbolInfoInteger(symbol, SYMBOL_VISIBLE)) continue;
      
      for(int t = 0; t < tfCount; t++)
      {
         WolfeWave wave;
         if(ScanSymbol(symbol, timeframes[t], wave))
         {
            bool isUpdate = IsPatternDuplicate(wave);
            
            if(!isUpdate)
            {
               AddPatternToHistory(wave);
               g_patternsFound++;
            }
            
            foundThisScan++;
            
            Print("");
            Print(isUpdate ? "UPDATE" : "*** NEU ***");
            Print(wave.symbol, " ", TFToString(wave.timeframe), " ", wave.isBullish ? "BULL" : "BEAR");
            
            // NEU: ProcessAndUpload erstellt jetzt PENDING Signal
            ProcessAndUploadPending(wave, isUpdate);
         }
      }
      
      Sleep(50);
      if(s > 0 && s % 25 == 0) Print("... ", s, "/", toScan);
   }
   
   Print("");
   Print("========== SCAN ENDE ==========");
   Print("Gefunden: ", foundThisScan, " | Gesamt: ", g_patternsFound);
   Print("Pending: ", ArraySize(g_pendingSignals), " | Active: ", ArraySize(g_activeTrades));
}

//+------------------------------------------------------------------+
bool ScanSymbol(string symbol, ENUM_TIMEFRAMES tf, WolfeWave &wave)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(symbol, tf, 0, InpScanBars, rates);
   if(copied < 50) return false;
   
   ZZPoint zzPoints[];
   CalculateZigZag(rates, copied, zzPoints);
   
   if(ArraySize(zzPoints) < 5) return false;
   
   wave.symbol = symbol;
   wave.timeframe = tf;
   
   return FindWolfeWave(zzPoints, rates, wave);
}

//+------------------------------------------------------------------+
void CalculateZigZag(MqlRates &rates[], int count, ZZPoint &zzPoints[])
{
   ArrayResize(zzPoints, 0);
   
   double zigzag[];
   int direction[];
   ArrayResize(zigzag, count);
   ArrayResize(direction, count);
   ArrayInitialize(zigzag, 0);
   ArrayInitialize(direction, 0);
   
   double lastHigh = 0, lastLow = 0;
   int lastHighBar = -1, lastLowBar = -1;
   int trend = 0;
   
   for(int i = count - InpZZDepth - 1; i >= 0; i--)
   {
      int highestBar = i;
      double highestVal = rates[i].high;
      for(int j = 1; j < InpZZDepth && i + j < count; j++)
      {
         if(rates[i + j].high > highestVal)
         {
            highestVal = rates[i + j].high;
            highestBar = i + j;
         }
      }
      
      int lowestBar = i;
      double lowestVal = rates[i].low;
      for(int j = 1; j < InpZZDepth && i + j < count; j++)
      {
         if(rates[i + j].low < lowestVal)
         {
            lowestVal = rates[i + j].low;
            lowestBar = i + j;
         }
      }
      
      if(highestBar == i)
      {
         if(trend != 1)
         {
            trend = 1;
            lastHigh = rates[i].high;
            lastHighBar = i;
            zigzag[i] = rates[i].high;
            direction[i] = 1;
         }
         else if(rates[i].high > lastHigh)
         {
            if(lastHighBar >= 0) zigzag[lastHighBar] = 0;
            lastHigh = rates[i].high;
            lastHighBar = i;
            zigzag[i] = rates[i].high;
            direction[i] = 1;
         }
      }
      
      if(lowestBar == i)
      {
         if(trend != -1)
         {
            trend = -1;
            lastLow = rates[i].low;
            lastLowBar = i;
            zigzag[i] = rates[i].low;
            direction[i] = -1;
         }
         else if(rates[i].low < lastLow)
         {
            if(lastLowBar >= 0) zigzag[lastLowBar] = 0;
            lastLow = rates[i].low;
            lastLowBar = i;
            zigzag[i] = rates[i].low;
            direction[i] = -1;
         }
      }
   }
   
   for(int i = 0; i < count; i++)
   {
      if(zigzag[i] != 0)
      {
         ZZPoint point;
         point.bar = i;
         point.price = zigzag[i];
         point.time = rates[i].time;
         point.isHigh = (direction[i] > 0);
         
         int size = ArraySize(zzPoints);
         ArrayResize(zzPoints, size + 1);
         zzPoints[size] = point;
         
         if(size >= 12) break;
      }
   }
}

//+------------------------------------------------------------------+
bool FindWolfeWave(ZZPoint &zzPoints[], MqlRates &rates[], WolfeWave &wave)
{
   int count = ArraySize(zzPoints);
   
   for(int start = 0; start <= count - 5; start++)
   {
      ZZPoint pts[5];
      for(int i = 0; i < 5; i++)
         pts[i] = zzPoints[start + i];
      
      if(pts[4].bar - pts[0].bar > InpMaxBarsPattern) continue;
      
      int bars54 = pts[1].bar - pts[0].bar;
      int bars43 = pts[2].bar - pts[1].bar;
      int bars32 = pts[3].bar - pts[2].bar;
      int bars21 = pts[4].bar - pts[3].bar;
      
      if(bars54 < InpMinBarsBetween || bars43 < InpMinBarsBetween ||
         bars32 < InpMinBarsBetween || bars21 < InpMinBarsBetween)
         continue;
      
      if(!pts[0].isHigh && pts[1].isHigh && !pts[2].isHigh && 
          pts[3].isHigh && !pts[4].isHigh)
      {
         if(ValidateBullish(pts, rates, wave)) return true;
      }
      
      if(pts[0].isHigh && !pts[1].isHigh && pts[2].isHigh && 
         !pts[3].isHigh && pts[4].isHigh)
      {
         if(ValidateBearish(pts, rates, wave)) return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
bool ValidateBullish(ZZPoint &pts[], MqlRates &rates[], WolfeWave &wave)
{
   if(pts[0].bar > InpMaxBarsP5) return false;
   if(pts[0].bar < 1) return false;
   
   double p1 = pts[4].price, p2 = pts[3].price, p3 = pts[2].price;
   double p4 = pts[1].price, p5 = pts[0].price;
   datetime t1 = pts[4].time, t2 = pts[3].time, t3 = pts[2].time;
   datetime t4 = pts[1].time, t5 = pts[0].time;
   
   if(p3 >= p1) return false;
   if(p4 >= p2) return false;
   if(p4 <= p1 || p4 <= p3) return false;
   if(p2 <= p1 || p2 <= p3 || p4 <= p3 || p4 <= p5) return false;
   
   double patternHeight = MathAbs(p2 - p3);
   if(patternHeight < 0.0001) return false;
   
   // V28.4: Reject patterns where a single candle is too large (> 75% of pattern height)
   // This filters out charts with extreme outlier candles that dominate the view
   int barStart = pts[4].bar;  // P1 bar
   int barEnd = pts[0].bar;    // P5 bar
   for(int b = barEnd; b <= barStart && b < ArraySize(rates); b++)
   {
      double candleSize = MathAbs(rates[b].high - rates[b].low);
      double candlePct = (candleSize / patternHeight) * 100.0;
      if(candlePct > InpMaxCandleSizePct)
      {
         if(InpDebugMode) Print("REJECT: Single candle too large: ", DoubleToString(candlePct, 1), "% > ", DoubleToString(InpMaxCandleSizePct, 1), "% of pattern height");
         return false;
      }
   }
   
   // NEW: Reject patterns where height is too small relative to price (invisible wedges)
   double avgPrice = (p1 + p2 + p3 + p4 + p5) / 5.0;
   double heightPct = (patternHeight / avgPrice) * 100.0;
   if(heightPct < InpMinPatternHeightPct)
   {
      if(InpDebugMode) Print("REJECT: Pattern height too small: ", DoubleToString(heightPct, 2), "% < ", DoubleToString(InpMinPatternHeightPct, 2), "%");
      return false;
   }
   
   double slope13 = (p3 - p1) / (double)(t3 - t1);
   double slope24 = (p4 - p2) / (double)(t4 - t2);
   
   // NEW: Check convergence angle - reject if lines are too parallel
   double angle13 = MathArctan(slope13 * 86400) * 180.0 / M_PI;  // Convert to degrees (approx per day)
   double angle24 = MathArctan(slope24 * 86400) * 180.0 / M_PI;
   double convergenceAngle = MathAbs(angle13 - angle24);
   if(convergenceAngle < InpMinConvergenceAngle)
   {
      if(InpDebugMode) Print("REJECT: Convergence angle too small: ", DoubleToString(convergenceAngle, 2), "° < ", DoubleToString(InpMinConvergenceAngle, 2), "°");
      return false;
   }
   
   double b13 = p1 - slope13 * (double)t1;
   double b24 = p2 - slope24 * (double)t2;
   double slopeDiff = slope13 - slope24;
   
   if(MathAbs(slopeDiff) < 0.0000000001) return false;
   
   double tCross = (b24 - b13) / slopeDiff;
   datetime crossTime = (datetime)tCross;
   
   // FIX 2: Kreuzung muss in der ZUKUNFT sein (nach aktueller Zeit)
   datetime currentTime = TimeCurrent();
   if(crossTime <= currentTime) 
   {
      if(InpDebugMode) Print("REJECT: Kreuzung in Vergangenheit: ", TimeToString(crossTime));
      return false;
   }
   
   // FIX 1: Wenn EPA + 3 Kerzen bereits ueberschritten -> nicht erkennen
   if(currentTime > crossTime)
   {
      int barsAfterEPA = pts[0].bar;  // Bars seit P5
      int periodSec = PeriodSeconds(wave.timeframe);
      int estimatedBarsAfterCross = (int)((currentTime - crossTime) / periodSec);
      if(estimatedBarsAfterCross >= InpBarsAfterEPA)
      {
         if(InpDebugMode) Print("REJECT: EPA + ", estimatedBarsAfterCross, " Kerzen ueberschritten");
         return false;
      }
   }
   
   if(crossTime <= t5) return false;
   
   // V28.4: EPA darf max 1.5x Pattern-Dauer in der Zukunft liegen (sonst nicht sichtbar auf Chart)
   int patternDuration = (int)(t5 - t1);
   if(crossTime > t5 + (int)(patternDuration * InpMaxEPADistanceMult))
   {
      if(InpDebugMode) Print("REJECT: EPA too far in future: ", DoubleToString((double)(crossTime - t5) / patternDuration, 1), "x pattern duration");
      return false;
   }
   
   double pCross = slope13 * tCross + b13;
   if(pCross <= p5) return false;
   
   wave.p1 = pts[4]; wave.p2 = pts[3]; wave.p3 = pts[2];
   wave.p4 = pts[1]; wave.p5 = pts[0];
   wave.isBullish = true;
   wave.epaTime = crossTime;
   wave.epaPrice = pCross;
   wave.line13_slope = slope13;
   wave.line13_intercept = b13;
   
   if(InpDebugMode) 
   {
      Print("BULLISH Keil gefunden - EPA: ", TimeToString(crossTime), " (in Zukunft)");
   }
   
   return true;
}

//+------------------------------------------------------------------+
bool ValidateBearish(ZZPoint &pts[], MqlRates &rates[], WolfeWave &wave)
{
   if(pts[0].bar > InpMaxBarsP5) return false;
   if(pts[0].bar < 1) return false;
   
   double p1 = pts[4].price, p2 = pts[3].price, p3 = pts[2].price;
   double p4 = pts[1].price, p5 = pts[0].price;
   datetime t1 = pts[4].time, t2 = pts[3].time, t3 = pts[2].time;
   datetime t4 = pts[1].time, t5 = pts[0].time;
   
   if(p3 <= p1) return false;
   if(p4 <= p2) return false;
   if(p4 >= p1 || p4 >= p3) return false;
   if(p1 <= p2 || p3 <= p2 || p3 <= p4 || p5 <= p4) return false;
   
   double patternHeight = MathAbs(p3 - p2);
   if(patternHeight < 0.0001) return false;
   
   // V28.4: Reject patterns where a single candle is too large (> 75% of pattern height)
   // This filters out charts with extreme outlier candles that dominate the view
   int barStart = pts[4].bar;  // P1 bar
   int barEnd = pts[0].bar;    // P5 bar
   for(int b = barEnd; b <= barStart && b < ArraySize(rates); b++)
   {
      double candleSize = MathAbs(rates[b].high - rates[b].low);
      double candlePct = (candleSize / patternHeight) * 100.0;
      if(candlePct > InpMaxCandleSizePct)
      {
         if(InpDebugMode) Print("REJECT: Single candle too large: ", DoubleToString(candlePct, 1), "% > ", DoubleToString(InpMaxCandleSizePct, 1), "% of pattern height");
         return false;
      }
   }
   
   // NEW: Reject patterns where height is too small relative to price (invisible wedges)
   double avgPrice = (p1 + p2 + p3 + p4 + p5) / 5.0;
   double heightPct = (patternHeight / avgPrice) * 100.0;
   if(heightPct < InpMinPatternHeightPct)
   {
      if(InpDebugMode) Print("REJECT: Pattern height too small: ", DoubleToString(heightPct, 2), "% < ", DoubleToString(InpMinPatternHeightPct, 2), "%");
      return false;
   }
   
   double slope13 = (p3 - p1) / (double)(t3 - t1);
   double slope24 = (p4 - p2) / (double)(t4 - t2);
   
   // NEW: Check convergence angle - reject if lines are too parallel
   double angle13 = MathArctan(slope13 * 86400) * 180.0 / M_PI;  // Convert to degrees (approx per day)
   double angle24 = MathArctan(slope24 * 86400) * 180.0 / M_PI;
   double convergenceAngle = MathAbs(angle13 - angle24);
   if(convergenceAngle < InpMinConvergenceAngle)
   {
      if(InpDebugMode) Print("REJECT: Convergence angle too small: ", DoubleToString(convergenceAngle, 2), "° < ", DoubleToString(InpMinConvergenceAngle, 2), "°");
      return false;
   }
   
   double b13 = p1 - slope13 * (double)t1;
   double b24 = p2 - slope24 * (double)t2;
   double slopeDiff = slope13 - slope24;
   
   if(MathAbs(slopeDiff) < 0.0000000001) return false;
   
   double tCross = (b24 - b13) / slopeDiff;
   datetime crossTime = (datetime)tCross;
   
   // FIX 2: Kreuzung muss in der ZUKUNFT sein (nach aktueller Zeit)
   datetime currentTime = TimeCurrent();
   if(crossTime <= currentTime) 
   {
      if(InpDebugMode) Print("REJECT: Kreuzung in Vergangenheit: ", TimeToString(crossTime));
      return false;
   }
   
   // FIX 1: Wenn EPA + 3 Kerzen bereits ueberschritten -> nicht erkennen
   if(currentTime > crossTime)
   {
      int periodSec = PeriodSeconds(wave.timeframe);
      int estimatedBarsAfterCross = (int)((currentTime - crossTime) / periodSec);
      if(estimatedBarsAfterCross >= InpBarsAfterEPA)
      {
         if(InpDebugMode) Print("REJECT: EPA + ", estimatedBarsAfterCross, " Kerzen ueberschritten");
         return false;
      }
   }
   
   if(crossTime <= t5) return false;
   
   // V28.4: EPA darf max 1.5x Pattern-Dauer in der Zukunft liegen (sonst nicht sichtbar auf Chart)
   int patternDuration = (int)(t5 - t1);
   if(crossTime > t5 + (int)(patternDuration * InpMaxEPADistanceMult))
   {
      if(InpDebugMode) Print("REJECT: EPA too far in future: ", DoubleToString((double)(crossTime - t5) / patternDuration, 1), "x pattern duration");
      return false;
   }
   
   double pCross = slope13 * tCross + b13;
   if(pCross >= p5) return false;
   
   wave.p1 = pts[4]; wave.p2 = pts[3]; wave.p3 = pts[2];
   wave.p4 = pts[1]; wave.p5 = pts[0];
   wave.isBullish = false;
   wave.epaTime = crossTime;
   wave.epaPrice = pCross;
   wave.line13_slope = slope13;
   wave.line13_intercept = b13;
   
   if(InpDebugMode) 
   {
      Print("BEARISH Keil gefunden - EPA: ", TimeToString(crossTime), " (in Zukunft)");
   }
   
   return true;
}

//+------------------------------------------------------------------+
// NEU: Verarbeite Keil - pruefe ob Durchbruch bereits passiert ist
//+------------------------------------------------------------------+
void ProcessAndUploadPending(WolfeWave &wave, bool isUpdate)
{
   string symbolClean = wave.symbol;
   StringReplace(symbolClean, ".", "");
   StringReplace(symbolClean, "/", "");
   
   MqlDateTime dtP4;
   TimeToStruct(wave.p4.time, dtP4);
   
   string market = GetMarket(wave.symbol);
   string tfStr = TFToString(wave.timeframe);
   string typeStr = wave.isBullish ? "BULL" : "BEAR";
   
   string p4DateStr = StringFormat("%04d%02d%02d_%02d%02d", 
                       dtP4.year, dtP4.mon, dtP4.day, dtP4.hour, dtP4.min);
   string wedgeId = typeStr + "_" + symbolClean + "_" + p4DateStr;
   
   // === V28.4 FIX: Verhindere Downgrade von ACTIVE -> PENDING ===
   // Bei Updates: Wenn Signal bereits ACTIVE ist, nicht als PENDING verarbeiten!
   if(isUpdate && IsSignalAlreadyActive(wedgeId))
   {
      Print("[SKIP] Signal ", wedgeId, " ist bereits ACTIVE - kein Downgrade zu PENDING!");
      // Optional: Bild-Update für ACTIVE Signal (falls nötig)
      return;
   }
   
   // === PRUEFE OB DURCHBRUCH BEREITS PASSIERT IST ===
   double breakoutPrice = 0;
   datetime breakoutTime = 0;
   bool hasBreakout = CheckForHistoricalBreakout(wave, breakoutPrice, breakoutTime);
   
   if(hasBreakout)
   {
      Print("*** HISTORISCHER DURCHBRUCH GEFUNDEN! ***");
      Print("    Entry: ", breakoutPrice, " @ ", TimeToString(breakoutTime));
      
      // Sofort als ACTIVE behandeln
      ProcessAsActiveSignal(wave, wedgeId, market, breakoutPrice, breakoutTime, isUpdate);
   }
   else
   {
      // Kein Durchbruch - als PENDING speichern
      Print("[PENDING] Warte auf Durchbruch: ", wedgeId);
      ProcessAsPendingSignal(wave, wedgeId, market, isUpdate);
   }
}

//+------------------------------------------------------------------+
// Pruefe ob es bereits einen Durchbruch nach P5 gab
// SOFORT bei Durchbruch (High/Low), Entry = Linienpreis
//+------------------------------------------------------------------+
bool CheckForHistoricalBreakout(WolfeWave &wave, double &outPrice, datetime &outTime)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Hole alle Kerzen seit P5
   int barsSinceP5 = iBarShift(wave.symbol, wave.timeframe, wave.p5.time, false);
   
   if(InpDebugMode)
   {
      Print("[BREAKOUT CHECK] ", wave.symbol, " ", TFToString(wave.timeframe));
      Print("   P1: ", wave.p1.price, " @ ", TimeToString(wave.p1.time));
      Print("   P3: ", wave.p3.price, " @ ", TimeToString(wave.p3.time));
      Print("   P5: ", wave.p5.price, " @ ", TimeToString(wave.p5.time));
      Print("   Bars since P5: ", barsSinceP5);
   }
   
   if(barsSinceP5 < 1) 
   {
      if(InpDebugMode) Print("   -> Keine Kerzen nach P5");
      return false;
   }
   
   // Hole mehr Kerzen fuer sicheren Vergleich
   int barsToGet = barsSinceP5 + 10;
   if(CopyRates(wave.symbol, wave.timeframe, 0, barsToGet, rates) < barsSinceP5) 
   {
      if(InpDebugMode) Print("   -> CopyRates fehlgeschlagen");
      return false;
   }
   
   // Linien-Parameter fuer Two-Point-Form
   double p1_price = wave.p1.price;
   double p3_price = wave.p3.price;
   datetime t1 = wave.p1.time;
   datetime t3 = wave.p3.time;
   double timeDiff13 = (double)(t3 - t1);
   
   if(timeDiff13 == 0)
   {
      if(InpDebugMode) Print("   -> t3 == t1, kann Linie nicht berechnen");
      return false;
   }
   
   // Iteriere von der aeltesten Kerze nach P5 bis zur neuesten
   // Auch aktuelle Kerze (Index 0) pruefen fuer sofortigen Entry!
   for(int b = barsSinceP5 - 1; b >= 0; b--)
   {
      datetime barTime = rates[b].time;
      
      // Nur Kerzen NACH P5 pruefen
      if(barTime <= wave.p5.time) continue;
      
      // Berechne Linien-Preis mit Two-Point-Form
      double linePrice = p1_price + (p3_price - p1_price) * ((double)(barTime - t1) / timeDiff13);
      
      double highPrice = rates[b].high;
      double lowPrice = rates[b].low;
      
      if(InpDebugMode && b <= barsSinceP5 - 1 && b >= barsSinceP5 - 5)
      {
         Print("   Bar ", b, ": ", TimeToString(barTime), 
               " | High: ", DoubleToString(highPrice, 5), 
               " | Low: ", DoubleToString(lowPrice, 5),
               " | Line: ", DoubleToString(linePrice, 5));
      }
      
      bool breakoutDetected = false;
      
      if(wave.isBullish)
      {
         // BULLISH: High durchbricht Linie von unten nach oben
         // Preis muss von UNTER der Linie kommen und UEBER gehen
         if(highPrice > linePrice && lowPrice <= linePrice)
         {
            breakoutDetected = true;
         }
      }
      else
      {
         // BEARISH: Low durchbricht Linie von oben nach unten
         // Preis muss von UEBER der Linie kommen und UNTER gehen
         if(lowPrice < linePrice && highPrice >= linePrice)
         {
            breakoutDetected = true;
         }
      }
      
      if(breakoutDetected)
      {
         // Entry = Linienpreis (exakter Durchbruchspunkt)
         outPrice = linePrice;
         outTime = barTime;
         Print("   *** DURCHBRUCH GEFUNDEN! ***");
         Print("   Entry (Linienpreis): ", DoubleToString(outPrice, 5), " @ ", TimeToString(outTime));
         return true;
      }
   }
   
   if(InpDebugMode) Print("   -> Kein Durchbruch gefunden");
   return false;
}

//+------------------------------------------------------------------+
// Verarbeite als ACTIVE Signal (Durchbruch bereits passiert)
//+------------------------------------------------------------------+
void ProcessAsActiveSignal(WolfeWave &wave, string wedgeId, string market, 
                           double entryPrice, datetime entryTime, bool isUpdate)
{
   // V28.4: Bei Updates pruefen ob neues Bild noetig ist (gleiche Logik wie bei Pending)
   if(isUpdate && !ShouldCreateNewImage(wedgeId, wave.timeframe, market))
   {
      if(InpDebugMode)
         Print("[SKIP] Active Signal - Kein neues Bild noetig: ", wedgeId);
      return;
   }
   
   // Berechne SL und TPs
   double slPrice, tp1Price, tp2Price, tp3Price;
   
   // WICHTIG: TP3 ist der Punkt auf der 1-4 Linie zum Zeitpunkt greenEnd
   // greenEnd = P5 + Keildauer (wie weit der Keil nach P5 verlÃ¤ngert wird)
   double slope14 = (wave.p4.price - wave.p1.price) / (double)(wave.p4.time - wave.p1.time);
   int keilDauer = (int)(wave.p5.time - wave.p1.time);
   datetime greenEnd = wave.p5.time + keilDauer;
   double tp3OnLine = wave.p1.price + slope14 * (double)(greenEnd - wave.p1.time);
   
   if(wave.isBullish)
   {
      // BULLISH: Preis steigt -> TPs ÃœBER Entry, SL UNTER Entry
      slPrice = entryPrice * (1.0 - InpSLPercent / 100.0);
      
      // TP3 muss ÃœBER Entry sein fuer BULLISH
      if(tp3OnLine <= entryPrice)
      {
         // Fallback: TP3 = Entry + 3x SL-Abstand
         tp3OnLine = entryPrice + (entryPrice - slPrice) * 3.0;
         Print("[WARN] TP3 korrigiert fuer BULLISH: ", tp3OnLine);
      }
      
      double tpRange = tp3OnLine - entryPrice;
      tp1Price = entryPrice + tpRange * 0.33;
      tp2Price = entryPrice + tpRange * 0.66;
      tp3Price = tp3OnLine;
   }
   else
   {
      // BEARISH: Preis faellt -> TPs UNTER Entry, SL ÃœBER Entry
      slPrice = entryPrice * (1.0 + InpSLPercent / 100.0);
      
      // TP3 muss UNTER Entry sein fuer BEARISH
      if(tp3OnLine >= entryPrice)
      {
         // Fallback: TP3 = Entry - 3x SL-Abstand
         tp3OnLine = entryPrice - (slPrice - entryPrice) * 3.0;
         Print("[WARN] TP3 korrigiert fuer BEARISH: ", tp3OnLine);
      }
      
      double tpRange = entryPrice - tp3OnLine;
      tp1Price = entryPrice - tpRange * 0.33;
      tp2Price = entryPrice - tpRange * 0.66;
      tp3Price = tp3OnLine;
   }
   
   // Validierung: TPs muessen in richtiger Reihenfolge sein
   if(wave.isBullish)
   {
      if(tp1Price <= entryPrice || tp2Price <= tp1Price || tp3Price <= tp2Price)
      {
         Print("[ERROR] Ungueltige TP-Reihenfolge BULLISH: E=", entryPrice, 
               " TP1=", tp1Price, " TP2=", tp2Price, " TP3=", tp3Price);
      }
   }
   else
   {
      if(tp1Price >= entryPrice || tp2Price >= tp1Price || tp3Price >= tp2Price)
      {
         Print("[ERROR] Ungueltige TP-Reihenfolge BEARISH: E=", entryPrice, 
               " TP1=", tp1Price, " TP2=", tp2Price, " TP3=", tp3Price);
      }
   }
   
   // Debug-Ausgabe
   Print("[ACTIVE] ", wedgeId, " ", (wave.isBullish ? "BULL" : "BEAR"));
   Print("   Entry: ", entryPrice, " SL: ", slPrice, " (", DoubleToString(InpSLPercent, 1), "%)");
   Print("   TP1: ", tp1Price, " TP2: ", tp2Price, " TP3: ", tp3Price);
   
   // ActiveTrade erstellen
   ActiveTrade trade;
   trade.wedgeId = wedgeId;
   trade.symbol = wave.symbol;
   trade.timeframe = wave.timeframe;
   trade.isBullish = wave.isBullish;
   trade.entryPrice = entryPrice;
   trade.slPrice = slPrice;
   trade.tp1Price = tp1Price;
   trade.tp2Price = tp2Price;
   trade.tp3Price = tp3Price;
   trade.entryTime = entryTime;
   trade.market = market;
   trade.tp1Hit = false;
   trade.tp2Hit = false;
   trade.tp3Hit = false;
   trade.slHit = false;
   trade.barsTracked = 0;
   trade.p1 = wave.p1;
   trade.p2 = wave.p2;
   trade.p3 = wave.p3;
   trade.p4 = wave.p4;
   trade.p5 = wave.p5;
   trade.epaTime = wave.epaTime;
   trade.epaPrice = wave.epaPrice;
   
   // Bild MIT TPs erstellen
   string imageUrl = CreateActiveTradeImage(trade);
   trade.imagePath = imageUrl;
   
   // In DB speichern
   SaveActiveSignalToDatabase(trade, isUpdate);
   
   // Zu Active Array hinzufuegen (nur bei neuen)
   if(!isUpdate)
   {
      int size = ArraySize(g_activeTrades);
      ArrayResize(g_activeTrades, size + 1);
      g_activeTrades[size] = trade;
      Print("[OK] Active Trade hinzugefuegt: ", wedgeId);
   }
}

//+------------------------------------------------------------------+
// Verarbeite als PENDING Signal (noch kein Durchbruch)
//+------------------------------------------------------------------+
void ProcessAsPendingSignal(WolfeWave &wave, string wedgeId, string market, bool isUpdate)
{
   // NEU: Bei Updates pruefen ob neues Bild noetig ist
   if(isUpdate && !ShouldCreateNewImage(wedgeId, wave.timeframe, market))
   {
      // Kein neues Bild noetig - KEIN DB Update (image_path bleibt erhalten)
      if(InpDebugMode)
         Print("[SKIP] Kein Update noetig: ", wedgeId);
      return;
   }
   
   long chartId = ChartOpen(wave.symbol, wave.timeframe);
   if(chartId == 0) { Print("Chart Error!"); return; }
   
   SetupChartStyle(chartId);
   
   int patternStart = wave.p1.bar;
   int shift = patternStart - 10;
   if(shift < 0) shift = 0;
   ChartNavigate(chartId, CHART_END, -shift);
   
   Sleep(500);
   
   // Zeichne NUR den Keil (OHNE TPs!)
   DrawPatternPendingOnly(chartId, wave);
   ChartRedraw(chartId);
   Sleep(500);
   
   string tfStr = TFToString(wave.timeframe);
   
   // NEU: Versionierter Dateiname fuer Bild-Historie
   string versionTs = GetVersionTimestamp();
   string versionedFile = wedgeId + "_v" + versionTs + ".png";
   string tempFile = versionedFile;
   
   if(!ChartScreenShot(chartId, tempFile, 1920, 1080, ALIGN_RIGHT))
   {
      Print("Screenshot Error!");
      ChartClose(chartId);
      return;
   }
   
   Sleep(300);
   
   // Upload mit versioniertem Pfad
   string imagePath = market + "/" + tfStr + "/" + versionedFile;
   bool uploadOk = UploadImageToSupabase(tempFile, imagePath);
   
   string imageUrl = "";
   if(uploadOk)
   {
      imageUrl = InpSupabaseUrl + "/storage/v1/object/public/signals/" + imagePath;
      Print("[OK] Pending Bild: ", imagePath);
      
      // NEU: Bild in Historie speichern fuer Slider
      SaveImageToHistory(wedgeId, imageUrl);
      
      // V28.1: Auch image_path in signals Tabelle updaten (für Kachel-Anzeige)
      if(isUpdate)
         UpdateSignalImagePath(wedgeId, imageUrl);
   }
   
   // Speichere als PENDING Signal
   SavePendingSignalToDatabase(wave, wedgeId, imageUrl, isUpdate, market);
   
   // Fuege zu pending Array hinzu (nur bei neuen Patterns)
   if(!isUpdate)
   {
      AddToPendingSignals(wave, wedgeId, imageUrl, market);
   }
   
   FileDelete(tempFile);
   ChartClose(chartId);
}

//+------------------------------------------------------------------+
// ACTIVE Signal direkt in DB speichern (mit Entry/SL/TPs)
//+------------------------------------------------------------------+
void SaveActiveSignalToDatabase(ActiveTrade &trade, bool isUpdate)
{
   string symbolName = SymbolInfoString(trade.symbol, SYMBOL_DESCRIPTION);
   if(symbolName == "") symbolName = trade.symbol;
   
   symbolName = EscapeJSON(symbolName);
   string symbolEsc = EscapeJSON(trade.symbol);
   string imageUrlEsc = EscapeJSON(trade.imagePath);
   
   string tfStr = TFToString(trade.timeframe);
   
   double slPct = ((trade.slPrice - trade.entryPrice) / trade.entryPrice) * 100;
   double tp1Pct = ((trade.tp1Price - trade.entryPrice) / trade.entryPrice) * 100;
   double tp2Pct = ((trade.tp2Price - trade.entryPrice) / trade.entryPrice) * 100;
   double tp3Pct = ((trade.tp3Price - trade.entryPrice) / trade.entryPrice) * 100;
   
   // NEU V27.28: R/R basierend auf TP3
   double risk = MathAbs(trade.entryPrice - trade.slPrice);
   double reward = MathAbs(trade.tp3Price - trade.entryPrice);  // TP3!
   double rr = (risk > 0) ? NormalizeDouble(reward / risk, 1) : 0;
   
   string json = "{";
   json += "\"wedge_id\":\"" + trade.wedgeId + "\"";
   json += ",\"symbol\":\"" + symbolEsc + "\"";
   json += ",\"symbol_name\":\"" + symbolName + "\"";
   json += ",\"market\":\"" + trade.market + "\"";
   json += ",\"timeframe\":\"" + tfStr + "\"";
   json += ",\"direction\":\"" + (trade.isBullish ? "BULLISH" : "BEARISH") + "\"";
   
   // Entry und Levels
   json += ",\"entry\":" + DoubleToString(trade.entryPrice, 6);
   json += ",\"entry_time\":\"" + DatetimeToISO(trade.entryTime) + "\"";  // V28.1: ISO Format
   json += ",\"sl\":" + DoubleToString(trade.slPrice, 6);
   json += ",\"tp1\":" + DoubleToString(trade.tp1Price, 6);
   json += ",\"tp2\":" + DoubleToString(trade.tp2Price, 6);
   json += ",\"tp3\":" + DoubleToString(trade.tp3Price, 6);
   
   json += ",\"sl_pct\":" + DoubleToString(slPct, 2);
   json += ",\"tp1_pct\":" + DoubleToString(tp1Pct, 2);
   json += ",\"tp2_pct\":" + DoubleToString(tp2Pct, 2);
   json += ",\"tp3_pct\":" + DoubleToString(tp3Pct, 2);
   json += ",\"rr\":" + DoubleToString(rr, 2);
   
   // Punkte
   json += ",\"p1_price\":" + DoubleToString(trade.p1.price, 6);
   json += ",\"p1_time\":\"" + TimeToString(trade.p1.time, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"p2_price\":" + DoubleToString(trade.p2.price, 6);
   json += ",\"p2_time\":\"" + TimeToString(trade.p2.time, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"p3_price\":" + DoubleToString(trade.p3.price, 6);
   json += ",\"p3_time\":\"" + TimeToString(trade.p3.time, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"p4_price\":" + DoubleToString(trade.p4.price, 6);
   json += ",\"p4_time\":\"" + TimeToString(trade.p4.time, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"p5_price\":" + DoubleToString(trade.p5.price, 6);
   json += ",\"p5_time\":\"" + TimeToString(trade.p5.time, TIME_DATE|TIME_MINUTES) + "\"";
   
   // EPA
   json += ",\"epa_time\":\"" + TimeToString(trade.epaTime, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"epa_price\":" + DoubleToString(trade.epaPrice, 6);
   
   // image_path nur setzen wenn nicht leer
   if(trade.imagePath != "")
   {
      json += ",\"image_path\":\"" + imageUrlEsc + "\"";
   }
   
   // Status ACTIVE
   json += ",\"status\":\"active\"";
   json += ",\"tp1_hit\":false";
   json += ",\"tp2_hit\":false";
   json += ",\"tp3_hit\":false";
   json += ",\"sl_hit\":false";
   
   json += "}";
   
   string url;
   string method;
   
   if(isUpdate)
   {
      url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + trade.wedgeId;
      method = "PATCH";
   }
   else
   {
      url = InpSupabaseUrl + "/rest/v1/signals";
      method = "POST";
   }
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char result[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   int res = WebRequest(method, url, headers, 5000, postData, result, resultHeaders);
   
   if(res == 200 || res == 201 || res == 204)
      Print("[OK] DB ACTIVE: ", trade.wedgeId, " | R/R: 1:", DoubleToString(rr, 1));
   else if(res == 409)
      Print("[INFO] Bereits vorhanden: ", trade.wedgeId);
   else
      Print("[ERROR] DB: ", res);
}

//+------------------------------------------------------------------+
// PENDING Signal in DB speichern
//+------------------------------------------------------------------+
void SavePendingSignalToDatabase(WolfeWave &wave, string wedgeId, string imageUrl, bool isUpdate, string market)
{
   string symbolName = SymbolInfoString(wave.symbol, SYMBOL_DESCRIPTION);
   if(symbolName == "") symbolName = wave.symbol;
   
   symbolName = EscapeJSON(symbolName);
   string symbolEsc = EscapeJSON(wave.symbol);
   string imageUrlEsc = EscapeJSON(imageUrl);
   
   string tfStr = TFToString(wave.timeframe);
   
   // NEU V27.28: Vorlaeufige R/R Berechnung fuer PENDING Signale
   // Entry geschaetzt auf P5-Preis, SL/TP basierend auf Keil-Struktur
   double estEntry = wave.p5.price;
   double estSL, estTP3;
   
   // TP3 auf gruener Linie (1-4) berechnen
   double slope14 = (wave.p4.price - wave.p1.price) / (double)(wave.p4.time - wave.p1.time);
   int keilDauer = (int)(wave.p5.time - wave.p1.time);
   datetime greenEnd = wave.p5.time + keilDauer;
   double tp3OnLine = wave.p1.price + slope14 * (double)(greenEnd - wave.p1.time);
   
   if(wave.isBullish)
   {
      estSL = estEntry * (1.0 - InpSLPercent / 100.0);
      estTP3 = (tp3OnLine > estEntry) ? tp3OnLine : estEntry * 1.15;  // Fallback +15%
   }
   else
   {
      estSL = estEntry * (1.0 + InpSLPercent / 100.0);
      estTP3 = (tp3OnLine < estEntry) ? tp3OnLine : estEntry * 0.85;  // Fallback -15%
   }
   
   double risk = MathAbs(estEntry - estSL);
   double reward = MathAbs(estTP3 - estEntry);
   double rr = (risk > 0) ? NormalizeDouble(reward / risk, 1) : 0;
   
   string json = "{";
   json += "\"wedge_id\":\"" + wedgeId + "\"";
   json += ",\"symbol\":\"" + symbolEsc + "\"";
   json += ",\"symbol_name\":\"" + symbolName + "\"";
   json += ",\"market\":\"" + market + "\"";
   json += ",\"timeframe\":\"" + tfStr + "\"";
   json += ",\"direction\":\"" + (wave.isBullish ? "BULLISH" : "BEARISH") + "\"";
   
   // Vorlaeufige Werte fuer PENDING (werden bei ACTIVE ueberschrieben)
   json += ",\"entry\":" + DoubleToString(estEntry, 6);
   json += ",\"sl\":" + DoubleToString(estSL, 6);
   json += ",\"tp3\":" + DoubleToString(estTP3, 6);
   json += ",\"rr\":" + DoubleToString(rr, 1);
   
   // Punkte speichern
   json += ",\"p1_price\":" + DoubleToString(wave.p1.price, 6);
   json += ",\"p1_time\":\"" + TimeToString(wave.p1.time, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"p2_price\":" + DoubleToString(wave.p2.price, 6);
   json += ",\"p2_time\":\"" + TimeToString(wave.p2.time, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"p3_price\":" + DoubleToString(wave.p3.price, 6);
   json += ",\"p3_time\":\"" + TimeToString(wave.p3.time, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"p4_price\":" + DoubleToString(wave.p4.price, 6);
   json += ",\"p4_time\":\"" + TimeToString(wave.p4.time, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"p5_price\":" + DoubleToString(wave.p5.price, 6);
   json += ",\"p5_time\":\"" + TimeToString(wave.p5.time, TIME_DATE|TIME_MINUTES) + "\"";
   
   // EPA speichern
   json += ",\"epa_time\":\"" + TimeToString(wave.epaTime, TIME_DATE|TIME_MINUTES) + "\"";
   json += ",\"epa_price\":" + DoubleToString(wave.epaPrice, 6);
   
   // image_path nur setzen wenn nicht leer (sonst bleibt alter Wert erhalten)
   if(imageUrl != "")
   {
      json += ",\"image_path\":\"" + imageUrlEsc + "\"";
   }
   
   // STATUS = PENDING (KEINE Entry/SL/TP Werte!)
   if(!isUpdate)
   {
      json += ",\"status\":\"pending\"";
   }
   
   json += "}";
   
   if(InpDebugMode) Print("JSON: ", StringSubstr(json, 0, 200), "...");
   
   string url;
   string method;
   string headers;
   
   if(isUpdate)
   {
      url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + wedgeId;
      method = "PATCH";
   }
   else
   {
      url = InpSupabaseUrl + "/rest/v1/signals";
      method = "POST";
   }
   
   headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: application/json\r\n";
   headers += "Prefer: return=minimal\r\n";
   
   uchar postData[];
   char result[];
   string resultHeaders;
   
   int len = StringLen(json);
   ArrayResize(postData, len);
   for(int i = 0; i < len; i++)
      postData[i] = (uchar)StringGetCharacter(json, i);
   
   int res = WebRequest(
      method,
      url,
      headers,
      5000,
      postData,
      result,
      resultHeaders
   );
   
   if(res == 200 || res == 201 || res == 204)
   {
      Print("[OK] DB PENDING: ", wedgeId, " | R/R: 1:", DoubleToString(rr, 1));
   }
   else if(res == 409)
   {
      // NEU V27.28: 409 = Duplikat, kein Fehler!
      Print("[INFO] Bereits vorhanden: ", wedgeId);
   }
   else if(res == -1)
   {
      Print("[ERROR] WebRequest: ", GetLastError());
   }
   else
   {
      Print("[ERROR] DB: ", res);
      if(InpDebugMode) Print("Response: ", CharArrayToString(result));
   }
}

//+------------------------------------------------------------------+
// Zu Pending Signals Array hinzufuegen
//+------------------------------------------------------------------+
void AddToPendingSignals(WolfeWave &wave, string wedgeId, string imageUrl, string market)
{
   PendingSignal sig;
   sig.wedgeId = wedgeId;
   sig.symbol = wave.symbol;
   sig.timeframe = wave.timeframe;
   sig.isBullish = wave.isBullish;
   sig.p1 = wave.p1;
   sig.p2 = wave.p2;
   sig.p3 = wave.p3;
   sig.p4 = wave.p4;
   sig.p5 = wave.p5;
   sig.epaTime = wave.epaTime;
   sig.epaPrice = wave.epaPrice;
   sig.line13_slope = wave.line13_slope;
   sig.line13_intercept = wave.line13_intercept;
   sig.market = market;
   sig.imagePath = imageUrl;
   sig.p5Time = wave.p5.time;
   sig.waitingForBreakout = true;
   
   int size = ArraySize(g_pendingSignals);
   ArrayResize(g_pendingSignals, size + 1);
   g_pendingSignals[size] = sig;
   
   Print("[OK] Pending Signal hinzugefuegt: ", wedgeId);
}

//+------------------------------------------------------------------+
bool UploadImageToSupabase(string localFile, string remotePath)
{
   int handle = FileOpen(localFile, FILE_READ|FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      Print("Datei nicht gefunden: ", localFile);
      return false;
   }
   
   int fileSize = (int)FileSize(handle);
   if(fileSize <= 0)
   {
      FileClose(handle);
      return false;
   }
   
   uchar fileData[];
   ArrayResize(fileData, fileSize);
   FileReadArray(handle, fileData);
   FileClose(handle);
   
   string url = InpSupabaseUrl + "/storage/v1/object/signals/" + remotePath;
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "Content-Type: image/png\r\n";
   headers += "x-upsert: true\r\n";
   
   char result[];
   string resultHeaders;
   
   int res = WebRequest(
      "PUT",
      url,
      headers,
      10000,
      fileData,
      result,
      resultHeaders
   );
   
   if(res == 200 || res == 201)
   {
      return true;
   }
   else if(res == -1)
   {
      Print("WebRequest Error: ", GetLastError());
      return false;
   }
   else
   {
      Print("HTTP Error: ", res);
      if(InpDebugMode) Print("Response: ", CharArrayToString(result));
      return false;
   }
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(lparam == 'S')
      {
         Print(">>> MANUELLER SCAN <<<");
         PerformScan();
      }
      if(lparam == 'T')
      {
         Print(">>> TRACKING CHECK <<<");
         CheckActiveTradesForCompletion();
         Print("Active Trades: ", ArraySize(g_activeTrades));
      }
      if(lparam == 'P')
      {
         Print(">>> PENDING CHECK <<<");
         CheckPendingSignalsForBreakout();
         Print("Pending Signals: ", ArraySize(g_pendingSignals));
      }
      if(lparam == 'V')
      {
         Print(">>> VALIDIERUNG COMPLETED SIGNALS <<<");
         ValidateCompletedSignals();
      }
   }
}

//+------------------------------------------------------------------+
// NEU: Validiere abgeschlossene Signale und korrigiere falsche Ergebnisse
//+------------------------------------------------------------------+
void ValidateCompletedSignals()
{
   Print("Lade completed_signals aus DB...");
   
   string url = InpSupabaseUrl + "/rest/v1/completed_signals?select=*&limit=100";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   
   char result[];
   string resultHeaders;
   uchar empty[];
   
   int res = WebRequest("GET", url, headers, 10000, empty, result, resultHeaders);
   
   if(res != 200)
   {
      Print("[ERROR] Konnte completed_signals nicht laden: ", res);
      return;
   }
   
   string response = CharArrayToString(result);
   if(response == "[]")
   {
      Print("Keine completed_signals gefunden.");
      return;
   }
   
   // Parse JSON Array
   int corrected = 0;
   int checked = 0;
   
   // Einfaches Parsing - suche nach wedge_id Eintraegen
   int pos = 0;
   while((pos = StringFind(response, "\"wedge_id\":\"", pos)) >= 0)
   {
      pos += 12;
      int endPos = StringFind(response, "\"", pos);
      if(endPos < 0) break;
      
      string wedgeId = StringSubstr(response, pos, endPos - pos);
      checked++;
      
      // Finde das Symbol
      int symbolPos = StringFind(response, "\"symbol\":\"", pos);
      if(symbolPos < 0) continue;
      symbolPos += 10;
      int symbolEnd = StringFind(response, "\"", symbolPos);
      string symbol = StringSubstr(response, symbolPos, symbolEnd - symbolPos);
      
      // Finde Timeframe
      int tfPos = StringFind(response, "\"timeframe\":\"", pos);
      if(tfPos < 0) continue;
      tfPos += 13;
      int tfEnd = StringFind(response, "\"", tfPos);
      string tfStr = StringSubstr(response, tfPos, tfEnd - tfPos);
      ENUM_TIMEFRAMES tf = StringToTF(tfStr);
      
      // Finde Entry Zeit und Preis
      int entryTimePos = StringFind(response, "\"entry_time\":\"", pos);
      int entryPricePos = StringFind(response, "\"entry_price\":", pos);
      int slPricePos = StringFind(response, "\"sl_price\":", pos);
      int tp1PricePos = StringFind(response, "\"tp1_price\":", pos);
      
      // Finde aktuelles Ergebnis
      int resultPos = StringFind(response, "\"result\":\"", pos);
      if(resultPos < 0) continue;
      resultPos += 10;
      int resultEnd = StringFind(response, "\"", resultPos);
      string currentResult = StringSubstr(response, resultPos, resultEnd - resultPos);
      
      // Validiere dieses Signal
      if(ValidateSingleSignal(wedgeId, symbol, tf, currentResult))
         corrected++;
      
      pos = endPos;
   }
   
   Print("========================================");
   Print("Validierung abgeschlossen!");
   Print("GeprÃ¼ft: ", checked, " | Korrigiert: ", corrected);
   Print("========================================");
}

//+------------------------------------------------------------------+
bool ValidateSingleSignal(string wedgeId, string symbol, ENUM_TIMEFRAMES tf, string currentResult)
{
   // Diese Funktion prÃ¼ft ob das Ergebnis korrekt ist
   // Gibt true zurÃ¼ck wenn eine Korrektur nÃ¶tig war
   
   // Hole die Signaldaten aus signals Tabelle
   string url = InpSupabaseUrl + "/rest/v1/signals?wedge_id=eq." + wedgeId + "&select=*";
   
   string headers = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
   headers += "apikey: " + InpSupabaseKey + "\r\n";
   
   char result[];
   string resultHeaders;
   uchar empty[];
   
   int res = WebRequest("GET", url, headers, 5000, empty, result, resultHeaders);
   if(res != 200) return false;
   
   string signalData = CharArrayToString(result);
   if(signalData == "[]") return false;
   
   // Parse die wichtigen Werte
   double entryPrice = ExtractJSONDouble(signalData, "entry_price");
   double slPrice = ExtractJSONDouble(signalData, "sl_price");
   double tp1Price = ExtractJSONDouble(signalData, "tp1_price");
   double tp2Price = ExtractJSONDouble(signalData, "tp2_price");
   string direction = ExtractJSONString(signalData, "direction");
   string entryTimeStr = ExtractJSONString(signalData, "entry_time");
   
   if(entryPrice <= 0 || slPrice <= 0) return false;
   
   bool isBullish = (direction == "BULLISH");
   
   // Konvertiere Entry-Zeit
   StringReplace(entryTimeStr, "T", " ");
   int plusPos = StringFind(entryTimeStr, "+");
   if(plusPos > 0) entryTimeStr = StringSubstr(entryTimeStr, 0, plusPos);
   datetime entryTime = StringToTime(entryTimeStr);
   
   if(entryTime == 0) return false;
   
   // Hole Preisdaten
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int barsSinceEntry = iBarShift(symbol, tf, entryTime, false);
   if(barsSinceEntry < 0 || barsSinceEntry > 500) return false;
   
   if(CopyRates(symbol, tf, 0, barsSinceEntry + 5, rates) < 2) return false;
   
   // PrÃ¼fe was wirklich passiert ist
   datetime tp1Time = 0, tp2Time = 0, slTime = 0;
   
   for(int b = ArraySize(rates) - 1; b >= 0; b--)
   {
      if(rates[b].time < entryTime) continue;
      
      double high = rates[b].high;
      double low = rates[b].low;
      
      if(isBullish)
      {
         if(high >= tp1Price && tp1Time == 0) tp1Time = rates[b].time;
         if(high >= tp2Price && tp2Time == 0) tp2Time = rates[b].time;
         if(low <= slPrice && slTime == 0) slTime = rates[b].time;
      }
      else
      {
         if(low <= tp1Price && tp1Time == 0) tp1Time = rates[b].time;
         if(low <= tp2Price && tp2Time == 0) tp2Time = rates[b].time;
         if(high >= slPrice && slTime == 0) slTime = rates[b].time;
      }
   }
   
   // Bestimme korrektes Ergebnis
   string correctResult = "";
   
   if(slTime > 0)
   {
      // SL wurde getroffen
      if(tp2Time > 0 && tp2Time < slTime)
         correctResult = "PARTIAL_SUCCESS";
      else if(tp1Time > 0 && tp1Time < slTime)
         correctResult = "PARTIAL_SUCCESS";
      else
         correctResult = "SL_HIT";
   }
   else
   {
      // Kein SL - check TPs (vereinfacht, TP3 fehlt hier)
      if(tp2Time > 0)
         correctResult = "PARTIAL_SUCCESS";
      else if(tp1Time > 0)
         correctResult = "PARTIAL_SUCCESS";
   }
   
   // Vergleiche mit aktuellem Ergebnis
   if(correctResult != "" && correctResult != currentResult)
   {
      Print("[KORREKTUR] ", wedgeId, ": ", currentResult, " -> ", correctResult);
      
      // Update in DB
      string json = "{\"result\":\"" + correctResult + "\"}";
      
      string updateUrl = InpSupabaseUrl + "/rest/v1/completed_signals?wedge_id=eq." + wedgeId;
      
      string updateHeaders = "Authorization: Bearer " + InpSupabaseKey + "\r\n";
      updateHeaders += "apikey: " + InpSupabaseKey + "\r\n";
      updateHeaders += "Content-Type: application/json\r\n";
      updateHeaders += "Prefer: return=minimal\r\n";
      
      uchar postData[];
      char updateResult[];
      string updateResultHeaders;
      
      int len = StringLen(json);
      ArrayResize(postData, len);
      for(int i = 0; i < len; i++)
         postData[i] = (uchar)StringGetCharacter(json, i);
      
      WebRequest("PATCH", updateUrl, updateHeaders, 5000, postData, updateResult, updateResultHeaders);
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES StringToTF(string tf)
{
   if(tf == "M5") return PERIOD_M5;
   if(tf == "M15") return PERIOD_M15;
   if(tf == "H1") return PERIOD_H1;
   if(tf == "H4") return PERIOD_H4;
   if(tf == "D1") return PERIOD_D1;
   if(tf == "W1") return PERIOD_W1;
   return PERIOD_H1;
}

//+------------------------------------------------------------------+
void OnTick() { }
//+------------------------------------------------------------------+
