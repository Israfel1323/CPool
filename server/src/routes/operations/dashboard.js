import express from 'express';

import { requireAuth } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

import { getDashboardSummary } from '../../services/operations/dashboard.service.js';

import {
    successResponse,
    errorResponse,
} from '../../utils/response.js';

const router = express.Router();

router.use(requireAuth);
router.use(requireAdmin);

router.get('/', async (req, res) => {
    try {

        const summary = await getDashboardSummary();

        return successResponse(
            res,
            summary,
            'Dashboard summary fetched successfully.'
        );

    } catch (err) {

        console.error(err);

        return errorResponse(
            res,
            'Unable to fetch dashboard summary.',
            'DASHBOARD_FETCH_FAILED',
            500
        );

    }
});

export default router;