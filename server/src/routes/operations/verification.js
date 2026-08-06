import express from 'express';

import { requireAuth } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

import {
    getVerificationRequests,
    getVerificationRequest,
    updateVerificationStatusWithAudit,
} from '../../services/operations/verification.service.js';
import {
    logOperation,
} from '../../services/operations/operations-audit.service.js';

import {
    successResponse,
    errorResponse,
} from '../../utils/response.js';

const router = express.Router();

router.use(requireAuth);
router.use(requireAdmin);

router.get('/requests', async (req, res) => {
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

        const status = req.query.status ?? 'pending';
        const type = req.query.type ?? null;
        const search = req.query.search?.trim() ?? '';
        const data = await getVerificationRequests({
            page,
            limit,
            status,
            type,
            search,
        });


        return successResponse(
            res,
            data,
            'Verification requests fetched successfully.'
        );
    } catch (err) {
        console.error(err);

        return errorResponse(
            res,
            'Unable to fetch verification requests.',
            'VERIFICATION_FETCH_FAILED',
            500
        );
    }
});
router.get('/:id', async (req, res) => {
    try {

        const request = await getVerificationRequest(
            req.params.id
        );

        if (!request) {
            return errorResponse(
                res,
                'Verification request not found.',
                'NOT_FOUND',
                404
            );
        }

        return successResponse(
            res,
            request,
            'Verification request fetched successfully.'
        );

    } catch (err) {

        console.error(err);

        return errorResponse(
            res,
            'Unable to fetch verification request.',
            'FETCH_FAILED',
            500
        );

    }
});
router.put('/:id/approve', async (req, res) => {
    try {

        const verification =
            await updateVerificationStatusWithAudit({
                verificationId: req.params.id,
                status: 'approved',
                adminProfileId: req.user.id,
                req,
                logOperation,
            });

        if (!verification) {
            return errorResponse(
                res,
                'Verification request not found.',
                'NOT_FOUND',
                404
            );
        }



        return successResponse(
            res,
            verification,
            'Verification approved successfully.'
        );

    } catch (err) {

        console.error(err);

        return errorResponse(
            res,
            'Unable to approve verification.',
            'APPROVE_FAILED',
            500
        );

    }
});
router.put('/:id/reject', async (req, res) => {
    try {

        const { reason } = req.body;

        if (!reason || !reason.trim()) {
            return errorResponse(
                res,
                'A rejection reason is required.',
                'REJECTION_REASON_REQUIRED',
                400
            );
        }

        const verification =
            await updateVerificationStatusWithAudit({
                verificationId: req.params.id,
                status: 'rejected',
                reason,
                adminProfileId: req.user.id,
                req,
                logOperation,
            });

        if (!verification) {
            return errorResponse(
                res,
                'Verification request not found.',
                'NOT_FOUND',
                404
            );
        }

        return successResponse(
            res,
            verification,
            'Verification rejected successfully.'
        );

    } catch (err) {

        console.error(err);

        return errorResponse(
            res,
            'Unable to reject verification.',
            'REJECT_FAILED',
            500
        );

    }
});
export default router;