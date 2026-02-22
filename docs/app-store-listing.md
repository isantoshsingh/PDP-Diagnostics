# Shopify App Store Listing — Prowl

Use this document as the source of truth when filling out the Shopify App Store listing form.

---

## App Name

**Prowl**

_(30 characters max — "Prowl" = 5 characters)_

---

## App Card Subtitle

**Product page monitoring & broken PDP alerts**

---

## App Introduction (100 characters max)

```
Detect broken product pages before they cost you sales. Daily scans, smart alerts, zero store impact.
```

_(99 characters)_

---

## App Details (500 characters max)

```
Prowl monitors your product pages daily using a real headless browser — the same way your customers experience them. It detects missing add-to-cart buttons, JavaScript errors, broken images, invisible prices, and more.

When a real issue is confirmed across two consecutive scans, you get a clear alert with guidance on what went wrong and how to fix it. No false alarms, no noise.

Setup takes under a minute: pick up to 5 product pages, and Prowl handles the rest. Works with every Shopify theme.
```

_(496 characters)_

---

## Feature List (up to 80 characters each)

1. `Daily automated scans of your product pages using a real browser`
2. `Detects missing add-to-cart buttons, JS errors, broken images, and more`
3. `Two-scan confirmation eliminates false positives`
4. `Clear alerts with fix guidance — only for real, persistent issues`
5. `Works with every Shopify theme — free or third-party`
6. `Zero impact on your storefront speed or customer experience`
7. `Dashboard with color-coded health status for every monitored page`
8. `Read-only permissions — Prowl never modifies your store`

---

## Pricing Details

```
$10/month after a 14-day free trial. Full access to all features during the trial — no limitations.
```

---

## Key Benefits (for internal reference / marketing pages)

| Benefit | Description |
|---|---|
| **Early warning system** | Catch broken pages before your revenue drops |
| **Minimal false positives** | Two-scan confirmation means alerts you can trust |
| **No technical skills needed** | Plain-language diagnostics and guided fixes |
| **All themes supported** | Works with any Shopify theme out of the box |
| **No store slowdown** | Scans run externally — your storefront stays fast |
| **Privacy-first** | Read-only access, no customer data collected |

---

## Search Terms (suggested)

- broken product page
- PDP monitoring
- add to cart missing
- product page errors
- revenue loss prevention
- page health check

---

## Demo / Review Instructions (for Shopify review team)

1. Install the app on a development store.
2. On first launch, the app redirects to the billing approval screen ($10/month, 14-day free trial).
3. After approving billing, you land on the dashboard.
4. Navigate to **Product Pages** and click **Add Product Page**.
5. Use the Shopify resource picker to select 1-3 products.
6. Click **Scan Now** on any product page to trigger a manual scan.
7. After the scan completes (up to 30 seconds), view the results on the product page detail screen.
8. Navigate to **Issues** to see any detected problems with severity levels.
9. Navigate to **Scans** to view scan history.
10. Navigate to **Settings** to configure alert email and preferences.

**Expected behavior:**
- Scans run without affecting the storefront.
- Issues are created only when problems are detected.
- Alerts are sent only for high-severity issues confirmed across 2 scans.
- The dashboard shows color-coded status: green (healthy), yellow (warnings), red (critical issues).

---

## Notes for Submission

- **Billing:** All charges go through the Shopify Billing API.
- **Scopes:** `read_products`, `read_themes` (read-only).
- **No customer data:** The app does not access orders, customers, or checkout data.
- **Webhooks:** Handles `app_uninstalled`, `app_subscription_update`, and `shop_update`.
- **Phase 1 only:** The listing should not reference auto-fix, SEO, or optimization features — those are planned for future phases.
