# CPool — Phase 1 MVP

Zero-funding carpooling stack: **Flutter** + **Node.js/Express** + **PostgreSQL** + **Supabase Auth** + **OpenStreetMap** + **Razorpay**.

## Architecture

```
Flutter App  →  Supabase (auth)  →  JWT
     ↓
Express API  →  PostgreSQL
     ↓
Nominatim (geocode proxy) · Razorpay (orders)
```

## Quick start

### 1. PostgreSQL

```bash
docker compose up -d
```

### 2. API

```bash
cd server
cp .env.example .env
# Edit .env — at minimum DATABASE_URL and Supabase keys
npm install
npm run db:migrate
npm run dev
```

API runs at `http://localhost:3000`. Check: `GET http://localhost:3000/health`

### 3. Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. **Authentication → Providers**: enable Email and Google
3. Copy **Project URL** and **anon key** into root `.env`
4. Copy **service role key** and **JWT secret** into `server/.env`
5. For Google: add OAuth client in Google Cloud, add client IDs in Supabase; set `GOOGLE_WEB_CLIENT_ID` in `.env` for mobile

### 4. Flutter

```bash
cp .env.example .env
# Fill SUPABASE_URL, SUPABASE_ANON_KEY, API_BASE_URL=http://localhost:3000
flutter pub get
flutter run
```

Android emulator API URL: use `http://10.0.2.2:3000` instead of `localhost`.

### 5. Razorpay (optional)

1. [Razorpay Dashboard](https://dashboard.razorpay.com) → Test mode keys
2. Set `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` in `server/.env`
3. Set `RAZORPAY_KEY_ID` in Flutter `.env`
4. Book a ride → copy booking ID → **Profile → Payments**

## API endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | — | DB health |
| POST | `/users/sync` | ✓ | Upsert profile from Supabase user |
| GET | `/users/me` | ✓ | Current profile |
| GET/POST | `/commutes` | POST ✓ | List / create commutes |
| POST | `/commutes/:id/book` | ✓ | Book seats |
| GET | `/geocode/search?q=` | — | Nominatim search proxy |
| POST | `/payments/orders` | ✓ | Create Razorpay order |
| POST | `/payments/confirm` | ✓ | Confirm payment (MVP) |
| GET/POST | `/chat/:commuteId` | ✓ | In-app messages |

## Flutter features

- Dark/light theme (black, grey, violet)
- Animated splash
- 5-tab navigation
- **Search**: OSM map + Nominatim via API
- **Auth**: email/password + Google (Supabase)
- **Payments**: Razorpay (Android/iOS; web shows order id)
- **Chat**: per-commute threads (no voice/calls)

## Monthly cost target

₹0–₹500 on free tiers (Docker Postgres local, Railway/Render, Supabase free, FCM later).

## Project layout

```
lib/           Flutter UI + integrations
server/        Express API + SQL schema
docker-compose.yml
.env.example   Flutter secrets template
server/.env.example
```

## Removed from MVP (by design)

Anonymous calling, AI matching, corporate/university portals, carbon dashboard, complex trust algorithms.

## Next after this

- Firebase Cloud Messaging
- Student ID upload → Supabase Storage
- Razorpay signature verification on server
- Deploy API (Railway/Render) + web (Vercel/Next.js)
