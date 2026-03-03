# BMB Merch Server — Setup & Deployment Guide

> **Version 3.1.0** | Last updated: 2025-07-14
>
> This guide walks through configuring Shopify webhooks, environment variables,
> HMAC verification, and deploying the BMB Merch Server to production.
>
> **No Shopify catalog changes are made by this server.**
> It only reads order data via webhooks and maps products using the local
> `product-catalog.json` file.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Environment Variables](#2-environment-variables)
3. [Create the Shopify "orders/paid" Webhook](#3-create-the-shopify-orderspaid-webhook)
4. [HMAC Signature Verification](#4-hmac-signature-verification)
5. [Local Development Workflow](#5-local-development-workflow)
6. [Testing the Pipeline](#6-testing-the-pipeline)
7. [Endpoint Reference](#7-endpoint-reference)
8. [Production Deployment](#8-production-deployment)
9. [Persistence Strategy](#9-persistence-strategy)
10. [Security Considerations](#10-security-considerations)
11. [Go Live Checklist](#11-go-live-checklist)

---

## 1. Prerequisites

| Requirement        | Version / Notes                                  |
|--------------------|--------------------------------------------------|
| Node.js            | 18+ (LTS recommended)                            |
| npm                | 9+                                               |
| ImageMagick        | 7+ (for CMYK PDF conversion)                     |
| ICC color profiles | `/usr/share/color/icc/ghostscript/` (optional)   |
| Shopify store      | `backmybracket.myshopify.com` (admin access)     |
| SMTP server        | Gmail App Password or similar transactional SMTP  |
| Domain / VPS       | Public HTTPS URL for Shopify webhook callback     |

Install dependencies:

```bash
cd bmb-merch-server
npm install
```

---

## 2. Environment Variables

Copy `.env.example` (or the existing `.env`) and fill in real values:

```bash
cp .env .env.production
```

### Required variables

| Variable                 | Description                                         | Example                               |
|--------------------------|-----------------------------------------------------|---------------------------------------|
| `PORT`                   | HTTP listen port                                    | `3000`                                |
| `NODE_ENV`               | `production` or `development`                       | `production`                          |
| `SHOPIFY_WEBHOOK_SECRET` | HMAC signing secret from Shopify webhook setup      | `whsec_abc123...`                     |
| `SMTP_HOST`              | SMTP server hostname                                | `smtp.gmail.com`                      |
| `SMTP_PORT`              | SMTP port (587 = STARTTLS, 465 = SSL)               | `587`                                 |
| `SMTP_USER`              | SMTP login                                          | `orders@backmybracket.com`            |
| `SMTP_PASS`              | SMTP password / app password                        | `xxxx xxxx xxxx xxxx`                 |
| `PRINTER_EMAIL`          | Printer's email for fulfillment                     | `jkim@aceusainc.com`                  |
| `ADMIN_TOKEN`            | Secret for `/admin/*` and `/webhooks/shopify/test`  | `<random 40+ char string>`           |

### Optional variables

| Variable              | Default         | Description                                     |
|-----------------------|-----------------|-------------------------------------------------|
| `OUTPUT_COLOR_MODES`  | `RGB,CMYK`      | Comma-separated: `RGB`, `CMYK`, or both         |
| `PRINTER_DELIVERY`    | `email`         | `email`, `folder`, `sftp` (comma-separated)     |
| `PRINTER_DROPBOX_DIR` | `./printer_dropbox` | Local folder path (if `folder` delivery)    |
| `SFTP_HOST`           | —               | SFTP hostname (if `sftp` delivery)              |
| `SFTP_PORT`           | `22`            | SFTP port                                       |
| `SFTP_USER`           | —               | SFTP username                                   |
| `SFTP_PASS`           | —               | SFTP password                                   |
| `SFTP_REMOTE_DIR`     | `/uploads`      | Remote directory for SFTP uploads               |
| `EMAIL_MAX_RETRIES`   | `3`             | Retry attempts for email delivery               |
| `EMAIL_RETRY_BASE_MS` | `2000`          | Base delay between retries (doubles each time)  |
| `CC_EMAILS`           | `ahmad@backmybracket.com,amchi81@gmail.com` | CC list |

---

## 3. Create the Shopify "orders/paid" Webhook

### Step 1: Determine your webhook URL

Your server must be reachable over HTTPS. The exact path is:

```
https://<YOUR_DOMAIN>/webhooks/shopify
```

Examples:
- `https://api.backmybracket.com/webhooks/shopify`
- `https://bmb-merch.fly.dev/webhooks/shopify`
- `https://bmb.onrender.com/webhooks/shopify`

### Step 2: Create the webhook in Shopify Admin

1. Go to **Shopify Admin** → **Settings** → **Notifications** → **Webhooks**
   - Or navigate directly: `https://backmybracket.myshopify.com/admin/settings/notifications`

2. Scroll to the **Webhooks** section at the bottom.

3. Click **Create webhook**:

   | Field          | Value                                              |
   |----------------|----------------------------------------------------|
   | **Event**      | `Order payment`  (this triggers `orders/paid`)     |
   | **Format**     | `JSON`                                             |
   | **URL**        | `https://<YOUR_DOMAIN>/webhooks/shopify`           |
   | **API version**| Latest stable (e.g., `2024-10` or `2025-01`)      |

4. Click **Save**.

### Step 3: Copy the signing secret

After creating the webhook, Shopify shows the **signing secret** (starts with `whsec_` or is a hex string).

1. Copy this secret.
2. Set it in your `.env`:

   ```env
   SHOPIFY_WEBHOOK_SECRET=whsec_your_actual_secret_here
   ```

3. **Restart** your server so the new secret takes effect.

### Step 4: Send a test notification

On the webhooks page, click **Send test notification** next to your webhook.
Check your server logs for:

```
[Webhook] Received orders/paid for order #0
[FULFILLMENT] webhook orderId=... status=started
```

If HMAC fails, you'll see:

```
[Webhook] HMAC verification failed
```

→ Double-check `SHOPIFY_WEBHOOK_SECRET` matches exactly.

---

## 4. HMAC Signature Verification

Shopify signs every webhook payload with HMAC-SHA256. The server verifies this
to prevent forged requests.

### How it works

1. Shopify computes: `HMAC = Base64( HMAC-SHA256( raw_body, secret ) )`
2. Shopify sends the result in the `X-Shopify-Hmac-Sha256` header.
3. Our server recomputes the HMAC from the raw request body and the
   `SHOPIFY_WEBHOOK_SECRET` env var.
4. If the two match (using `crypto.timingSafeEqual`), the request is authentic.

### Verify locally

```bash
# Generate a test HMAC for a payload
SECRET="your_webhook_secret"
PAYLOAD='{"id":123456,"name":"#1001","line_items":[]}'
echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64
```

Then call:

```bash
HMAC=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

curl -X POST http://localhost:3000/webhooks/shopify \
  -H "Content-Type: application/json" \
  -H "X-Shopify-Topic: orders/paid" \
  -H "X-Shopify-Hmac-Sha256: $HMAC" \
  -d "$PAYLOAD"
```

### In production

- **Always** set a real `SHOPIFY_WEBHOOK_SECRET`.
- The server skips HMAC verification **only** when `SHOPIFY_WEBHOOK_SECRET` is
  unset or starts with `whsec_xxx` (dev placeholder).
- In production (`NODE_ENV=production`), never leave the secret as a placeholder.

### Common HMAC issues

| Symptom                          | Cause                                     | Fix                                           |
|----------------------------------|-------------------------------------------|-----------------------------------------------|
| 401 "HMAC verification failed"  | Secret mismatch                           | Copy exact secret from Shopify Admin          |
| Empty `X-Shopify-Hmac-Sha256`   | Webhook URL uses HTTP, not HTTPS          | Shopify only sends HMAC over HTTPS            |
| Body parsing corrupts signature  | JSON middleware before raw middleware      | Ensure `/webhooks` route uses `express.raw()` |

---

## 5. Local Development Workflow

### Start the server

```bash
# Development mode (skips HMAC, logs emails to console)
NODE_ENV=development npm start
```

### Test with the test endpoint (no Shopify needed)

```bash
curl -X POST http://localhost:3000/webhooks/shopify/test \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: bmb-admin-secret-change-me" \
  -d '{
    "id": 99990001,
    "name": "#DEV-TEST-001",
    "email": "dev@test.com",
    "shipping_address": {
      "first_name": "Dev",
      "last_name": "Tester",
      "address1": "123 Dev St",
      "city": "Dallas",
      "province_code": "TX",
      "zip": "75001"
    },
    "line_items": [{
      "title": "Grid Iron Hoodie",
      "product_id": 9208241586344,
      "variant_id": 48123456789000,
      "properties": [
        { "name": "bracket_id", "value": "dev-bracket-001" },
        { "name": "bracket_title", "value": "DEV TOURNAMENT" },
        { "name": "champion_name", "value": "TEST TEAM" },
        { "name": "team_count", "value": "16" },
        { "name": "print_style", "value": "classic" },
        { "name": "color", "value": "Black" },
        { "name": "size", "value": "L" },
        { "name": "product_id", "value": "bp_grid_iron" }
      ]
    }]
  }'
```

### Test with a pre-existing artifact

```bash
# Step 1: Generate a preview to create an artifact
ARTIFACT_ID=$(curl -s -X POST http://localhost:3000/generate-preview?format=json \
  -H "Content-Type: application/json" \
  -d '{
    "bracketTitle": "TEST BRACKET",
    "championName": "DUKE",
    "teamCount": 16,
    "teams": ["Duke","UNC","Kansas","Kentucky"],
    "picks": {},
    "style": "classic",
    "productId": "bp_grid_iron",
    "colorName": "Black",
    "isDarkGarment": true
  }' | jq -r '.artifactId')

echo "Artifact ID: $ARTIFACT_ID"

# Step 2: Test the pipeline with that artifact
curl -X POST http://localhost:3000/webhooks/shopify/test \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: bmb-admin-secret-change-me" \
  -d "{
    \"id\": 99990002,
    \"name\": \"#DEV-ARTIFACT-TEST\",
    \"email\": \"dev@test.com\",
    \"shipping_address\": {
      \"first_name\": \"Dev\", \"last_name\": \"Tester\",
      \"address1\": \"123 Dev St\", \"city\": \"Dallas\",
      \"province_code\": \"TX\", \"zip\": \"75001\"
    },
    \"line_items\": [{
      \"title\": \"Grid Iron Hoodie\",
      \"product_id\": 9208241586344,
      \"variant_id\": 48123456789000,
      \"properties\": [
        { \"name\": \"bracket_id\", \"value\": \"dev-bracket-002\" },
        { \"name\": \"artifact_id\", \"value\": \"$ARTIFACT_ID\" },
        { \"name\": \"bracket_title\", \"value\": \"ARTIFACT TEST\" },
        { \"name\": \"champion_name\", \"value\": \"DUKE\" },
        { \"name\": \"team_count\", \"value\": \"16\" },
        { \"name\": \"print_style\", \"value\": \"classic\" },
        { \"name\": \"color\", \"value\": \"Black\" },
        { \"name\": \"size\", \"value\": \"L\" },
        { \"name\": \"product_id\", \"value\": \"bp_grid_iron\" }
      ]
    }]
  }"
```

### Send an artifact directly to the printer

```bash
curl -X POST http://localhost:3000/admin/send-to-printer \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: bmb-admin-secret-change-me" \
  -d "{
    \"artifactId\": \"$ARTIFACT_ID\",
    \"testOrderNumber\": \"#PRINTER-TEST-001\",
    \"testCustomer\": {
      \"name\": \"Ahmad Test\",
      \"email\": \"ahmad@backmybracket.com\",
      \"address\": \"123 Main St\",
      \"city\": \"Dallas\",
      \"state\": \"TX\",
      \"zip\": \"75001\",
      \"size\": \"XL\"
    }
  }"
```

---

## 6. Testing the Pipeline

### Test endpoint vs. real webhook

| Feature                  | `POST /webhooks/shopify`        | `POST /webhooks/shopify/test`      |
|--------------------------|---------------------------------|------------------------------------|
| HMAC verification        | Yes (required in production)    | No (uses ADMIN_TOKEN instead)      |
| Idempotency              | Yes (keyed by shopifyOrderId)   | Yes (prefixed with `test-`)        |
| Artifact loading         | Yes                             | Yes                                |
| SVG regeneration         | Fallback if no artifact         | Fallback if no artifact            |
| Packing slip generation  | Yes                             | Yes                                |
| Printer delivery         | Yes (all configured methods)    | Yes (all configured methods)       |
| Fulfillment log          | Yes                             | Yes (logged with test prefix)      |

### Check fulfillment status

```bash
# By Shopify order ID (or test order ID)
curl http://localhost:3000/fulfillment/test-99990001

# List all failures
curl -H "X-Admin-Token: bmb-admin-secret-change-me" \
  http://localhost:3000/admin/fulfillment?status=failed

# Observability summary (last 20 events, 24h failures)
curl -H "X-Admin-Token: bmb-admin-secret-change-me" \
  http://localhost:3000/admin/logs/summary
```

---

## 7. Endpoint Reference

### Public Endpoints

| Method | Path                        | Auth      | Description                                      |
|--------|-----------------------------|-----------|--------------------------------------------------|
| GET    | `/health`                   | None      | Health check (version, uptime, config)           |
| POST   | `/generate-preview`         | None      | Generate bracket preview + persist artifacts     |
| GET    | `/preview/:id`              | None      | Retrieve a saved preview JPEG                    |
| GET    | `/products`                 | None      | Active products (`?includeInactive=true` for all)|
| POST   | `/webhooks/shopify`         | HMAC      | Shopify orders/paid webhook                      |
| GET    | `/fulfillment/:orderId`     | None      | Fulfillment status for an order                  |

### Admin Endpoints (all require `X-Admin-Token` header)

| Method | Path                         | Description                                      |
|--------|------------------------------|--------------------------------------------------|
| POST   | `/webhooks/shopify/test`     | Full pipeline test without Shopify               |
| PATCH  | `/admin/products/:internalId`| Toggle product isActive                          |
| GET    | `/admin/products`            | List all products (active + inactive)            |
| GET    | `/admin/fulfillment`         | List fulfillments (`?status=failed` to filter)   |
| POST   | `/admin/send-to-printer`     | Deliver an artifact to the printer               |
| GET    | `/admin/logs/summary`        | Last 20 events, 24h failures, delivery config    |

---

## 8. Production Deployment

### Recommended platforms

- **Render** — easy Docker / Node.js deployment with persistent disk
- **Fly.io** — global edge with persistent volumes
- **Railway** — simple Node.js hosting with env management
- **DigitalOcean App Platform** — managed infrastructure
- **AWS EC2 / Lightsail** — full control with systemd service

### Deploy steps

1. **Set all environment variables** (see Section 2).
2. **Ensure HTTPS** — Shopify only sends webhooks to HTTPS URLs.
3. **Start the server**:
   ```bash
   NODE_ENV=production npm start
   ```
4. **Verify health**:
   ```bash
   curl https://<YOUR_DOMAIN>/health
   ```
5. **Create the Shopify webhook** (see Section 3).
6. **Test with the test endpoint** (see Section 6).
7. **Send a Shopify test notification** from Settings → Notifications → Webhooks.

### Process management (systemd example)

```ini
# /etc/systemd/system/bmb-merch.service
[Unit]
Description=BMB Merch Server
After=network.target

[Service]
Type=simple
User=bmb
WorkingDirectory=/opt/bmb-merch-server
ExecStart=/usr/bin/node src/server.js
Restart=on-failure
RestartSec=5
EnvironmentFile=/opt/bmb-merch-server/.env.production

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable bmb-merch
sudo systemctl start bmb-merch
sudo journalctl -u bmb-merch -f
```

### Docker

```dockerfile
FROM node:18-slim
RUN apt-get update && apt-get install -y imagemagick
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 3000
CMD ["node", "src/server.js"]
```

---

## 9. Persistence Strategy

This server uses **minimal file-based persistence** — no external database.

| Data                  | Location                         | Format  | Notes                              |
|-----------------------|----------------------------------|---------|------------------------------------|
| Product catalog       | `src/data/product-catalog.json`  | JSON    | Source of truth for product config  |
| Fulfillment log       | `data/fulfillment_log.json`      | JSON    | Idempotency + status tracking      |
| Artifacts             | `output/artifacts/<id>/`         | Files   | SVG, PNG, PDF + manifest.json      |
| Previews              | `output/previews/`               | JPEG    | Generated preview images           |
| Print-ready files     | `output/print_ready/`            | PNG     | RGB rasters (3600px, 300 DPI)      |
| CMYK files            | `output/print_ready_cmyk/`       | PDF     | CMYK PDFs (12", 300 DPI)           |
| Packing slips         | `output/packing_slips/`          | PDF     | Per-order packing slip PDFs        |
| Printer dropbox       | `printer_dropbox/`               | Files   | Copied files (if folder delivery)  |

### Backup recommendations

- **Back up `data/fulfillment_log.json`** regularly — contains idempotency state.
- **Back up `output/artifacts/`** — contains all generated print files.
- `product-catalog.json` is version-controlled — no backup needed.

### Future: cloud storage

The `artifact-store.js` module is designed for easy swap to S3 / GCS:
- Replace `fs.copyFileSync` with `s3.upload()`
- Replace `fs.existsSync` with `s3.headObject()`
- Keep the same public API (`saveArtifact`, `loadArtifact`, etc.)

---

## 10. Security Considerations

### ADMIN_TOKEN

- All `/admin/*` routes and `/webhooks/shopify/test` require `X-Admin-Token` header.
- Generate a strong token: `openssl rand -hex 32`
- Never commit the real token to version control.
- Requests without a valid token receive `401 Unauthorized`.

### HMAC verification

- Production: always set `SHOPIFY_WEBHOOK_SECRET` to the real Shopify signing secret.
- The server uses `crypto.timingSafeEqual()` to prevent timing attacks.
- The secret is never logged or exposed in responses.

### Artifact URLs

- Artifact IDs are 16-character hex strings from `crypto.randomBytes(8)`.
- This gives 2^64 possible IDs — effectively unguessable.
- Directory listing is **disabled** on `/output` (no index, no directory traversal).
- Files are only accessible via their full, exact path.

### No Shopify writes

- This server makes **zero write calls** to the Shopify API.
- Product catalog is read-only (mapped locally in `product-catalog.json`).
- The `toggleActive` function only modifies the local JSON file.
- Shopify product/variant data is never created, updated, or deleted.

---

## 11. Go Live Checklist

Use this checklist before pointing the Shopify webhook to your production server.

### Environment

- [ ] `NODE_ENV=production`
- [ ] `SHOPIFY_WEBHOOK_SECRET` set to real Shopify signing secret (not `whsec_xxx...`)
- [ ] `ADMIN_TOKEN` set to a strong random value (`openssl rand -hex 32`)
- [ ] `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS` set to real SMTP credentials
- [ ] `PRINTER_EMAIL` set to the printer's actual email
- [ ] `CC_EMAILS` set to the correct CC list
- [ ] `PRINTER_DELIVERY` set to desired methods (`email`, `email,folder`, etc.)
- [ ] If SFTP: `SFTP_HOST`, `SFTP_USER`, `SFTP_PASS`, `SFTP_REMOTE_DIR` configured
- [ ] If folder: `PRINTER_DROPBOX_DIR` writable

### Server

- [ ] Server is running on HTTPS (required for Shopify webhooks)
- [ ] `GET /health` returns `200 OK` with correct version (`3.1.0`)
- [ ] `GET /products` returns 5 active products
- [ ] `output/` directories exist (`previews/`, `artifacts/`, `packing_slips/`, etc.)
- [ ] Directory listing disabled on `/output` (confirmed via browser — should 404, not list)

### Shopify Webhook

- [ ] Webhook created in Shopify Admin → Settings → Notifications → Webhooks
- [ ] Event: `Order payment` (triggers `orders/paid`)
- [ ] URL: `https://<YOUR_DOMAIN>/webhooks/shopify`
- [ ] Format: JSON
- [ ] Signing secret copied to `SHOPIFY_WEBHOOK_SECRET`
- [ ] "Send test notification" succeeds (check server logs)

### Pipeline Test

- [ ] `POST /webhooks/shopify/test` succeeds with sample payload (uses ADMIN_TOKEN)
- [ ] Artifact loaded correctly (or SVG regenerated)
- [ ] Packing slip PDF generated
- [ ] Email delivery succeeds (check printer inbox / dev log)
- [ ] Fulfillment log entry created with status `sent`
- [ ] `GET /fulfillment/<orderId>` returns correct status

### Admin Endpoints

- [ ] All `/admin/*` routes return `401` without `X-Admin-Token`
- [ ] `/webhooks/shopify/test` returns `401` without `X-Admin-Token`
- [ ] `PATCH /admin/products/:id` toggles isActive (and does NOT modify Shopify)
- [ ] `POST /admin/send-to-printer` delivers files and logs correctly
- [ ] `GET /admin/logs/summary` returns recent events and failure count

### Production Safety

- [ ] No `.env` file committed to git (in `.gitignore`)
- [ ] `/output` directory listing returns 404 (not a file list)
- [ ] Artifact URLs are unguessable (16-char hex IDs)
- [ ] No test/demo accounts in production
- [ ] HMAC verification enforced (not skipped)
- [ ] Email retry logic active (up to 3 attempts with backoff)
- [ ] Idempotency works (duplicate webhooks return "already_processed")

### Flutter App

- [ ] `MERCH_SERVER_URL` compile-time default points to production Render URL
      (currently `https://backmybracket-mobile-version-2.onrender.com` in `lib/core/config/app_config.dart`)
- [ ] For localhost dev builds, override:
      `flutter run --dart-define=MERCH_SERVER_URL=http://localhost:3000`
- [ ] `buildShopifyCheckoutUrl()` generates correct `/cart/<variantId>:1?properties[...]` format
- [ ] `artifact_id` included in checkout URL properties (captured from preview step + submit)
- [ ] `bracket_id`, `preview_url`, and all property keys match webhook expectations
- [ ] All property values are URI-encoded
- [ ] Console logs show `[MerchPreview]` and `[CompositePreview]` lines confirming server vs fallback

### Monitoring

- [ ] `GET /admin/logs/summary` bookmarked for daily checks
- [ ] `GET /admin/fulfillment?status=failed` checked regularly
- [ ] Server logs monitored for `[FULFILLMENT]` one-line entries
- [ ] Email delivery failures trigger investigation workflow

---

**Once all boxes are checked, your BMB Merch Server is ready for production orders.**

*No Shopify catalog changes are made by this server at any point.*
