# BlackShell Golf AI Worker

This Cloudflare Worker keeps the Gemini API key off the phone and exposes a
small API for short golf swing videos.

| Route | Purpose |
| --- | --- |
| `GET /health` | Reports whether the Gemini secret is configured. |
| `POST /analyze-swing` | Accepts one multipart video and returns structured coaching feedback. |

## Configure and deploy

Wrangler 4.36 or newer is required for the Rate Limiting binding in
`wrangler.toml`.

```sh
cd backend
npx --yes wrangler@latest secret put GEMINI_API_KEY
npx --yes wrangler@latest deploy
```

`secret put` reads the value from a protected prompt. Do not add the key to
`wrangler.toml`, a Dart define, `.dev.vars`, or source control.

After deployment, verify the Worker before configuring the app:

```sh
curl https://YOUR-WORKER.workers.dev/health
```

The current production endpoint is:

```sh
curl https://blackshell-golf-ai.tx-appe-chi.workers.dev/health
```

The response should include `"configured":true`. A missing secret keeps the
health route available but makes analysis requests return `missing_api_key`.

## Connect Flutter

The app defaults to
`https://blackshell-golf-ai.tx-appe-chi.workers.dev`. The public Worker URL is
configuration, not a secret. Override it for another environment with:

```sh
flutter run \
  --dart-define=AI_API_BASE_URL=https://YOUR-WORKER.workers.dev
```

For a build launched from Xcode, generate Flutter's Xcode configuration first:

```sh
flutter build ios --config-only \
  --dart-define=AI_API_BASE_URL=https://YOUR-WORKER.workers.dev
open ios/Runner.xcworkspace
```

`BLACKSHELL_AI_ENDPOINT` may be used instead when the full
`/analyze-swing` URL is needed. The mobile client accepts HTTPS endpoints;
plain HTTP is limited to `localhost`, `127.0.0.1`, and `::1` for development.

## Optional client token

The Worker can also require a bearer token:

```sh
npx --yes wrangler@latest secret put APP_BEARER_TOKEN
flutter run \
  --dart-define=AI_API_BASE_URL=https://YOUR-WORKER.workers.dev \
  --dart-define=BLACKSHELL_AI_TOKEN=YOUR_MATCHING_TOKEN
```

A token compiled into a distributed app can be extracted. Treat it as an
extra abuse barrier, not as user authentication. A production service should
also verify App Attest or another server-verifiable identity and set Gemini
budget alerts.

## CORS and abuse controls

Native iOS and Android requests do not need CORS. Browser origins are denied by
default. If a web client is added, set `APP_ORIGIN` to an explicit,
comma-separated allowlist such as:

```toml
[vars]
APP_ORIGIN = "https://golf.example.com,https://admin.example.com"
```

The `AI_RATE_LIMITER` binding allows five analysis attempts per minute for an
edge client key. This is an approximate abuse guard: Cloudflare rate limits are
eventually consistent, and mobile users can share network addresses. It does
not replace account quotas, authenticated user limits, or App Attest.

## Request behavior

- Videos are limited to 14 MB so the Base64 inline request remains under
  Gemini's 20 MB inline video guidance.
- Production uses Gemini 3.5 Flash at 5 fps, with 3.5 Flash Lite as an
  availability fallback, to keep mobile analysis responsive and economical.
- MIME type, request size, context length, model output shape, and response
  size are validated.
- Gemini calls time out after 90 seconds and fall back across the configured
  stable Flash models only for retryable/model-availability failures.
- The Worker requests JSON mode and validates every required field and length
  before returning the result to the phone.
- Browser origins are closed unless explicitly configured; every response is
  marked `no-store` and carries a request ID.
- The uploaded video is held only for the request and is not persisted by this
  Worker.

Never commit `GEMINI_API_KEY`, `APP_BEARER_TOKEN`, `.dev.vars`, signing keys, or
production credentials. The root `.gitignore` excludes the usual local secret
and signing formats.
