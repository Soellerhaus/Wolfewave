// ===== WolfeWaveSignals Shared JavaScript =====

// ===== CONFIG =====
const SB_URL = 'https://ufqglmqiuyasszieprsr.supabase.co';
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmcWdsbXFpdXlhc3N6aWVwcnNyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzODAzNDQsImV4cCI6MjA4Mzk1NjM0NH0.F2pfyfNNSr8hqZYowjDIbXmek-GvmpyZRwIEUaC3h-4';
const STORAGE_URL = `${SB_URL}/storage/v1/object/public/signals`;

// ===== HELPERS =====
function $(id) { return document.getElementById(id); }

function money(v) {
    return (+v||0).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function price(v) {
    const n = +v;
    if (!n) return '--';
    return n >= 100 ? n.toFixed(2) : n >= 1 ? n.toFixed(4) : n.toFixed(5);
}

function fmtDate(s) {
    if (!s) return '--';
    const d = new Date(s);
    if (isNaN(d)) return '--';
    return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: '2-digit' }) + ' ' +
           d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
}

// ===== SYMBOL NAMES =====
let symbolNames = {};

function getSymbolName(symbol, signal) {
    if (!symbol) return 'Unbekannt';
    if (symbolNames[symbol]) return symbolNames[symbol];
    if (signal?.symbol_name && signal.symbol_name !== symbol) return signal.symbol_name;
    let s = symbol.replace(/\.(OQ|N|DE|L|PA|AS|SW|MC|MI|AX|HK|T|SS|SZ|F)$/i, '');
    if (s.length === 6 && /^[A-Z]+$/.test(s)) {
        const b = s.substring(0,3), q = s.substring(3,6);
        const fx = ['USD','EUR','GBP','JPY','CHF','AUD','NZD','CAD','HKD','SGD','MXN','SEK','NOK','TRY','ZAR','PLN','CZK','HUF'];
        if (fx.includes(b) && fx.includes(q)) return `${b}/${q}`;
    }
    return s;
}

function getImageUrl(signal) {
    const path = signal.image_path || signal.original_path;
    if (!path) return '';
    if (path.startsWith('http')) return path;
    return `${STORAGE_URL}/${path}`;
}

function getTradingViewUrl(sym) {
    const map = {'.OQ':'NASDAQ','.N':'NYSE','.DE':'XETR','.PA':'EURONEXT','.HK':'HKEX'};
    for (const [sfx, ex] of Object.entries(map)) {
        if (sym.endsWith(sfx)) {
            let base = sym.slice(0, -sfx.length).replace(/[a-z]$/,'');
            return `https://www.tradingview.com/chart/?symbol=${ex}:${base}`;
        }
    }
    if (sym.length === 6 && !sym.includes('.')) return `https://www.tradingview.com/chart/?symbol=FX:${sym}`;
    return `https://www.tradingview.com/chart/?symbol=${sym}`;
}

// ===== SUPABASE FETCH =====
async function sb(table, query) {
    const r = await fetch(`${SB_URL}/rest/v1/${table}?${query}`, {
        headers: { 'apikey': SB_KEY, 'Authorization': `Bearer ${SB_KEY}`, 'Prefer': 'count=none' }
    });
    if (!r.ok) throw new Error(`${table}: ${r.status}`);
    return r.json();
}

// ===== LOAD SYMBOL NAMES =====
async function loadSymbolNames() {
    try {
        let offset = 0, all = [];
        while (true) {
            const data = await sb('symbol_markets', `select=symbol,name&name=not.is.null&limit=1000&offset=${offset}`);
            all = all.concat(data);
            if (data.length < 1000) break;
            offset += 1000;
        }
        all.forEach(d => { if (d.symbol && d.name) symbolNames[d.symbol] = d.name; });
    } catch(e) { console.warn('Symbol names:', e); }
}

// ===== LOAD ALL SIGNAL IMAGES (returns Map<wedge_id, Array>) =====
async function loadAllSignalImages() {
    try {
        const imgs = await sb('signal_images', 'select=wedge_id,image_url,image_type,is_display_photo,scanned_at&order=scanned_at.desc&limit=10000');
        const byWedge = {};
        imgs.forEach(img => {
            if (!byWedge[img.wedge_id]) byWedge[img.wedge_id] = [];
            byWedge[img.wedge_id].push({
                url: img.image_url,
                type: img.is_display_photo ? 'display_photo' : (img.image_type || 'detect'),
                scanned_at: img.scanned_at
            });
        });
        // Sort each wedge's images: detect -> entry -> latest -> display_photo
        const order = { 'detect': 1, 'entry': 2, 'latest': 3, 'display_photo': 4 };
        Object.values(byWedge).forEach(arr => {
            arr.sort((a, b) => (order[a.type] || 0) - (order[b.type] || 0));
        });
        return byWedge;
    } catch(e) {
        console.warn('Images:', e);
        return {};
    }
}

// ===== GET BEST IMAGE FOR SIGNAL =====
function getBestImage(imageMap, wedgeId) {
    const imgs = imageMap[wedgeId];
    if (!imgs || !imgs.length) return '';
    // Priority: display_photo > latest > entry > detect
    const prio = { 'display_photo': 99, 'latest': 3, 'entry': 2, 'detect': 1 };
    let best = imgs[0];
    imgs.forEach(img => {
        if ((prio[img.type] || 0) > (prio[best.type] || 0)) best = img;
    });
    const url = best.url;
    if (!url) return '';
    if (url.startsWith('http')) return url;
    return `${STORAGE_URL}/${url}`;
}

// ===== LIGHTBOX =====
function openLightbox(url) {
    if (!url) return;
    const lb = $('lightbox');
    const img = $('lightbox-img');
    if (lb && img) {
        img.src = url;
        lb.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
}

function closeLightbox() {
    const lb = $('lightbox');
    if (lb) {
        lb.classList.remove('active');
        document.body.style.overflow = '';
    }
}

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closeLightbox();
});

// ===== SIGNAL CARD RENDERERS =====
function renderSignalCard(s, imgMap) {
    const imgUrl = imgMap ? getBestImage(imgMap, s.wedge_id) : getImageUrl(s);
    const name = getSymbolName(s.symbol, s);
    const dir = s.direction || '';
    const isBull = dir.toUpperCase().includes('BULL') || dir.toUpperCase() === 'BUY';
    const statusCls = s.status === 'active' ? 'badge-active' : 'badge-pending';
    const imgs = imgMap ? (imgMap[s.wedge_id] || []) : [];
    const hasMulti = imgs.length > 1;

    return `<div class="signal-card" onclick="${hasMulti ? `openCarousel('${s.wedge_id}')` : `openLightbox('${imgUrl}')`}">
        ${imgUrl ? `<img class="signal-img" src="${imgUrl}" alt="${name}" loading="lazy" onerror="this.style.display='none'">` :
            '<div class="signal-img" style="display:flex;align-items:center;justify-content:center;color:var(--text-muted);font-size:13px;">Kein Bild</div>'}
        ${hasMulti ? `<div style="position:absolute;top:12px;left:12px;background:rgba(0,0,0,0.6);color:#fff;padding:2px 8px;border-radius:6px;font-size:11px;">${imgs.length} Bilder</div>` : ''}
        <div class="signal-body">
            <div class="signal-head">
                <div>
                    <div class="signal-symbol">${name}</div>
                    <div class="signal-name">${s.symbol} &middot; ${s.timeframe || '--'}</div>
                </div>
                <div class="signal-badges">
                    <span class="badge ${statusCls}">${s.status}</span>
                    <span class="badge ${isBull ? 'badge-bullish' : 'badge-bearish'}">${isBull ? 'BULL' : 'BEAR'}</span>
                </div>
            </div>
            <div class="signal-prices">
                <div class="signal-price price-entry"><div class="lbl">Entry</div><div class="val">${price(s.entry)}</div></div>
                <div class="signal-price price-sl"><div class="lbl">SL</div><div class="val">${price(s.sl)}</div></div>
                <div class="signal-price price-tp"><div class="lbl">TP1</div><div class="val">${price(s.tp1)}</div></div>
            </div>
            <div class="signal-prices" style="margin-top: 6px;">
                <div class="signal-price price-tp"><div class="lbl">TP2</div><div class="val">${price(s.tp2)}</div></div>
                <div class="signal-price price-tp"><div class="lbl">TP3</div><div class="val">${price(s.tp3)}</div></div>
                <div class="signal-price"><div class="lbl">R:R</div><div class="val signal-rr">${s.rr ? (+s.rr).toFixed(1) : '--'}</div></div>
            </div>
            ${s.formation_type ? `<div class="signal-formation"><span class="formation-badge">\u2605 ${s.formation_type}</span></div>` : ''}
            <div class="signal-meta">
                <span>${s.market || '--'}</span>
                <a href="${getTradingViewUrl(s.symbol)}" target="_blank" rel="noopener" style="color: var(--accent); text-decoration: none;" onclick="event.stopPropagation()">TradingView &rarr;</a>
                <span>${fmtDate(s.created_at)}</span>
            </div>
        </div>
    </div>`;
}

function renderCompletedCard(s, imgMap) {
    const imgUrl = imgMap ? getBestImage(imgMap, s.wedge_id) : getImageUrl(s);
    const name = getSymbolName(s.symbol, s);
    let resultText, resultCls;
    if (s.tp3_hit) { resultText = 'TP3'; resultCls = 'result-tp3'; }
    else if (s.tp2_hit) { resultText = 'TP2'; resultCls = 'result-tp2'; }
    else if (s.tp1_hit) { resultText = 'TP1'; resultCls = 'result-tp1'; }
    else { resultText = 'SL'; resultCls = 'result-sl'; }
    const imgs = imgMap ? (imgMap[s.wedge_id] || []) : [];
    const hasMulti = imgs.length > 1;

    return `<div class="signal-card" onclick="${hasMulti ? `openCarousel('${s.wedge_id}')` : `openLightbox('${imgUrl}')`}" style="position:relative;">
        <span class="result-badge ${resultCls}">${resultText}</span>
        ${imgUrl ? `<img class="signal-img" src="${imgUrl}" alt="${name}" loading="lazy" onerror="this.style.display='none'">` :
            '<div class="signal-img" style="display:flex;align-items:center;justify-content:center;color:var(--text-muted);font-size:13px;">Kein Bild</div>'}
        ${hasMulti ? `<div style="position:absolute;top:12px;left:12px;background:rgba(0,0,0,0.6);color:#fff;padding:2px 8px;border-radius:6px;font-size:11px;">${imgs.length} Bilder</div>` : ''}
        <div class="signal-body">
            <div class="signal-head">
                <div>
                    <div class="signal-symbol">${name}</div>
                    <div class="signal-name">${s.symbol} &middot; ${s.timeframe || '--'}</div>
                </div>
                <span class="badge ${s.direction === 'BULLISH' ? 'badge-bullish' : 'badge-bearish'}">${s.direction || '--'}</span>
            </div>
            <div class="signal-prices">
                <div class="signal-price price-entry"><div class="lbl">Entry</div><div class="val">${price(s.entry)}</div></div>
                <div class="signal-price price-sl"><div class="lbl">SL</div><div class="val">${price(s.sl)}</div></div>
                <div class="signal-price price-tp"><div class="lbl">TP1</div><div class="val">${price(s.tp1)}</div></div>
            </div>
            ${s.formation_type ? `<div class="signal-formation"><span class="formation-badge">\u2605 ${s.formation_type}</span></div>` : ''}
            <div class="signal-meta">
                <span>${s.market || '--'}</span>
                <span>${fmtDate(s.created_at)}</span>
            </div>
        </div>
    </div>`;
}
