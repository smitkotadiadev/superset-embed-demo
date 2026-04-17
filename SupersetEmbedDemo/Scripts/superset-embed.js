(function (window, document) {
    "use strict";

    var DEFAULT_UI_CONFIG = {
        hideTitle: false,
        hideTab: false,
        hideChartControls: false,
        filters: { visible: true, expanded: true }
    };

    function resolveUrl(path) {
        var basePath = window.__SUPERSET_DEMO_APP_PATH || "/";
        if (basePath.slice(-1) !== "/") basePath += "/";
        if (path.charAt(0) === "/") path = path.slice(1);
        return basePath + path;
    }

    function fetchGuestToken(options) {
        var payload = {
            dashboardUuid: options.dashboardUuid,
            username: options.username || null,
            firstName: options.firstName || null,
            lastName: options.lastName || null,
            tenantId: options.tenantId || null,
            rls: options.rls || []
        };
        return window.fetch(resolveUrl("Handlers/GuestTokenHandler.ashx"), {
            method: "POST",
            credentials: "same-origin",
            headers: { "Content-Type": "application/json", "Accept": "application/json" },
            body: JSON.stringify(payload)
        }).then(function (res) {
            if (!res.ok) {
                return res.text().then(function (text) {
                    throw new Error("Guest token request failed (" + res.status + "): " + text);
                });
            }
            return res.json();
        }).then(function (json) {
            if (!json || !json.token) {
                throw new Error("Guest token response missing token field.");
            }
            return json.token;
        });
    }

    function showLoading(container) {
        var overlay = container.querySelector(".embed-loading");
        if (overlay) overlay.classList.remove("hidden");
    }

    function hideLoading(container) {
        var overlay = container.querySelector(".embed-loading");
        if (overlay) overlay.classList.add("hidden");
    }

    function showError(container, message) {
        hideLoading(container);
        var mount = container.querySelector("[data-embed-mount]") || container;
        mount.innerHTML = "";
        var banner = document.createElement("div");
        banner.className = "status-banner status-banner--error";
        banner.innerHTML = "<div><strong>Embedding failed</strong>" +
            escapeHtml(message) + "</div>";
        mount.appendChild(banner);
    }

    function escapeHtml(s) {
        return String(s || "").replace(/[&<>"']/g, function (c) {
            return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
        });
    }

    function loadEmbeddedSdk(sdkUrl) {
        return new Promise(function (resolve, reject) {
            if (window.supersetEmbeddedSdk && window.supersetEmbeddedSdk.embedDashboard) {
                resolve(window.supersetEmbeddedSdk);
                return;
            }
            var existing = document.querySelector("script[data-superset-sdk]");
            if (existing) {
                existing.addEventListener("load", function () {
                    resolve(window.supersetEmbeddedSdk);
                });
                existing.addEventListener("error", function () {
                    reject(new Error("Failed to load Superset Embedded SDK."));
                });
                return;
            }
            var script = document.createElement("script");
            script.src = sdkUrl;
            script.async = true;
            script.setAttribute("data-superset-sdk", "true");
            script.onload = function () {
                if (window.supersetEmbeddedSdk && window.supersetEmbeddedSdk.embedDashboard) {
                    resolve(window.supersetEmbeddedSdk);
                } else {
                    reject(new Error("Superset Embedded SDK loaded but globals missing."));
                }
            };
            script.onerror = function () {
                reject(new Error("Failed to load Superset Embedded SDK from " + sdkUrl));
            };
            document.head.appendChild(script);
        });
    }

    function embedDashboard(options) {
        if (!options || !options.mountElement) {
            throw new Error("embedDashboard requires a mountElement option.");
        }
        if (!options.dashboardUuid) {
            throw new Error("embedDashboard requires a dashboardUuid option.");
        }
        if (!options.supersetDomain) {
            throw new Error("embedDashboard requires a supersetDomain option.");
        }

        var container = options.containerElement || options.mountElement;
        showLoading(container);

        var uiConfig = Object.assign({}, DEFAULT_UI_CONFIG, options.uiConfig || {});
        var sdkUrl = options.sdkUrl || "https://unpkg.com/@superset-ui/embedded-sdk";

        return loadEmbeddedSdk(sdkUrl)
            .then(function (sdk) {
                return sdk.embedDashboard({
                    id: options.dashboardUuid,
                    supersetDomain: options.supersetDomain,
                    mountPoint: options.mountElement,
                    fetchGuestToken: function () {
                        return fetchGuestToken({
                            dashboardUuid: options.dashboardUuid,
                            username: options.user && options.user.username,
                            firstName: options.user && options.user.firstName,
                            lastName: options.user && options.user.lastName,
                            tenantId: options.user && options.user.tenantId,
                            rls: options.rls
                        });
                    },
                    dashboardUiConfig: {
                        hideTitle: uiConfig.hideTitle,
                        hideTab: uiConfig.hideTab,
                        hideChartControls: uiConfig.hideChartControls,
                        filters: uiConfig.filters,
                        urlParams: options.urlParams || {}
                    },
                    iframeSandboxExtras: options.iframeSandboxExtras || [],
                    iframeAllowExtras: options.iframeAllowExtras || ["fullscreen"],
                    referrerPolicy: options.referrerPolicy || "strict-origin-when-cross-origin"
                });
            })
            .then(function (instance) {
                setTimeout(function () { hideLoading(container); }, 400);
                if (typeof options.onReady === "function") options.onReady(instance);
                return instance;
            })
            .catch(function (err) {
                showError(container, err && err.message ? err.message : String(err));
                if (typeof options.onError === "function") options.onError(err);
            });
    }

    function loadDashboardList(targetElement, options) {
        options = options || {};
        window.fetch(resolveUrl("Handlers/DashboardsHandler.ashx"), {
            method: "GET",
            credentials: "same-origin",
            headers: { "Accept": "application/json" }
        }).then(function (res) {
            if (!res.ok) throw new Error("Request failed: " + res.status);
            return res.json();
        }).then(function (data) {
            if (typeof options.onData === "function") options.onData(data);
        }).catch(function (err) {
            if (typeof options.onError === "function") options.onError(err);
        });
    }

    window.SupersetDemo = {
        embedDashboard: embedDashboard,
        fetchGuestToken: fetchGuestToken,
        loadDashboardList: loadDashboardList,
        resolveUrl: resolveUrl
    };
})(window, document);
