import express from 'express';

import { requireAuth } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

import {
    getSosAlerts,
    getSosAlert,
    resolveSosAlert,
} from '../../services/operations/sos.service.js';

import { logOperation } from '../../services/operations/operations-audit.service.js';

import {
    successResponse,
    errorResponse,
} from '../../utils/response.js';

const router = express.Router();

router.use(requireAuth);
router.use(requireAdmin);

router.get('/alerts', async (req, res) => {
    try {
        const page = Math.max(1, Number(req.query.page ?? 1));
        const limit = Math.min(100, Math.max(1, Number(req.query.limit ?? 20)));
        const status = req.query.status ?? 'active';

        if (!['active', 'resolved', 'cancelled', 'all'].includes(status)) {
            return errorResponse(
                res,
                'Invalid SOS alert status.',
                'INVALID_SOS_STATUS',
                400,
            );
        }

        const data = await getSosAlerts({
            page,
            limit,
            status,
        });

        return successResponse(
            res,
            data,
            'SOS alerts fetched successfully.',
        );
    } catch (err) {
        console.error(err);

        return errorResponse(
            res,
            'Unable to fetch SOS alerts.',
            'SOS_FETCH_FAILED',
            500,
        );
    }
});

router.get('/alerts/:id', async (req, res) => {
    try {
        const data = await getSosAlert(req.params.id);

        if (!data) {
            return errorResponse(
                res,
                'SOS alert not found.',
                'NOT_FOUND',
                404,
            );
        }

        return successResponse(
            res,
            data,
            'SOS alert fetched successfully.',
        );
    } catch (err) {
        console.error(err);

        return errorResponse(
            res,
            'Unable to fetch SOS alert.',
            'SOS_ALERT_FETCH_FAILED',
            500,
        );
    }
});

router.put('/alerts/:id/resolve', async (req, res) => {
    try {
        const data = await resolveSosAlert({
            alertId: req.params.id,
            adminProfileId: req.user.id,
            req,
            logOperation,
        });

        if (!data) {
            return errorResponse(
                res,
                'SOS alert not found.',
                'NOT_FOUND',
                404,
            );
        }

        return successResponse(
            res,
            data,
            'SOS alert resolved successfully.',
        );
    } catch (err) {
        console.error(err);

        if (err.message === 'SOS_ALREADY_RESOLVED') {
            return errorResponse(
                res,
                'SOS alert is no longer active.',
                'SOS_ALREADY_RESOLVED',
                409,
            );
        }

        return errorResponse(
            res,
            'Unable to resolve SOS alert.',
            'SOS_RESOLVE_FAILED',
            500,
        );
    }
});

export default router;