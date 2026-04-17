If Docker/WSL is not installed on your Windows server, so you'll need to run Superset on a separate host (Linux, WSL, or Docker Desktop on your workstation). Here is the complete end-to-end procedure.

## 1. Stand up Apache Superset (Docker Compose path)

On any machine that has Docker:

```bash
git clone https://github.com/apache/superset
cd superset
git checkout 6.0.0          # or any recent tag
```

## 2. Enable embedding + CORS for the ASP.NET origin

Superset reads a Python config at `docker/pythonpath_dev/superset_config_docker.py`. Create it (or edit it) with the following. The two ASP.NET origins shown come from the IIS site you're already running:

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
        "http://localhost:51834",
    ],
}

TALISMAN_ENABLED = False
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = ["superset.views.core.log", "superset.security.api"]

OVERRIDE_HTTP_HEADERS = {"X-Frame-Options": ""}
HTTP_HEADERS = {}
```

Then start:

```bash
docker compose -f docker-compose-non-dev.yml up -d
```

When it's up, Superset is on `http://<superset-host>:8088` with default credentials `admin` / `admin`.

## 3. Create the `EmbeddedViewer` guest role

In the Superset UI, go to **Settings → List Roles → + Role**. Name it `EmbeddedViewer`. Grant only what embedded users need, typically:

- `can read Chart`
- `can read Dashboard`
- `can read Dataset`
- `can explore json Superset` (needed by the SDK)
- `can dashboard Superset`
- `menu access Dashboards`

Under **Settings → List Users**, open the `admin` user and make sure it keeps the `Admin` role — the ASP.NET backend uses admin credentials to mint tokens.

## 4. Enable embedding on a dashboard and copy the UUID

1. Open any dashboard (or create a new one).
2. Click the **…** menu in the top-right → **Embed dashboard**.
3. In "Allowed domains" paste both ASP.NET origins:

   ```
   http://localhost:51834
   ```

4. Click **Enable embedding**. Superset shows an `Embed ID` — that's the UUID the ASP.NET code needs.

Also grant the `EmbeddedViewer` role access to every dataset the dashboard queries: **Datasets → (edit icon) → Permissions → add Role**.

## 5. Point the ASP.NET app at your Superset

Edit `C:\Users\Administrator\Documents\Projects\Daniel\ASP.NET\SupersetEmbedDemo\Web.config` and change the `appSettings`:

```xml
<add key="Superset.BaseUrl"            value="http://<superset-host>:8088" />
<add key="Superset.AdminUsername" value="admin" />
<add key="Superset.AdminPassword" value="admin" />
<add key="Superset.AuthProvider" value="db" />
<add key="Superset.GuestTokenTtlSeconds" value="300" />
<add key="Superset.DemoMode" value="false" />
<add key="Superset.DemoDashboardUuid" value="" />
<add key="Superset.EmbeddedSdkUrl" value="https://cdn.jsdelivr.net/npm/@superset-ui/embedded-sdk@0.3.0/bundle/index.js" />
<add key="Superset.TenantRlsClauseTemplate" value="" />
```

Then recycle the app pool so the new config is picked up:

```powershell
C:\Windows\System32\inetsrv\appcmd.exe recycle apppool DefaultAppPool
```

## 6. Test end-to-end

1. Browse to `http://localhost:51834/Reports.aspx`. The yellow "Demo mode" banner should be gone and the list should now be your real Superset dashboards (pulled via `GET /api/v1/dashboard/` using the cached admin token).
2. Click **Open** on a dashboard that has embedding enabled. `ViewReport.aspx` loads, calls `Handlers/GuestTokenHandler.ashx`, which calls `POST /api/v1/security/guest_token/` on Superset, and the iframe renders the real dashboard.
3. In the same page you'll see the "bootstrap payload sent to the browser" block — the `dashboardUuid` there should match the one you copied in step 4, and `supersetDomain` should be your Superset URL.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Reports.aspx` shows an "Error loading dashboards" banner | Admin login failing | Verify `Superset.BaseUrl`, `AdminUsername`, `AdminPassword`; test `curl -X POST $BASE/api/v1/security/login -H "Content-Type: application/json" -d '{"username":"admin","password":"admin","provider":"db","refresh":true}'` |
| iframe loads but shows "Access denied" | Dataset permission | Add `EmbeddedViewer` role to every dataset the dashboard uses |
| iframe stays blank / CSP error in browser console | `X-Frame-Options` or Talisman blocking embed | Confirm `TALISMAN_ENABLED = False` and `OVERRIDE_HTTP_HEADERS = {"X-Frame-Options": ""}` are set, then restart Superset |
| Browser console: `CORS error` | `CORS_OPTIONS.origins` missing | Add the exact ASP.NET origin (scheme + host + port) and restart Superset |
| Guest token call returns 422 | `allowed_domains` on the dashboard doesn't include your ASP.NET origin | Open dashboard → Embed dashboard → add origin |
| Guest token returned but iframe loops on load | Cookies blocked (Safari / cross-site) | Put Superset and ASP.NET on the same parent domain (e.g. `reports.example.com` + `app.example.com`) or use Chrome/Edge for the demo |

## Quick pre-flight check from this host

Once your Superset is up, run this on the Windows Server to confirm both ends agree:

```powershell
$base = "http://<superset-host>:8088"
$login = Invoke-RestMethod -Method Post -Uri "$base/api/v1/security/login" `
  -ContentType "application/json" `
  -Body '{"username":"admin","password":"admin","provider":"db","refresh":true}'
$login.access_token.Substring(0,40) + "..."
Invoke-RestMethod -Uri "$base/api/v1/dashboard/" `
  -Headers @{ Authorization = "Bearer $($login.access_token)" } |
  Select-Object -ExpandProperty result | Select-Object id,dashboard_title,status
```

If that prints a token and a dashboard list, your Superset is correctly exposing the REST API and the ASP.NET app will work identically once `Web.config` points at it.
