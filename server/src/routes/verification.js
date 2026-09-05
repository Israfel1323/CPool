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

/**
 * Get verification status.
 *
 * Example:
 * GET /verification/status?type=student
 * GET /verification/status?type=driver
 */
router.get(
  '/status',
  requireAuth,
  async (req, res) => {
    try {
      const type = req.query.type;

      if (!type || !['student', 'driver'].includes(type)) {
        return res.status(400).json({
          success: false,
          error: 'A valid verification type is required.',
        });
      }

      const result = await query(
        `
        SELECT
          id,
          profile_id,
          verification_type,
          institution_name,
          status,
          created_at,
          reviewed_at,
          rejection_reason,
          id_card_url,
          id_card_front_url,
          id_card_back_url,
          reference_id
        FROM verification_requests
        WHERE profile_id = $1
          AND verification_type = $2
        ORDER BY created_at DESC
        LIMIT 1
        `,
        [req.user.id, type],
      );

      if (result.rows.length === 0) {
        return res.json({
          success: true,
          status: 'none',
          verification_type: type,
        });
      }

      return res.json({
        success: true,
        data: result.rows[0],
      });
    } catch (err) {
      console.error(err);

      return res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  },
);

/**
 * Submit student verification.
 *
 * Expects multipart/form-data:
 * - front
 * - back
 */
router.post(
  '/upload',
  requireAuth,
  upload.fields([
    { name: 'frontIdCard', maxCount: 1 },
    { name: 'backIdCard', maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const frontFile = req.files?.frontIdCard?.[0];
      const backFile = req.files?.backIdCard?.[0];

      if (!frontFile || !backFile) {
        return res.status(400).json({
          success: false,
          error: 'Both front and back ID card images are required.',
        });
      }

      /*
       * Check the user's existing student verification.
       */
      const existing = await query(
        `
        SELECT id, status
        FROM verification_requests
        WHERE profile_id = $1
          AND verification_type = 'student'
        LIMIT 1
        `,
        [req.user.id],
      );

      if (existing.rows.length > 0) {
        const existingRequest = existing.rows[0];

        if (existingRequest.status === 'pending') {
          return res.status(409).json({
            success: false,
            status: 'pending',
            message:
              'Your student verification has already been submitted and is currently under review.',
          });
        }

        if (existingRequest.status === 'approved') {
          return res.status(409).json({
            success: false,
            status: 'approved',
            message:
              'Your student verification has already been approved.',
          });
        }
      }

      /*
       * Upload front and back images to Supabase Storage.
       */
      const frontPath = await uploadStudentId(
        frontFile.buffer,
        frontFile.originalname,
        frontFile.mimetype,
        req.user.id,
        'front',
      );

      const backPath = await uploadStudentId(
        backFile.buffer,
        backFile.originalname,
        backFile.mimetype,
        req.user.id,
        'back',
      );

      /*
       * If a rejected request already exists, reuse it.
       * Otherwise create a new verification request.
       */
      if (existing.rows.length > 0) {
        const existingRequest = existing.rows[0];

        await query(
          `
          UPDATE verification_requests
          SET
            institution_name = $1,
            id_card_url = $2,
            id_card_front_url = $3,
            id_card_back_url = $4,
            status = 'pending',
            reviewed_by = NULL,
            reviewed_at = NULL,
            rejection_reason = NULL,
            updated_at = NOW()
          WHERE id = $5
          `,
          [
            'MGIT',
            frontPath,
            frontPath,
            backPath,
            existingRequest.id,
          ],
        );
      } else {
        await query(
          `
          INSERT INTO verification_requests
          (
            profile_id,
            institution_name,
            id_card_url,
            id_card_front_url,
            id_card_back_url,
            verification_type,
            status
          )
          VALUES
          (
            $1,
            $2,
            $3,
            $4,
            $5,
            'student',
            'pending'
          )
          `,
          [
            req.user.id,
            'MGIT',
            frontPath,
            frontPath,
            backPath,
          ],
        );
      }

      return res.json({
        success: true,
        status: 'pending',
        verification_type: 'student',
        frontPath,
        backPath,
        message:
          'Your student verification has been submitted successfully.',
      });
    } catch (err) {
      console.error(err);

      return res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  },
);

export default router;