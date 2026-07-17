import { Router } from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

/** Sync Supabase user into profiles table */
router.post('/sync', requireAuth, async (req, res) => {
  const u = req.user;
  const displayName =
    u.user_metadata?.full_name ??
    u.user_metadata?.name ??
    u.email?.split('@')[0] ??
    'Rider';

  const result = await query(
    `INSERT INTO profiles (
    id,
    email,
    display_name,
    full_name,
    avatar_url
)
VALUES (
    $1,
    $2,
    $3,
    $4,
    $5
)
     ON CONFLICT (id) DO UPDATE SET
       email = EXCLUDED.email,

display_name = COALESCE(
    EXCLUDED.display_name,
    profiles.display_name
),

full_name = COALESCE(
    profiles.full_name,
    EXCLUDED.full_name
),

avatar_url = COALESCE(
    EXCLUDED.avatar_url,
    profiles.avatar_url
),

updated_at = NOW()
     RETURNING *`,
    [
  u.id,
  u.email,
  displayName,
  displayName,
  u.user_metadata?.avatar_url ?? null,
],
  );

  res.json({ profile: result.rows[0] });
});

router.get('/me', requireAuth, async (req, res) => {
  const result = await query('SELECT * FROM profiles WHERE id = $1', [req.user.id]);
  if (!result.rows[0]) {
    return res.status(404).json({ error: 'Profile not found. Call POST /users/sync first.' });
  }
  res.json({ profile: result.rows[0] });
});

router.patch('/me', requireAuth, async (req, res) => {
  const {
  full_name,
  phone_number,
  branch,
  roll_number,
  admission_year,
} = req.body;
  const result = await query(
    `UPDATE profiles
SET

full_name = COALESCE($2, full_name),

phone_number = COALESCE($3, phone_number),

branch = COALESCE($4, branch),

roll_number = COALESCE($5, roll_number),

admission_year = COALESCE($6, admission_year),

profile_completed = TRUE,

updated_at = NOW()

WHERE id = $1

RETURNING *`,
    [
  req.user.id,
  full_name,
  phone_number,
  branch,
  roll_number,
  admission_year,
],
  );
  res.json({ profile: result.rows[0] });
});

export default router;
