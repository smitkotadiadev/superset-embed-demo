<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" Async="true" CodeBehind="Reports.aspx.cs" Inherits="SupersetEmbedDemo.Reports" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitlePlaceHolder" runat="server">Reports</asp:Content>

<asp:Content ID="MainContentArea" ContentPlaceHolderID="MainContent" runat="server">
    <section>
        <div class="row-between">
            <div>
                <h1>Reports</h1>
                <p class="muted">Dashboards available in Superset. Click <strong>Open</strong> to embed one in the next page.</p>
            </div>
            <div class="button-row">
                <a class="btn btn--secondary btn--sm" href="<%: ResolveUrl("~/Reports.aspx") %>">Refresh</a>
                <a class="btn btn--primary btn--sm" href="<%: ResolveUrl("~/CreateReport.aspx") %>">Create report</a>
            </div>
        </div>

        <asp:Panel ID="ErrorBanner" runat="server" Visible="false" CssClass="status-banner status-banner--error">
            <div>
                <strong>Could not load dashboards from Superset</strong>
                <asp:Literal ID="ErrorMessage" runat="server" />
            </div>
        </asp:Panel>

        <asp:Panel ID="DemoBanner" runat="server" Visible="false" CssClass="status-banner status-banner--warning">
            <div>
                <strong>Demo mode is active</strong>
                The list below is a sample. Set <code>Superset.DemoMode</code> to <code>false</code> in
                <code>Web.config</code> and configure an admin login to load dashboards from a real Superset instance.
            </div>
        </asp:Panel>

        <div class="card">
            <table class="data-table" role="table">
                <thead>
                    <tr>
                        <th>Title</th>
                        <th>Owner</th>
                        <th>Tags</th>
                        <th>Status</th>
                        <th>Updated</th>
                        <th style="width: 200px;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="DashboardList" runat="server" OnItemDataBound="DashboardList_OnItemDataBound">
                        <ItemTemplate>
                            <tr>
                                <td>
                                    <strong><%# Eval("Title") %></strong><br />
                                    <span class="muted" style="font-size:12px;"><%# Eval("Description") %></span>
                                </td>
                                <td><%# Eval("Owner") %></td>
                                <td>
                                    <asp:Repeater ID="TagRepeater" runat="server" DataSource='<%# Eval("Tags") %>'>
                                        <ItemTemplate>
                                            <span class="badge badge--muted"><%# Container.DataItem %></span>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </td>
                                <td>
                                    <asp:Literal ID="StatusLiteral" runat="server" />
                                </td>
                                <td class="muted"><%# Eval("ChangedOn", "{0:yyyy-MM-dd HH:mm}") %></td>
                                <td>
                                    <asp:HyperLink ID="OpenLink" runat="server" CssClass="btn btn--primary btn--sm"
                                        NavigateUrl='<%# "~/ViewReport.aspx?id=" + Eval("Id") %>' Text="Open" />
                                    <asp:HyperLink ID="EditLink" runat="server" CssClass="btn btn--ghost btn--sm"
                                        Target="_blank" Text="Edit in Superset" />
                                </td>
                            </tr>
                        </ItemTemplate>
                    </asp:Repeater>
                    <asp:Literal ID="EmptyState" runat="server" />
                </tbody>
            </table>
        </div>
    </section>

    <section>
        <h2>How this list is built</h2>
        <div class="card-grid">
            <div class="card">
                <h3>Server-side fetch</h3>
                <p>The page-load handler calls <code>SupersetClient.ListDashboardsAsync()</code>, which hits
                    <code>GET /api/v1/dashboard/</code> with the cached admin access token and parses the
                    JSON response into <code>DashboardInfo</code> objects bound to the repeater.</p>
            </div>
            <div class="card">
                <h3>Client-side AJAX variant</h3>
                <p>For dynamic grids, use the AJAX handler instead:</p>
                <pre><code>fetch("/Handlers/DashboardsHandler.ashx")
  .then(r => r.json())
  .then(data => render(data.dashboards));</code></pre>
            </div>
            <div class="card">
                <h3>Embed eligibility</h3>
                <p>Only dashboards flagged as <em>embedded</em> in Superset return a UUID that the Embedded SDK
                    can consume. The demo mock marks one row as draft and one as non-embedded to show the UI
                    states.</p>
            </div>
        </div>
    </section>
</asp:Content>
