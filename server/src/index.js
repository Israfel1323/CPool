import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import verificationRouter from './routes/verification.js';
import healthRouter from './routes/health.js';
import usersRouter from './routes/users.js';
import commutesRouter from './routes/commutes.js';
import geocodeRouter from './routes/geocode.js';
import paymentsRouter from './routes/payments.js';
import chatRouter from './routes/chat.js';
import driverDetailsRouter from './routes/driver-details.js';
import operationsRouter from './routes/operations/index.js';
import supportRouter from './routes/support.js';
import emergencyContactsRouter from './routes/emergency-contacts.js';
import tripSafetyRouter from './routes/trip-safety.js';
import vehiclesRouter from './routes/vehicles.js';

const app = express();
const port = Number(process.env.PORT) || 3000;

const corsOrigins =
  process.env.CORS_ORIGINS?.split(',').map((s) => s.trim()) ?? ['*'];

app.use(helmet());
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(
  cors({
    origin: corsOrigins.includes('*') ? true : corsOrigins,
    credentials: true,
  }),
);
app.use(express.json());

app.get('/', (_req, res) => {
  res.json({
    name: 'CPool API',
    version: '1.0.0',
    docs: {
      health: 'GET /health',
      users: 'POST /users/sync, GET /users/me',
      commutes: 'GET|POST /commutes',
      geocode: 'GET /geocode/search?q=',
      payments: 'POST /payments/orders',
      chat: 'GET|POST /chat/:commuteId',
      verification: 'POST /verification/upload',
      support: 'GET|POST /support/tickets',
    },
  });
});

app.use('/health', healthRouter);
app.use('/users', usersRouter);
app.use('/commutes', commutesRouter);
app.use('/geocode', geocodeRouter);
app.use('/payments', paymentsRouter);
app.use('/chat', chatRouter);
app.use('/verification', verificationRouter);
app.use('/driver-details', driverDetailsRouter);
app.use('/operations', operationsRouter);
app.use('/support', supportRouter);
app.use('/emergency-contacts', emergencyContactsRouter);
app.use('/trip-safety', tripSafetyRouter);
app.use('/vehicles', vehiclesRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(port, () => {
  console.log(`CPool API listening on http://localhost:${port}`);
});
