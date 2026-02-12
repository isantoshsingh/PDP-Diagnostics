---
description: Shopify App Bridge Web Components and JavaScript APIs for embedded apps using App Home
---

# Shopify App Bridge — Web Components & APIs Skill

This skill documents the **correct** usage of Shopify App Bridge web components and JavaScript APIs for embedded Shopify apps. App Bridge provides navigation, modals, title bars, save bars, toast notifications, resource pickers, and direct API access — all rendered within the Shopify admin.

> **Important:** App Bridge components render *outside* your app's iframe, in the Shopify admin itself. They are NOT part of your component hierarchy — they communicate via JavaScript messages with the admin.

**Official Docs:**
- App Bridge Overview: https://shopify.dev/docs/api/app-bridge
- App Bridge Library: https://shopify.dev/docs/api/app-bridge-library
- App Bridge Web Components: https://shopify.dev/docs/api/app-home/app-bridge-web-components
- App Bridge APIs: https://shopify.dev/docs/api/app-bridge-library/apis
- Migration Guide: https://shopify.dev/docs/api/app-bridge/migration-guide
- Using Modals: https://shopify.dev/docs/api/app-bridge/using-modals-in-your-app

---

## 1. Setup

App Bridge loads from a CDN script tag. No npm package needed (the npm `@shopify/app-bridge` package is in maintenance mode).

```html
<head>
  <meta name="shopify-api-key" content="<%= ShopifyApp.configuration.api_key %>" />
  <script src="https://cdn.shopify.com/shopifycloud/app-bridge.js"></script>
  <script src="https://cdn.shopify.com/shopifycloud/polaris.js"></script>
</head>
```

After loading, the global `shopify` object is available on `window`. Shopify automatically keeps the script up-to-date.

For TypeScript support, install `@shopify/app-bridge-types` as a dev dependency and add it to `compilerOptions.types`.

---

## 2. App Bridge Web Components

### 2.1 `s-app-nav` — Navigation Menu

Creates the app navigation sidebar (desktop) or title-bar dropdown (mobile). Modeled after the HTML `<nav>` element.

**Rules:**
- Nested navigation items are NOT supported
- Add `rel="home"` to the home route link — it sets the app home but is NOT rendered as a visible nav link
- Active link is automatically matched based on current URL

```html
<s-app-nav>
  <s-link href="/" rel="home">Home</s-link>
  <s-link href="/product_pages">Monitored Pages</s-link>
  <s-link href="/issues">Issues</s-link>
  <s-link href="/scans">Scan History</s-link>
  <s-link href="/settings">Settings</s-link>
  <s-link href="/billing">Pricing</s-link>
</s-app-nav>
```

> **Note:** In App Home docs this component uses `s-app-nav` + `s-link`. In older App Bridge Library docs it may appear as `ui-nav-menu` with `<a>` children. Use `s-app-nav` for new development.

---

### 2.2 `ui-title-bar` — Title Bar

Populates the Shopify admin title bar with a title, action buttons, and breadcrumbs.

**Attributes:**
| Attribute | Type | Description |
|---|---|---|
| `title` | string | Title text. Can also be set via `document.title` |

**Children:**

| Element | Attributes | Description |
|---|---|---|
| `<button>` | `variant`, `tone`, `onclick` | Action button |
| `<a>` | `variant`, `href` | Link action |
| `<section>` | `label` | Groups secondary actions in a dropdown |

**Button `variant` values:** `"primary"`, `"breadcrumb"`, or omit for secondary.
**Button `tone` values:** `"critical"`, `"default"` (only on `<button>`).

```html
<!-- Title bar with primary + secondary actions -->
<ui-title-bar title="Products">
  <button onclick="handleSecondary()">Secondary action</button>
  <button variant="primary" onclick="handlePrimary()">Primary action</button>
</ui-title-bar>

<!-- Title bar with breadcrumb -->
<ui-title-bar title="Product Details">
  <a variant="breadcrumb" href="/products">Products</a>
  <button variant="primary" onclick="handleSave()">Save</button>
</ui-title-bar>

<!-- Title bar with grouped secondary actions -->
<ui-title-bar title="Orders">
  <section label="More actions">
    <button onclick="handleExport()">Export</button>
    <button onclick="handleImport()">Import</button>
  </section>
  <button variant="primary" onclick="handleCreate()">Create order</button>
</ui-title-bar>
```

> **Note:** In App Home, you can also use the `s-page` component which handles both title bar and page layout in one component (with slots like `primary-action`, `secondary-actions`, `breadcrumb-actions`, `accessory`). Use `s-page` for page-level title bars and `ui-title-bar` inside modals.

---

### 2.3 `ui-modal` / `s-modal` — Modal

Displays an overlay that blocks interaction with the rest of the app.

> **Naming:** App Home docs use `s-modal` for inline content. App Bridge Library docs use `ui-modal`. Both work — `s-modal` is preferred for new App Home development.

**Attributes:**
| Attribute | Type | Description |
|---|---|---|
| `id` | string | Unique identifier (required for programmatic control) |
| `src` | string | URL to load in modal iframe (if set, inline children except `ui-title-bar` are ignored) |
| `variant` | string | Modal size: `"small"`, `"base"` (default), `"large"`, `"max"` (fullscreen replacement) |
| `heading` | string | Modal title (for `s-modal`) |

**Instance Methods:**
| Method | Description |
|---|---|
| `show()` | Opens the modal. Returns a promise — can be awaited |
| `hide()` | Closes the modal |

**Instance Properties:**
| Property | Description |
|---|---|
| `contentWindow` | `Window` object of modal iframe (only when `src` is used and modal is open) |
| `src` | Getter/setter for modal source URL |
| `variant` | Getter/setter for modal size |

**Events:** `show`, `hide`

#### Inline Content Modal

```html
<ui-modal id="confirm-modal">
  <div>
    <p>Are you sure you want to delete this resource?</p>
  </div>
  <ui-title-bar title="Confirm Delete">
    <button onclick="document.getElementById('confirm-modal').hide()">Cancel</button>
    <button variant="primary" tone="critical" onclick="handleDelete()">Delete</button>
  </ui-title-bar>
</ui-modal>

<button onclick="document.getElementById('confirm-modal').show()">
  Delete Resource
</button>
```

#### Using `s-modal` (App Home Style)

```html
<s-modal id="info-modal" heading="More Information" size="large">
  <s-box padding="base">
    <s-paragraph>Details about this feature.</s-paragraph>
  </s-box>
  <s-button slot="primary-action" onclick="document.getElementById('info-modal').hide()">
    Done
  </s-button>
  <s-button slot="secondary-actions" onclick="document.getElementById('info-modal').hide()">
    Cancel
  </s-button>
</s-modal>

<s-button onclick="document.getElementById('info-modal').show()">
  Learn More
</s-button>
```

#### URL-Based Modal (src)

```html
<ui-modal id="edit-modal" src="/products/123/edit" variant="large">
  <ui-title-bar title="Edit Product">
    <button variant="primary" onclick="handleSave()">Save</button>
    <button onclick="document.getElementById('edit-modal').hide()">Cancel</button>
  </ui-title-bar>
</ui-modal>
```

#### Programmatic Control via `shopify` Global

```javascript
shopify.modal.show('confirm-modal');
shopify.modal.hide('confirm-modal');
```

#### Communication Between Modal and Parent

For `src`-based modals, use `postMessage`:
```javascript
// In the modal (child):
window.opener.postMessage({ type: 'save', data: formData }, '*');

// In the parent:
const modal = document.getElementById('edit-modal');
await modal.show();
modal.contentWindow.postMessage({ type: 'init', data: config }, '*');
```

---

### 2.4 `s-app-window` — Fullscreen Modal Window

Displays a fullscreen modal window for complex workflows. Replaces the deprecated Fullscreen API.

**Attributes:**
| Attribute | Type | Description |
|---|---|---|
| `src` | string | URL of the content (required). Only supports src-based content |

**Instance Methods:** `show()`, `hide()`

```html
<s-app-window id="full-editor" src="/products/123/full-edit">
</s-app-window>

<s-button onclick="document.getElementById('full-editor').show()">
  Open Full Editor
</s-button>
```

The `s-app-window` content page should use `s-page` for layout:
```html
<!-- Inside the src page -->
<s-page heading="Full Editor">
  <s-button slot="primary-action" variant="primary" onclick="handleSave()">Save</s-button>
  <s-button slot="secondary-actions" onclick="handleCancel()">Cancel</s-button>

  <!-- Page content -->
  <s-section heading="Details">
    <form data-save-bar>
      <!-- form fields -->
    </form>
  </s-section>
</s-page>
```

---

### 2.5 `ui-save-bar` — Contextual Save Bar

Shows when a form has unsaved changes. Appears above the Shopify admin top bar.

**Attributes:**
| Attribute | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `discardConfirmation` | boolean | Show confirmation dialog on discard |

**Instance Methods:**
| Method | Description |
|---|---|
| `show()` | Shows the save bar |
| `hide()` | Hides the save bar |
| `toggle()` | Toggles visibility |

**Instance Properties:**
| Property | Description |
|---|---|
| `showing` | Boolean — whether save bar is currently visible |
| `discardConfirmation` | Getter/setter for discard confirmation |

**Events:** `show`, `hide`

#### Manual Save Bar

```html
<ui-save-bar id="my-save-bar">
  <button onclick="handleDiscard()">Discard</button>
  <button variant="primary" onclick="handleSave()">Save</button>
</ui-save-bar>
```

```javascript
// Show/hide programmatically
document.getElementById('my-save-bar').show();
document.getElementById('my-save-bar').hide();

// Or via shopify global
shopify.saveBar.show('my-save-bar');
shopify.saveBar.hide('my-save-bar');
```

#### Automatic Save Bar (Recommended)

Add `data-save-bar` to any `<form>` element. App Bridge auto-detects changes and shows the save bar. Pressing "Save" submits the form. Pressing "Discard" resets the form.

```html
<form action="/settings" method="post" data-save-bar>
  <input type="hidden" name="authenticity_token" value="<%= form_authenticity_token %>">

  <s-text-field label="Store Name" name="store_name" value="My Store"></s-text-field>
  <s-select label="Scan Frequency" name="frequency" value="daily">
    <s-option value="daily">Daily</s-option>
    <s-option value="weekly">Weekly</s-option>
  </s-select>
</form>
```

> **Best practice:** Use `data-save-bar` on forms instead of manual `ui-save-bar` whenever possible. It handles change detection, save, and discard automatically.

---

## 3. JavaScript APIs (`shopify` Global)

All APIs are available on the `shopify` global object after App Bridge loads.

### 3.1 Toast Notifications

Non-disruptive messages at the bottom of the interface.

```javascript
// Basic toast
shopify.toast.show('Product saved successfully');

// With options
shopify.toast.show('Changes saved', {
  duration: 3000  // milliseconds, default: 5000
});

// Error toast
shopify.toast.show('Failed to save product', {
  isError: true
});

// Toast with action button
shopify.toast.show('Product deleted', {
  action: {
    content: 'Undo',
    onAction: () => undoDelete()
  }
});
```

**Return value:** `show()` returns an ID that can be used to dismiss the toast later.

---

### 3.2 Resource Picker

Search-based UI for selecting products, collections, or variants. Both the app and user must have necessary permissions.

```javascript
// Basic product picker
const selected = await shopify.resourcePicker({ type: 'product' });

if (!selected) {
  // User cancelled
  return;
}

// Process selected products
selected.forEach(product => {
  console.log(product.id);       // "gid://shopify/Product/12345"
  console.log(product.title);    // "Product Title"
  console.log(product.handle);   // "product-handle"
  console.log(product.images[0].originalSrc);  // Image URL
});
```

**Options:**
| Option | Type | Description |
|---|---|---|
| `type` | string | `"product"`, `"collection"`, `"variant"` |
| `multiple` | boolean/number | Allow multi-select. `true`, `false`, or max count (e.g., `5`) |
| `actionVerb` | string | Verb for title and primary action (e.g., `"select"`, `"add"`) |
| `query` | string | Initial GraphQL search query |
| `filter.variants` | boolean | Show product variants |
| `filter.draft` | boolean | Show draft products |
| `filter.hidden` | boolean | Show hidden products (unpublished) |
| `filter.archived` | boolean | Show archived products |
| `selectionIds` | array | Pre-select resources by GID |

```javascript
// Advanced: multiple products with filters and pre-selection
const selected = await shopify.resourcePicker({
  type: 'product',
  action: 'select',
  multiple: 5,
  filter: {
    draft: false,
    archived: false,
    variants: false
  },
  selectionIds: [
    { id: 'gid://shopify/Product/12345' }
  ]
});
```

---

### 3.3 Session Token (ID Token)

Retrieves an OpenID Connect ID Token for authenticating requests to your backend.

```javascript
const token = await shopify.idToken();

// Use in request headers
fetch('/api/data', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

> **Note:** App Bridge automatically adds session tokens to `fetch` requests from your app. Manual `idToken()` calls are only needed for custom authentication flows.

**Expired token handling:** Return a `401 Unauthorized` with the `X-Shopify-Retry-Invalid-Session-Request` header, and App Bridge will refresh the token and retry the request automatically.

---

### 3.4 Direct API Access

Make authenticated Admin GraphQL API calls directly from the browser using the `shopify:` URL scheme.

**Requires TOML configuration:**
```toml
[access.admin]
direct_api_mode = "offline"
embedded_app_direct_api_access = true
```

```javascript
const response = await fetch('shopify:admin/api/graphql.json', {
  method: 'POST',
  body: JSON.stringify({
    query: `query GetProduct($id: ID!) {
      product(id: $id) { title description }
    }`,
    variables: { id: 'gid://shopify/Product/1234567890' }
  })
});

const { data } = await response.json();
```

> **Note:** These calls are automatically authenticated. No access token needed in headers.

---

### 3.5 Navigation

Programmatically navigate the embedded app.

```javascript
// Navigate within app
shopify.navigate('/products');

// Navigate to Shopify admin page
shopify.navigate('shopify:admin/products');

// Open external URL
shopify.navigate('https://example.com', { target: '_blank' });
```

---

## 4. Common Patterns for This Project

### Pattern: Delete Confirmation Modal

```html
<ui-modal id="delete-<%= page.id %>">
  <div>
    <s-box padding="base">
      <s-paragraph>
        Are you sure you want to remove <strong><%= page.title %></strong> from monitoring?
        This will delete all scan history and issues.
      </s-paragraph>
    </s-box>
  </div>
  <ui-title-bar title="Remove Page">
    <button onclick="document.getElementById('delete-<%= page.id %>').hide()">Cancel</button>
    <button variant="primary" tone="critical"
            onclick="document.getElementById('delete-form-<%= page.id %>').submit()">
      Remove
    </button>
  </ui-title-bar>
</ui-modal>

<form id="delete-form-<%= page.id %>" action="<%= product_page_path(page) %>"
      method="post" style="display: none;">
  <input type="hidden" name="_method" value="delete">
  <input type="hidden" name="authenticity_token" value="<%= form_authenticity_token %>">
</form>
```

### Pattern: Add Products via Resource Picker

```javascript
async function addProducts() {
  const selected = await shopify.resourcePicker({
    type: 'product',
    multiple: 5,
    filter: { draft: false, archived: false, variants: false }
  });

  if (!selected) return;

  // Submit selected products to backend
  const form = document.getElementById('add-products-form');
  const input = document.getElementById('selected-products');
  input.value = JSON.stringify(selected.map(p => ({
    shopify_product_id: p.id.replace('gid://shopify/Product/', ''),
    title: p.title,
    handle: p.handle,
    image_url: p.images[0]?.originalSrc
  })));
  form.submit();
}
```

### Pattern: Flash Messages as Toasts

```javascript
document.addEventListener('DOMContentLoaded', () => {
  const flash = document.getElementById('shopify-flash');
  if (!flash) return;

  const notice = flash.dataset.notice;
  const error = flash.dataset.error;

  if (notice) shopify.toast.show(notice, { duration: 3000 });
  if (error) shopify.toast.show(error, { duration: 5000, isError: true });
});
```

### Pattern: Rescan with Loading Feedback

```javascript
async function rescanPage(pageId) {
  const button = document.getElementById(`rescan-btn-${pageId}`);
  button.disabled = true;

  shopify.toast.show('Scan queued...', { duration: 2000 });

  const form = document.getElementById(`rescan-form-${pageId}`);
  form.submit();
}
```

---

## 5. Key Differences: `ui-*` vs `s-*` Components

| Feature | `ui-*` (App Bridge Library) | `s-*` (App Home / Polaris) |
|---|---|---|
| Navigation | `ui-nav-menu` with `<a>` children | `s-app-nav` with `s-link` children |
| Title Bar | `ui-title-bar` with `<button>` children | `s-page` with action slots |
| Modal (inline) | `ui-modal` with HTML children | `s-modal` with heading attr + slots |
| Modal (fullscreen) | `ui-modal variant="max"` | `s-app-window` with `src` |
| Save Bar | `ui-save-bar` with `<button>` children | `data-save-bar` on `<form>` |

> **For this project:** We use `s-app-nav` for navigation, `s-page` for page-level title bars, `ui-title-bar` inside modals, and `data-save-bar` on forms. Both `ui-modal` and `s-modal` work for inline modals.

---

## 6. Common Mistakes

### Never use self-closing tags with web components
```html
<!-- WRONG -->
<ui-modal id="my-modal" />

<!-- CORRECT -->
<ui-modal id="my-modal"></ui-modal>
```

### Modal requires exactly one parent element for inline content
```html
<!-- WRONG: multiple children -->
<ui-modal id="my-modal">
  <p>First paragraph</p>
  <p>Second paragraph</p>
  <ui-title-bar title="Title"></ui-title-bar>
</ui-modal>

<!-- CORRECT: wrap in single parent -->
<ui-modal id="my-modal">
  <div>
    <p>First paragraph</p>
    <p>Second paragraph</p>
  </div>
  <ui-title-bar title="Title"></ui-title-bar>
</ui-modal>
```

### ui-title-bar inside modal + page can cause conflicts
If you have `ui-title-bar` on the page AND inside a `ui-modal`, navigating between pages may cause the page title bar to disappear while loading. Use `s-page` for page titles and `ui-title-bar` only inside modals.

### Save bar button without variant is the discard button
```html
<ui-save-bar id="save-bar">
  <button>Discard</button>                    <!-- No variant = discard -->
  <button variant="primary">Save</button>     <!-- Primary = save -->
</ui-save-bar>
```

### Event listeners must use string event names
```javascript
// CORRECT
document.getElementById('my-modal').addEventListener('show', callback);
document.getElementById('my-modal').addEventListener('hide', callback);

// WRONG — no 'on' prefix
document.getElementById('my-modal').addEventListener('onshow', callback);
```

---

## 7. Quick Reference

### Web Components
| Component | Purpose | Key API |
|---|---|---|
| `s-app-nav` | App navigation sidebar | Children: `s-link` with `href`, `rel` |
| `ui-title-bar` | Admin title bar (in modals) | `title` attr, `<button>` children |
| `s-page` | Page title bar + layout | `heading` attr, slots: `primary-action`, `secondary-actions`, `breadcrumb-actions`, `accessory`, `aside` |
| `ui-modal` / `s-modal` | Overlay modal | `id`, `src`, `variant`/`size`, `heading`; methods: `show()`, `hide()` |
| `s-app-window` | Fullscreen modal | `src`; methods: `show()`, `hide()` |
| `ui-save-bar` | Contextual save bar | `id`, `discardConfirmation`; methods: `show()`, `hide()`, `toggle()` |

### JavaScript APIs (`shopify.*`)
| API | Purpose | Usage |
|---|---|---|
| `shopify.toast.show(msg, opts)` | Toast notification | `{ duration, isError, action }` |
| `shopify.resourcePicker(opts)` | Product/collection picker | `{ type, multiple, filter, selectionIds }` |
| `shopify.idToken()` | Session token | Returns promise with JWT |
| `shopify.modal.show(id)` | Open modal by ID | Programmatic modal control |
| `shopify.modal.hide(id)` | Close modal by ID | Programmatic modal control |
| `shopify.saveBar.show(id)` | Show save bar by ID | Programmatic save bar control |
| `shopify.saveBar.hide(id)` | Hide save bar by ID | Programmatic save bar control |
| `shopify.navigate(url)` | Navigate in embedded app | Supports `shopify:admin/*` URLs |
| `fetch('shopify:admin/api/graphql.json', opts)` | Direct Admin API | Requires TOML config |
