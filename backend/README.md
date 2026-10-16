# Retired backend prototype

The former V0.4 Worker implementation has been removed because it exposed
different paths and was not used by the current app.

The maintained API is implemented in `server/handler.js`. Its Cloudflare
Workers entry point and deployment configuration live in `worker/`. Do not add
source-specific scraping or a second API implementation here.
