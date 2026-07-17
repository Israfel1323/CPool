import { Router } from 'express';

const router = Router();
const cache = new Map();

const NOMINATIM = 'https://nominatim.openstreetmap.org';

function userAgent() {
  return process.env.NOMINATIM_USER_AGENT ?? 'CPool/1.0';
}

/** Proxy search — respects Nominatim usage policy via server User-Agent */
router.get('/search', async (req, res) => {
  const q = req.query.q;
  if (!q || String(q).trim().length < 2) {
    return res.status(400).json({ error: 'Query q must be at least 2 characters' });
  }
  const cacheKey = String(q).trim().toLowerCase();
  
  if (cache.has(cacheKey)) {
    return res.json({
      results: cache.get(cacheKey),
    });
  }

  const limit = Math.min(Number(req.query.limit) || 5, 10);
  const url = new URL(`${NOMINATIM}/search`);
  url.searchParams.set('q', String(q).trim());

url.searchParams.set('format', 'json');
url.searchParams.set('addressdetails', '1');
url.searchParams.set('limit', String(limit));

url.searchParams.set('countrycodes', 'in');

url.searchParams.set(
  'viewbox',
  '78.2180,17.6090,78.6858,17.2015'
);

url.searchParams.set('bounded', '1');

  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': userAgent(), Accept: 'application/json' },
    });
    if (!response.ok) {
      return res.status(response.status).json({ error: 'Geocoding service error' });
    }
    const data = await response.json();
    
    const results = data.map((item) => ({
      
      display_name: item.display_name,
      lat: parseFloat(item.lat),
      lon: parseFloat(item.lon),
      type: item.type,
      importance: item.importance,
      
    }));
    cache.set(cacheKey, results);
    res.json({ results });
  } catch (err) {
    res.status(502).json({ error: 'Geocoding failed', detail: err.message });
  }
});

router.get('/reverse', async (req, res) => {
  const lat = req.query.lat;
  const lon = req.query.lon;
  if (lat == null || lon == null) {
    return res.status(400).json({ error: 'lat and lon required' });
  }

  const url = new URL(`${NOMINATIM}/reverse`);
  url.searchParams.set('lat', String(lat));
  url.searchParams.set('lon', String(lon));
  url.searchParams.set('format', 'json');

  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': userAgent(), Accept: 'application/json' },
    });
    if (!response.ok) {
      return res.status(response.status).json({ error: 'Reverse geocoding error' });
    }
    const data = await response.json();
    res.json({
      display_name: data.display_name,
      lat: parseFloat(data.lat),
      lon: parseFloat(data.lon),
    });
  } catch (err) {
    res.status(502).json({ error: 'Reverse geocoding failed', detail: err.message });
  }
});

export default router;
