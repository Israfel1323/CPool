import express from 'express';
import multer from 'multer';
import { query } from '../db/pool.js';

import { uploadStudentId } from '../services/storage.js';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024,
  },
});
router.get(
  '/status',
  requireAuth,
  async (req, res) => {
    try {
      const result = await query(
        `
        SELECT
          institution_name,
          status,
          created_at,
          reviewed_at,
          rejection_reason,
          id_card_url
        FROM verification_requests
        WHERE profile_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        `,
        [req.user.id],
      );

      if (result.rows.length === 0) {
        return res.json({
          status: 'none',
        });
      }

      return res.json(result.rows[0]);
    } catch (err) {
      console.error(err);

      return res.status(500).json({
        error: err.message,
      });
    }
  },
);
router.post(
  '/upload',
  requireAuth,
  upload.single('idCard'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          error: 'No file uploaded.',
        });
      }
      const existing = await query(
  `
  SELECT id
  FROM verification_requests
  WHERE profile_id = $1
    AND status = 'pending'
  LIMIT 1
  `,
  [req.user.id],
);

if (existing.rows.length > 0) {
  return res.status(409).json({
    success: false,
    status: 'pending',
    message:
      'Your identity verification has already been submitted and is currently under review. No further action is required.',
  });
}

      const filePath = await uploadStudentId(
        req.file.buffer,
        req.file.originalname,
        req.file.mimetype,
        req.user.id,
      );
await query(
  `
  INSERT INTO verification_requests
  (
    profile_id,
    institution_name,
    id_card_url,
    status
  )
  VALUES
  (
    $1,
    $2,
    $3,
    'pending'
  )
  `,
  [
    req.user.id,
    'MGIT', // temporary default
    filePath,
  ],
);
     return res.json({
  success: true,
  status: 'pending',
  filePath,
  message: 'Your identity verification has been submitted successfully. Our team will review it within 24–48 hours.',
});
    } catch (err) {
      console.error(err);

      return res.status(500).json({
        error: err.message,
      });
    }
  },
);

export default router;