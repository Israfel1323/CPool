# CPool API

Express + PostgreSQL backend for the Flutter app.

## Setup

```bash
cp .env.example .env
npm install
npm run db:migrate
npm run dev
```

Default `DATABASE_URL` with Docker Compose:

```
postgresql://postgres:postgres@localhost:5432/cpool
```

## Environment

See `.env.example` for all variables. Required for full functionality:

- `DATABASE_URL`
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
- `NOMINATIM_USER_AGENT` (your app name + contact email per OSM policy)
- `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` (optional until payments)
