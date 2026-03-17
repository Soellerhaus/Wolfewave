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

function getStock3Url(sym) {
    const S3 = {
        // === Forex ===
        'AUDCAD':'/devisen/australischer-dollar-kanadischer-dollar-138092',
        'AUDCHF':'/devisen/australischer-dollar-schweizer-franken-138093',
        'AUDJPY':'/devisen/australischer-dollar-japanischer-yen-138098',
        'AUDNZD':'/devisen/australischer-dollar-neuseelaendischer-dollar-138100',
        'AUDUSD':'/devisen/australischer-dollar-us-dollar-134013',
        'CADCHF':'/devisen/kanadischer-dollar-schweizer-franken-138105',
        'CADJPY':'/devisen/kanadischer-dollar-japanischer-yen-138108',
        'CHFJPY':'/devisen/schweizer-franken-japanischer-yen-138115',
        'EURCHF':'/devisen/euro-schweizer-franken-134001',
        'EURGBP':'/devisen/euro-britisches-pfund-134002',
        'EURJPY':'/devisen/euro-japanischer-yen-134003',
        'EURUSD':'/devisen/euro-us-dollar-134000',
        'GBPCHF':'/devisen/britisches-pfund-schweizer-franken-134014',
        'GBPJPY':'/devisen/britisches-pfund-japanischer-yen-138141',
        'GBPUSD':'/devisen/britisches-pfund-us-dollar-134004',
        'NZDJPY':'/devisen/neuseelaendischer-dollar-japanischer-yen-138159',
        'NZDUSD':'/devisen/neuseelaendischer-dollar-us-dollar-134015',
        'USDCAD':'/devisen/us-dollar-kanadischer-dollar-134017',
        'USDCHF':'/devisen/us-dollar-schweizer-franken-134005',
        'USDJPY':'/devisen/us-dollar-japanischer-yen-134006',
        // === Indizes ===
        'DE40.c':'/indizes/dax-performance-index-133962',
        'DJ30.c':'/indizes/dow-jones-industrial-average-index-price-usd-133965',
        'US500.c':'/indizes/s-and-p-500-index-133954',
        'USTEC.c':'/indizes/nasdaq-100-index-133955',
        'UK100.c':'/indizes/euro-stoxx-50-index-price-eur-133942',
        'JP225.c':'/indizes/nikkei-225-stock-average-index-133958',
        'HK50.c':'/indizes/hang-seng-index-133956',
        // === Rohstoffe ===
        'XAUUSD':'/rohstoffe/gold-133979',
        'XAGUSD':'/rohstoffe/silber-133984',
        'XAUEUR':'/rohstoffe/gold-133979',
        'USOIL.c':'/rohstoffe/wti-oel-133999',
        'UKOIL.c':'/rohstoffe/brent-crude-oel-133978',
        // === Krypto ===
        'BTCUSD':'/kryptos/bitcoin-us-dollar-kurs-btc-usd-23087055',
        'ETHUSD':'/kryptos/ethereum-us-dollar-kurs-eth-usd-23087058',
        'SOLUSD':'/kryptos/solana-us-dollar-kurs-sol-usd-49269559',
        'ADAUSD':'/kryptos/cardano-us-dollar-kurs-ada-usd-44940570',
        'XRPUSD':'/kryptos/ripple-us-dollar-kurs-xrp-usd-25866091',
        // === DE Aktien ===
        'ADSGn.DE':'/aktien/adidas-123104',
        'ALVG.DE':'/aktien/allianz-122117',
        'BASFn.DE':'/aktien/basf-119104',
        'BAYGn.DE':'/aktien/bayer-122121',
        'BMWG.DE':'/aktien/bayerische-motoren-werke-119092',
        'CBKG.DE':'/aktien/commerzbank-122105',
        'DAIGn.DE':'/aktien/mercedes-benz-119102',
        'DBKGn.DE':'/aktien/deutsche-bank-118687',
        'DPWGn.DE':'/aktien/deutsche-post-122006',
        'EONGn.DE':'/aktien/eon-121955',
        'IFXGn.DE':'/aktien/infineon-technologies-121679',
        'LHAG.DE':'/aktien/deutsche-lufthansa-118817',
        'MUVGn.DE':'/aktien/muenchener-rueckvers-ges-122030',
        'RWEG.DE':'/aktien/rwe-121684',
        'SAPG.DE':'/aktien/sap-de0007164600-121676',
        'SIEGn.DE':'/aktien/siemens-de0007236101-122118',
        'VNAn.DE':'/aktien/vonovia-13244731',
        'VOWG_p.DE':'/aktien/volkswagen-vorzugsaktien-118955',
        // === EU Aktien ===
        'AIR.PA':'/aktien/airbus-120560',
        'BNPP.PA':'/aktien/bnp-paribas-120960',
        'LVMH.PA':'/aktien/lvmh-moet-hennessy-louis-vuitton-120940',
        'OREP.PA':'/aktien/l-oreal-121288',
        'TOTF.PA':'/aktien/totalenergies-fr0000120271-123358',
        'SAN.MC':'/aktien/banco-santander-120947',
        'IBE.MC':'/aktien/iberdrola-468979',
        // === US Aktien (.OQ) ===
        'A.OQ':'/aktien/agilent-technologies-119224',
        'AAPL.OQ':'/aktien/apple-121472',
        'ABBV.OQ':'/aktien/abbvie-12451473',
        'ABNB.OQ':'/aktien/airbnb-47353146',
        'ABT.OQ':'/aktien/abbott-laboratories-120441',
        'ACN.OQ':'/aktien/accenture-3130033',
        'ADBE.OQ':'/aktien/adobe-121484',
        'ADI.OQ':'/aktien/analog-devices-120996',
        'ADM.OQ':'/aktien/archer-daniels-midland-120658',
        'ADP.OQ':'/aktien/automatic-data-processing-120759',
        'ADSK.OQ':'/aktien/autodesk-120849',
        'AES.OQ':'/aktien/aes-121212',
        'AFL.OQ':'/aktien/aflac-121000',
        'AMAT.OQ':'/aktien/applied-materials-121594',
        'AMD.OQ':'/aktien/advanced-micro-devices-118914',
        'AMGN.OQ':'/aktien/amgen-120952',
        'AMP.OQ':'/aktien/ameriprise-financial-119367',
        'AMT.OQ':'/aktien/american-tower-us03027x1000-9596745',
        'AMZN.OQ':'/aktien/amazon-119109',
        'ANET.OQ':'/aktien/arista-networks-registered-shares-new-on-15385417',
        'APD.OQ':'/aktien/air-products-and-chemicals-126143',
        'APH.OQ':'/aktien/amphenol-132785',
        'ARM.OQ':'/aktien/arm-holdings-adr-65657404',
        'ASML.OQ':'/aktien/asml-adr-usa-12516743',
        'AVGO.OQ':'/aktien/broadcom-3042409',
        'AXON.OQ':'/aktien/axon-enterprise-122623',
        'AZO.OQ':'/aktien/autozone-127751',
        'BALL.OQ':'/aktien/ball-127207',
        'BAX.OQ':'/aktien/baxter-international-122073',
        'BDX.OQ':'/aktien/becton-dickinson-126136',
        'BIIB.OQ':'/aktien/biogen-inc-131735',
        'BKR.OQ':'/aktien/baker-hughes-25592016',
        'BKNG.OQ':'/aktien/booking-holdings-122694',
        'BLDR.OQ':'/aktien/builders-firstsource-1033021',
        'BMY.OQ':'/aktien/bristol-myers-squibb-120529',
        'BSX.OQ':'/aktien/boston-scientific-120314',
        'BX.OQ':'/aktien/blackstone-group-343687',
        'CAH.OQ':'/aktien/cardinal-health-126807',
        'CARR.OQ':'/aktien/carrier-global-39887778',
        'CB.OQ':'/aktien/chubb-ch0044328745-125431',
        'CBOE.OQ':'/aktien/cboe-global-markets-4774325',
        'CBRE.OQ':'/aktien/cbre-group-9050603',
        'CCL.OQ':'/aktien/carnival-pa1436583006-127537',
        'CEG.OQ':'/aktien/constellation-energy-53781170',
        'CF.OQ':'/aktien/cf-industries-128351',
        'CHTR.OQ':'/aktien/charter-communications-6379384',
        'CI.OQ':'/aktien/cigna-group-the-127307',
        'CMCSA.OQ':'/aktien/comcast-us20030n1019-1521027',
        'COF.OQ':'/aktien/capital-one-financial-126361',
        'COST.OQ':'/aktien/costco-wholesale-120602',
        'CPRT.OQ':'/aktien/copart-132228',
        'CRWD.OQ':'/aktien/crowdstrike-35356723',
        'CSCO.OQ':'/aktien/cisco-systems-121948',
        'CSGP.OQ':'/aktien/costar-group-120263',
        'CSX.OQ':'/aktien/csx-121182',
        'CTAS.OQ':'/aktien/cintas-119823',
        'CTSH.OQ':'/aktien/cognizant-technology-sol-119378',
        'DDOG.OQ':'/aktien/datadog-36982184',
        'DXCM.OQ':'/aktien/dexcom-130249',
        'EXC.OQ':'/aktien/exelon-121625',
        'FANG.OQ':'/aktien/diamondback-energy-12558066',
        'FAST.OQ':'/aktien/fastenal-121395',
        'FTNT.OQ':'/aktien/fortinet-3841905',
        'GEHC.OQ':'/aktien/ge-healthcare-technologies-60655751',
        'GILD.OQ':'/aktien/gilead-sciences-120820',
        'GOOG.OQ':'/aktien/alphabet-us02079k1079-15001883',
        'GOOGL.OQ':'/aktien/alphabet-us02079k3059-122698',
        'IDXX.OQ':'/aktien/idexx-laboratories-1034851',
        'INTC.OQ':'/aktien/intel-119850',
        'INTU.OQ':'/aktien/intuit-119830',
        'ISRG.OQ':'/aktien/intuitive-surgical-118724',
        'KDP.OQ':'/aktien/keurig-dr-pepper-1077879',
        'KHC.OQ':'/aktien/kraft-heinz-us5007541064-18717313',
        'KLAC.OQ':'/aktien/kla-121893',
        'LRCX.OQ':'/aktien/lam-research-registered-shares-new-on-118479',
        'MAR.OQ':'/aktien/marriott-international-127385',
        'MCHP.OQ':'/aktien/microchip-technology-120784',
        'MDLZ.OQ':'/aktien/mondelez-international-11755800',
        'MELI.OQ':'/aktien/mercadolibre-400961',
        'META.OQ':'/aktien/meta-platforms-10720222',
        'MNST.OQ':'/aktien/monster-beverage-new-9660391',
        'MPWR.OQ':'/aktien/monolithic-power-systems-1035525',
        'MRVL.OQ':'/aktien/marvell-technology-grp-120415',
        'MSFT.OQ':'/aktien/microsoft-121429',
        'MU.OQ':'/aktien/micron-technology-120843',
        'NFLX.OQ':'/aktien/netflix-119122',
        'NVDA.OQ':'/aktien/nvidia-121019',
        'NXPI.OQ':'/aktien/nxp-semiconductors-5191665',
        'ODFL.OQ':'/aktien/old-dominion-freight-line-1035875',
        'ORLY.OQ':'/aktien/oreilly-automotive-new-5587197',
        'PCAR.OQ':'/aktien/paccar-120831',
        'PANW.OQ':'/aktien/palo-alto-networks-12593690',
        'PAYX.OQ':'/aktien/paychex-120864',
        'PDD.OQ':'/aktien/pdd-30731070',
        'PYPL.OQ':'/aktien/paypal-18720545',
        'QCOM.OQ':'/aktien/qualcomm-121329',
        'REGN.OQ':'/aktien/regeneron-pharmaceuticals-120755',
        'ROP.OQ':'/aktien/roper-technologies-129854',
        'ROST.OQ':'/aktien/ross-stores-121600',
        'SBUX.OQ':'/aktien/starbucks-121306',
        'SHW.OQ':'/aktien/sherwin-williams-696567',
        'SNPS.OQ':'/aktien/synopsys-120531',
        'TSLA.OQ':'/aktien/tesla-4852961',
        'TTWO.OQ':'/aktien/take-two-interactive-softw-126013',
        'UNH.OQ':'/aktien/unitedhealth-group-126419',
        'VRSK.OQ':'/aktien/verisk-analytics-3367535',
        'VRTX.OQ':'/aktien/vertex-pharmaceuticals-119208',
        'WBD.OQ':'/aktien/warner-bros-discovery-125092',
        'WDC.OQ':'/aktien/western-digital-120902',
        'ZS.OQ':'/aktien/zscaler-28935397',
        // === US Aktien (.N) ===
        'AEP.N':'/aktien/american-electric-power-120942',
        'AIG.N':'/aktien/american-international-grp-2755891',
        'ALL.N':'/aktien/allstate-128753',
        'AXP.N':'/aktien/american-express-121473',
        'BA.N':'/aktien/boeing-121471',
        'BAC.N':'/aktien/bank-of-america-121038',
        'BBY.N':'/aktien/best-buy-120198',
        'BLK.N':'/aktien/blackrock-funding-registered-shares-on-1842331',
        'BRKb.N':'/aktien/berkshire-hathaway-us0846707026-3896369',
        'C.N':'/aktien/citigroup-120808',
        'CAT.N':'/aktien/caterpillar-121560',
        'CMG.N':'/aktien/chipotle-mexican-grill-129638',
        'CNC.N':'/aktien/centene-4086445',
        'CRM.N':'/aktien/salesforce-122349',
        'CVX.N':'/aktien/chevron-121813',
        'DIS.N':'/aktien/disney-the-walt-121626',
        'GS.N':'/aktien/goldman-sachs-group-119083',
        'HD.N':'/aktien/home-depot-120928',
        'HON.N':'/aktien/honeywell-international-121441',
        'IBM.N':'/aktien/intl-business-machines-121205',
        'JNJ.N':'/aktien/johnson-and-johnson-121213',
        'JPM.N':'/aktien/jpmorgan-chase-120971',
        'KO.N':'/aktien/coca-cola-121664',

        'MCD.N':'/aktien/mcdonalds-121618',
        'MRK.N':'/aktien/merck-and--new-3531853',
        'MMM.N':'/aktien/3m-121334',
        'MO.N':'/aktien/altria-group-121628',
        'NKE.N':'/aktien/nike-119231',
        'PEP.N':'/aktien/pepsico-121458',
        'PG.N':'/aktien/procter-and-gamble-121408',
        'PLTR.N':'/aktien/palantir-technologies-45205653',
        'SCHW.N':'/aktien/charles-schwab-119453',
        'SHOP.N':'/aktien/shopify-18327425',
        'SQ.N':'/aktien/block-20110371',
        'T.N':'/aktien/at-and-t-123987',
        'TMUS.N':'/aktien/t-mobile-us-12815235',
        'V.N':'/aktien/visa-935439',
        'VZ.N':'/aktien/verizon-communications-120888',
        'WMT.N':'/aktien/walmart-120544',
        // === US Aktien (.O) ===
        'EA.O':'/aktien/electronic-arts-121036',
        'TXN.O':'/aktien/texas-instruments-121805',
    };
    return S3[sym] ? 'https://stock3.com' + S3[sym] : '';
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
        // Sort each wedge's images: newest first (entry/latest before detect)
        const order = { 'display_photo': 4, 'latest': 3, 'entry': 2, 'detect': 1 };
        Object.values(byWedge).forEach(arr => {
            arr.sort((a, b) => (order[b.type] || 0) - (order[a.type] || 0));
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
function signalLogo(sym) {
    const clean = sym.replace(/\.(OQ|N|DE|L|PA|MI|MC|AS|BR|HK|T|AX|SW|CO|HE|ST|OL|VX)$/i, '')
        .replace(/G$/, ''); // SAPG->SAP, ALVG->ALV etc
    const fb = clean.substring(0, 2);
    return `<img style="width:28px;height:28px;border-radius:50%;object-fit:contain;background:rgba(255,255,255,.08);margin-right:8px;vertical-align:middle;" src="https://assets.parqet.com/logos/symbol/${clean}" alt="" onerror="this.outerHTML='<span style=\\'display:inline-flex;width:28px;height:28px;border-radius:50%;background:rgba(255,255,255,.06);color:var(--text-muted);align-items:center;justify-content:center;font-size:10px;font-weight:700;vertical-align:middle;margin-right:8px;\\'>${fb}</span>'">`;
}

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
                <div style="display:flex;align-items:center;">
                    ${signalLogo(s.symbol)}
                    <div>
                        <div class="signal-symbol">${name}</div>
                        <div class="signal-name">${s.symbol} &middot; ${s.timeframe || '--'}</div>
                    </div>
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
                ${getStock3Url(s.symbol) ? `<a href="${getStock3Url(s.symbol)}" target="_blank" rel="noopener" style="color: var(--accent); text-decoration: none;" onclick="event.stopPropagation()">Chart &rarr;</a>` : ''}
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
                <div style="display:flex;align-items:center;">
                    ${signalLogo(s.symbol)}
                    <div>
                        <div class="signal-symbol">${name}</div>
                        <div class="signal-name">${s.symbol} &middot; ${s.timeframe || '--'}</div>
                    </div>
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
