const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://ufqglmqiuyasszieprsr.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const data = req.body;
    if (!data.wedgeId || !data.imageBase64) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const imageBuffer = Buffer.from(data.imageBase64, 'base64');
    const timestamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0];
    const imagePath = `${data.market}/${data.timeframe}/${data.wedgeId}/v_${timestamp}.png`;

    await supabase.storage.from('signals').upload(imagePath, imageBuffer, {
      contentType: 'image/png',
      upsert: true
    });

    const { data: urlData } = supabase.storage.from('signals').getPublicUrl(imagePath);

    const signalData = {
      wedge_id: data.wedgeId,
      symbol: data.symbol,
      symbol_name: data.symbolName || data.symbol,
      market: data.market,
      timeframe: data.timeframe,
      direction: data.direction,
      entry_price: parseFloat(data.entry) || 0,
      sl: parseFloat(data.sl) || 0,
      tp1: parseFloat(data.tp1) || 0,
      tp2: parseFloat(data.tp2) || 0,
      tp3: parseFloat(data.tp3) || 0,
      image_path: urlData.publicUrl,
      created_at: new Date().toISOString()
    };

    const { data: existing } = await supabase
      .from('signals')
      .select('id')
      .eq('wedge_id', data.wedgeId)
      .single();

    if (existing) {
      await supabase.from('signals').update(signalData).eq('wedge_id', data.wedgeId);
    } else {
      await supabase.from('signals').insert([signalData]);
    }

    return res.status(200).json({ success: true, wedgeId: data.wedgeId });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
