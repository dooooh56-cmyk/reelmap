# ReelMap web

Dependency-free Worker + HTML app. Gemini for video/image/text extraction; Kakao Local for restaurant verification; Kakao JavaScript SDK for maps. No server database. Browser-local library.

```sh
cp .env.example .env.local
# Enter API keys and a demo access code in .env.local
bash scripts/build.sh
node scripts/dev.mjs
# http://localhost:8787
```

```sh
node tests/core.test.mjs
node scripts/validate-artifact.mjs
```

POST `/api/analyze`: `{url?,text?,media?:{mime,data},analyzeMedia?:boolean}`, base64 without a data URL prefix. Max 12MiB media, 20,000 characters text. POST `/api/search`: `{query}`. Optional `X-Demo-Code` is required when `DEMO_ACCESS_CODE` is configured. Secrets are server environment variables. `KAKAO_JAVASCRIPT_KEY` is a public, origin-restricted SDK identifier. Do not put REST or Gemini secrets into browser settings.

Build bundles the HTML into a single Worker module. `/native-map` is a map-only view for the SwiftUI app's WKWebView. There is no signup or account synchronization. API provider credit/quota exhaustion can block multimodal analysis. Caption-rule fallback is explicitly labeled, and ambiguous locations always require review.

Analysis first tries the caption and verifies places. Attached media is skipped only when every caption restaurant has one exact name/address match. Incomplete caption results fall back to media. Set `analyzeMedia:true` to analyze the file directly with any supplied caption. Provider outages do not trigger an automatic second AI request. Per-request measured input/output/thinking/total tokens are returned in `usage`; missing measurements return null. Supplemental input skips the Instagram refetch.
