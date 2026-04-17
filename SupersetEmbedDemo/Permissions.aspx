<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Permissions.aspx.cs" Inherits="SupersetEmbedDemo.Permissions" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitlePlaceHolder" runat="server">Permissions</asp:Content>

<asp:Content ID="MainContentArea" ContentPlaceHolderID="MainContent" runat="server">
    <section>
        <h1>Permissions &amp; security model</h1>
        <p class="lead">
            In an embedded scenario the <em>host</em> application (this ASP.NET site) remains the source of truth
            for user identity. Superset never authenticates end-users directly - it simply trusts the signed
            guest token produced by the host. Understanding who is allowed to see what happens in two places:
            Superset-side roles, and host-supplied RLS clauses.
        </p>

        <div class="card-grid">
            <div class="card card--accent">
                <h3>1. Superset roles (what features are available)</h3>
                <p>Superset has three baked-in roles plus a configurable guest role:</p>
                <ul>
                    <li><strong>Admin</strong> &mdash; full access including settings.</li>
                    <li><strong>Alpha</strong> &mdash; can create/edit dashboards and charts.</li>
                    <li><strong>Gamma</strong> &mdash; can view dashboards; restricted authoring.</li>
                    <li><strong>Public</strong> &mdash; unauthenticated viewing (usually disabled).</li>
                    <li><strong>Guest</strong> &mdash; configured via <code>GUEST_ROLE_NAME</code>; this is the role the guest token assumes.</li>
                </ul>
                <p class="muted">Define a custom role (e.g. <code>EmbeddedViewer</code>) with only the permissions your embedded users need,
                    then set <code>GUEST_ROLE_NAME = "EmbeddedViewer"</code> in <code>superset_config.py</code>.</p>
            </div>

            <div class="card card--accent">
                <h3>2. Dataset ownership (what data is available)</h3>
                <p>Even when a dashboard is embedded, Superset checks that the guest role has access to the
                    underlying datasets. Grant dataset access to <code>EmbeddedViewer</code> explicitly for each
                    dataset the embedded dashboards use.</p>
                <p class="muted">Best practice: create one dataset per logical entity and grant access to the
                    guest role at dataset level, not at database level.</p>
            </div>

            <div class="card card--accent">
                <h3>3. RLS clauses (what rows are visible)</h3>
                <p>Row Level Security clauses travel inside the guest token. They are appended as a
                    <code>WHERE</code> to every query against the dataset and cannot be bypassed from the browser.
                    Typical pattern: scope by tenant, region, or cost-centre.</p>
                <pre><code>{
  "rls": [
    { "clause": "tenant_id = 'acme-42'" },
    { "clause": "region IN ('EMEA','APAC')", "dataset": 17 }
  ]
}</code></pre>
            </div>
        </div>
    </section>

    <section>
        <h2>Example: map an ASP.NET identity to a guest token</h2>
        <p>The server-side code below shows how the current ASP.NET user is translated into a Superset guest token request:</p>
        <pre><code>public GuestTokenRequest BuildRequestFor(IPrincipal principal, string dashboardUuid)
{
    var user = new SupersetUser {
        Username  = principal.Identity.Name,
        FirstName = Claim(principal, ClaimTypes.GivenName),
        LastName  = Claim(principal, ClaimTypes.Surname),
        TenantId  = Claim(principal, "tenant_id"),
        Role      = principal.IsInRole("Manager") ? "Manager" : "Viewer"
    };

    var rls = new List&lt;RlsRule&gt; {
        new RlsRule { Clause = $"tenant_id = '{user.TenantId.Replace("'", "''")}'" }
    };
    if (user.Role == "Viewer") {
        rls.Add(new RlsRule { Clause = "is_confidential = 0" });
    }

    return new GuestTokenRequest {
        DashboardUuid     = dashboardUuid,
        User              = user,
        RowLevelSecurity  = rls
    };
}</code></pre>
        <p class="muted">The same mapping lives in <code>GuestTokenHandler.ashx.cs</code> in this sample.</p>
    </section>

    <section>
        <h2>What the guest can and cannot do</h2>
        <div class="card-grid">
            <div class="card card--info">
                <h3>Allowed</h3>
                <ul>
                    <li>View the specific dashboard UUIDs listed in the token's <code>resources</code> array.</li>
                    <li>Change <em>dashboard filters</em> (subject to RLS).</li>
                    <li>Drill through to chart <em>Explore</em> view if <code>GUEST_ROLE_NAME</code> permits it.</li>
                    <li>Download CSV / Excel / PNG if the role grants the relevant permission.</li>
                </ul>
            </div>
            <div class="card card--warning">
                <h3>Not allowed</h3>
                <ul>
                    <li>View dashboards or datasets not referenced in the token.</li>
                    <li>Bypass RLS clauses &mdash; even by crafting query strings.</li>
                    <li>Access the admin UI, SQL Lab, or alert/report configuration (unless explicitly granted).</li>
                    <li>Reuse an expired token (default TTL is 5 minutes; SDK requests a new one transparently).</li>
                </ul>
            </div>
        </div>
    </section>

    <section>
        <h2>Audit &amp; logging</h2>
        <ul>
            <li>Superset records every guest-token-initiated request with the <code>username</code> you sent.</li>
            <li>Enable <code>LOG_LEVEL = "INFO"</code> and ship logs to your SIEM to correlate ASP.NET sessions with Superset activity.</li>
            <li>For SOC2 / HIPAA scenarios set <code>GUEST_TOKEN_JWT_SECRET</code> explicitly and rotate it via a secret manager.</li>
        </ul>
    </section>
</asp:Content>
