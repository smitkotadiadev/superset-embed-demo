using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using SupersetEmbedDemo.Models;
using SupersetEmbedDemo.Services;

namespace SupersetEmbedDemo.Handlers
{
    public class DataSourceProxyHandler : IHttpHandler
    {
        private static readonly List<DataSetRecord> _seed = BuildSeed();

        public bool IsReusable => true;

        public void ProcessRequest(HttpContext context)
        {
            context.Response.ContentType = "application/json";
            context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
            context.Response.AppendHeader("Access-Control-Allow-Origin", "*");

            try
            {
                int page = ParseInt(context.Request.QueryString["page"], 1);
                int pageSize = Math.Min(500, ParseInt(context.Request.QueryString["pageSize"], 50));
                string region = context.Request.QueryString["region"];
                string category = context.Request.QueryString["category"];
                DateTime? fromDate = ParseDate(context.Request.QueryString["from"]);
                DateTime? toDate = ParseDate(context.Request.QueryString["to"]);

                IEnumerable<DataSetRecord> query = _seed;

                if (!string.IsNullOrWhiteSpace(region))
                {
                    query = query.Where(r => string.Equals(r.Region, region, StringComparison.OrdinalIgnoreCase));
                }
                if (!string.IsNullOrWhiteSpace(category))
                {
                    query = query.Where(r => string.Equals(r.Category, category, StringComparison.OrdinalIgnoreCase));
                }
                if (fromDate.HasValue)
                {
                    query = query.Where(r => r.SaleDate >= fromDate.Value);
                }
                if (toDate.HasValue)
                {
                    query = query.Where(r => r.SaleDate <= toDate.Value);
                }

                var list = query.ToList();
                var total = list.Count;
                var pageData = list.Skip((page - 1) * pageSize).Take(pageSize).ToList();

                var response = new DataSetResponse
                {
                    Total = total,
                    Page = page,
                    PageSize = pageSize,
                    Records = pageData
                };

                var json = JsonUtil.Serialize(new Dictionary<string, object>
                {
                    { "total", response.Total },
                    { "page", response.Page },
                    { "pageSize", response.PageSize },
                    { "records", response.Records.Select(r => new Dictionary<string, object>
                        {
                            { "id", r.Id },
                            { "region", r.Region },
                            { "product", r.Product },
                            { "category", r.Category },
                            { "revenue", r.Revenue },
                            { "units", r.Units },
                            { "saleDate", r.SaleDate.ToString("yyyy-MM-dd") },
                            { "salesRep", r.SalesRep }
                        }).ToList()
                    }
                });
                context.Response.Write(json);
            }
            catch (Exception ex)
            {
                context.Response.StatusCode = 500;
                context.Response.Write(JsonUtil.Serialize(new Dictionary<string, object>
                {
                    { "error", true }, { "message", ex.Message }
                }));
            }
        }

        private static int ParseInt(string raw, int fallback)
        {
            int v;
            return int.TryParse(raw, out v) ? v : fallback;
        }

        private static DateTime? ParseDate(string raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;
            DateTime v;
            return DateTime.TryParse(raw, out v) ? (DateTime?)v : null;
        }

        private static List<DataSetRecord> BuildSeed()
        {
            var regions = new[] { "North America", "EMEA", "APAC", "LATAM" };
            var products = new[] { "Orion", "Hyperion", "Atlas", "Nimbus", "Helios", "Quasar" };
            var categories = new[] { "Cloud", "Hardware", "Services", "Licences" };
            var reps = new[] { "J. Patel", "M. Rodriguez", "K. Tanaka", "L. Müller", "S. Okafor", "R. Andersson" };
            var records = new List<DataSetRecord>();
            var rng = new Random(42);
            var start = new DateTime(DateTime.UtcNow.Year, 1, 1);
            for (int i = 0; i < 250; i++)
            {
                records.Add(new DataSetRecord
                {
                    Id = "REC-" + (1000 + i),
                    Region = regions[rng.Next(regions.Length)],
                    Product = products[rng.Next(products.Length)],
                    Category = categories[rng.Next(categories.Length)],
                    Units = rng.Next(1, 250),
                    Revenue = Math.Round((decimal)(rng.NextDouble() * 80000 + 1200), 2),
                    SaleDate = start.AddDays(rng.Next(0, 120)),
                    SalesRep = reps[rng.Next(reps.Length)]
                });
            }
            return records;
        }
    }
}
