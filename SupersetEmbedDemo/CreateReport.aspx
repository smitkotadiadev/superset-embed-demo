<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="CreateReport.aspx.cs" Inherits="SupersetEmbedDemo.CreateReport" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitlePlaceHolder" runat="server">Create report</asp:Content>

<asp:Content ID="MainContentArea" ContentPlaceHolderID="MainContent" runat="server">
    <section>
        <h1>Create a new report</h1>
        <p class="lead">
            Superset is a visual authoring tool. Dashboards (reports) are created and edited inside Superset itself.
            The host application is responsible for deep-linking users into the right Superset screen and, once
            the dashboard is ready, enabling it for embedding.
        </p>

        <div class="card card--info">
            <strong>Recommended workflow</strong>
            <ol>
                <li>Sign-in (or SSO) the user into Superset with a role that includes <em>Dashboard</em> and <em>Chart</em> write permission.</li>
                <li>Deep-link them to <code>/chart/add</code> to build charts, then <code>/dashboard/new</code> to assemble the dashboard.</li>
                <li>Once saved, toggle <strong>Enable embedding</strong> in the dashboard's Settings menu - this returns an <code>embedded.uuid</code>.</li>
                <li>Store the <code>embedded.uuid</code> in your application and point <code>ViewReport.aspx?id=...</code> at it.</li>
            </ol>
        </div>

        <div class="card-grid">
            <div class="card card--accent">
                <h3>Jump into Superset</h3>
                <p>Open the Superset authoring screens in a new tab. The user needs a Superset account with the
                    <code>Alpha</code>, <code>Gamma</code> (for limited authoring) or <code>Admin</code> role.</p>
                <div class="button-row">
                    <asp:HyperLink ID="NewDashboardLink" runat="server" Target="_blank" CssClass="btn btn--primary"
                        Text="New dashboard" />
                    <asp:HyperLink ID="NewChartLink" runat="server" Target="_blank" CssClass="btn btn--secondary"
                        Text="New chart" />
                    <asp:HyperLink ID="DashboardListLink" runat="server" Target="_blank" CssClass="btn btn--ghost"
                        Text="All dashboards" />
                </div>
            </div>

            <div class="card card--accent">
                <h3>Register a new embed</h3>
                <p>After a user saves a dashboard in Superset, the host application receives or polls the
                    <code>embedded.uuid</code> and stores it. The admin API exposes this via:</p>
                <pre><code>GET  /api/v1/dashboard/{id}/embedded
POST /api/v1/dashboard/{id}/embedded
{
  "allowed_domains": ["<asp:Literal ID="AllowedDomainLiteral" runat="server" />"]
}</code></pre>
                <p class="muted">The <code>allowed_domains</code> list is the CORS guardrail for where the dashboard can be embedded.</p>
            </div>

            <div class="card card--accent">
                <h3>Inline iframe authoring (optional)</h3>
                <p>You can embed the Superset authoring UI directly using the same domain and an iframe
                    with an authenticated session. This skips the deep-link redirect but requires SSO so the
                    user is logged into Superset.</p>
                <pre><code>&lt;iframe src="<asp:Literal ID="EmbedDashboardNewUrl" runat="server" />"
        sandbox="allow-same-origin allow-scripts allow-forms allow-popups"&gt;
&lt;/iframe&gt;</code></pre>
            </div>
        </div>
    </section>

    <section>
        <h2>API-driven creation (advanced)</h2>
        <p>For automation scenarios - e.g. cloning a template dashboard when a new customer is provisioned -
            Superset's admin REST API can create dashboards and charts programmatically.</p>

        <div class="card">
            <h3>Create a dashboard via REST</h3>
            <pre><code>POST /api/v1/dashboard/
Authorization: Bearer &lt;admin_access_token&gt;
X-CSRFToken: &lt;csrf_token&gt;
Content-Type: application/json

{
  "dashboard_title": "Customer 42 - Sales overview",
  "slug": "cust-42-sales",
  "owners": [1],
  "published": false,
  "json_metadata": "{}",
  "position_json": "{}"
}</code></pre>
        </div>

        <div class="card">
            <h3>Server-side helper (C#)</h3>
            <pre><code>public async Task&lt;int&gt; CreateDashboardAsync(string title, string slug)
{
    var accessToken = await GetAccessTokenAsync();
    var csrfToken   = await GetCsrfTokenAsync(accessToken);

    var payload = JsonUtil.Serialize(new Dictionary&lt;string, object&gt; {
        { "dashboard_title", title },
        { "slug", slug },
        { "published", false }
    });

    using (var request = new HttpRequestMessage(HttpMethod.Post,
        _baseUrl + "/api/v1/dashboard/"))
    {
        request.Content = new StringContent(payload, Encoding.UTF8, "application/json");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Headers.Add("X-CSRFToken", csrfToken);
        var response = await _http.SendAsync(request);
        var json = await response.Content.ReadAsStringAsync();
        return (int)JsonUtil.ParseObject(json)["id"];
    }
}</code></pre>
        </div>

        <div class="card card--warning">
            <strong>Caveat</strong>
            The REST API accepts empty <code>json_metadata</code> and <code>position_json</code>, producing an
            empty dashboard. Populating charts and layout programmatically is possible but verbose; most teams
            either create a template dashboard and clone it, or let users build dashboards in the Superset UI.
        </div>
    </section>

    <section>
        <h2>Recommended admin-side settings</h2>
        <ul>
            <li><code>EMBEDDED_SUPERSET</code> must be in <code>FEATURE_FLAGS</code>.</li>
            <li><code>PUBLIC_ROLE_LIKE_GAMMA</code> or a custom <code>GUEST_ROLE_NAME</code> should be set to limit what guests can see.</li>
            <li>Dashboard owners should explicitly grant dataset access to the guest role.</li>
            <li>Set <code>GUEST_TOKEN_JWT_EXP_SECONDS</code> between 300 and 900 seconds for a balance of UX and security.</li>
        </ul>
    </section>
</asp:Content>
