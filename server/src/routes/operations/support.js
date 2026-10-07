import express from 'express';

import { requireAuth } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

import {
    getSupportTickets,
    getSupportTicket,
    replyToSupportTicket,
    resolveSupportTicket,
} from '../../services/operations/support.service.js';

import { logOperation } from '../../services/operations/operations-audit.service.js';

import {
    successResponse,
    errorResponse,
} from '../../utils/response.js';

const router = express.Router();

router.use(requireAuth);
router.use(requireAdmin);

router.get('/tickets', async (req, res) => {
    try {
        const page = Math.max(1, Number(req.query.page ?? 1));
        const limit = Math.min(100, Math.max(1, Number(req.query.limit ?? 20)));
        const status = req.query.status ?? 'open';
        const search = req.query.search?.trim() ?? '';

        if (!['open', 'resolved', 'all'].includes(status)) {
            return errorResponse(res, 'Invalid support ticket status.', 'INVALID_SUPPORT_STATUS', 400);
        }

        const data = await getSupportTickets({ page, limit, status, search });
        return successResponse(res, data, 'Support tickets fetched successfully.');
    } catch (err) {
        console.error(err);
        return errorResponse(res, 'Unable to fetch support tickets.', 'SUPPORT_FETCH_FAILED', 500);
    }
});

router.get('/tickets/:id', async (req, res) => {
    try {
        const data = await getSupportTicket(req.params.id);
        if (!data) return errorResponse(res, 'Support ticket not found.', 'NOT_FOUND', 404);
        return successResponse(res, data, 'Support ticket fetched successfully.');
    } catch (err) {
        console.error(err);
        return errorResponse(res, 'Unable to fetch support ticket.', 'SUPPORT_TICKET_FETCH_FAILED', 500);
    }
});

router.post('/tickets/:id/reply', async (req, res) => {
    try {
        const message = req.body?.message;
        if (!message || !message.trim()) {
            return errorResponse(res, 'A reply message is required.', 'MESSAGE_REQUIRED', 400);
        }

        const data = await replyToSupportTicket({
            ticketId: req.params.id,
            adminProfileId: req.user.id,
            message,
        });

        if (!data) return errorResponse(res, 'Support ticket not found.', 'NOT_FOUND', 404);
        return successResponse(res, data, 'Support reply added successfully.');
    } catch (err) {
        console.error(err);
        if (err.message === 'TICKET_RESOLVED') {
            return errorResponse(res, 'Resolved tickets cannot receive new replies.', 'TICKET_RESOLVED', 409);
        }
        return errorResponse(res, 'Unable to add support reply.', 'SUPPORT_REPLY_FAILED', 500);
    }
});

router.put('/tickets/:id/resolve', async (req, res) => {
    try {
        const data = await resolveSupportTicket({
            ticketId: req.params.id,
            adminProfileId: req.user.id,
            req,
            logOperation,
        });

        if (!data) return errorResponse(res, 'Support ticket not found.', 'NOT_FOUND', 404);
        return successResponse(res, data, 'Support ticket resolved successfully.');
    } catch (err) {
        console.error(err);
        if (err.message === 'TICKET_ALREADY_RESOLVED') {
            return errorResponse(res, 'Support ticket is already resolved.', 'TICKET_ALREADY_RESOLVED', 409);
        }
        return errorResponse(res, 'Unable to resolve support ticket.', 'SUPPORT_RESOLVE_FAILED', 500);
    }
});

export default router;
