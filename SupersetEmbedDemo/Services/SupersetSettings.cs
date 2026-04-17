using System;
using System.Configuration;

namespace SupersetEmbedDemo.Services
{
    public static class SupersetSettings
    {
        public static string BaseUrl => GetRequired("Superset.BaseUrl").TrimEnd('/');
        public static string AdminUsername => GetRequired("Superset.AdminUsername");
        public static string AdminPassword => GetRequired("Superset.AdminPassword");
        public static string AuthProvider => GetOptional("Superset.AuthProvider", "db");
        public static string EmbeddedSdkUrl => GetOptional("Superset.EmbeddedSdkUrl",
            "https://unpkg.com/@superset-ui/embedded-sdk");
        public static string DemoDashboardUuid => GetOptional("Superset.DemoDashboardUuid",
            "abc123-demo-dashboard-uuid");

        public static int GuestTokenTtlSeconds
        {
            get
            {
                int ttl;
                return int.TryParse(GetOptional("Superset.GuestTokenTtlSeconds", "300"), out ttl) ? ttl : 300;
            }
        }

        public static bool DemoMode
        {
            get
            {
                bool demo;
                return bool.TryParse(GetOptional("Superset.DemoMode", "true"), out demo) && demo;
            }
        }

        private static string GetRequired(string key)
        {
            string value = ConfigurationManager.AppSettings[key];
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new InvalidOperationException(
                    "Missing required appSetting '" + key + "' in Web.config.");
            }
            return value;
        }

        private static string GetOptional(string key, string fallback)
        {
            string value = ConfigurationManager.AppSettings[key];
            return string.IsNullOrWhiteSpace(value) ? fallback : value;
        }
    }
}
