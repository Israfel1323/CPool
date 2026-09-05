import express from 'express';

import { requireAuth } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';
import {
    createSignedStorageUrl,
} from '../../services/storage.js';

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
router.get('/:id/document/:side', async (req, res) => {
    try {
        const { id, side } = req.params;

        if (side !== 'front' && side !== 'back') {
            return errorResponse(
                res,
                'Invalid document side.',
                'INVALID_DOCUMENT_SIDE',
                400,
            );
        }

        const request = await getVerificationRequest(id);

        if (!request) {
            return errorResponse(
                res,
                'Verification request not found.',
                'NOT_FOUND',
                404,
            );
        }

        let documentUrl;
        let bucket;

        if (request.verification_type === 'student') {
            bucket = 'student-ids';

            documentUrl =
                side === 'front'
                    ? request.id_card_front_url
                    : request.id_card_back_url;
        } else if (request.verification_type === 'driver') {
            bucket = 'driver-licenses';

            documentUrl =
                side === 'front'
                    ? request.license_front_url
                    : request.license_back_url;
        } else {
            return errorResponse(
                res,
                'Unsupported verification type.',
                'INVALID_VERIFICATION_TYPE',
                400,
            );
        }

        if (!documentUrl) {
            return errorResponse(
                res,
                'Requested document is not available.',
                'DOCUMENT_NOT_FOUND',
                404,
            );
        }

        let filePath = documentUrl;

        // Driver documents may be stored as a public Supabase URL.
        // Student documents are stored directly as storage paths.
        if (documentUrl.startsWith('http')) {
            const marker =
                `/storage/v1/object/public/${bucket}/`;

            const markerIndex = documentUrl.indexOf(marker);

            if (markerIndex === -1) {
                return errorResponse(
                    res,
                    'Stored document path is invalid.',
                    'INVALID_DOCUMENT_PATH',
                    500,
                );
            }

            filePath = documentUrl.substring(
                markerIndex + marker.length,
            );
        }

        const signedUrl = await createSignedStorageUrl(
            bucket,
            filePath,
            300,
        );

        return successResponse(
            res,
            {
                url: signedUrl,
                expiresIn: 300,
                side,
                verificationType: request.verification_type,
            },
            'Document URL generated successfully.',
        );
    } catch (err) {
        console.error(err);

        return errorResponse(
            res,
            'Unable to generate document URL.',
            'DOCUMENT_URL_FAILED',
            500,
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