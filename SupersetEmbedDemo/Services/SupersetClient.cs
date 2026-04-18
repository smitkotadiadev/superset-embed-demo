using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using SupersetEmbedDemo.Models;

namespace SupersetEmbedDemo.Services
{
    public class SupersetClient
    {
        private const string CacheKeyAccessToken = "__superset_access_token";
        private const string CacheKeyCsrfToken = "__superset_csrf_token";

        private static CookieContainer _cookies = new CookieContainer();
        private static readonly HttpClient _http = BuildHttpClient();
        private static readonly SemaphoreSlim _tokenLock = new SemaphoreSlim(1, 1);

        private readonly string _baseUrl;

        public SupersetClient()
        {
            _baseUrl = SupersetSettings.BaseUrl;
        }

        public SupersetClient(string baseUrl)
        {
            _baseUrl = (baseUrl ?? string.Empty).TrimEnd('/');
        }

        private static HttpClient BuildHttpClient()
        {
            var handler = new HttpClientHandler
            {
                AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
                UseCookies = true,
                CookieContainer = _cookies
            };
            var client = new HttpClient(handler)
            {
                Timeout = TimeSpan.FromSeconds(30)
            };
            client.DefaultRequestHeaders.Accept.Clear();
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            client.DefaultRequestHeaders.UserAgent.ParseAdd("SupersetEmbedDemo/1.0 (ASP.NET)");
            return client;
        }

        private void InvalidateSession()
        {
            var cache = HttpRuntime.Cache;
            cache?.Remove(CacheKeyAccessToken);
            cache?.Remove(CacheKeyCsrfToken);
            try
            {
                var jar = new CookieContainer();
                var uri = new Uri(_baseUrl);
                foreach (Cookie c in _cookies.GetCookies(uri))
                {
                    c.Expired = true;
                }
            }
            catch
            {
            }
        }

        public async Task<string> GetAccessTokenAsync(bool forceRefresh = false)
        {
            var cache = HttpRuntime.Cache;
            if (!forceRefresh)
            {
                var cached = cache != null ? cache[CacheKeyAccessToken] as string : null;
                if (!string.IsNullOrEmpty(cached))
                {
                    return cached;
                }
            }

            await _tokenLock.WaitAsync().ConfigureAwait(false);
            try
            {
                if (!forceRefresh && cache != null)
                {
                    var cached = cache[CacheKeyAccessToken] as string;
                    if (!string.IsNullOrEmpty(cached))
                    {
                        return cached;
                    }
                }

                var payload = JsonUtil.Serialize(new Dictionary<string, object>
                {
                    { "username", SupersetSettings.AdminUsername },
                    { "password", SupersetSettings.AdminPassword },
                    { "provider", SupersetSettings.AuthProvider },
                    { "refresh", true }
                });

                using (var request = new HttpRequestMessage(HttpMethod.Post, _baseUrl + "/api/v1/security/login"))
                {
                    request.Content = new StringContent(payload, Encoding.UTF8, "application/json");
                    using (var response = await _http.SendAsync(request).ConfigureAwait(false))
                    {
                        var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                        if (!response.IsSuccessStatusCode)
                        {
                            throw new SupersetApiException(
                                "Superset login failed (" + (int)response.StatusCode + "): " + Truncate(body, 500));
                        }

                        var dict = JsonUtil.ParseObject(body);
                        var token = dict != null && dict.ContainsKey("access_token")
                            ? dict["access_token"] as string
                            : null;
                        if (string.IsNullOrEmpty(token))
                        {
                            throw new SupersetApiException("Superset login did not return access_token.");
                        }
                        cache?.Insert(CacheKeyAccessToken, token, null,
                            DateTime.UtcNow.AddMinutes(15),
                            System.Web.Caching.Cache.NoSlidingExpiration);
                        return token;
                    }
                }
            }
            finally
            {
                _tokenLock.Release();
            }
        }

        public async Task<string> GetCsrfTokenAsync(string accessToken)
        {
            var cache = HttpRuntime.Cache;
            var cached = cache != null ? cache[CacheKeyCsrfToken] as string : null;
            if (!string.IsNullOrEmpty(cached))
            {
                return cached;
            }

            using (var request = new HttpRequestMessage(HttpMethod.Get, _baseUrl + "/api/v1/security/csrf_token/"))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
                using (var response = await _http.SendAsync(request).ConfigureAwait(false))
                {
                    var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!response.IsSuccessStatusCode)
                    {
                        throw new SupersetApiException(
                            "Failed to get CSRF token (" + (int)response.StatusCode + "): " + Truncate(body, 500));
                    }
                    var dict = JsonUtil.ParseObject(body);
                    var csrf = dict != null && dict.ContainsKey("result")
                        ? dict["result"] as string
                        : null;
                    if (string.IsNullOrEmpty(csrf))
                    {
                        throw new SupersetApiException("CSRF token response missing 'result' field.");
                    }
                    cache?.Insert(CacheKeyCsrfToken, csrf, null,
                        DateTime.UtcNow.AddMinutes(10),
                        System.Web.Caching.Cache.NoSlidingExpiration);
                    return csrf;
                }
            }
        }

        public Task<string> CreateGuestTokenAsync(GuestTokenRequest payload)
        {
            return CreateGuestTokenInternalAsync(payload, retriesLeft: 2);
        }

        private async Task<string> CreateGuestTokenInternalAsync(GuestTokenRequest payload, int retriesLeft)
        {
            if (payload == null) throw new ArgumentNullException("payload");
            if (string.IsNullOrWhiteSpace(payload.DashboardUuid))
                throw new ArgumentException("DashboardUuid is required.", "payload");

            var accessToken = await GetAccessTokenAsync(forceRefresh: retriesLeft < 2).ConfigureAwait(false);
            var csrfToken = await GetCsrfTokenAsync(accessToken).ConfigureAwait(false);

            var user = payload.User ?? SupersetUser.Anonymous();
            var body = new Dictionary<string, object>
            {
                {
                    "user", new Dictionary<string, object>
                    {
                        { "username", user.Username ?? "guest" },
                        { "first_name", user.FirstName ?? "Guest" },
                        { "last_name", user.LastName ?? "User" }
                    }
                },
                {
                    "resources", new[]
                    {
                        new Dictionary<string, object>
                        {
                            { "type", "dashboard" },
                            { "id", payload.DashboardUuid }
                        }
                    }
                },
                { "rls", BuildRlsList(payload.RowLevelSecurity) }
            };

            var json = JsonUtil.Serialize(body);

            using (var request = new HttpRequestMessage(HttpMethod.Post,
                _baseUrl + "/api/v1/security/guest_token/"))
            {
                request.Content = new StringContent(json, Encoding.UTF8, "application/json");
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
                request.Headers.Add("X-CSRFToken", csrfToken);
                request.Headers.Referrer = new Uri(_baseUrl);

                using (var response = await _http.SendAsync(request).ConfigureAwait(false))
                {
                    var respBody = await response.Content.ReadAsStringAsync().ConfigureAwait(false);

                    var needsRetry =
                        retriesLeft > 0 &&
                        (response.StatusCode == HttpStatusCode.Unauthorized ||
                         (response.StatusCode == HttpStatusCode.BadRequest &&
                          respBody != null &&
                          respBody.IndexOf("CSRF", StringComparison.OrdinalIgnoreCase) >= 0));

                    if (needsRetry)
                    {
                        InvalidateSession();
                        return await CreateGuestTokenInternalAsync(payload, retriesLeft - 1)
                            .ConfigureAwait(false);
                    }

                    if (!response.IsSuccessStatusCode)
                    {
                        throw new SupersetApiException(
                            "Failed to create guest token (" + (int)response.StatusCode + "): " +
                            Truncate(respBody, 500));
                    }

                    var dict = JsonUtil.ParseObject(respBody);
                    var token = dict != null && dict.ContainsKey("token")
                        ? dict["token"] as string
                        : null;
                    if (string.IsNullOrEmpty(token))
                    {
                        throw new SupersetApiException("Guest token response missing 'token' field.");
                    }
                    return token;
                }
            }
        }

        public async Task<List<DashboardInfo>> ListDashboardsAsync(int pageSize = 50)
        {
            var accessToken = await GetAccessTokenAsync().ConfigureAwait(false);
            var url = _baseUrl + "/api/v1/dashboard/?q=" + Uri.EscapeDataString(
                "(page:0,page_size:" + pageSize + ",order_column:changed_on_delta_humanized,order_direction:desc)");

            using (var request = new HttpRequestMessage(HttpMethod.Get, url))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
                using (var response = await _http.SendAsync(request).ConfigureAwait(false))
                {
                    var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!response.IsSuccessStatusCode)
                    {
                        throw new SupersetApiException(
                            "Failed to list dashboards (" + (int)response.StatusCode + "): " +
                            Truncate(body, 500));
                    }
                    return ParseDashboardList(body);
                }
            }
        }

        public async Task EnrichWithEmbedInfoAsync(List<DashboardInfo> dashboards)
        {
            if (dashboards == null || dashboards.Count == 0) return;

            using (var gate = new SemaphoreSlim(8))
            {
                var tasks = new List<Task>(dashboards.Count);
                foreach (var d in dashboards)
                {
                    if (d == null || d.Id <= 0 || !d.Published) continue;
                    var info = d;
                    await gate.WaitAsync().ConfigureAwait(false);
                    tasks.Add(Task.Run(async () =>
                    {
                        try
                        {
                            var uuid = await GetDashboardEmbedUuidAsync(info.Id).ConfigureAwait(false);
                            if (!string.IsNullOrEmpty(uuid))
                            {
                                info.Uuid = uuid;
                                info.EmbedEnabled = true;
                            }
                        }
                        catch
                        {
                        }
                        finally
                        {
                            gate.Release();
                        }
                    }));
                }
                await Task.WhenAll(tasks).ConfigureAwait(false);
            }
        }

        public async Task<string> GetDashboardEmbedUuidAsync(int dashboardId)
        {
            var accessToken = await GetAccessTokenAsync().ConfigureAwait(false);
            var url = _baseUrl + "/api/v1/dashboard/" + dashboardId + "/embedded";

            using (var request = new HttpRequestMessage(HttpMethod.Get, url))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
                using (var response = await _http.SendAsync(request).ConfigureAwait(false))
                {
                    if (response.StatusCode == HttpStatusCode.NotFound)
                    {
                        return null;
                    }
                    var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!response.IsSuccessStatusCode)
                    {
                        throw new SupersetApiException(
                            "Failed to get embed config (" + (int)response.StatusCode + "): " +
                            Truncate(body, 500));
                    }
                    var dict = JsonUtil.ParseObject(body);
                    if (dict != null && dict.ContainsKey("result"))
                    {
                        var result = dict["result"] as Dictionary<string, object>;
                        if (result != null && result.ContainsKey("uuid"))
                        {
                            return result["uuid"] as string;
                        }
                    }
                    return null;
                }
            }
        }

        private static List<object> BuildRlsList(List<RlsRule> rules)
        {
            var list = new List<object>();
            if (rules == null) return list;
            foreach (var rule in rules)
            {
                if (rule == null || string.IsNullOrWhiteSpace(rule.Clause)) continue;
                var entry = new Dictionary<string, object> { { "clause", rule.Clause } };
                if (rule.DatasetId.HasValue)
                {
                    entry["dataset"] = rule.DatasetId.Value;
                }
                list.Add(entry);
            }
            return list;
        }

        private static List<DashboardInfo> ParseDashboardList(string json)
        {
            var result = new List<DashboardInfo>();
            var dict = JsonUtil.ParseObject(json);
            if (dict == null || !dict.ContainsKey("result")) return result;

            var items = dict["result"] as System.Collections.ArrayList;
            if (items == null) return result;
            foreach (var itemObj in items)
            {
                var item = itemObj as Dictionary<string, object>;
                if (item == null) continue;
                var info = new DashboardInfo
                {
                    Id = ParseInt(item, "id"),
                    Title = GetString(item, "dashboard_title"),
                    Slug = GetString(item, "slug"),
                    Status = GetString(item, "status"),
                    Published = GetBool(item, "published"),
                    ChangedOn = ParseDate(item, "changed_on_utc")
                };

                if (item.ContainsKey("changed_by"))
                {
                    var changedBy = item["changed_by"] as Dictionary<string, object>;
                    if (changedBy != null)
                    {
                        var first = GetString(changedBy, "first_name");
                        var last = GetString(changedBy, "last_name");
                        info.Owner = (first + " " + last).Trim();
                    }
                }

                if (item.ContainsKey("tags"))
                {
                    var tags = item["tags"] as System.Collections.ArrayList;
                    if (tags != null)
                    {
                        foreach (var tag in tags)
                        {
                            var tagDict = tag as Dictionary<string, object>;
                            if (tagDict != null)
                            {
                                var name = GetString(tagDict, "name");
                                if (!string.IsNullOrEmpty(name))
                                {
                                    info.Tags.Add(name);
                                }
                            }
                        }
                    }
                }

                result.Add(info);
            }
            return result;
        }

        private static string GetString(Dictionary<string, object> d, string key)
        {
            return d != null && d.ContainsKey(key) && d[key] != null ? d[key].ToString() : null;
        }

        private static int ParseInt(Dictionary<string, object> d, string key)
        {
            if (d == null || !d.ContainsKey(key) || d[key] == null) return 0;
            int v;
            return int.TryParse(d[key].ToString(), out v) ? v : 0;
        }

        private static bool GetBool(Dictionary<string, object> d, string key)
        {
            if (d == null || !d.ContainsKey(key) || d[key] == null) return false;
            bool v;
            return bool.TryParse(d[key].ToString(), out v) && v;
        }

        private static DateTime ParseDate(Dictionary<string, object> d, string key)
        {
            if (d == null || !d.ContainsKey(key) || d[key] == null) return DateTime.MinValue;
            DateTime v;
            return DateTime.TryParse(d[key].ToString(), out v) ? v : DateTime.MinValue;
        }

        private static string Truncate(string s, int max)
        {
            if (string.IsNullOrEmpty(s)) return s;
            return s.Length <= max ? s : s.Substring(0, max) + "...";
        }
    }

    public class SupersetApiException : Exception
    {
        public SupersetApiException(string message) : base(message) { }
        public SupersetApiException(string message, Exception inner) : base(message, inner) { }
    }
}
