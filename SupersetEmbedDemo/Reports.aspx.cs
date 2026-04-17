using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Web.UI;
using System.Web.UI.WebControls;
using SupersetEmbedDemo.Handlers;
using SupersetEmbedDemo.Models;
using SupersetEmbedDemo.Services;

namespace SupersetEmbedDemo
{
    public partial class Reports : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack) return;
            RegisterAsyncTask(new PageAsyncTask(LoadDashboardsAsync));
        }

        private async Task LoadDashboardsAsync()
        {
            if (SupersetSettings.DemoMode)
            {
                DemoBanner.Visible = true;
                BindDashboards(DashboardsHandler.DemoDashboards());
                return;
            }

            try
            {
                var client = new SupersetClient();
                var dashboards = await client.ListDashboardsAsync();
                await client.EnrichWithEmbedInfoAsync(dashboards);
                BindDashboards(dashboards);
            }
            catch (Exception ex)
            {
                ErrorBanner.Visible = true;
                ErrorMessage.Text = System.Web.HttpUtility.HtmlEncode(ex.Message);
                BindDashboards(new List<DashboardInfo>());
            }
        }

        private void BindDashboards(List<DashboardInfo> items)
        {
            if (items == null || items.Count == 0)
            {
                EmptyState.Text =
                    "<tr><td colspan=\"6\" class=\"muted\" style=\"text-align:center; padding: 28px;\">" +
                    "No dashboards were returned. In a real Superset instance, create one and mark it as embedded.</td></tr>";
                return;
            }

            DashboardList.DataSource = items;
            DashboardList.DataBind();
        }

        protected void DashboardList_OnItemDataBound(object sender, RepeaterItemEventArgs e)
        {
            if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem) return;
            var info = (DashboardInfo)e.Item.DataItem;

            var statusLiteral = (Literal)e.Item.FindControl("StatusLiteral");
            if (statusLiteral != null)
            {
                statusLiteral.Text = BuildStatusBadges(info);
            }

            var openLink = (HyperLink)e.Item.FindControl("OpenLink");
            if (openLink != null && !info.Published)
            {
                openLink.Enabled = false;
                openLink.CssClass = "btn btn--secondary btn--sm";
                openLink.ToolTip = "Unpublished dashboards cannot be embedded.";
                openLink.NavigateUrl = "#";
            }

            var editLink = (HyperLink)e.Item.FindControl("EditLink");
            if (editLink != null)
            {
                editLink.NavigateUrl = BuildSupersetEditUrl(info);
            }
        }

        private static string BuildStatusBadges(DashboardInfo info)
        {
            var parts = new List<string>();
            parts.Add(info.Published
                ? "<span class=\"badge badge--published\">Published</span>"
                : "<span class=\"badge badge--draft\">Draft</span>");
            if (info.EmbedEnabled)
            {
                parts.Add(" <span class=\"badge badge--embedded\">Embed on</span>");
            }
            return string.Join(" ", parts);
        }

        private static string BuildSupersetEditUrl(DashboardInfo info)
        {
            var baseUrl = SupersetSettings.BaseUrl;
            if (info.Id > 0)
            {
                return baseUrl + "/superset/dashboard/" + info.Id + "/?edit=true";
            }
            return baseUrl + "/dashboard/list/";
        }
    }
}
