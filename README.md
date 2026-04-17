# SupersetEmbedDemo

Reference implementation showing how to embed **Apache Superset** (running as Docker on Linux) inside a **classic ASP.NET Web Forms** SaaS product hosted on **Windows + IIS**.

## Architecture

```
┌────────────────────────────┐            ┌──────────────────────────────┐
│  Windows Server 2022       │            │  Linux host                  │
│  IIS / ASP.NET 4.7.2       │  ─REST→    │  Docker Compose              │
│  SupersetEmbedDemo (host)  │  ←iframe─  │  apache/superset:6.0.0       │
│  http://<host>:51834       │            │  http://<host>:8088          │
└────────────────────────────┘            └──────────────────────────────┘
         ▲                                              ▲
         │ browser                                      │
         └──────────────── end user ────────────────────┘
```

Same pattern fits the existing draw.io integration — draw.io and Superset can both ride a single Linux/Docker host, exposed as iframes from the ASP.NET product.

## Implementation status

| Requirement | Status | Artefact |
|---|---|---|
| How to embed | Done | `ViewReport.aspx`, `Scripts/superset-embed.js`, `Handlers/GuestTokenHandler.ashx` |
| List reports | Done — live embed status detected | `Reports.aspx`, `Handlers/DashboardsHandler.ashx` |
| Open a report | Done | `ViewReport.aspx` |
| Create a new report | Done (deep-link + REST) | `CreateReport.aspx` |
| REST/JSON datasets + parameters | Done | `DataSources.aspx`, `Handlers/DataSourceProxyHandler.ashx` |
| Per-tenant row-level security | Done — clause template in config | `Web.config` → `Superset.TenantRlsClauseTemplate` |
| Permissions model | Done | `Permissions.aspx` |
| CSS / styling limits | Done | `Limitations.aspx`, `Styles/Site.css` |
| VS solution loads without changes | Done | no NuGet packages; pure BCL references |

Verified against a live Apache Superset 6.0.0 (Docker) instance — 15 dashboards listed, 4 correctly flagged as embed-enabled, guest-token embed round-trip succeeds.

## Repository layout

```
SupersetEmbedDemo.sln                 solution file (VS 2019 / 2022, no NuGet)
SupersetEmbedDemo/
  Default.aspx                        overview + 3-step embed flow
  Reports.aspx                        list all dashboards (live embed detection)
  ViewReport.aspx                     embed a dashboard with guest token + RLS
  CreateReport.aspx                   deep-link / REST paths to author new reports
  DataSources.aspx                    REST JSON dataset demo + parameter passing
  Permissions.aspx                    roles, dataset grants, RLS, audit notes
  Limitations.aspx                    styling tiers + known limits
  Site.Master / Styles/Site.css       shared chrome + design tokens
  Services/
    SupersetClient.cs                 admin login, CSRF, list, embed UUID, guest token
    SupersetSettings.cs               Web.config reader
  Handlers/
    GuestTokenHandler.ashx            POST endpoint that mints guest tokens
    DashboardsHandler.ashx            GET endpoint returning JSON list
    DataSourceProxyHandler.ashx       sample REST JSON source with filters
  Scripts/superset-embed.js           SDK loader + fetchGuestToken callback
  Web.config                          all runtime settings
```

## Running locally on the current Windows host

The project is already hosted under IIS on this server:

- Site: `SupersetEmbedDemo` on port `51834`, app pool `DefaultAppPool`
- Directly reachable: `http://localhost:51834/` and `http://<server-ip>:51834/`

Manage it with:

```powershell
C:\Windows\System32\inetsrv\appcmd.exe start   site SupersetEmbedDemo
C:\Windows\System32\inetsrv\appcmd.exe stop    site SupersetEmbedDemo
C:\Windows\System32\inetsrv\appcmd.exe recycle apppool DefaultAppPool
```

To open the solution elsewhere, just double-click `SupersetEmbedDemo.sln` in Visual Studio 2019/2022 with the **ASP.NET and web development** workload installed. No NuGet restore is required.

## Part A — Stand up Apache Superset (Docker on Linux)

On your Linux host with Docker:

```bash
git clone https://github.com/apache/superset
cd superset
git checkout 6.0.0
```

## Part B — Configure Superset for embedding

Create `docker/pythonpath_dev/superset_config_docker.py` with:

```python
FEATURE_FLAGS = {
    "EMBEDDED_SUPERSET": True,
    "DASHBOARD_RBAC": True,
}

GUEST_ROLE_NAME = "EmbeddedViewer"
GUEST_TOKEN_JWT_SECRET = "replace-with-a-long-random-string"
GUEST_TOKEN_JWT_EXP_SECONDS = 300

ENABLE_CORS = True
CORS_OPTIONS = {
    "supports_credentials": True,
    "allow_headers": ["*"],
    "resources": ["*"],
    "origins": [
        "http://<your-windows-host>:51834",
        "http://localhost:51834",
    ],
}

TALISMAN_ENABLED = False
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = ["superset.views.core.log", "superset.security.api"]

OVERRIDE_HTTP_HEADERS = {"X-Frame-Options": ""}
HTTP_HEADERS = {}
```

Start Superset:

```bash
docker compose -f docker-compose-non-dev.yml up -d
```

When it's up: `http://<superset-host>:8088`, default credentials `admin / admin`.

## Part C — Superset-side one-time setup

### C.1 Create the `EmbeddedViewer` guest role

**Settings → List Roles → + Role**, name `EmbeddedViewer`, grant at minimum:

- `can read Chart`
- `can read Dashboard`
- `can read Dataset`
- `can explore json Superset`
- `can dashboard Superset`
- `menu access Dashboards`

### C.2 Grant `can_set_embedded` to Admin (only needed in 5.x/6.x)

**Settings → List Roles → Admin → Edit** and add:

- `can set embedded Dashboard`
- `can delete embedded Dashboard`

Without these, Superset 6.0 hides the "Embed dashboard" menu item even with `EMBEDDED_SUPERSET = True`.

### C.3 Enable embedding on each dashboard

Open the dashboard → top-right kebab (⋯) → **Embed dashboard** → paste your ASP.NET origins into "Allowed domains" → **Enable embedding**. Superset returns an Embed ID (UUID) — the ASP.NET app discovers this automatically via `GET /api/v1/dashboard/{id}/embedded`, so no UUID needs to be pasted anywhere.

Also grant the `EmbeddedViewer` role to every dataset each dashboard queries: **Datasets → edit → Permissions → add Role**.

## Part D — Point ASP.NET at your Superset

Edit `SupersetEmbedDemo/Web.config`:

```xml
<add key="Superset.BaseUrl"              value="http://<superset-host>:8088" />
<add key="Superset.AdminUsername"        value="admin" />
<add key="Superset.AdminPassword"        value="admin" />
<add key="Superset.AuthProvider"         value="db" />
<add key="Superset.GuestTokenTtlSeconds" value="300" />
<add key="Superset.DemoMode"             value="false" />
<add key="Superset.DemoDashboardUuid"    value="" />
<add key="Superset.EmbeddedSdkUrl"       value="https://cdn.jsdelivr.net/npm/@superset-ui/embedded-sdk@0.3.0/bundle/index.js" />
<add key="Superset.TenantRlsClauseTemplate" value="" />
```

Recycle the app pool:

```powershell
C:\Windows\System32\inetsrv\appcmd.exe recycle apppool DefaultAppPool
```

## Part E — Multi-tenant row-level security (optional)

The guest token carries RLS clauses that Superset appends as an invisible `WHERE` on every query — users cannot bypass them from the browser because the clauses are signed into the JWT.

Set `Superset.TenantRlsClauseTemplate` to enable tenant isolation. `{tenantId}` is substituted with the current user's tenant:

```xml
<!-- off (safe default; works against any dataset) -->
<add key="Superset.TenantRlsClauseTemplate" value="" />

<!-- dataset has a tenant_id column -->
<add key="Superset.TenantRlsClauseTemplate" value="tenant_id = '{tenantId}'" />

<!-- different column name / compound clause -->
<add key="Superset.TenantRlsClauseTemplate" value="customer_code = '{tenantId}' AND is_public = 0" />
```

Single quotes in the tenant value are escaped automatically. The default is empty so the sample works out of the box against generic Superset datasets (World Bank, FCC survey, etc.) that have no tenant column.

## Part F — Test end-to-end

1. Browse `http://<windows-host>:51834/Reports.aspx` — the yellow "Demo mode" banner is gone and you see your real Superset dashboards. Rows whose dashboards have embedding enabled show the **Embed on** badge.
2. Click **Open** on any embed-enabled row. `ViewReport.aspx` calls `Handlers/GuestTokenHandler.ashx`, which calls `POST /api/v1/security/guest_token/` on Superset and mounts the iframe.
3. The "bootstrap payload sent to the browser" panel on `ViewReport.aspx` exposes the exact JSON passed to the SDK (UUID, domain, user, urlParams, RLS) — useful for debugging.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Reports.aspx` shows "Error loading dashboards" | Admin login failing | Re-check `Superset.BaseUrl`, `AdminUsername`, `AdminPassword`; run the pre-flight check below |
| Embed status badge missing on a dashboard you know is embeddable | Dashboard has no embed config | Open dashboard → kebab → Embed dashboard → Enable embedding |
| iframe loads but charts error with `column "tenant_id" does not exist` | RLS template injects a column that doesn't exist on your dataset | Set `Superset.TenantRlsClauseTemplate` to `""` until datasets have the tenant column |
| iframe shows Superset "Access denied" | Dataset permission | Add `EmbeddedViewer` role to every dataset the dashboard uses |
| iframe blank, CSP error in browser console | `X-Frame-Options` or Talisman blocking embed | Verify `TALISMAN_ENABLED = False` and `OVERRIDE_HTTP_HEADERS = {"X-Frame-Options": ""}`, restart Superset |
| Browser console: CORS error | Origin not in allowlist | Add exact scheme+host+port to `CORS_OPTIONS.origins` and restart Superset |
| Guest token call returns 422 | Dashboard's `allowed_domains` missing the origin | Open dashboard → Embed dashboard → add origin |
| Guest token returns but iframe loops on load | Cookies blocked (Safari / cross-site) | Put Superset and ASP.NET on the same parent domain (e.g. `reports.example.com` + `app.example.com`), or use Chrome/Edge |
| "Embed dashboard" menu item missing in Superset 6.0 | `can_set_embedded` permission not granted | See **C.2** above |
| SDK fails to load from unpkg | Alpha path removed from npm | Use the jsDelivr URL shown in Part D (`@0.3.0/bundle/index.js`) |

## Pre-flight check from the Windows host

```powershell
$base = "http://<superset-host>:8088"
$login = Invoke-RestMethod -Method Post -Uri "$base/api/v1/security/login" `
  -ContentType "application/json" `
  -Body '{"username":"admin","password":"admin","provider":"db","refresh":true}'
$h = @{ Authorization = "Bearer $($login.access_token)" }
Invoke-RestMethod -Uri "$base/api/v1/dashboard/" -Headers $h |
  Select-Object -ExpandProperty result | Select-Object id, dashboard_title, status
```

If that prints an access token and a dashboard list, your Superset is correctly exposing the REST API and the ASP.NET app will work identically as soon as `Web.config` points at it.

## Production deployment outline

When ready to ship this alongside the SaaS product:

1. **Linux Docker host** — runs `docker compose up -d` for Superset (and draw.io if you want the same pattern). Expose via reverse proxy on `reports.<product>.com`.
2. **Windows Server + IIS** — the classic ASP.NET product including the embed pages from this sample. Deploy as a standard IIS site or as a sub-application inside the existing product.
3. **Same registrable parent domain** for both — Safari and increasingly Chrome block third-party cookies, so colocating under one parent (e.g. `app.<product>.com` + `reports.<product>.com`) keeps guest-session cookies flowing.
4. **Secrets** — move `Superset.AdminPassword` and `GUEST_TOKEN_JWT_SECRET` into a proper secret store (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault). `Web.config` can reference external keys with `configSource` and AppSetting references.
5. **TLS everywhere** — put both hosts behind HTTPS; update CORS origins, `SESSION_COOKIE_SECURE = True` in `superset_config_docker.py`.
6. **Superset upgrades** — the Embedded SDK is still labelled alpha; pin to a specific `@superset-ui/embedded-sdk` version in `Superset.EmbeddedSdkUrl` rather than `@latest`.
