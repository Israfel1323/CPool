import express from 'express';

import { requireAuth } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

import { getAuditLogs } from '../../services/operations/audit.service.js';

import {
    successResponse,
    errorResponse,
} from '../../utils/response.js';

const router = express.Router();

router.use(requireAuth);
router.use(requireAdmin);

router.get('/', async (req, res) => {
    try {

        const page = Math.max(
            1,
            Number(req.query.page ?? 1)
        );

        const limit = Math.min(
            100,
            Math.max(
                1,
                Number(req.query.limit ?? 20)
            )
        );

        const logs = await getAuditLogs({
            page,
            limit,
        });

        return successResponse(
            res,
            logs,
            'Audit logs fetched successfully.'
        );

    } catch (err) {

        console.error(err);

        return errorResponse(
            res,
            'Unable to fetch audit logs.',
            'AUDIT_FETCH_FAILED',
            500
        );

    }
});

export default router;