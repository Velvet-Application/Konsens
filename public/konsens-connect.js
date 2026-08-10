(function (global) {
  "use strict";

  var config = { apiBase: "", apiKey: "" };

  function configure(next) {
    config.apiBase = String(next && next.apiBase || "").replace(/\/$/, "");
    config.apiKey = String(next && next.apiKey || "");
    if (!config.apiBase || !config.apiKey) throw new Error("Konsens Connect requires apiBase and apiKey");
  }

  function headers() {
    return { "content-type": "application/json", "x-konsens-key": config.apiKey };
  }

  async function event(eventType, metadata) {
    var response = await fetch(config.apiBase + "/v1/sdk/events", {
      method: "POST",
      headers: headers(),
      body: JSON.stringify({ eventType: eventType, metadata: metadata || {} })
    });
    if (!response.ok) throw new Error("Konsens SDK event rejected");
    return response.json();
  }

  async function signal(challengeId) {
    var response = await fetch(config.apiBase + "/v1/signals/challenges/" + encodeURIComponent(challengeId), {
      headers: { "x-konsens-key": config.apiKey }
    });
    if (!response.ok) throw new Error("Konsens signal unavailable");
    return response.json();
  }

  async function mount(selector, options) {
    var root = typeof selector === "string" ? document.querySelector(selector) : selector;
    if (!root) throw new Error("Konsens mount target not found");
    var challengeId = options && options.challengeId;
    if (!challengeId) throw new Error("challengeId is required");
    root.innerHTML = '<div style="padding:18px;border:1px solid #e3e7ed;border-radius:18px;font-family:system-ui;background:#fff;color:#17213b">Chargement du signal Konsens…</div>';
    try {
      var payload = await signal(challengeId);
      var item = payload.signal;
      var yes = Math.round(Number(item.yes_ratio || 0) * 100);
      var no = 100 - yes;
      var dark = options && options.theme === "dark";
      var bg = dark ? "#07110f" : "#ffffff";
      var fg = dark ? "#ffffff" : "#17213b";
      var muted = dark ? "#aab5b0" : "#718096";
      root.innerHTML = '<section style="padding:20px;border-radius:20px;background:' + bg + ';color:' + fg + ';font-family:system-ui;box-shadow:0 14px 40px rgba(23,33,59,.08)">' +
        '<div style="font-size:10px;font-weight:800;letter-spacing:.12em;color:#4c6fff">KONSENS SIGNAL</div>' +
        '<h3 style="margin:8px 0 14px;font-size:20px;line-height:1.2">' + escapeHtml(item.question) + '</h3>' +
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">' +
          '<div style="padding:14px;border-radius:14px;background:rgba(76,111,255,.12)"><b style="font-size:24px">' + yes + '%</b><span style="display:block;color:' + muted + ';font-size:11px">OUI</span></div>' +
          '<div style="padding:14px;border-radius:14px;background:rgba(199,243,107,.16)"><b style="font-size:24px">' + no + '%</b><span style="display:block;color:' + muted + ';font-size:11px">NON</span></div>' +
        '</div>' +
        '<div style="margin-top:12px;color:' + muted + ';font-size:11px">' + Number(item.total_count || 0).toLocaleString("fr-FR") + ' prédictions · Powered by Konsens</div>' +
      '</section>';
      await event("render", { challengeId: challengeId, component: "signal-card", sdkVersion: "1.0.0" });
      return payload;
    } catch (error) {
      root.innerHTML = '<div style="padding:18px;border:1px solid #e3e7ed;border-radius:18px;font-family:system-ui;background:#fff;color:#17213b">Signal Konsens indisponible.</div>';
      try { await event("error", { challengeId: challengeId, message: String(error && error.message || error) }); } catch (_) {}
      throw error;
    }
  }

  function escapeHtml(value) {
    return String(value).replace(/[&<>"]/g, function (character) {
      return ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[character];
    });
  }

  global.Konsens = { configure: configure, mount: mount, signal: signal, event: event, version: "1.0.0" };
})(window);
