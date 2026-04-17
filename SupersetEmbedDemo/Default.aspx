<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="SupersetEmbedDemo.Default" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitlePlaceHolder" runat="server">Overview</asp:Content>

<asp:Content ID="MainContentArea" ContentPlaceHolderID="MainContent" runat="server">
    <section>
        <h1>Embed Apache Superset in classic ASP.NET</h1>
        <p class="lead">
            This prototype shows how to embed live Apache Superset dashboards inside a classic
            ASP.NET Web Forms application. It covers the end-to-end flow: admin authentication,
            guest token minting, dashboard listing, embedding, data sources via REST, and
            permissioning.
        </p>

        <div class="card card--info">
            <strong>How to run</strong>
            <ol>
                <li>Open <code>SupersetEmbedDemo.sln</code> in Visual Studio 2019+ (.NET Framework 4.7.2).</li>
                <li>Press F5. The project uses IIS Express and starts at <code>http://localhost:51834</code>.</li>
                <li>By default <code>Superset.DemoMode</code> is <code>true</code> in <code>Web.config</code>, so pages render with mock data and a static dashboard mockup.</li>
                <li>Set <code>Superset.DemoMode</code> to <code>false</code> and fill in the other <code>Superset.*</code> settings in <code>Web.config</code> to talk to a real Apache Superset instance.</li>
            </ol>
        </div>
    </section>

    <section>
        <h2>What this sample demonstrates</h2>
        <div class="feature-grid">
            <a class="feature-tile" href="<%: ResolveUrl("~/Reports.aspx") %>">
                <div class="feature-tile-title">Listing reports</div>
                <p class="feature-tile-desc">Reads dashboards from <code>/api/v1/dashboard/</code> using a server-held admin token, then renders a searchable list.</p>
            </a>
            <a class="feature-tile" href="<%: ResolveUrl("~/ViewReport.aspx?id=1") %>">
                <div class="feature-tile-title">Opening a report</div>
                <p class="feature-tile-desc">Mounts the Superset Embedded SDK against a dashboard UUID, using a guest token minted server-side.</p>
            </a>
            <a class="feature-tile" href="<%: ResolveUrl("~/CreateReport.aspx") %>">
                <div class="feature-tile-title">Creating a report</div>
                <p class="feature-tile-desc">Deep-links into the Superset editor and shows how to register the new dashboard for embedding.</p>
            </a>
            <a class="feature-tile" href="<%: ResolveUrl("~/DataSources.aspx") %>">
                <div class="feature-tile-title">REST API data sources</div>
                <p class="feature-tile-desc">A local JSON endpoint simulating a REST-backed dataset, with parameters and response shape suitable for Superset.</p>
            </a>
            <a class="feature-tile" href="<%: ResolveUrl("~/Permissions.aspx") %>">
                <div class="feature-tile-title">Permissions &amp; RLS</div>
                <p class="feature-tile-desc">Maps ASP.NET identity to Superset roles and Row Level Security clauses attached to the guest token.</p>
            </a>
            <a class="feature-tile" href="<%: ResolveUrl("~/Limitations.aspx") %>">
                <div class="feature-tile-title">Styling &amp; limitations</div>
                <p class="feature-tile-desc">What host CSS can and cannot do inside the Superset iframe, plus known API limitations.</p>
            </a>
        </div>
    </section>

    <section>
        <h2>How embedding works</h2>
        <div class="card-grid">
            <div class="card">
                <h3>1. Server obtains admin access token</h3>
                <p><code>POST /api/v1/security/login</code> with an admin account. The response contains
                    <code>access_token</code> which the ASP.NET server caches in memory for 15 minutes.</p>
                <pre><code>var client = new SupersetClient();
string accessToken = await client.GetAccessTokenAsync();</code></pre>
            </div>
            <div class="card">
                <h3>2. Server mints a per-user guest token</h3>
                <p>For each embed request, the server calls <code>POST /api/v1/security/guest_token/</code>
                    with the target dashboard UUID, user info, and Row Level Security clauses.</p>
                <pre><code>var token = await client.CreateGuestTokenAsync(new GuestTokenRequest {
    DashboardUuid = "abc123",
    User = new SupersetUser { Username = "daniel" },
    RowLevelSecurity = { new RlsRule { Clause = "tenant_id = 42" } }
});</code></pre>
            </div>
            <div class="card">
                <h3>3. Browser embeds the dashboard</h3>
                <p>The page loads <code>@superset-ui/embedded-sdk</code> from a CDN. The SDK mounts an iframe
                    to the Superset domain and uses the <code>fetchGuestToken</code> callback to refresh tokens.</p>
                <pre><code>SupersetDemo.embedDashboard({
  dashboardUuid: "abc123",
  supersetDomain: "https://superset.example.com",
  mountElement: document.getElementById("dashboard-mount")
});</code></pre>
            </div>
        </div>
    </section>

    <section>
        <h2>Environment checklist</h2>
        <ul>
            <li>Apache Superset 3.x or newer with <code>FEATURE_FLAGS = {"EMBEDDED_SUPERSET": True}</code>.</li>
            <li>Dashboard marked as <strong>Enable embedding</strong> in Superset Admin - returns an embed UUID.</li>
            <li>Superset <code>GUEST_ROLE_NAME</code> configured with the permissions you want the guest to have.</li>
            <li>CORS configured on Superset: add your ASP.NET origin to <code>ENABLE_CORS = True</code> and <code>CORS_OPTIONS</code>.</li>
            <li><code>TALISMAN_ENABLED = False</code> (or relaxed CSP) so the iframe can load in the host page.</li>
            <li>Host origin added to <code>WTF_CSRF_ENABLED</code> allow list if you use browser-side writes.</li>
        </ul>
    </section>
</asp:Content>
