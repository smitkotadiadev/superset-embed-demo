<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" Async="true" CodeBehind="ViewReport.aspx.cs" Inherits="SupersetEmbedDemo.ViewReport" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitlePlaceHolder" runat="server">
    <asp:Literal ID="PageTitle" runat="server" Text="Report" />
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadPlaceHolder" runat="server">
    <script src="<%: ResolveUrl("~/Scripts/superset-embed.js") %>"></script>
</asp:Content>

<asp:Content ID="MainContentArea" ContentPlaceHolderID="MainContent" runat="server">
    <section>
        <div class="row-between">
            <div>
                <h1><asp:Literal ID="DashboardTitle" runat="server" Text="Report" /></h1>
                <p class="muted">
                    <asp:Literal ID="DashboardDescription" runat="server" />
                </p>
            </div>
            <div class="button-row">
                <a class="btn btn--secondary btn--sm" href="<%: ResolveUrl("~/Reports.aspx") %>">Back to list</a>
                <asp:HyperLink ID="OpenInSuperset" runat="server" Target="_blank"
                    CssClass="btn btn--ghost btn--sm" Text="Open in Superset" />
            </div>
        </div>

        <asp:Panel ID="ErrorBanner" runat="server" Visible="false" CssClass="status-banner status-banner--error">
            <div>
                <strong>Could not embed dashboard</strong>
                <asp:Literal ID="ErrorMessage" runat="server" />
            </div>
        </asp:Panel>

        <asp:Panel ID="DemoBanner" runat="server" Visible="false" CssClass="status-banner status-banner--warning">
            <div>
                <strong>Demo mode</strong>
                The frame below is a static mockup representing what the Superset iframe would render. Disable
                <code>Superset.DemoMode</code> and configure <code>Superset.BaseUrl</code> to embed the real dashboard.
            </div>
        </asp:Panel>

        <div class="embed-toolbar">
            <div>
                <div class="embed-toolbar-title"><asp:Literal ID="ToolbarTitle" runat="server" /></div>
                <div class="embed-toolbar-meta">
                    Embed UUID: <code><asp:Literal ID="EmbedUuidLiteral" runat="server" /></code> &middot;
                    Guest user: <code><asp:Literal ID="GuestUserLiteral" runat="server" /></code> &middot;
                    Tenant: <code><asp:Literal ID="TenantLiteral" runat="server" /></code>
                </div>
            </div>
            <div class="button-row">
                <label class="muted" style="display:flex; align-items:center; gap:6px; font-size:13px;">
                    <input type="checkbox" id="HideTitleToggle" /> Hide title
                </label>
                <label class="muted" style="display:flex; align-items:center; gap:6px; font-size:13px;">
                    <input type="checkbox" id="ExpandFiltersToggle" checked /> Expand filters
                </label>
                <button type="button" class="btn btn--secondary btn--sm" id="ReloadEmbedBtn">Reload</button>
            </div>
        </div>

        <div class="embed-frame" id="DashboardContainer">
            <div class="embed-loading" id="DashboardLoading">
                <div class="spinner"></div>
                <div>Requesting guest token and loading dashboard...</div>
            </div>
            <div id="DashboardMount" data-embed-mount></div>
            <asp:Panel ID="DemoMock" runat="server" Visible="false">
                <div class="mock-dashboard">
                    <div class="mock-filter-bar">
                        <span class="muted" style="font-size:12px; text-transform: uppercase; letter-spacing:0.04em;">Filters</span>
                        <span class="badge">Region: All</span>
                        <span class="badge">Category: All</span>
                        <span class="badge">Date: Year to date</span>
                        <span class="badge">Tenant: <asp:Literal ID="MockTenantLabel" runat="server" /></span>
                    </div>
                    <div class="mock-kpi">
                        <div class="mock-kpi-label">Revenue</div>
                        <div class="mock-kpi-value">$4.82M</div>
                        <div class="mock-kpi-delta">&#9650; 12.4% vs. previous period</div>
                    </div>
                    <div class="mock-kpi">
                        <div class="mock-kpi-label">Units sold</div>
                        <div class="mock-kpi-value">18,432</div>
                        <div class="mock-kpi-delta">&#9650; 6.1%</div>
                    </div>
                    <div class="mock-kpi">
                        <div class="mock-kpi-label">Avg. deal size</div>
                        <div class="mock-kpi-value">$261</div>
                        <div class="mock-kpi-delta mock-kpi-delta--down">&#9660; 2.8%</div>
                    </div>
                    <div class="mock-kpi">
                        <div class="mock-kpi-label">New customers</div>
                        <div class="mock-kpi-value">1,204</div>
                        <div class="mock-kpi-delta">&#9650; 18.9%</div>
                    </div>
                    <div class="mock-chart">
                        <h4>Revenue by quarter</h4>
                        <div class="mock-bars">
                            <div class="mock-bar" style="height: 60%;" data-label="Q1"></div>
                            <div class="mock-bar" style="height: 78%;" data-label="Q2"></div>
                            <div class="mock-bar" style="height: 52%;" data-label="Q3"></div>
                            <div class="mock-bar" style="height: 94%;" data-label="Q4"></div>
                        </div>
                    </div>
                    <div class="mock-pie">
                        <div class="mock-pie-chart"></div>
                        <div class="mock-legend">
                            <div class="mock-legend-item"><span class="mock-legend-swatch" style="background:#20a7c9;"></span> North America &mdash; 42%</div>
                            <div class="mock-legend-item"><span class="mock-legend-swatch" style="background:#ff9b00;"></span> EMEA &mdash; 24%</div>
                            <div class="mock-legend-item"><span class="mock-legend-swatch" style="background:#3aaa35;"></span> APAC &mdash; 19%</div>
                            <div class="mock-legend-item"><span class="mock-legend-swatch" style="background:#e04355;"></span> LATAM &mdash; 15%</div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
        </div>
    </section>

    <section>
        <h2>What happens when this page loads</h2>
        <ol>
            <li>
                ASP.NET builds a <em>context payload</em> on the server (current user, tenant, dashboard ID) and
                writes it as JSON into a bootstrap tag for the browser.
            </li>
            <li>
                The browser loads <code>@superset-ui/embedded-sdk</code> from the configured CDN URL.
            </li>
            <li>
                The SDK calls the host-supplied <code>fetchGuestToken</code> callback, which POSTs to
                <code>/Handlers/GuestTokenHandler.ashx</code>.
            </li>
            <li>
                The ASHX handler calls <code>POST /api/v1/security/guest_token/</code> on Superset with the user
                info and RLS clauses, and returns the token to the browser.
            </li>
            <li>
                The SDK injects an iframe pointing at <code>/embedded</code> on your Superset domain, passing
                the guest token via <code>postMessage</code>.
            </li>
        </ol>

        <div class="card">
            <h3>Bootstrap payload sent to the browser</h3>
            <pre><code id="BootstrapPayloadPre">&lt;waiting for render&gt;</code></pre>
        </div>
    </section>

    <script type="application/json" id="SupersetBootstrap"><asp:Literal ID="BootstrapJson" runat="server" /></script>

    <script>
        (function () {
            var bootstrap = {};
            try { bootstrap = JSON.parse(document.getElementById("SupersetBootstrap").textContent || "{}"); }
            catch (e) { bootstrap = {}; }

            window.__SUPERSET_DEMO_APP_PATH = bootstrap.appPath || "/";

            var pre = document.getElementById("BootstrapPayloadPre");
            if (pre) pre.textContent = JSON.stringify(bootstrap, null, 2);

            var container = document.getElementById("DashboardContainer");
            var mount = document.getElementById("DashboardMount");
            var reloadBtn = document.getElementById("ReloadEmbedBtn");
            var hideTitle = document.getElementById("HideTitleToggle");
            var expandFilters = document.getElementById("ExpandFiltersToggle");

            function activeEmbedOptions() {
                return {
                    dashboardUuid: bootstrap.dashboardUuid,
                    supersetDomain: bootstrap.supersetDomain,
                    mountElement: mount,
                    containerElement: container,
                    sdkUrl: bootstrap.sdkUrl,
                    user: bootstrap.user,
                    urlParams: bootstrap.urlParams || {},
                    uiConfig: {
                        hideTitle: !!(hideTitle && hideTitle.checked),
                        filters: { visible: true, expanded: !!(expandFilters && expandFilters.checked) }
                    }
                };
            }

            function renderDashboard() {
                if (bootstrap.demoMode) return;
                if (!mount) return;
                mount.innerHTML = "";
                if (window.SupersetDemo) {
                    window.SupersetDemo.embedDashboard(activeEmbedOptions());
                }
            }

            if (reloadBtn) reloadBtn.addEventListener("click", renderDashboard);
            if (hideTitle) hideTitle.addEventListener("change", renderDashboard);
            if (expandFilters) expandFilters.addEventListener("change", renderDashboard);

            if (bootstrap.demoMode) {
                var loading = document.getElementById("DashboardLoading");
                if (loading) loading.classList.add("hidden");
            } else if (bootstrap.dashboardUuid) {
                renderDashboard();
            } else {
                var loading2 = document.getElementById("DashboardLoading");
                if (loading2) loading2.classList.add("hidden");
            }
        })();
    </script>
</asp:Content>
