using System;
using System.Web.UI;
using SupersetEmbedDemo.Services;

namespace SupersetEmbedDemo
{
    public partial class SiteMaster : MasterPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            ConfigBaseUrl.Text = System.Web.HttpUtility.HtmlEncode(SupersetSettings.BaseUrl);
            ConfigDemoMode.Text = SupersetSettings.DemoMode ? "on" : "off";
            EnvLabel.Text = SupersetSettings.DemoMode ? "Demo mode" : "Live Superset";
            if (EnvDot != null)
            {
                EnvDot.Attributes["class"] = SupersetSettings.DemoMode
                    ? "env-dot env-dot--demo"
                    : "env-dot env-dot--live";
            }
        }
    }
}
