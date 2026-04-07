# FinAlly — Agent Reference

## Architecture

Single Docker container, single port (8000). FastAPI serves the REST/SSE API and static Next.js export from the same origin.

```
Docker Container (port 8000)
├── FastAPI (Python/uv)
│   ├── /api/*          REST endpoints
│   ├── /api/stream/*   SSE streaming
│   └── /*              Next.js static export
└── SQLite              db/finally.db (volume-mounted)
```

**Stack:**
- Frontend: Next.js (TypeScript), static export (`output: 'export'`)
- Backend: FastAPI, managed by `uv`
- Database: SQLite at `db/finally.db`
- Real-time: Server-Sent Events (SSE)
- AI: LiteLLM → OpenRouter (Cerebras)
- Market data: simulator by default; real data via `MASSIVELY_API_KEY` env var

## Key File Locations

```
finally/
├── backend/
│   ├── app/
│   │   ├── main.py          FastAPI app, static file serving
│   │   ├── database.py      SQLite init, connection helper
│   │   ├── portfolio.py     Portfolio routes + trade execution
│   │   ├── watchlist.py     Watchlist routes
│   │   ├── chat.py          AI chat route
│   │   ├── prices.py        Price cache utilities
│   │   ├── snapshots.py     Portfolio snapshot recorder
│   │   └── market/
│   │       ├── provider.py  Market data provider factory
│   │       ├── stream.py    SSE price stream route
│   │       └── cache.py     In-memory price cache
│   ├── pyproject.toml
│   └── uv.lock
├── frontend/
│   ├── src/
│   │   ├── app/             Next.js App Router pages
│   │   ├── components/      React components
│   │   ├── hooks/           Custom React hooks
│   │   └── lib/             Utilities
│   ├── package.json
│   └── next.config.ts
├── db/
│   └── .gitkeep             Tracks the db/ dir; finally.db is gitignored
├── planning/
│   └── PLAN.md              This file
├── scripts/
│   ├── start_mac.sh
│   └── stop_mac.sh
├── Dockerfile
└── docker-compose.yml
```

## API Contract

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check → `{"status": "ok"}` |
| GET | `/api/stream/prices` | SSE stream of price ticks |
| GET | `/api/portfolio` | Portfolio summary (cash, positions, total value) |
| POST | `/api/portfolio/trade` | Execute market order `{ticker, quantity, side}` |
| GET | `/api/portfolio/history` | Portfolio value snapshots over time |
| GET | `/api/watchlist` | List watchlist items |
| POST | `/api/watchlist` | Add ticker `{ticker}` |
| DELETE | `/api/watchlist/{ticker}` | Remove ticker |
| POST | `/api/chat` | AI chat `{message}` → `{response}` |

**Trade request:** `{"ticker": "AAPL", "quantity": 10, "side": "buy" | "sell"}`

**SSE price tick format:** `data: {"ticker": "AAPL", "price": 182.34, "change": 0.12}`

## Local Development

**Backend** (from `backend/`):
```bash
uv run uvicorn app.main:app --reload --port 8000
```

**Frontend** (from `frontend/`):
```bash
npm install
npm run dev        # dev server on port 3000
npm run build      # static export to out/
```

**Docker** (from repo root):
```bash
docker compose up --build
# App available at http://localhost:8000
```

## Database

SQLite at `db/finally.db`. Schema initialized on startup via `app.database.init_db()`.

Tables: `portfolio` (cash balance), `positions`, `trades`, `watchlist`, `price_snapshots`

The `db/` directory is tracked via `db/.gitkeep`; the database file itself is gitignored.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `MASSIVELY_API_KEY` | — | Real market data; omit to use simulator |
| `OPENROUTER_API_KEY` | — | Required for AI chat |
| `MODEL` | `cerebras/llama-3.3-70b` | LiteLLM model string |
