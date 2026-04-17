<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Limitations.aspx.cs" Inherits="SupersetEmbedDemo.Limitations" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitlePlaceHolder" runat="server">Limitations &amp; styling</asp:Content>

<asp:Content ID="MainContentArea" ContentPlaceHolderID="MainContent" runat="server">
    <section>
        <h1>Styling and limitations</h1>
        <p class="lead">
            What you can and can't do when embedding Superset inside a host ASP.NET application, with a focus
            on styling, data freshness, and operational considerations worth knowing before committing to the
            technology.
        </p>
    </section>

    <section>
        <h2>Styling the embedded dashboard</h2>
        <p>
            The Superset dashboard renders inside a cross-origin iframe. Browsers prevent the host page's CSS
            from reaching across that boundary - so styling the dashboard itself requires changes inside
            Superset. Here's what's available, roughly in order of effort.
        </p>

        <div class="card-grid">
            <div class="card">
                <h3>1. Host-level styling</h3>
                <p>
                    You can style everything <em>around</em> the iframe - toolbars, navigation, filters, KPI
                    strips - as standard ASP.NET pages with CSS. The <code>Site.css</code> in this project is a
                    reference example.
                </p>
                <p class="muted">Cheap, fast, gives 80% of the "it feels native" result.</p>
            </div>
            <div class="card">
                <h3>2. Dashboard-level CSS (admin UI)</h3>
                <p>
                    In Superset, open a dashboard and choose <em>Edit CSS</em>. The CSS you enter there is
                    injected into the dashboard iframe. You can retarget Superset classes, e.g.
                    <code>.dashboard-component-chart-holder</code> or <code>.header-title</code>.
                </p>
                <pre><code>.dashboard-header { background: #1b2230 !important; color: #fff; }
.chart-header     { font-family: "Segoe UI", sans-serif; }
.slice_container  { border-radius: 8px; }</code></pre>
            </div>
            <div class="card">
                <h3>3. Global theming (server-side)</h3>
                <p>
                    <code>superset_config.py</code> accepts a <code>THEME_OVERRIDES</code> dict (Superset 4.x+)
                    and supports custom colour palettes. Changes require a Superset restart and apply to all
                    dashboards.
                </p>
                <pre><code>THEME_OVERRIDES = {
  "colors": {
    "primary": { "base": "#20a7c9" },
    "grayscale": { "light1": "#f6f7fb" }
  }
}</code></pre>
            </div>
            <div class="card">
                <h3>4. Custom React build (nuclear option)</h3>
                <p>
                    Fork Superset, change the React components, rebuild. Gives pixel-level control but you
                    inherit a large maintenance burden. Only worth it if you ship Superset as a product surface.
                </p>
            </div>
        </div>

        <div class="card card--warning">
            <strong>What the host page cannot change</strong>
            <ul>
                <li>Fonts, colours or layout <em>inside</em> the Superset iframe via host CSS - that's blocked by the same-origin policy.</li>
                <li>Individual chart types - these are rendered by Superset's React/D3/ECharts components.</li>
                <li>The loading spinner that Superset shows before the dashboard has finished fetching data.</li>
            </ul>
        </div>
    </section>

    <section>
        <h2>Known limitations worth budgeting for</h2>

        <div class="card">
            <h3>Embedded SDK is still labelled <em>alpha</em></h3>
            <p>The package is <code>@superset-ui/embedded-sdk@0.1.0-alpha.x</code>. It is stable enough for
                production (many SaaS products ship it), but expect occasional breaking changes on minor
                bumps and test before upgrading.</p>
        </div>

        <div class="card">
            <h3>Authoring happens in Superset, not in the host</h3>
            <p>There is no official <em>embedded authoring</em> SDK. To let users create or edit dashboards you
                either (a) deep-link them into the Superset UI, or (b) iframe the Superset authoring UI with an
                authenticated session. SSO between your ASP.NET site and Superset is required for (b) to feel
                seamless.</p>
        </div>

        <div class="card">
            <h3>REST/JSON sources are second class</h3>
            <p>Superset expects SQL. REST APIs work via Shillelagh or via an ETL into a database. Building a
                truly real-time dashboard on top of a REST endpoint usually requires either a streaming source
                (Kafka + Druid/Pinot) or frequent polling into a warehouse.</p>
        </div>

        <div class="card">
            <h3>Filter persistence per guest is limited</h3>
            <p>Guest sessions do not persist dashboard filter state server-side. You can round-trip filter
                values through <code>urlParams</code> if you want filters to survive page reloads, but users
                cannot "save a view" the way an authenticated Superset user can.</p>
        </div>

        <div class="card">
            <h3>Alerts &amp; scheduled reports are workspace-level</h3>
            <p>Email/Slack alerts live inside Superset and target Superset users. If your end-users exist only
                on the ASP.NET side, you need a small glue service that triggers alerts based on the REST API
                you expose to Superset, or a scheduled ASP.NET job that calls the Superset chart export APIs.</p>
        </div>

        <div class="card">
            <h3>iframe, not web component</h3>
            <p>Embedding uses an iframe. That means:</p>
            <ul>
                <li>You cannot style the interior from the host page.</li>
                <li>Focus management, keyboard shortcuts, and accessibility testing need to happen at the Superset level.</li>
                <li>Certain ad-blockers and corporate proxies treat embedded iframes more aggressively.</li>
            </ul>
        </div>

        <div class="card">
            <h3>Browser storage &amp; third-party cookies</h3>
            <p>Browsers are progressively locking down third-party cookies. If your Superset is on a different
                domain from the host, the guest session cookie may be blocked in Safari by default. Mitigations:
                serve Superset on a subdomain of the host site (e.g. <code>reports.example.com</code>), or ensure
                the Embedded SDK is configured with <code>SameSite=None; Secure</code> cookies.</p>
        </div>

        <div class="card">
            <h3>Performance scaling</h3>
            <p>Every embed triggers at least one guest token call plus whatever queries the dashboard runs.
                Cache <code>access_token</code> at the host (this sample caches for 15 minutes), and use Superset's
                query cache plus a warm-up job for frequently-viewed dashboards.</p>
        </div>
    </section>

    <section>
        <h2>Compatibility matrix used in this sample</h2>
        <table class="data-table">
            <thead>
                <tr><th>Component</th><th>Tested</th><th>Notes</th></tr>
            </thead>
            <tbody>
                <tr><td>ASP.NET Web Forms</td><td>.NET Framework 4.7.2</td><td>Also works on 4.8. Requires <code>Async="true"</code> on pages doing server-to-Superset calls.</td></tr>
                <tr><td>Visual Studio</td><td>2019 / 2022</td><td>Open <code>SupersetEmbedDemo.sln</code> directly. No NuGet restore required (uses only BCL types).</td></tr>
                <tr><td>Apache Superset</td><td>3.x, 4.x</td><td>Requires <code>EMBEDDED_SUPERSET</code> feature flag and a dashboard marked <em>embed enabled</em>.</td></tr>
                <tr><td>Embedded SDK</td><td><code>0.1.0-alpha.11</code></td><td>Loaded from <code>unpkg.com</code> CDN; swappable via <code>Superset.EmbeddedSdkUrl</code>.</td></tr>
                <tr><td>Browser</td><td>Edge, Chrome, Firefox</td><td>Safari needs cookie settings tuned (see above).</td></tr>
            </tbody>
        </table>
    </section>
</asp:Content>
