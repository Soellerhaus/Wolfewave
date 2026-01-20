export const config = {
  api: {
    bodyParser: {
      sizeLimit: '10mb',
    },
  },
};

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://ufqglmqiuyasszieprsr.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

// Erlaubte Origins für CORS
const ALLOWED_ORIGINS = [
  'https://wolfewavesignals.com',
  'https://www.wolfewavesignals.com',
  'http://localhost:3000'
];

// Erlaubte Werte für Validierung
const VALID_MARKETS = ['FOREX', 'CRYPTO', 'INDICES', 'STOCKS', 'COMMODITIES', 'OTHER'];
const VALID_TIMEFRAMES = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN'];
const VALID_DIRECTIONS = ['LONG', 'SHORT', ''];

function getCorsHeaders(origin) {
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function validateSignalData(data) {
  const errors = [];

  if (!data || typeof data !== 'object') {
    return ['Request body must be a valid JSON object'];
  }

  if (!data.wedgeId || typeof data.wedgeId !== 'string') {
    errors.push('wedgeId is required and must be a string');
  }

  if (data.market && !VALID_MARKETS.includes(data.market)) {
    errors.push(`market must be one of: ${VALID_MARKETS.join(', ')}`);
  }

  if (data.timeframe && !VALID_TIMEFRAMES.includes(data.timeframe)) {
    errors.push(`timeframe must be one of: ${VALID_TIMEFRAMES.join(', ')}`);
  }

  if (data.direction && !VALID_DIRECTIONS.includes(data.direction)) {
    errors.push(`direction must be one of: ${VALID_DIRECTIONS.filter(d => d).join(', ')}`);
  }

  // Preiswerte validieren (falls vorhanden)
  const priceFields = ['entry', 'sl', 'tp1', 'tp2', 'tp3'];
  for (const field of priceFields) {
    if (data[field] !== undefined && data[field] !== '') {
      const value = parseFloat(data[field]);
      if (isNaN(value) || value < 0) {
        errors.push(`${field} must be a valid positive number`);
      }
    }
  }

  return errors;
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

export default async function handler(req, res) {
  const origin = req.headers.origin || '';
  const corsHeaders = getCorsHeaders(origin);

  // CORS Headers setzen
  Object.entries(corsHeaders).forEach(([key, value]) => {
    res.setHeader(key, value);
  });

  // Preflight Request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Nur POST erlauben
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const data = req.body;

    // Eingabe validieren
    const validationErrors = validateSignalData(data);
    if (validationErrors.length > 0) {
      return res.status(400).json({
        error: 'Validation failed',
        details: validationErrors
      });
    }

    let imageUrl = '';

    // Bild hochladen falls vorhanden
    if (data.imageBase64) {
      try {
        const imageBuffer = Buffer.from(data.imageBase64, 'base64');
        const timestamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0];
        const market = data.market || 'OTHER';
        const timeframe = data.timeframe || 'H1';
        const imagePath = `${market}/${timeframe}/${data.wedgeId}/v_${timestamp}.png`;

        const { error: uploadError } = await supabase.storage
          .from('signals')
          .upload(imagePath, imageBuffer, {
            contentType: 'image/png',
            upsert: true
          });

        if (uploadError) {
          console.error('Image upload error:', uploadError);
          // Weitermachen auch wenn Bild-Upload fehlschlägt
        } else {
          const { data: urlData } = supabase.storage.from('signals').getPublicUrl(imagePath);
          imageUrl = urlData?.publicUrl || '';
        }
      } catch (imageError) {
        console.error('Image processing error:', imageError);
        // Weitermachen auch wenn Bildverarbeitung fehlschlägt
      }
    }

    // Signal-Daten vorbereiten
    const signalData = {
      wedge_id: data.wedgeId,
      symbol: data.symbol || '',
      symbol_name: data.symbolName || data.symbol || '',
      market: data.market || 'OTHER',
      timeframe: data.timeframe || 'H1',
      direction: data.direction || '',
      entry_price: parseFloat(data.entry) || 0,
      sl: parseFloat(data.sl) || 0,
      tp1: parseFloat(data.tp1) || 0,
      tp2: parseFloat(data.tp2) || 0,
      tp3: parseFloat(data.tp3) || 0,
      image_path: imageUrl,
      created_at: new Date().toISOString()
    };

    // Prüfen ob Signal bereits existiert
    const { data: existing, error: selectError } = await supabase
      .from('signals')
      .select('id')
      .eq('wedge_id', data.wedgeId)
      .maybeSingle();

    if (selectError) {
      console.error('Database select error:', selectError);
      return res.status(500).json({ error: 'Database error while checking existing signal' });
    }

    // Update oder Insert
    if (existing) {
      const { error: updateError } = await supabase
        .from('signals')
        .update(signalData)
        .eq('wedge_id', data.wedgeId);

      if (updateError) {
        console.error('Database update error:', updateError);
        return res.status(500).json({ error: 'Failed to update signal' });
      }
    } else {
      const { error: insertError } = await supabase
        .from('signals')
        .insert([signalData]);

      if (insertError) {
        console.error('Database insert error:', insertError);
        return res.status(500).json({ error: 'Failed to insert signal' });
      }
    }

    return res.status(200).json({
      success: true,
      wedgeId: data.wedgeId,
      action: existing ? 'updated' : 'created'
    });

  } catch (error) {
    console.error('Unexpected error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
