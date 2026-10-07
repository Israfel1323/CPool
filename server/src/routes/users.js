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

  try {
    // Existing CPool profile row = existing user.
    // profile_completed is only the completion state, not the initial
    // old-user/new-user routing signal.
    const existing = await query(
      `SELECT 1 FROM profiles WHERE id = $1 LIMIT 1`,
      [u.id],
    );

    const isNewProfile = existing.rowCount === 0;
    let result;

    if (isNewProfile) {
      result = await query(
        `INSERT INTO profiles (
           id, email, display_name, full_name, avatar_url
         )
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [
          u.id,
          u.email,
          displayName,
          displayName,
          u.user_metadata?.avatar_url ?? null,
        ],
      );
    } else {
      result = await query(
        `UPDATE profiles
         SET email = $2,
             display_name = COALESCE(profiles.display_name, $3),
             full_name = COALESCE(profiles.full_name, $4),
             avatar_url = COALESCE($5, profiles.avatar_url),
             updated_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [
          u.id,
          u.email,
          displayName,
          displayName,
          u.user_metadata?.avatar_url ?? null,
        ],
      );
    }

    return res.json({
      profile: result.rows[0],
      isNewProfile,
    });
  } catch (err) {
    console.error('Profile sync failed:', err);
    return res.status(500).json({
      error: 'Unable to sync profile.',
    });
  }
});

router.get('/interests', requireAuth, async (_req, res) => {
  const result = await query(
    `SELECT id, name, category, icon, display_order
     FROM interests
     ORDER BY display_order ASC, name ASC`,
  );

  res.json({ interests: result.rows });
});

router.get('/me', requireAuth, async (req, res) => {
  const result = await query('SELECT * FROM profiles WHERE id = $1', [req.user.id]);
  if (!result.rows[0]) {
    return res.status(404).json({ error: 'Profile not found. Call POST /users/sync first.' });
  }

  const interestsResult = await query(
    `SELECT i.id, i.name, i.category, i.icon, i.display_order
     FROM profile_interests pi
     JOIN interests i ON i.id = pi.interest_id
     WHERE pi.profile_id = $1
     ORDER BY i.display_order ASC, i.name ASC`,
    [req.user.id],
  );

  res.json({
    profile: {
      ...result.rows[0],
      interests: interestsResult.rows,
    },
  });
});

router.patch('/me', requireAuth, async (req, res) => {
  const {
    full_name,
    phone_number,
    institution_name,
    branch,
    roll_number,
    admission_year,
    gender,
    avatar_url,
    interests,
  } = req.body;

  if (interests !== undefined) {
    if (!Array.isArray(interests)) {
      return res.status(400).json({
        error: 'interests must be an array',
        code: 'INVALID_INTERESTS',
      });
    }

    const uniqueInterestIds = [...new Set(
      interests.map((id) => Number(id)),
    )];

    if (
      uniqueInterestIds.some(
        (id) => !Number.isInteger(id) || id <= 0,
      )
    ) {
      return res.status(400).json({
        error: 'interests must contain valid interest IDs',
        code: 'INVALID_INTEREST_IDS',
      });
    }

    if (uniqueInterestIds.length > 7) {
      return res.status(400).json({
        error: 'You can select up to 7 interests',
        code: 'INTEREST_LIMIT_EXCEEDED',
      });
    }

    const validInterests = await query(
      `SELECT id
       FROM interests
       WHERE id = ANY($1::bigint[])`,
      [uniqueInterestIds],
    );

    if (validInterests.rows.length !== uniqueInterestIds.length) {
      return res.status(400).json({
        error: 'One or more selected interests do not exist',
        code: 'INVALID_INTEREST_IDS',
      });
    }

    const client = await (await import('../db/pool.js')).getPool().connect();

    try {
      await client.query('BEGIN');

      const profileResult = await client.query(
        `UPDATE profiles
         SET
           display_name = COALESCE($2, display_name),
           full_name = COALESCE($2, full_name),
           phone_number = COALESCE($3, phone_number),
           institution_name = COALESCE($4, institution_name),
           branch = COALESCE($5, branch),
           roll_number = COALESCE($6, roll_number),
           admission_year = COALESCE($7, admission_year),
           gender = COALESCE($8, gender),
           avatar_url = COALESCE($9, avatar_url),
           profile_completed = TRUE,
           updated_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [
          req.user.id,
          full_name,
          phone_number,
          institution_name,
          branch,
          roll_number,
          admission_year,
          gender,
          avatar_url,
        ],
      );

      if (!profileResult.rows[0]) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Profile not found.' });
      }

      await client.query(
        `DELETE FROM profile_interests
         WHERE profile_id = $1`,
        [req.user.id],
      );

      if (uniqueInterestIds.length > 0) {
        await client.query(
          `INSERT INTO profile_interests (profile_id, interest_id)
           SELECT $1, unnest($2::bigint[])`,
          [req.user.id, uniqueInterestIds],
        );
      }

      const interestsResult = await client.query(
        `SELECT i.id, i.name, i.category, i.icon, i.display_order
         FROM profile_interests pi
         JOIN interests i ON i.id = pi.interest_id
         WHERE pi.profile_id = $1
         ORDER BY i.display_order ASC, i.name ASC`,
        [req.user.id],
      );

      await client.query('COMMIT');

      return res.json({
        profile: {
          ...profileResult.rows[0],
          interests: interestsResult.rows,
        },
      });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => { });
      throw error;
    } finally {
      client.release();
    }
  }

  const result = await query(
    `UPDATE profiles
     SET
       display_name = COALESCE($2, display_name),
       full_name = COALESCE($2, full_name),
       phone_number = COALESCE($3, phone_number),
       institution_name = COALESCE($4, institution_name),
       branch = COALESCE($5, branch),
       roll_number = COALESCE($6, roll_number),
       admission_year = COALESCE($7, admission_year),
       gender = COALESCE($8, gender),
       avatar_url = COALESCE($9, avatar_url),
       profile_completed = TRUE,
       updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [
      req.user.id,
      full_name,
      phone_number,
      institution_name,
      branch,
      roll_number,
      admission_year,
      gender,
      avatar_url,
    ],
  );

  res.json({ profile: result.rows[0] });
});

export default router;
