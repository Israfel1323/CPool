import { createClient } from '@supabase/supabase-js';

let supabaseAdmin;

function getSupabaseAdmin() {
  if (!supabaseAdmin) {
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) {
      throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY required');
    }
    supabaseAdmin = createClient(url, key, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
  }
  return supabaseAdmin;
}

/** Verifies Supabase JWT and attaches req.user */
export async function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization token' });
  }

  const token = header.slice(7);
  try {
    const { data, error } = await getSupabaseAdmin().auth.getUser(token);
    console.log('AUTH ERROR:', error);
    console.log('AUTH USER:', data?.user?.email);
    if (error || !data.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    req.user = data.user;
    next();
  } catch {
    return res.status(401).json({ error: 'Authentication failed' });
  }
}

/** Optional auth — sets req.user when token present */
export async function optionalAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return next();
  }
  const token = header.slice(7);
  try {
    const { data } = await getSupabaseAdmin().auth.getUser(token);
    if (data?.user) req.user = data.user;
  } catch {
    /* ignore */
  }
  next();
}
