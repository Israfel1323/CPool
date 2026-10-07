import express from 'express';

import verificationRouter from './verification.js';
import dashboardRouter from './dashboard.js';
import auditRouter from './audit.js';
import supportRouter from './support.js';
import sosRouter from './sos.js';

const router = express.Router();

router.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Operations Dashboard',
  });
});

router.use('/verification', verificationRouter);
router.use('/dashboard', dashboardRouter);
router.use('/audit-logs', auditRouter);
router.use('/support', supportRouter);
router.use('/sos', sosRouter);

export default router;
