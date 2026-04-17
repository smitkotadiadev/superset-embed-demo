using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web.UI;
using SupersetEmbedDemo.Handlers;
using SupersetEmbedDemo.Models;
using SupersetEmbedDemo.Services;

namespace SupersetEmbedDemo
{
    public partial class ViewReport : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack) return;
            RegisterAsyncTask(new PageAsyncTask(LoadReportAsync));
        }

        private async Task LoadReportAsync()
        {
            int dashboardId = 0;
            int.TryParse(Request.QueryString["id"], out dashboardId);

            DashboardInfo info = null;
            string embedUuid = null;

            if (SupersetSettings.DemoMode)
            {
                DemoBanner.Visible = true;
                DemoMock.Visible = true;
                var demo = DashboardsHandler.DemoDashboards();
                info = demo.FirstOrDefault(d => d.Id == dashboardId) ?? demo.First();
                embedUuid = string.IsNullOrEmpty(info.Uuid)
                    ? SupersetSettings.DemoDashboardUuid
                    : info.Uuid;
            }
            else
            {
                try
                {
                    var client = new SupersetClient();
                    var all = await client.ListDashboardsAsync();
                    info = all.FirstOrDefault(d => d.Id == dashboardId) ?? all.FirstOrDefault();
                    if (info != null)
                    {
                        embedUuid = await client.GetDashboardEmbedUuidAsync(info.Id);
                        if (!string.IsNullOrEmpty(embedUuid))
                        {
                            info.Uuid = embedUuid;
                            info.EmbedEnabled = true;
                        }
                    }
                }
                catch (Exception ex)
                {
                    ErrorBanner.Visible = true;
                    ErrorMessage.Text = System.Web.HttpUtility.HtmlEncode(ex.Message);
                }
            }

            if (info == null)
            {
                info = new DashboardInfo { Title = "Report not found", Description = "No dashboard was loaded." };
            }

            var user = ResolveCurrentUser();
            BindPage(info, embedUuid, user);
        }

        private SupersetUser ResolveCurrentUser()
        {
            var user = new SupersetUser
            {
                Username = User != null && User.Identity != null && User.Identity.IsAuthenticated
                    ? User.Identity.Name
                    : "daniel",
                FirstName = "Daniel",
                LastName = "Evans",
                Email = "daniel@example.com",
                TenantId = Request.QueryString["tenant"] ?? "acme-42",
                Role = "Viewer"
            };
            return user;
        }

        private void BindPage(DashboardInfo info, string embedUuid, SupersetUser user)
        {
            PageTitle.Text = System.Web.HttpUtility.HtmlEncode(info.Title ?? "Report");
            DashboardTitle.Text = System.Web.HttpUtility.HtmlEncode(info.Title ?? "Report");
            DashboardDescription.Text = System.Web.HttpUtility.HtmlEncode(info.Description ?? string.Empty);
            ToolbarTitle.Text = System.Web.HttpUtility.HtmlEncode(info.Title ?? "Report");
            EmbedUuidLiteral.Text = System.Web.HttpUtility.HtmlEncode(
                string.IsNullOrEmpty(embedUuid) ? "(not published for embedding)" : embedUuid);
            GuestUserLiteral.Text = System.Web.HttpUtility.HtmlEncode(user.Username);
            TenantLiteral.Text = System.Web.HttpUtility.HtmlEncode(user.TenantId);
            MockTenantLabel.Text = System.Web.HttpUtility.HtmlEncode(user.TenantId);

            OpenInSuperset.NavigateUrl = info.Id > 0
                ? SupersetSettings.BaseUrl + "/superset/dashboard/" + info.Id + "/"
                : SupersetSettings.BaseUrl + "/dashboard/list/";

            var rls = BuildRlsForUser(user);

            var bootstrap = new Dictionary<string, object>
            {
                { "dashboardId", info.Id },
                { "dashboardUuid", embedUuid ?? string.Empty },
                { "dashboardTitle", info.Title },
                { "supersetDomain", SupersetSettings.BaseUrl },
                { "sdkUrl", SupersetSettings.EmbeddedSdkUrl },
                { "demoMode", SupersetSettings.DemoMode },
                { "appPath", ResolveUrl("~/") },
                {
                    "user", new Dictionary<string, object>
                    {
                        { "username", user.Username },
                        { "firstName", user.FirstName },
                        { "lastName", user.LastName },
                        { "tenantId", user.TenantId }
                    }
                },
                {
                    "urlParams", new Dictionary<string, object>
                    {
                        { "standalone", "3" },
                        { "tenant_id", user.TenantId }
                    }
                },
                { "rls", rls }
            };

            BootstrapJson.Text = JsonUtil.Serialize(bootstrap);
        }

        private static List<object> BuildRlsForUser(SupersetUser user)
        {
            var list = new List<object>();
            if (!string.IsNullOrEmpty(user.TenantId))
            {
                list.Add(new Dictionary<string, object>
                {
                    { "clause", "tenant_id = '" + user.TenantId.Replace("'", "''") + "'" }
                });
            }
            return list;
        }
    }
}
