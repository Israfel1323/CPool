import { Router } from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.use(requireAuth);

const clean = (value) =>
    typeof value === 'string' ? value.trim() : '';

/**
 * Get the current user's emergency contacts.
 */
router.get('/', async (req, res) => {
    try {
        const result = await query(
            `SELECT id, name, phone_number, relationship,
              created_at, updated_at
       FROM emergency_contacts
       WHERE user_id = $1
       ORDER BY created_at ASC`,
            [req.user.id],
        );

        return res.json({
            contacts: result.rows,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({
            error: 'Unable to fetch emergency contacts.',
        });
    }
});

/**
 * Add an emergency contact.
 * Maximum 2 contacts per user.
 */
router.post('/', async (req, res) => {
    try {
        const name = clean(req.body?.name);
        const phoneNumber = clean(req.body?.phone_number);
        const relationship = clean(req.body?.relationship) || null;

        if (!name) {
            return res.status(400).json({
                error: 'Contact name is required.',
            });
        }

        if (!phoneNumber) {
            return res.status(400).json({
                error: 'Contact phone number is required.',
            });
        }

        if (name.length > 100) {
            return res.status(400).json({
                error: 'Contact name is too long.',
            });
        }

        if (phoneNumber.length > 30) {
            return res.status(400).json({
                error: 'Contact phone number is invalid.',
            });
        }

        if (relationship && relationship.length > 50) {
            return res.status(400).json({
                error: 'Relationship is too long.',
            });
        }

        const count = await query(
            `SELECT COUNT(*)::int AS count
       FROM emergency_contacts
       WHERE user_id = $1`,
            [req.user.id],
        );

        if (count.rows[0].count >= 2) {
            return res.status(409).json({
                error: 'You can have a maximum of 2 emergency contacts.',
            });
        }

        const result = await query(
            `INSERT INTO emergency_contacts
          (user_id, name, phone_number, relationship)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, phone_number, relationship,
                 created_at, updated_at`,
            [
                req.user.id,
                name,
                phoneNumber,
                relationship,
            ],
        );

        return res.status(201).json({
            contact: result.rows[0],
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({
            error: 'Unable to add emergency contact.',
        });
    }
});

/**
 * Update an emergency contact belonging to the current user.
 */
router.patch('/:id', async (req, res) => {
    try {
        const name = clean(req.body?.name);
        const phoneNumber = clean(req.body?.phone_number);
        const relationship = clean(req.body?.relationship) || null;

        if (!name) {
            return res.status(400).json({
                error: 'Contact name is required.',
            });
        }

        if (!phoneNumber) {
            return res.status(400).json({
                error: 'Contact phone number is required.',
            });
        }

        if (name.length > 100) {
            return res.status(400).json({
                error: 'Contact name is too long.',
            });
        }

        if (phoneNumber.length > 30) {
            return res.status(400).json({
                error: 'Contact phone number is invalid.',
            });
        }

        if (relationship && relationship.length > 50) {
            return res.status(400).json({
                error: 'Relationship is too long.',
            });
        }

        const result = await query(
            `UPDATE emergency_contacts
       SET name = $1,
           phone_number = $2,
           relationship = $3,
           updated_at = NOW()
       WHERE id = $4
         AND user_id = $5
       RETURNING id, name, phone_number, relationship,
                 created_at, updated_at`,
            [
                name,
                phoneNumber,
                relationship,
                req.params.id,
                req.user.id,
            ],
        );

        if (result.rowCount === 0) {
            return res.status(404).json({
                error: 'Emergency contact not found.',
            });
        }

        return res.json({
            contact: result.rows[0],
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({
            error: 'Unable to update emergency contact.',
        });
    }
});

/**
 * Delete an emergency contact belonging to the current user.
 */
router.delete('/:id', async (req, res) => {
    try {
        const result = await query(
            `DELETE FROM emergency_contacts
       WHERE id = $1
         AND user_id = $2
       RETURNING id`,
            [req.params.id, req.user.id],
        );

        if (result.rowCount === 0) {
            return res.status(404).json({
                error: 'Emergency contact not found.',
            });
        }

        return res.json({
            message: 'Emergency contact deleted successfully.',
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({
            error: 'Unable to delete emergency contact.',
        });
    }
});

export default router;