using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using SupersetEmbedDemo.Models;
using SupersetEmbedDemo.Services;

namespace SupersetEmbedDemo.Handlers
{
    public class DashboardsHandler : HttpTaskAsyncHandler
    {
        public override bool IsReusable => false;

        public override async System.Threading.Tasks.Task ProcessRequestAsync(HttpContext context)
        {
            context.Response.ContentType = "application/json";
            context.Response.Cache.SetCacheability(HttpCacheability.NoCache);

            try
            {
                List<DashboardInfo> dashboards;
                if (SupersetSettings.DemoMode)
                {
                    dashboards = DemoDashboards();
                }
                else
                {
                    var client = new SupersetClient();
                    dashboards = await client.ListDashboardsAsync();
                    await client.EnrichWithEmbedInfoAsync(dashboards);
                }

                var payload = new Dictionary<string, object>
                {
                    { "count", dashboards.Count },
                    { "demo", SupersetSettings.DemoMode },
                    { "dashboards", dashboards.Select(d => new Dictionary<string, object>
                        {
                            { "id", d.Id },
                            { "uuid", d.Uuid },
                            { "title", d.Title },
                            { "slug", d.Slug },
                            { "description", d.Description },
                            { "owner", d.Owner },
                            { "changedOn", d.ChangedOn == DateTime.MinValue ? null : d.ChangedOn.ToString("u") },
                            { "published", d.Published },
                            { "embedEnabled", d.EmbedEnabled },
                            { "tags", d.Tags }
                        }).ToList()
                    }
                };

                await WriteJsonAsync(context, payload);
            }
            catch (SupersetApiException ex)
            {
                context.Response.StatusCode = 502;
                await WriteJsonAsync(context, new Dictionary<string, object>
                {
                    { "error", true }, { "message", ex.Message }
                });
            }
            catch (Exception ex)
            {
                context.Response.StatusCode = 500;
                await WriteJsonAsync(context, new Dictionary<string, object>
                {
                    { "error", true }, { "message", ex.Message }
                });
            }
        }

        public static List<DashboardInfo> DemoDashboards()
        {
            return new List<DashboardInfo>
            {
                new DashboardInfo
                {
                    Id = 1,
                    Uuid = SupersetSettings.DemoDashboardUuid,
                    Title = "Sales performance overview",
                    Slug = "sales-performance",
                    Description = "Revenue, units sold, and regional performance. Uses the Sales REST API data source with tenant-level row security.",
                    Owner = "Analytics team",
                    ChangedOn = DateTime.UtcNow.AddHours(-6),
                    Published = true,
                    EmbedEnabled = true,
                    Tags = new List<string> { "sales", "executive" }
                },
                new DashboardInfo
                {
                    Id = 2,
                    Uuid = "7c4f2a61-demo-operations-dashboard",
                    Title = "Operations KPI board",
                    Slug = "operations-kpis",
                    Description = "On-time delivery, fulfillment SLA, and warehouse utilization.",
                    Owner = "Ops team",
                    ChangedOn = DateTime.UtcNow.AddDays(-2),
                    Published = true,
                    EmbedEnabled = true,
                    Tags = new List<string> { "ops" }
                },
                new DashboardInfo
                {
                    Id = 3,
                    Uuid = "9d84e7c3-demo-finance-dashboard",
                    Title = "Finance cashflow report",
                    Slug = "finance-cashflow",
                    Description = "Receivables, payables and forecast for the current quarter.",
                    Owner = "Finance team",
                    ChangedOn = DateTime.UtcNow.AddDays(-1),
                    Published = true,
                    EmbedEnabled = false,
                    Tags = new List<string> { "finance", "restricted" }
                },
                new DashboardInfo
                {
                    Id = 4,
                    Uuid = "",
                    Title = "Marketing funnel (draft)",
                    Slug = "marketing-funnel",
                    Description = "Campaign conversions - awaiting review before publishing.",
                    Owner = "Marketing team",
                    ChangedOn = DateTime.UtcNow.AddHours(-20),
                    Published = false,
                    EmbedEnabled = false,
                    Tags = new List<string> { "marketing", "draft" }
                }
            };
        }

        private static System.Threading.Tasks.Task WriteJsonAsync(HttpContext context, object data)
        {
            var json = JsonUtil.Serialize(data);
            var bytes = System.Text.Encoding.UTF8.GetBytes(json);
            return context.Response.OutputStream.WriteAsync(bytes, 0, bytes.Length);
        }
    }
}
