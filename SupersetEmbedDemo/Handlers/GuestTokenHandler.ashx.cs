using System;
using System.Collections.Generic;
using System.IO;
using System.Web;
using SupersetEmbedDemo.Models;
using SupersetEmbedDemo.Services;

namespace SupersetEmbedDemo.Handlers
{
    public class GuestTokenHandler : HttpTaskAsyncHandler
    {
        public override bool IsReusable => false;

        public override async System.Threading.Tasks.Task ProcessRequestAsync(HttpContext context)
        {
            context.Response.ContentType = "application/json";
            context.Response.Cache.SetCacheability(HttpCacheability.NoCache);

            if (!string.Equals(context.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase))
            {
                context.Response.StatusCode = 405;
                context.Response.Headers["Allow"] = "POST";
                await WriteErrorAsync(context, "Only POST is allowed for this endpoint.");
                return;
            }

            string body;
            using (var reader = new StreamReader(context.Request.InputStream))
            {
                body = await reader.ReadToEndAsync();
            }

            Dictionary<string, object> payload;
            try
            {
                payload = JsonUtil.ParseObject(body) ?? new Dictionary<string, object>();
            }
            catch (Exception ex)
            {
                context.Response.StatusCode = 400;
                await WriteErrorAsync(context, "Invalid JSON payload: " + ex.Message);
                return;
            }

            var dashboardUuid = GetString(payload, "dashboardUuid");
            if (string.IsNullOrWhiteSpace(dashboardUuid))
            {
                context.Response.StatusCode = 400;
                await WriteErrorAsync(context, "dashboardUuid is required.");
                return;
            }

            var currentUser = ResolveUser(context, payload);
            var request = new GuestTokenRequest
            {
                DashboardUuid = dashboardUuid,
                User = currentUser,
                RowLevelSecurity = BuildRlsRules(currentUser, payload)
            };

            if (SupersetSettings.DemoMode)
            {
                var demoToken = BuildDemoToken(request);
                await WriteJsonAsync(context, new Dictionary<string, object>
                {
                    { "token", demoToken },
                    { "demo", true },
                    { "ttlSeconds", SupersetSettings.GuestTokenTtlSeconds }
                });
                return;
            }

            try
            {
                var client = new SupersetClient();
                var token = await client.CreateGuestTokenAsync(request);
                await WriteJsonAsync(context, new Dictionary<string, object>
                {
                    { "token", token },
                    { "ttlSeconds", SupersetSettings.GuestTokenTtlSeconds }
                });
            }
            catch (SupersetApiException ex)
            {
                context.Response.StatusCode = 502;
                await WriteErrorAsync(context, ex.Message);
            }
            catch (Exception ex)
            {
                context.Response.StatusCode = 500;
                await WriteErrorAsync(context, "Unexpected error: " + ex.Message);
            }
        }

        private static SupersetUser ResolveUser(HttpContext context, Dictionary<string, object> payload)
        {
            var user = new SupersetUser
            {
                Username = GetString(payload, "username"),
                FirstName = GetString(payload, "firstName"),
                LastName = GetString(payload, "lastName"),
                Email = GetString(payload, "email"),
                TenantId = GetString(payload, "tenantId"),
                Role = GetString(payload, "role")
            };

            if (string.IsNullOrEmpty(user.Username) && context.User != null && context.User.Identity != null &&
                context.User.Identity.IsAuthenticated)
            {
                user.Username = context.User.Identity.Name;
            }

            if (string.IsNullOrEmpty(user.Username)) user.Username = "guest";
            if (string.IsNullOrEmpty(user.FirstName)) user.FirstName = "Guest";
            if (string.IsNullOrEmpty(user.LastName)) user.LastName = "User";
            if (string.IsNullOrEmpty(user.TenantId)) user.TenantId = "default";

            return user;
        }

        private static List<RlsRule> BuildRlsRules(SupersetUser user, Dictionary<string, object> payload)
        {
            var rules = new List<RlsRule>();

            if (!string.IsNullOrEmpty(user.TenantId) && !user.TenantId.Equals("default", StringComparison.OrdinalIgnoreCase))
            {
                rules.Add(new RlsRule { Clause = "tenant_id = '" + SqlEscape(user.TenantId) + "'" });
            }

            if (!payload.ContainsKey("rls") || !(payload["rls"] is System.Collections.ArrayList extraRls))
            {
                return rules;
            }

            foreach (var item in extraRls)
            {
                if (!(item is Dictionary<string, object> entry)) continue;
                var clause = GetString(entry, "clause");
                if (string.IsNullOrWhiteSpace(clause)) continue;

                var rule = new RlsRule { Clause = clause };
                if (entry.ContainsKey("dataset") && int.TryParse(
                    entry["dataset"]?.ToString(), out var datasetId))
                {
                    rule.DatasetId = datasetId;
                }
                rules.Add(rule);
            }
            return rules;
        }

        private static string BuildDemoToken(GuestTokenRequest request)
        {
            var header = new Dictionary<string, object> { { "alg", "HS256" }, { "typ", "demo" } };
            var payload = new Dictionary<string, object>
            {
                { "user", request.User.Username },
                { "resource", request.DashboardUuid },
                { "iat", DateTimeOffset.UtcNow.ToUnixTimeSeconds() },
                { "exp", DateTimeOffset.UtcNow.AddSeconds(SupersetSettings.GuestTokenTtlSeconds).ToUnixTimeSeconds() },
                { "demo", true }
            };
            return Base64UrlEncode(JsonUtil.Serialize(header)) + "." +
                   Base64UrlEncode(JsonUtil.Serialize(payload)) + "." +
                   Base64UrlEncode(Guid.NewGuid().ToString("N"));
        }

        private static string Base64UrlEncode(string value)
        {
            var bytes = System.Text.Encoding.UTF8.GetBytes(value ?? string.Empty);
            return Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        }

        private static string SqlEscape(string input)
        {
            return input == null ? string.Empty : input.Replace("'", "''");
        }

        private static string GetString(Dictionary<string, object> d, string key)
        {
            return d != null && d.ContainsKey(key) && d[key] != null ? d[key].ToString() : null;
        }

        private static System.Threading.Tasks.Task WriteJsonAsync(HttpContext context, object data)
        {
            var json = JsonUtil.Serialize(data);
            var bytes = System.Text.Encoding.UTF8.GetBytes(json);
            return context.Response.OutputStream.WriteAsync(bytes, 0, bytes.Length);
        }

        private static System.Threading.Tasks.Task WriteErrorAsync(HttpContext context, string message)
        {
            return WriteJsonAsync(context, new Dictionary<string, object>
            {
                { "error", true },
                { "message", message }
            });
        }
    }
}
