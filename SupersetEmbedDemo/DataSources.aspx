<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="DataSources.aspx.cs" Inherits="SupersetEmbedDemo.DataSources" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitlePlaceHolder" runat="server">Data sources</asp:Content>

<asp:Content ID="MainContentArea" ContentPlaceHolderID="MainContent" runat="server">
    <section>
        <h1>Feeding Superset with JSON/REST data</h1>
        <p class="lead">
            Superset is fundamentally a SQL-on-a-database BI tool. Its first-class connectors are relational
            (PostgreSQL, MSSQL, MySQL, Snowflake, BigQuery, etc.). To plug a REST API / JSON feed into Superset
            you have three realistic options, ordered from simplest to most flexible.
        </p>

        <div class="card-grid">
            <div class="card card--accent">
                <h3>Option A &mdash; Land JSON in a database</h3>
                <p>Your ASP.NET app (or a small ETL job) calls the REST endpoint and writes the rows into a table
                    in e.g. SQL Server or PostgreSQL. Superset connects to that table. This is the approach most
                    teams pick because it gives Superset a stable, typed schema.</p>
                <p class="muted">Refresh cadence can be minutes, hours or real-time depending on how you schedule the sync.</p>
            </div>
            <div class="card card--accent">
                <h3>Option B &mdash; Use Trino / Presto / DuckDB</h3>
                <p>Point Superset at a federated query engine that can expose REST or document stores as SQL.
                    Trino has connectors for JSON, ElasticSearch, MongoDB, Kafka and others.</p>
                <p class="muted">Good when the source data is already structured; adds one extra service to your stack.</p>
            </div>
            <div class="card card--accent">
                <h3>Option C &mdash; Shillelagh / REST adapter</h3>
                <p>Superset supports <a href="https://github.com/betodealmeida/shillelagh" target="_blank" rel="noopener">Shillelagh</a>,
                    a SQLAlchemy dialect that lets Superset query REST APIs, Google Sheets and CSVs as if they
                    were tables. Install it in the Superset container, then define a database connection that
                    points at your REST endpoint.</p>
                <p class="muted">Fastest path from "JSON feed" to "Superset chart" but with throughput and join limitations.</p>
            </div>
        </div>
    </section>

    <section>
        <h2>Sample REST endpoint in this project</h2>
        <p>
            The handler <code>/Handlers/DataSourceProxyHandler.ashx</code> simulates a tenant REST API that
            returns paginated sales records. You can point Superset at it through Shillelagh, or ingest from
            it into a SQL table. Try it below with parameters.
        </p>

        <div class="card">
            <div class="form-grid">
                <div class="form-field">
                    <label for="RegionFilter">Region</label>
                    <select id="RegionFilter">
                        <option value="">All</option>
                        <option>North America</option>
                        <option>EMEA</option>
                        <option>APAC</option>
                        <option>LATAM</option>
                    </select>
                </div>
                <div class="form-field">
                    <label for="CategoryFilter">Category</label>
                    <select id="CategoryFilter">
                        <option value="">All</option>
                        <option>Cloud</option>
                        <option>Hardware</option>
                        <option>Services</option>
                        <option>Licences</option>
                    </select>
                </div>
                <div class="form-field">
                    <label for="PageSize">Page size</label>
                    <input type="number" id="PageSize" value="25" min="1" max="250" />
                </div>
                <div class="form-field">
                    <label for="PageNum">Page</label>
                    <input type="number" id="PageNum" value="1" min="1" />
                </div>
                <div class="form-field" style="justify-content: flex-end;">
                    <label>&nbsp;</label>
                    <button type="button" id="RunQueryBtn" class="btn btn--primary">Run query</button>
                </div>
            </div>

            <div class="row-between">
                <div class="muted" id="QueryMeta">Showing - results will appear below.</div>
                <code id="QueryUrl" class="muted" style="font-size: 12px;"></code>
            </div>

            <div style="overflow:auto; margin-top:12px;">
                <table class="data-table" id="DataSetTable">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Region</th>
                            <th>Product</th>
                            <th>Category</th>
                            <th>Units</th>
                            <th>Revenue</th>
                            <th>Sale date</th>
                            <th>Rep</th>
                        </tr>
                    </thead>
                    <tbody id="DataSetTableBody">
                        <tr><td colspan="8" class="muted" style="text-align:center; padding: 24px;">Click Run query to load data.</td></tr>
                    </tbody>
                </table>
            </div>
        </div>

        <div class="card">
            <h3>Response shape</h3>
            <pre><code>{
  "total": 250,
  "page": 1,
  "pageSize": 25,
  "records": [
    {
      "id": "REC-1000",
      "region": "EMEA",
      "product": "Orion",
      "category": "Cloud",
      "revenue": 18420.55,
      "units": 42,
      "saleDate": "2026-02-17",
      "salesRep": "M. Rodriguez"
    }
  ]
}</code></pre>
        </div>
    </section>

    <section>
        <h2>Passing parameters into Superset charts</h2>
        <p>Parameters that come from the host ASP.NET session flow into Superset through three mechanisms:</p>

        <div class="card-grid">
            <div class="card">
                <h3>1. URL parameters via the SDK</h3>
                <p>Any key/value in <code>dashboardUiConfig.urlParams</code> is appended to the Superset iframe URL
                    and available to chart <code>Jinja</code> templating as <code>{{ url_param('tenant_id') }}</code>.</p>
                <pre><code>SupersetDemo.embedDashboard({
  dashboardUuid: "abc123",
  supersetDomain: "...",
  mountElement: el,
  urlParams: { tenant_id: "acme-42", region: "EMEA" }
});</code></pre>
            </div>
            <div class="card">
                <h3>2. Dashboard native filters</h3>
                <p>Dashboard filters defined in Superset can be pre-seeded from URL params via
                    <code>native_filters</code> query strings. Useful for things like pre-selecting
                    <em>Region = EMEA</em>.</p>
            </div>
            <div class="card">
                <h3>3. Row Level Security clauses</h3>
                <p>The guest token carries <code>rls</code> clauses that act as invisible <code>WHERE</code>
                    filters on datasets, e.g. <code>tenant_id = 'acme-42'</code>. Users cannot bypass these
                    from the browser because they are signed into the JWT.</p>
            </div>
        </div>
    </section>

    <script>
        (function () {
            var regionEl = document.getElementById("RegionFilter");
            var categoryEl = document.getElementById("CategoryFilter");
            var pageSizeEl = document.getElementById("PageSize");
            var pageEl = document.getElementById("PageNum");
            var runBtn = document.getElementById("RunQueryBtn");
            var body = document.getElementById("DataSetTableBody");
            var meta = document.getElementById("QueryMeta");
            var urlOut = document.getElementById("QueryUrl");

            function escapeHtml(s) {
                return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
                    return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
                });
            }

            function formatCurrency(n) {
                var num = Number(n);
                if (isNaN(num)) return "";
                return "$" + num.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
            }

            function runQuery() {
                var params = new URLSearchParams();
                if (regionEl.value) params.set("region", regionEl.value);
                if (categoryEl.value) params.set("category", categoryEl.value);
                params.set("pageSize", pageSizeEl.value || 25);
                params.set("page", pageEl.value || 1);
                var url = "<%: ResolveUrl("~/Handlers/DataSourceProxyHandler.ashx") %>?" + params.toString();
                urlOut.textContent = url;
                body.innerHTML = '<tr><td colspan="8" class="muted" style="text-align:center; padding: 24px;">Loading...</td></tr>';
                fetch(url, { headers: { "Accept": "application/json" } })
                    .then(function (r) { return r.json(); })
                    .then(function (data) {
                        if (!data.records || data.records.length === 0) {
                            body.innerHTML = '<tr><td colspan="8" class="muted" style="text-align:center; padding: 24px;">No records matched your filters.</td></tr>';
                            meta.textContent = "0 of 0 records";
                            return;
                        }
                        body.innerHTML = data.records.map(function (r) {
                            return "<tr>" +
                                "<td><code>" + escapeHtml(r.id) + "</code></td>" +
                                "<td>" + escapeHtml(r.region) + "</td>" +
                                "<td>" + escapeHtml(r.product) + "</td>" +
                                "<td><span class=\"badge badge--muted\">" + escapeHtml(r.category) + "</span></td>" +
                                "<td>" + escapeHtml(r.units) + "</td>" +
                                "<td><strong>" + escapeHtml(formatCurrency(r.revenue)) + "</strong></td>" +
                                "<td class=\"muted\">" + escapeHtml(r.saleDate) + "</td>" +
                                "<td>" + escapeHtml(r.salesRep) + "</td>" +
                                "</tr>";
                        }).join("");
                        meta.textContent = "Showing " + data.records.length + " of " + data.total + " records (page " + data.page + ")";
                    })
                    .catch(function (err) {
                        body.innerHTML = '<tr><td colspan="8" class="status-banner--error" style="text-align:center; padding: 24px;">Request failed: ' + escapeHtml(err && err.message ? err.message : err) + '</td></tr>';
                    });
            }

            runBtn.addEventListener("click", runQuery);
            runQuery();
        })();
    </script>
</asp:Content>
