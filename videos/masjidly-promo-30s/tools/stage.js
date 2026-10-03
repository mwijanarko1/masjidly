(function () {
  // ================= builders (the app, from the SwiftUI source) =================
  const THIN = " ";
  const $ = function (id) { return document.getElementById(id); };

  // gearshape.fill
  (function () {
    let d = "";
    const R = 19, r = 14.5, teeth = 8;
    for (let i = 0; i < teeth * 2; i++) {
      const a0 = (i / (teeth * 2)) * Math.PI * 2 - Math.PI / 2, a1 = ((i + 1) / (teeth * 2)) * Math.PI * 2 - Math.PI / 2, rad = i % 2 === 0 ? R : r;
      d += (i === 0 ? "M" : "L") + (Math.cos(a0) * rad).toFixed(2) + " " + (Math.sin(a0) * rad).toFixed(2) + " L" + (Math.cos(a1) * rad).toFixed(2) + " " + (Math.sin(a1) * rad).toFixed(2) + " ";
    }
    d += "Z M6.5 0 A6.5 6.5 0 1 0 -6.5 0 A6.5 6.5 0 1 0 6.5 0 Z";
    document.querySelectorAll(".h-gear").forEach(function (g) { g.setAttribute("d", d); });
  })();

  // PrayerSunPhaseIcon (Canvas 100x88)
  const star = function (cx, cy, s) { const c = s * 0.25; return "M" + cx + " " + (cy - s) + " Q" + (cx + c) + " " + (cy - c) + " " + (cx + s) + " " + cy + " Q" + (cx + c) + " " + (cy + c) + " " + cx + " " + (cy + s) + " Q" + (cx - c) + " " + (cy + c) + " " + (cx - s) + " " + cy + " Q" + (cx - c) + " " + (cy - c) + " " + cx + " " + (cy - s) + " Z"; };
  const ray = function (cx, cy, deg, r0, r1) { const a = deg * Math.PI / 180; return "M" + (cx + Math.cos(a) * r0).toFixed(2) + " " + (cy + Math.sin(a) * r0).toFixed(2) + " L" + (cx + Math.cos(a) * r1).toFixed(2) + " " + (cy + Math.sin(a) * r1).toFixed(2); };
  const T = 'stroke-width="1.8"', M = 'stroke-width="2.2"';
  const ICONS = {
    fajr: '<path ' + T + ' d="M34 53.68 L66 53.68"/><path ' + T + ' d="' + star(50, 39.68, 6) + '"/>',
    sunrise: '<path ' + M + ' d="M18 58.08 L82 58.08"/><path ' + M + ' d="M36 58.08 A14 14 0 0 1 64 58.08"/><path ' + M + ' d="' + ray(50, 58.08, -135, 20, 28) + " " + ray(50, 58.08, -90, 20, 28) + " " + ray(50, 58.08, -45, 20, 28) + '"/>',
    dhuhr: '<circle ' + M + ' cx="50" cy="44" r="12"/><path ' + M + ' d="' + [0, 45, 90, 135, 180, 225, 270, 315].map(function (g) { return ray(50, 44, g, 18, 26); }).join(" ") + '"/>',
    asr: '<path ' + M + ' d="M40 32.6 L40 46.6"/><path ' + T + ' d="M40 46.6 L68 54.6"/>',
    maghrib: '<path ' + M + ' d="M18 57.2 L82 57.2"/><path ' + M + ' d="M36 57.2 A14 14 0 0 1 64 57.2"/><path ' + T + ' d="M50 31.2 L50 39.2 M47 36.2 L50 39.2 L53 36.2"/>',
    isha: '<path ' + M + ' d="' + star(46, 44, 8) + '"/><path ' + T + ' d="' + star(62, 38, 4) + '"/><path ' + T + ' d="' + star(60, 52, 3) + '"/>'
  };
  const iconSvg = function (theme, id) {
    const dy = (theme === "sunrise" || theme === "maghrib") ? -13 : 0;
    return '<svg class="h-sun" ' + (id ? 'id="' + id + '" ' : "") + 'viewBox="0 0 100 88" style="top: ' + (35 + dy) + 'px;" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">' + ICONS[theme] + "</svg>";
  };

  // Pages: Masjid Faizul Islam, Sunday 27 Sep 2026 (production data)
  const AR = "'HF Arabic', 'HF Gill', sans-serif", UR = "'HF Urdu', 'HF Gill', sans-serif";
  const PAGES = [
    { theme: "fajr", time: "5:26" + THIN + "AM", iq: "Iqamah: 6:20AM", name: "Fajr" },
    { theme: "sunrise", time: "7:02" + THIN + "AM", iq: "Duha: 7:17AM &ndash; 12:47PM", name: "Sunrise" },
    { theme: "dhuhr", time: "1:02" + THIN + "PM", iq: "Iqamah: 2:00PM", name: "Dhuhr" },
    { theme: "asr", time: "4:57" + THIN + "PM", iq: "Iqamah: 5:45PM", name: "Asr" },
    { theme: "maghrib", time: "6:54" + THIN + "PM", iq: "Iqamah: 6:57PM", name: "Maghrib" },
    { theme: "isha", time: "8:16" + THIN + "PM", iq: "Iqamah: 8:30PM", name: "Isha" },
    { theme: "asr", time: "4:06" + THIN + "PM", iq: "Iqamah: 4:30PM", name: "Asr" },
    { theme: "dhuhr", time: "1:02" + THIN + "م", iq: "الإقامة : 2:00م", name: "الظهر", svg: AR, rtl: true },
    { theme: "dhuhr", time: "1:02" + THIN + "PM", iq: "اقامت : 2:00PM", name: "ظہر", svg: UR, rtl: true, iqFont: UR },
    { theme: "dhuhr", time: "1:02" + THIN + "PM", iq: "Iqamah: 2:00PM", name: "Dzuhur", svg: "'HF Gill', sans-serif" },
    { theme: "asr", time: "4:08" + THIN + "PM", iq: "Iqamah: 5:45PM", name: "Asr" },
    { theme: "asr", time: "4:53" + THIN + "PM", iq: "Iqamah: 5:30PM", name: "Asr" }
  ];
  $("h-pages").innerHTML = PAGES.map(function (p, i) {
    const iqStyle = p.rtl ? ' style="font-family: ' + (p.iqFont || AR) + ';" dir="rtl"' : "";
    const timeAttr = p.rtl ? ' dir="rtl"' + (p.iqFont ? "" : ' style="font-family: ' + AR + ';"') : "";
    const name = p.svg
      ? '<svg class="h-name-svg" viewBox="0 0 1080 150"><text id="h-p' + i + '-svgname" x="540" y="100" text-anchor="middle"' + (p.rtl ? ' direction="rtl"' : "") + ' font-family="' + p.svg.replace(/'/g, "") + '" font-size="79" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-width="1.6" stroke-dasharray="900" stroke-dashoffset="900">' + p.name + "</text></svg>"
      : '<div class="h-name" id="h-p' + i + '-name" data-layout-allow-overlap>' + p.name + "</div>";
    return '<div class="h-page' + (p.rtl ? " h-rtl" : "") + '" id="h-p' + i + '"><div class="h-time" id="h-p' + i + '-time" data-layout-allow-overlap' + timeAttr + ">" + p.time + '</div><div class="h-iq" data-layout-allow-overlap' + iqStyle + ">" + p.iq + "</div>" + name + "</div>";
  }).join("");
  $("h-suns").innerHTML = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"].map(function (s) { return iconSvg(s, "h-sun-" + s); }).join("");

  // Letter picker (dot = upcoming prayer: Asr)
  const LX = [307.5, 400.5, 493.5, 586.5, 679.5, 772.5], LY = 1510;
  const letterRow = function (id, letters, dotIndex) {
    let h = '<div class="h-letters" id="' + id + '">';
    letters.forEach(function (ch, i) {
      h += '<div class="h-l" style="left: ' + LX[i] + 'px;"><i class="lr" id="' + id + "-r" + i + '" data-layout-allow-overlap>' + ch + '</i><i class="ls" id="' + id + "-s" + i + '" data-layout-allow-overlap>' + ch + '</i><span class="dot"' + (i === dotIndex ? ' style="opacity: 0.9;"' : "") + "></span></div>";
    });
    return h + "</div>";
  };
  $("h-letters-wrap").innerHTML = letterRow("lt-en", ["F", "S", "D", "A", "M", "I"], 3);

  // Mosque tabs (5 once all are added)
  const TABS = [
    { id: "a", name: "Masjid Faizul Islam", sel: 350 },
    { id: "b", name: "Masjid Risalah", sel: 262 },
    { id: "c", name: "Sheffield Grand Mosque", sel: 370 },
    { id: "d", name: "Masjid Umar (YMA)", sel: 330 },
    { id: "e", name: "Madina Masjid Sheffield", sel: 370 }
  ];
  const UNSEL = 194;
  $("h-track").innerHTML = TABS.map(function (t, i) {
    return '<div class="h-tab" id="h-tab-' + t.id + '" style="width: ' + (i === 0 ? t.sel : 0) + 'px;' + (i === 0 ? "" : " opacity: 0;") + '"><div class="f" id="h-fill-' + t.id + '" style="opacity: 0.92;"></div><span class="t sel" id="h-sel-' + t.id + '" data-layout-allow-overlap data-layout-allow-overflow style="max-width: 370px;">' + t.name + '</span><span class="t uns" id="h-uns-' + t.id + '" data-layout-allow-overlap data-layout-allow-overflow style="max-width: 194px;">' + t.name + "</span></div>";
  }).join("") + '<div class="h-plus" id="h-plus"><svg width="39" height="39" viewBox="0 0 39 39" stroke="currentColor" stroke-width="3.6" stroke-linecap="round"><line x1="19.5" y1="5" x2="19.5" y2="34"/><line x1="5" y1="19.5" x2="34" y2="19.5"/></svg></div>';

  // Timetable rows at night: today's prayers past; Midnight + Last Third ahead
  const ROWS = [["Fajr", "5:26AM", "6:20AM", 1], ["Sunrise", "7:02AM", "-", 1], ["Dhuhr", "1:02PM", "2:00PM", 1], ["Asr", "4:57PM", "5:45PM", 1], ["Maghrib", "6:54PM", "6:57PM", 1], ["Isha", "8:16PM", "8:30PM", 1], ["Midnight", "12:11AM", "-", 0], ["Last Third", "1:56AM", "-", 0]];
  $("tt-rows").innerHTML = ROWS.map(function (r, i) {
    return '<div class="tt-row' + (r[3] ? " past" : "") + '" id="tt-r' + i + '" style="top: ' + (700 + i * 118) + 'px;"><span class="n">' + r[0] + '</span><span class="a">' + r[1] + '</span><span class="q">' + r[2] + "</span></div>";
  }).join("");

  // Theme cards: static copies of the Asr home screen
  const cardHtml = function () {
    const chrome = $("h-chrome").outerHTML.replace(/ id="[^"]*"/g, "");
    const letters = letterRow("x", ["F", "S", "D", "A", "M", "I"], 3).replace(/ id="[^"]*"/g, "").replace('<i class="lr" data-layout-allow-overlap>A</i><i class="ls" data-layout-allow-overlap>A</i>', '<i class="lr" data-layout-allow-overlap style="opacity: 0;">A</i><i class="ls" data-layout-allow-overlap style="opacity: 1;">A</i>');
    return '<div class="s-full" style="color: #111111;">' + chrome + '<div class="h-orb"><div class="h-ring1"></div><div class="h-ring2"></div>' + iconSvg("asr") + '<div class="h-qibla" style="transform: rotate(22deg);"><svg width="26" height="26" viewBox="0 0 12 12" style="position: absolute; left: 119px; top: -22px;"><path d="M6 0 L12 12 L0 12 Z" fill="currentColor"/></svg></div></div><div class="h-page" style="opacity: 1;"><div class="h-time">4:57' + THIN + 'PM</div><div class="h-iq">Iqamah: 5:45PM</div><div class="h-name">Asr</div></div>' + letters + "</div>";
  };
  ["t-orig", "t-cust", "t-mod"].forEach(function (id) { $(id).innerHTML = cardHtml(); });
  $("t-cust").insertAdjacentHTML("afterbegin", '<div id="t-cust2" style="position: absolute; inset: 0; background: linear-gradient(180deg, #FFE3B3 0%, #F7A1C4 100%); opacity: 0;"></div>');

  // ================= globe (orthographic, rotating) =================
  const G = { cx: 540, cy: 1070, R: 370, lat0: 22 * Math.PI / 180 };
  const CITIES = [["Sheffield", 53.4, -1.5], ["London", 51.5, -0.1], ["Birmingham", 52.5, -1.9], ["Manchester", 53.5, -2.2], ["Makkah", 21.4, 39.8], ["Madinah", 24.5, 39.6], ["Cairo", 30.0, 31.2], ["Dubai", 25.2, 55.3], ["Jakarta", -6.2, 106.8], ["Toronto", 43.7, -79.4], ["Sydney", -33.9, 151.2]];
  const LABEL = { Sheffield: [16, -14], London: [16, 34], Birmingham: [-190, 30], Manchester: [-200, -12], Makkah: [16, 46], Madinah: [-50, -30], Cairo: [-110, 12], Dubai: [18, 14], Jakarta: [16, 10], Toronto: [16, 10], Sydney: [16, 10] };
  const svgNS = "http://www.w3.org/2000/svg";
  const gsvg = $("g-svg");
  const mk = function (tag, attrs) { const e = document.createElementNS(svgNS, tag); Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); }); gsvg.appendChild(e); return e; };
  mk("circle", { cx: G.cx, cy: G.cy, r: G.R + 60, fill: "url(#g-glow)" });
  const defs = document.createElementNS(svgNS, "defs");
  defs.innerHTML = '<radialGradient id="g-glow"><stop offset="0.7" stop-color="#47A6FF" stop-opacity="0.18"/><stop offset="1" stop-color="#47A6FF" stop-opacity="0"/></radialGradient><radialGradient id="g-body" cx="0.4" cy="0.35"><stop offset="0" stop-color="#1B3A7A" stop-opacity="0.55"/><stop offset="1" stop-color="#050B24" stop-opacity="0.85"/></radialGradient>';
  gsvg.insertBefore(defs, gsvg.firstChild);
  mk("circle", { cx: G.cx, cy: G.cy, r: G.R, fill: "url(#g-body)", stroke: "rgba(160,190,255,0.45)", "stroke-width": 2 });
  const gridPath = mk("path", { fill: "none", stroke: "rgba(160,190,255,0.22)", "stroke-width": 1.4 });
  const arcPaths = CITIES.slice(1).map(function () { return mk("path", { fill: "none", stroke: "#FFD27A", "stroke-width": 3, "stroke-linecap": "round", opacity: 0.9 }); });
  const cityEls = CITIES.map(function (c) {
    const dot = mk("circle", { r: 9, fill: "#FFD27A" });
    const halo = mk("circle", { r: 22, fill: "rgba(255,210,122,0.25)" });
    const lab = mk("text", { "font-family": "HF Gill, sans-serif", "font-size": 32, "font-weight": 600, fill: "#E6E9FA" });
    lab.textContent = c[0];
    return { dot: dot, halo: halo, lab: lab };
  });
  const vec = function (lat, lon) { const p = lat * Math.PI / 180, l = lon * Math.PI / 180; return [Math.cos(p) * Math.cos(l), Math.cos(p) * Math.sin(l), Math.sin(p)]; };
  const proj = function (v, lon0, lift) {
    const l0 = lon0 * Math.PI / 180, c0 = Math.cos(G.lat0), s0 = Math.sin(G.lat0);
    // rotate so (lat0, lon0) faces the viewer
    const x1 = v[0] * Math.cos(-l0) - v[1] * Math.sin(-l0), y1 = v[0] * Math.sin(-l0) + v[1] * Math.cos(-l0), z1 = v[2];
    const depth = x1 * c0 + z1 * s0, up = -x1 * s0 + z1 * c0;
    const k = G.R * (lift || 1);
    return { x: G.cx + y1 * k, y: G.cy - up * k, vis: depth > 0 };
  };
  function drawGlobe(t) {
    const lon0 = -18 + 78 * Math.max(0, Math.min(1, (t - 47.3) / 4.4));
    let d = "";
    for (let lon = -180; lon < 180; lon += 30) {
      let pen = false;
      for (let lat = -90; lat <= 90; lat += 5) {
        const p = proj(vec(lat, lon), lon0);
        if (p.vis) { d += (pen ? "L" : "M") + p.x.toFixed(1) + " " + p.y.toFixed(1) + " "; pen = true; } else { pen = false; }
      }
    }
    for (let lat = -60; lat <= 60; lat += 30) {
      let pen = false;
      for (let lon = -180; lon <= 180; lon += 5) {
        const p = proj(vec(lat, lon), lon0);
        if (p.vis) { d += (pen ? "L" : "M") + p.x.toFixed(1) + " " + p.y.toFixed(1) + " "; pen = true; } else { pen = false; }
      }
    }
    gridPath.setAttribute("d", d);
    const hub = vec(CITIES[0][1], CITIES[0][2]);
    CITIES.forEach(function (c, i) {
      const appear = 48.0 + i * 0.22;
      const a = Math.max(0, Math.min(1, (t - appear) / 0.35));
      const p = proj(vec(c[1], c[2]), lon0);
      const e = cityEls[i];
      const show = p.vis ? a : 0;
      [e.dot, e.halo].forEach(function (n) { n.setAttribute("cx", p.x.toFixed(1)); n.setAttribute("cy", p.y.toFixed(1)); n.setAttribute("opacity", String(show)); });
      e.halo.setAttribute("r", String(14 + 10 * a));
      e.lab.setAttribute("x", (p.x + LABEL[c[0]][0]).toFixed(1)); e.lab.setAttribute("y", (p.y + LABEL[c[0]][1]).toFixed(1));
      e.lab.setAttribute("opacity", String(show));
      if (i === 0) { return; }
      // great-circle arc from Sheffield, lifted off the surface
      const to = vec(c[1], c[2]);
      const dot = hub[0] * to[0] + hub[1] * to[1] + hub[2] * to[2];
      const om = Math.acos(Math.max(-1, Math.min(1, dot)));
      const prog = Math.max(0, Math.min(1, (t - appear + 0.1) / 0.6));
      let ad = "", pen = false;
      const steps = 40;
      for (let s = 0; s <= steps * prog; s++) {
        const f = s / steps;
        const w1 = Math.sin((1 - f) * om) / Math.sin(om), w2 = Math.sin(f * om) / Math.sin(om);
        const v = [hub[0] * w1 + to[0] * w2, hub[1] * w1 + to[1] * w2, hub[2] * w1 + to[2] * w2];
        const q = proj(v, lon0, 1 + 0.16 * Math.sin(Math.PI * f) * Math.min(1, om));
        if (q.vis) { ad += (pen ? "L" : "M") + q.x.toFixed(1) + " " + q.y.toFixed(1) + " "; pen = true; } else { pen = false; }
      }
      arcPaths[i - 1].setAttribute("d", ad);
    });
  }

  // ================= per-frame text (seek-safe: pure functions of t) =================
  const GL = "#%&*+=<>/?$@";
  const scramble = function (text, p, t, seed) {
    const step = Math.floor(t * 22);
    let out = "";
    for (let i = 0; i < text.length; i++) { out += p >= (i + 1) / text.length ? text[i] : GL[(i * 7919 + step * 104729 + seed) % GL.length]; }
    return out;
  };
  const clamp = function (v) { return Math.max(0, Math.min(1, v)); };
  const mmss = function (s) { s = Math.max(0, s); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); };
  function render(t) {
    $("s-intro-word").textContent = scramble("Masjidly", clamp((t - 0.25) / 0.9), t, 3);
    $("s-cta-word").textContent = scramble("Masjidly", clamp((t - 51.9) / 0.7), t, 11);
    // hook: the calculated 5:06 ticks to your masjid's 5:26
    const m = t < 3.75 ? 6 : Math.min(26, 6 + Math.floor(clamp((t - 3.75) / 0.7) * 20));
    $("h-p0-time").textContent = "5:" + String(m).padStart(2, "0") + THIN + "AM";
    // widgets: live countdown to Isha adhan (8:16 PM) from 8:01:28 PM at 36.6s
    const left = 14 * 60 + 32 - Math.floor(Math.max(0, t - 36.6));
    $("w-clock").textContent = mmss(left);
    $("lw-cclock").textContent = mmss(left);
    const c = clamp((t - 47.9) / 0.9);
    $("g-digits").textContent = String(Math.round(340 * (1 - Math.pow(1 - c, 3))));
    if (t > 47.0 && t < 52.2) { drawGlobe(t); }
  }

  // ================= timeline =================
  const tl = gsap.timeline({ paused: true });
  const clock = { v: 0 };
  tl.fromTo(clock, { v: 0 }, { v: 55, duration: 55, ease: "none", onUpdate: function () { render(clock.v); } }, 0);
  render(0);

  const cam = function (px, py, s, qx, qy) { return { scale: s, x: qx - 540 - s * (px - 540), y: qy - 960 - s * (py - 960) }; };
  const move = function (sel, at, d, vars, ease) { tl.to(sel, Object.assign({ duration: d, ease: ease || "power3.inOut" }, vars), at); };
  // blur never rides an overshooting ease (a negative blur is invalid CSS)
  const pop = function (sel, at, from, dur) {
    const f = Object.assign({}, from || {}); const blur = f.filter; delete f.filter;
    tl.fromTo(sel, Object.assign({ opacity: 0, scale: 0.35 }, f), { opacity: 1, scale: 1, x: 0, y: 0, rotation: 0, duration: dur || 0.42, ease: "back.out(1.9)" }, at);
    if (blur) { tl.fromTo(sel, { filter: blur }, { filter: "blur(0px)", duration: 0.35, ease: "power2.out" }, at); }
  };
  const tap = function (x, y, at) {
    tl.set("#tap", { left: x, top: y }, at);
    tl.fromTo("#tap", { opacity: 0, scale: 0.6 }, { opacity: 1, scale: 1, duration: 0.1, ease: "power2.out", immediateRender: false }, at);
    tl.to("#tap", { opacity: 0, scale: 1.25, duration: 0.3, ease: "power2.out" }, at + 0.13);
  };
  let curPage = 0, curSun = "fajr", curLetter = 0;
  const INK = { fajr: ["#FFFFFF", "#111111"], sunrise: ["#111111", "#FFFFFF"], dhuhr: ["#111111", "#FFFFFF"], asr: ["#111111", "#FFFFFF"], maghrib: ["#111111", "#FFFFFF"], isha: ["#FFFFFF", "#111111"] };
  const select = function (page, letter, at) {
    const p = PAGES[page];
    if (page !== curPage) {
      tl.to("#h-p" + curPage, { opacity: 0, duration: 0.2, ease: "power1.out" }, at);
      tl.fromTo("#h-p" + page, { opacity: 0 }, { opacity: 1, duration: 0.28, ease: "power1.in", immediateRender: false }, at + 0.1);
    }
    if (p.theme !== curSun) {
      tl.to("#h-sun-" + curSun, { opacity: 0, duration: 0.25 }, at);
      tl.fromTo("#h-sun-" + p.theme, { opacity: 0 }, { opacity: 1, duration: 0.35, immediateRender: false }, at + 0.1);
      if (INK[p.theme][0] !== INK[curSun][0]) { tl.to("#h-ui", { color: INK[p.theme][0], "--inv": INK[p.theme][1], duration: 0.8, ease: "power1.inOut" }, at); }
    }
    if (letter !== null && letter !== curLetter) {
      tl.to("#lt-en-s" + curLetter, { opacity: 0, duration: 0.2 }, at);
      tl.to("#lt-en-r" + curLetter, { opacity: 0.38, duration: 0.2 }, at);
      tl.to("#lt-en-s" + letter, { opacity: 1, duration: 0.2 }, at);
      tl.to("#lt-en-r" + letter, { opacity: 0, duration: 0.2 }, at);
      curLetter = letter;
    }
    curPage = page; curSun = p.theme;
  };
  // Tab bar state: widths, selection and the ScrollViewReader-style centering on the selected tab
  let tabState = { added: [true, false, false, false, false], sel: 0 }, trackX = 0;
  const tabLayout = function (st) {
    const w = TABS.map(function (tb, i) { return st.added[i] ? (i === st.sel ? tb.sel : UNSEL) : 0; });
    let x = 0; const pos = [];
    w.forEach(function (wi) { pos.push(x); x += wi + (wi > 0 ? 13 : 0); });
    const contentW = 26 + x + 81 + 26;
    const center = 26 + pos[st.sel] + w[st.sel] / 2;
    const offset = Math.max(0, Math.min(center - 540, Math.max(0, contentW - 1080)));
    return { w: w, pos: pos, offset: offset, plusX: 26 + x + 40.5 };
  };
  const setTabs = function (st, at, noScroll) {
    const L = tabLayout(st);
    TABS.forEach(function (tb, i) {
      const wasAdded = tabState.added[i], isAdded = st.added[i];
      const on = i === st.sel;
      if (isAdded && !wasAdded) { tl.fromTo("#h-tab-" + tb.id, { width: 0, opacity: 0 }, { width: L.w[i], opacity: 1, duration: 0.42, ease: "power3.out" }, at); }
      else if (isAdded) { tl.to("#h-tab-" + tb.id, { width: L.w[i], duration: 0.3, ease: "power2.inOut" }, at); }
      if (isAdded) {
        tl.to("#h-fill-" + tb.id, { opacity: on ? 0.92 : 0.12, duration: 0.3 }, at);
        tl.to("#h-sel-" + tb.id, { opacity: on ? 1 : 0, duration: 0.3 }, at);
        tl.to("#h-uns-" + tb.id, { opacity: on ? 0 : 0.72, duration: 0.3 }, at);
      }
    });
    if (!noScroll) { tl.to("#h-track", { x: -L.offset, duration: 0.4, ease: "power2.inOut" }, at); trackX = -L.offset; }
    tabState = { added: st.added.slice(), sel: st.sel };
  };

  gsap.set(["#hk-calc", "#hk-mine", "#hk-badge", "#lg", "#s-themes", "#s-lock", "#s-whome", "#s-wlock", "#s-tt", "#s-globe", "#s-cta", "#am", "#am-dim"], { opacity: 0 });
  gsap.set(["#h-sun-sunrise", "#h-sun-dhuhr", "#h-sun-asr", "#h-sun-maghrib", "#h-sun-isha"], { opacity: 0 });
  gsap.set("#h-p0", { opacity: 1 });
  gsap.set("#lt-en-s0", { opacity: 1 });
  gsap.set("#lt-en-r0", { opacity: 0 });
  gsap.set(["#s-cam", "#tt-sheet"], { transformOrigin: "540px 960px" });
  gsap.set("#s-cam", { opacity: 0, transformPerspective: 2600 });
  gsap.set("#lg", { y: 500 });
  gsap.set(["#am-v1", "#am-v2", "#am-v3", "#am-v4", "#am-panel"], { opacity: 0 });

  // ===== 0-1.9 · logo, zoom through into the app =====
  tl.fromTo("#s-intro-icon", { opacity: 0, scale: 0.5, rotation: -10 }, { opacity: 1, scale: 1, rotation: 0, duration: 0.7, ease: "back.out(1.7)" }, 0.05);
  tl.fromTo("#s-intro-word", { opacity: 0, y: 30 }, { opacity: 1, y: 0, duration: 0.4, ease: "power3.out" }, 0.2);
  tl.to("#s-intro", { scale: 3.4, opacity: 0, filter: "blur(18px)", duration: 0.6, ease: "power3.in", transformOrigin: "540px 780px" }, 1.35);
  tl.fromTo("#s-cam", { scale: 2.3, x: 0, y: 0, opacity: 0, filter: "blur(22px)" }, { scale: 1, opacity: 1, filter: "blur(0px)", duration: 0.8, ease: "expo.out", immediateRender: false }, 1.6);

  // ===== A 1.9-7.6 · the calculated time ticks to your masjid's time =====
  tl.fromTo("#hk-calc", { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.35, ease: "power3.out" }, 2.45);
  move("#s-cam", 3.55, 0.45, cam(540, 820, 1.2, 540, 800), "expo.out");
  tl.to("#hk-calc", { opacity: 0, scale: 0.8, duration: 0.2 }, 4.4);
  pop("#hk-mine", 4.45, { scale: 0.6 });
  pop("#hk-badge", 4.55, { x: -40, filter: "blur(8px)" });
  move("#s-cam", 5.4, 0.7, { scale: 1, x: 0, y: 0 }, "power3.inOut");
  tl.to(["#hk-mine", "#hk-badge"], { opacity: 0, y: -16, duration: 0.3 }, 7.1);

  // ===== B 7.6-13.6 · prayer times, redesigned: tap F S D A M I =====
  tl.to("#s-cam", { rotationY: -5, duration: 1.2, ease: "power1.inOut" }, 7.7);
  tl.to("#s-cam", { rotationY: 5, scale: 1.03, duration: 4.4, ease: "power1.inOut" }, 8.9);
  [[1, 1, 9.2], [2, 2, 10.0], [3, 3, 10.8], [4, 4, 11.6], [5, 5, 12.4]].forEach(function (s) {
    tap(LX[s[1]], LY - 18, s[2] - 0.05);
    select(s[0], s[1], s[2]);
  });
  tl.to("#s-cam", { rotationY: 0, scale: 1, duration: 0.5, ease: "power2.inOut" }, 13.3);

  // ===== C 13.6-19.8 · in your language (the language picker) =====
  tap(LX[2], LY - 18, 13.75);
  select(2, 2, 13.8);
  tl.to("#lg", { opacity: 1, y: 0, duration: 0.55, ease: "expo.out" }, 14.3);
  tl.to(["#h-tabs", "#h-letters-wrap"], { opacity: 0, duration: 0.3 }, 14.3);
  tl.to(["#h-tabs", "#h-letters-wrap"], { opacity: 1, duration: 0.3 }, 19.7);
  const lgSel = function (row, at) {
    tl.to("#lg-hl", { y: row * 88, duration: 0.3, ease: "power3.out" }, at);
    tl.to("#lg-check", { y: row * 88, duration: 0.3, ease: "power3.out" }, at);
    tl.fromTo("#lg-check", { scale: 0.6 }, { scale: 1, duration: 0.3, ease: "back.out(2.5)", immediateRender: false }, at + 0.05);
  };
  const dissolve = function (sel, at) { tl.to(sel, { opacity: 0, scaleX: 1.4, filter: "blur(12px)", duration: 0.3, ease: "power2.in" }, at); };
  const restore = function (sel, at) { tl.fromTo(sel, { opacity: 0, scaleX: 1.4, filter: "blur(12px)" }, { opacity: 1, scaleX: 1, filter: "blur(0px)", duration: 0.35, ease: "power2.out", immediateRender: false }, at); };
  const draw = function (page, at) {
    const txt = "#h-p" + page + "-svgname";
    tl.fromTo(txt, { attr: { "stroke-dashoffset": 900 } }, { attr: { "stroke-dashoffset": 0 }, duration: 0.65, ease: "power1.inOut", immediateRender: false }, at);
    tl.fromTo(txt, { attr: { "fill-opacity": 0 } }, { attr: { "fill-opacity": 1 }, duration: 0.3, ease: "power1.in", immediateRender: false }, at + 0.5);
    tl.fromTo(txt, { attr: { "stroke-opacity": 1 } }, { attr: { "stroke-opacity": 0 }, duration: 0.3, immediateRender: false }, at + 0.7);
  };
  const pageSwap = function (outPage, inPage, at, outIsText) {
    if (outIsText) { dissolve("#h-p" + outPage + "-name", at); tl.to("#h-p" + outPage, { opacity: 0, duration: 0.3 }, at + 0.05); }
    else { tl.to("#h-p" + outPage, { opacity: 0, filter: "blur(10px)", duration: 0.25, ease: "power2.in" }, at); }
    tl.fromTo("#h-p" + inPage, { opacity: 0, filter: "blur(10px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.3, ease: "power2.out", immediateRender: false }, at + 0.15);
  };
  lgSel(1, 15.3); pageSwap(2, 7, 15.4, true); draw(7, 15.6);
  tl.fromTo("#s-cam", { scale: 1 }, { scale: 1.05, duration: 0.5, ease: "power2.out", immediateRender: false }, 15.4);
  lgSel(2, 16.8); pageSwap(7, 8, 16.9, false); draw(8, 17.1);
  tl.to("#s-cam", { scale: 1.08, duration: 0.5, ease: "power2.out" }, 16.9);
  lgSel(3, 18.1); pageSwap(8, 9, 18.2, false); draw(9, 18.4);
  tl.to("#s-cam", { scale: 1.02, duration: 0.5, ease: "power2.out" }, 18.2);
  lgSel(0, 19.1);
  tl.to("#h-p9", { opacity: 0, filter: "blur(10px)", duration: 0.25 }, 19.2);
  tl.fromTo("#h-p2", { opacity: 0, filter: "blur(10px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.3, immediateRender: false }, 19.35);
  restore("#h-p2-name", 19.35);
  tl.to("#s-cam", { scale: 1, duration: 0.4 }, 19.35);
  tl.to("#lg", { opacity: 0, y: 500, duration: 0.4, ease: "power3.in" }, 19.45);
  curPage = 2;

  // ===== D 19.8-26.4 · add 4 masjids, switch in one tap =====
  tap(LX[3], LY - 18, 19.95);
  select(3, 3, 20.0);
  move("#s-cam", 20.3, 0.5, { y: -160 }, "power3.inOut");
  const TAB_PAGES = [3, 6, 6, 10, 11];
  // The app's add-tab card (MosqueSelectionOnboardingView) at 2.2x: closed it is 771px tall at top 575 (h-ui);
  // the open Mosque dropdown grows it to 1364px at top 278. It springs out of the + button and fades back out.
  const amIn = function (at) {
    const L = tabLayout(tabState);
    tap(L.plusX + trackX, 1762 - 160, at);
    tl.fromTo("#am-dim", { opacity: 0 }, { opacity: 1, duration: 0.24, ease: "power1.out", immediateRender: false }, at + 0.06);
    tl.fromTo("#am", { opacity: 0, scale: 0.08, x: L.plusX + trackX - 540, y: 802, transformOrigin: "50% 50%" }, { opacity: 1, scale: 1, x: 0, y: 0, duration: 0.45, ease: "back.out(1.1)", immediateRender: false }, at + 0.06);
  };
  const amOut = function (at) {
    tap(540, 1237 - 160, at);
    tl.to(["#am", "#am-dim"], { opacity: 0, duration: 0.24, ease: "power1.out" }, at + 0.05);
    tl.to("#am", { scale: 0.96, duration: 0.24, ease: "power1.out" }, at + 0.05);
  };
  const addTab = function (idx, at) {
    const added = tabState.added.slice(); added[idx] = true;
    setTabs({ added: added, sel: idx }, at);
    select(TAB_PAGES[idx], null, at + 0.1);
  };
  const amDrop = function (open, at) {
    tl.to("#am", { clipPath: open ? "inset(0px 0px 0px 0px round 53px)" : "inset(297px 0px 296px 0px round 53px)", duration: 0.22, ease: "power1.inOut" }, at);
    tl.to("#am-in", { y: open ? 0 : 297, duration: 0.22, ease: "power1.inOut" }, at);
    tl.to("#am-go", { y: open ? 0 : -296, duration: 0.22, ease: "power1.inOut" }, at);
    tl.to("#am-chev", { rotation: open ? 180 : 0, duration: 0.22, ease: "power1.inOut" }, at);
    tl.to("#am-panel", { opacity: open ? 1 : 0, y: open ? 0 : -40, scale: open ? 1 : 0.98, duration: 0.22, ease: "power1.inOut" }, at);
  };
  gsap.set("#am-panel", { y: -40, scale: 0.98 });
  gsap.set("#am-in", { y: 297 });
  gsap.set("#am-go", { y: -296 });
  gsap.set("#am-chev", { transformOrigin: "50% 50%" });
  // 1: open the Mosque dropdown, scroll to Masjid Risalah, pick it, Continue
  amIn(20.75);
  tap(700, 1080 - 160, 21.3);
  amDrop(true, 21.35);
  tl.to("#am-items", { y: -616, duration: 0.5, ease: "power2.inOut" }, 21.62);
  tap(500, 1261 - 160, 22.15);
  tl.set("#am-sel", { y: 880 }, 22.18);
  tl.set("#am-v0", { opacity: 0 }, 22.2);
  tl.set("#am-v1", { opacity: 1 }, 22.2);
  amDrop(false, 22.22);
  amOut(22.55);
  addTab(1, 22.65);
  // 2-4: the next masjid is already picked, so it is one tap on Continue
  [[2, 23.1], [3, 24.0], [4, 24.9]].forEach(function (a) {
    tl.set("#am-v" + (a[0] - 1), { opacity: 0 }, a[1] - 0.2);
    tl.set("#am-v" + a[0], { opacity: 1 }, a[1] - 0.2);
    amIn(a[1]);
    amOut(a[1] + 0.5);
    addTab(a[0], a[1] + 0.6);
  });
  // swipe the tab bar back and tap Masjid Faizul Islam
  tl.to("#h-track", { x: 0, duration: 0.35, ease: "power2.inOut" }, 25.75);
  trackX = 0;
  tap(26 + UNSEL / 2, 1762 - 160, 25.95);
  setTabs({ added: [true, true, true, true, true], sel: 0 }, 26.0, true);
  select(3, null, 26.05);
  move("#s-cam", 26.15, 0.4, { y: 0 }, "power3.inOut");

  // ===== E 26.4-31.6 · make it yours: the three theme styles, then your own colours =====
  tl.fromTo("#s-themes", { opacity: 0 }, { opacity: 1, duration: 0.01 }, 26.45);
  tl.to("#s-cam", { opacity: 0, duration: 0.01 }, 26.47);
  tl.fromTo("#t-mod", { scale: 1, borderRadius: 0, y: 0 }, { scale: 0.4, borderRadius: 150, y: 90, duration: 0.65, ease: "expo.inOut" }, 26.47);
  tl.fromTo("#t-orig", { opacity: 0, scale: 0.36, x: -120, y: 90, rotationY: 30, transformPerspective: 2000 }, { opacity: 1, x: -360, rotationY: 18, duration: 0.45, ease: "expo.out" }, 26.85);
  tl.fromTo("#t-cust", { opacity: 0, scale: 0.36, x: 120, y: 90, rotationY: -30, transformPerspective: 2000 }, { opacity: 1, x: 360, rotationY: -18, duration: 0.45, ease: "expo.out" }, 26.85);
  tl.fromTo(["#t-lab-o", "#t-lab-m", "#t-lab-c"], { opacity: 0, y: -20 }, { opacity: 1, y: 0, duration: 0.3, stagger: 0.08, ease: "power3.out" }, 27.1);
  const focus = function (card, lab, at, rot) {
    tl.to(card, { scale: 0.46, rotationY: 0, duration: 0.4, ease: "power3.out" }, at);
    tl.to(lab, { scale: 1.15, duration: 0.3, ease: "back.out(2)" }, at);
    tl.to(card, { scale: 0.36, rotationY: rot, duration: 0.35, ease: "power3.inOut" }, at + 1.05);
    tl.to(lab, { scale: 1, duration: 0.3 }, at + 1.05);
  };
  tap(220, 1000, 27.75); focus("#t-orig", "#t-lab-o", 27.8, 18);
  tap(900, 1000, 28.95);
  tl.to("#t-cust", { scale: 0.46, rotationY: 0, duration: 0.4, ease: "power3.out" }, 29.0);
  tl.to("#t-lab-c", { scale: 1.15, duration: 0.3, ease: "back.out(2)" }, 29.0);
  tl.fromTo("#t-sw", { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.3, ease: "back.out(2)" }, 29.2);
  tl.to(["#t-cust2", "#t-sw-top2", "#t-sw-bot2"], { opacity: 1, duration: 0.6, ease: "power1.inOut" }, 29.9);
  tl.to("#t-cust", { scale: 0.36, rotationY: -18, duration: 0.35, ease: "power3.inOut" }, 30.6);
  tl.to("#t-lab-c", { scale: 1, duration: 0.3 }, 30.6);
  tl.to("#t-sw", { opacity: 0, duration: 0.25 }, 30.6);
  tl.to("#t-mod", { scale: 0.46, duration: 0.35, ease: "power3.out" }, 30.7);
  tl.to("#t-lab-m", { scale: 1.15, duration: 0.3, ease: "back.out(2)" }, 30.7);
  // tilt back in 3D, into the lock screen
  tl.to("#s-themes", { rotationX: 38, y: 260, scale: 0.72, opacity: 0, filter: "blur(10px)", transformPerspective: 1800, transformOrigin: "540px 1200px", duration: 0.55, ease: "power3.in" }, 31.1);

  // ===== F 31.6-36.6 · lock screen: the iqamah nudge, then the adhan =====
  tl.fromTo("#s-lock", { opacity: 0, rotationX: -24, y: -220, scale: 1.08, transformPerspective: 2200, transformOrigin: "540px 0px" }, { opacity: 1, rotationX: 7, y: 0, scale: 1, duration: 0.7, ease: "expo.out" }, 31.55);
  tl.fromTo("#s-lock", { filter: "blur(14px)" }, { filter: "blur(0px)", duration: 0.45, ease: "power2.out" }, 31.55);
  tl.to("#s-lock", { rotationX: 0, duration: 0.8, ease: "power2.out" }, 32.3);
  tl.fromTo("#s-n1", { opacity: 0, y: -300, scale: 0.9 }, { opacity: 1, y: 0, scale: 1, duration: 0.5, ease: "back.out(1.4)" }, 32.7);
  tl.to("#k-stack", { y: -320, duration: 0.4, ease: "power3.inOut" }, 33.9);
  tl.to("#s-n1-now", { opacity: 0, duration: 0.2 }, 33.95);
  tl.to("#s-n1-ago", { opacity: 1, duration: 0.2 }, 33.95);
  tl.to("#s-n1", { y: 280, scale: 0.96, duration: 0.4, ease: "power3.inOut" }, 34.0);
  tl.fromTo("#s-n2", { opacity: 0, y: -300, scale: 0.9 }, { opacity: 1, y: 0, scale: 1, duration: 0.5, ease: "back.out(1.4)" }, 34.2);
  tl.to("#s-lock", { scale: 1.03, duration: 1.8, ease: "power1.inOut" }, 34.4);
  tl.to("#s-lock", { y: -1900, opacity: 0, filter: "blur(12px)", duration: 0.45, ease: "power3.in" }, 36.2);

  // ===== G 36.6-43.2 · home screen widgets, then lock screen widgets =====
  tl.fromTo("#s-whome", { opacity: 0, rotationX: 30, y: 500, scale: 0.85, transformPerspective: 2200, transformOrigin: "540px 1400px" }, { opacity: 1, rotationX: 14, y: 80, scale: 0.92, duration: 0.7, ease: "expo.out" }, 36.55);
  pop("#w-small", 36.9, { y: 120, filter: "blur(10px)" });
  pop("#w-app", 37.1, { y: 80, filter: "blur(8px)" });
  pop("#w-large", 37.35, { y: 200, filter: "blur(12px)" }, 0.5);
  tl.to("#s-whome", { rotationX: 0, y: 0, scale: 1, duration: 0.7, ease: "power2.inOut" }, 37.9);
  tl.to("#s-whome", { scale: 1.04, y: -40, duration: 1.15, ease: "power1.inOut" }, 38.6);
  tl.to("#s-whome", { opacity: 0, scale: 0.86, y: 200, filter: "blur(12px)", duration: 0.4, ease: "power2.in" }, 39.8);
  tl.fromTo("#s-wlock", { opacity: 0, y: -600, transformPerspective: 2200, rotationX: -18, transformOrigin: "540px 0px" }, { opacity: 1, y: 0, rotationX: 0, duration: 0.6, ease: "expo.out" }, 39.95);
  pop("#lw-circ", 40.4, { y: 40 });
  pop("#lw-rect", 40.6, { y: 40 });
  tl.to("#s-wlock", { scale: 1.05, duration: 1.6, ease: "power1.inOut", transformOrigin: "540px 820px" }, 40.8);
  tl.fromTo("#tap-lw", { opacity: 0, scale: 0.6 }, { opacity: 1, scale: 1, duration: 0.1, immediateRender: false }, 42.45);
  tl.to("#tap-lw", { opacity: 0, scale: 1.25, duration: 0.25 }, 42.58);
  tl.to(["#lw-circ", ".lw-date", ".lw-clock"], { opacity: 0, filter: "blur(10px)", duration: 0.25 }, 42.6);
  tl.to("#lw-rect", { scale: 4, x: -120, y: 400, opacity: 0, filter: "blur(16px)", duration: 0.5, ease: "power3.in" }, 42.6);

  // ===== H 43.2-47.4 · the timetable at night: Midnight and Last Third =====
  tl.fromTo("#s-tt", { opacity: 0, scale: 0.75, filter: "blur(18px)" }, { opacity: 1, scale: 1, filter: "blur(0px)", duration: 0.55, ease: "expo.out", transformOrigin: "540px 900px" }, 43.0);
  tl.fromTo("#s-nb", { opacity: 0 }, { opacity: 0, duration: 0.01 }, 43.0);
  move("#tt-sheet", 43.9, 0.6, cam(460, 1585, 1.3, 540, 1100), "expo.inOut");
  tl.to(["#tt-sheet .tt-up", "#tt-sheet .past"], { opacity: 0.08, filter: "blur(6px)", duration: 0.45 }, 43.9);
  tl.fromTo(["#tt-r6", "#tt-r7"], { backgroundColor: "rgba(255,255,255,0)" }, { backgroundColor: "rgba(255,255,255,0.08)", duration: 0.35, stagger: 0.4 }, 44.5);
  move("#tt-sheet", 45.4, 0.55, { scale: 0.66, x: 0, y: -120 }, "expo.inOut");
  tl.to("#tt-sheet .tt-up", { opacity: 1, filter: "blur(0px)", duration: 0.4 }, 45.45);
  tl.to("#tt-sheet .past", { opacity: 0.35, filter: "blur(0px)", duration: 0.4 }, 45.45);
  tl.fromTo("#s-nb", { opacity: 0, y: 60 }, { opacity: 1, y: 0, duration: 0.35, ease: "power3.out", immediateRender: false }, 45.6);
  tl.fromTo("#nb-line", { scaleX: 0 }, { scaleX: 1, duration: 0.55, ease: "power2.inOut" }, 45.7);
  tl.fromTo("#nb-mid", { opacity: 0, y: 16 }, { opacity: 1, y: 0, duration: 0.3, ease: "back.out(2)" }, 46.1);
  tl.fromTo("#nb-lt", { opacity: 0, y: 16 }, { opacity: 1, y: 0, duration: 0.3, ease: "back.out(2)" }, 46.3);
  tl.to("#s-tt", { scale: 0.05, opacity: 0, filter: "blur(6px)", duration: 0.4, ease: "power3.in", transformOrigin: "540px 1070px" }, 47.0);

  // ===== I 47.4-51.6 · 340+ masjids on a turning globe =====
  tl.fromTo("#s-globe", { opacity: 0, scale: 0.15 }, { opacity: 1, scale: 1, duration: 0.8, ease: "expo.out", transformOrigin: "540px 1070px" }, 47.3);
  tl.fromTo("#g-plus", { opacity: 0, scale: 0.2 }, { opacity: 1, scale: 1, duration: 0.3, ease: "back.out(2.6)" }, 48.8);
  tl.to("#g-num", { scale: 1.05, duration: 1.2, ease: "power1.inOut" }, 49.0);
  tl.to("#s-globe", { scale: 0.2, opacity: 0, filter: "blur(8px)", duration: 0.45, ease: "power3.in", transformOrigin: "540px 560px" }, 51.2);

  // ===== J 51.6-55 · Masjidly, the next dawn =====
  tl.fromTo("#s-cta", { opacity: 0 }, { opacity: 1, duration: 0.2 }, 51.55);
  tl.fromTo("#s-cta-icon", { opacity: 0, scale: 0.4, y: 40 }, { opacity: 1, scale: 1, y: 0, duration: 0.6, ease: "back.out(1.6)" }, 51.55);
  tl.fromTo("#s-cta-word", { opacity: 0 }, { opacity: 1, duration: 0.25 }, 51.7);
  pop("#s-store-ios", 53.2, { y: 40 });
  pop("#s-store-play", 53.35, { y: 40 });

  window.__timelines["stage"] = tl;
})();
