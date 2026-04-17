using System;
using System.Web.UI;
using SupersetEmbedDemo.Services;

namespace SupersetEmbedDemo
{
    public partial class CreateReport : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            var baseUrl = SupersetSettings.BaseUrl;
            NewDashboardLink.NavigateUrl = baseUrl + "/dashboard/new/";
            NewChartLink.NavigateUrl = baseUrl + "/chart/add";
            DashboardListLink.NavigateUrl = baseUrl + "/dashboard/list/";
            EmbedDashboardNewUrl.Text = System.Web.HttpUtility.HtmlEncode(baseUrl + "/dashboard/new/");
            AllowedDomainLiteral.Text = System.Web.HttpUtility.HtmlEncode(Request.Url.GetLeftPart(UriPartial.Authority));
        }
    }
}
