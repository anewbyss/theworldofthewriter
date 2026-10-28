// World economy: population and GDP for every country since 1960, region totals on the
// world map, rankings and trends, plus any UN data file the writer imports.
(function (WOW) {
  const REF = window.WOW_REF;
  const ECON = window.WOW_ECON;
  const { h, svg, store, views: V } = WOW;

  const years = ECON.years;
  const yi = (y) => years.indexOf(y);
  const norm = (s) => String(s || "").normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z]/g, "");

  // ---- Imported datasets (stored as Research Pool entries so backups carry them) ----
  const datasets = () => store.list("research").filter((r) => r.series && typeof r.series === "object");
  const UN_NAMES = {
    "State of Palestine": "PSE", "United States of America": "USA", "Republic of Korea": "KOR", "Democratic People's Republic of Korea": "PRK",
    "United Republic of Tanzania": "TZA", "Lao People's Democratic Republic": "LAO", "Republic of Moldova": "MDA", "Democratic Republic of the Congo": "COD",
    "Congo": "COG", "United Kingdom of Great Britain and Northern Ireland": "GBR", "China, Hong Kong SAR": "HKG", "China, Macao SAR": "MAC",
    "Micronesia (Fed. States of)": "FSM", "Kosovo (under UNSC res. 1244)": "XKX", "Gambia": "GMB", "Bahamas": "BHS", "Curaçao": "CUW",
    "Saint Martin (French part)": "MAF", "Sint Maarten (Dutch part)": "SXM", "Kyrgyzstan": "KGZ", "Slovakia": "SVK", "Russia": "RUS",
    "Egypt": "EGY", "Yemen": "YEM", "Venezuela": "VEN", "Iran": "IRN", "Syria": "SYR", "Viet Nam": "VNM", "Côte d'Ivoire": "CIV", "Turkey": "TUR",
    "Netherlands (Kingdom of the)": "NLD", "United States Virgin Islands": "VIR", "Saint Kitts and Nevis": "KNA", "Saint Lucia": "LCA",
    "Saint Vincent and the Grenadines": "VCT", "Hong Kong": "HKG", "Macao": "MAC", "Macau": "MAC", "Cape Verde": "CPV", "Swaziland": "SWZ",
  };
  // Match a name from any UN file to a country: "Bolivia (Plurinational State of)" → Bolivia.
  const nameIndex = (() => {
    const m = new Map();
    const modernName = new Map(REF.modern.flatMap((g) => g.items.map((it) => [it.id, it.name])));
    for (const c of ECON.countries) {
      const keys = [c.name, c.name.split(",")[0], c.name.split(" (")[0], modernName.get(c.modern) || "", (modernName.get(c.modern) || "").split(" (")[0].split(" / ")[0]];
      for (const k of keys) if (k) m.set(norm(k), c);
    }
    for (const a of ECON.aggregates) m.set(norm(a.name), a);
    // Official UN names that differ from the bundled ones.
    for (const [alias, code] of Object.entries(UN_NAMES)) { const c = ECON.countries.find((x) => x.code === code); if (c) m.set(norm(alias), c); }
    return m;
  })();
  const findCountry = (name) => nameIndex.get(norm(name)) || nameIndex.get(norm(String(name).split(" (")[0])) || nameIndex.get(norm(String(name).split(",")[0]));

  // ---- Metrics ---------------------------------------------------------------
  function metrics() {
    const base = [
      { id: "pop", label: "Population", unit: "people", agg: "sum", get: (c, i) => c.pop[i] },
      { id: "gdp", label: "GDP (current US$)", unit: "US$", agg: "sum", get: (c, i) => (c.gdp[i] == null ? null : c.gdp[i] * 1e6) },
      { id: "gdppc", label: "GDP per person (US$)", unit: "US$", agg: "ratio", get: (c, i) => (c.gdp[i] == null || !c.pop[i] ? null : (c.gdp[i] * 1e6) / c.pop[i]) },
    ];
    for (const d of datasets()) {
      const byCode = new Map();
      for (const [name, vals] of Object.entries(d.series)) { const c = findCountry(name); if (c) byCode.set(c.code, vals); }
      base.push({ id: d.id, label: d.title || "Imported data", unit: d.unit || "", agg: d.agg || "mean", imported: d, get: (c, i) => byCode.get(c.code)?.[years[i]] ?? null });
    }
    return base;
  }
  function regionValue(m, pool, i) {
    const cs = ECON.countries.filter((c) => pool === "global" || c.pool === pool);
    if (m.agg === "ratio") {
      let g = 0, p = 0;
      for (const c of cs) if (c.gdp[i] != null && c.pop[i]) { g += c.gdp[i] * 1e6; p += c.pop[i]; }
      return p ? g / p : null;
    }
    const vals = cs.map((c) => m.get(c, i)).filter((v) => v != null);
    if (!vals.length) return null;
    const sum = vals.reduce((a, b) => a + b, 0);
    return m.agg === "sum" ? sum : sum / vals.length;
  }
  const lastYearWith = (m) => {
    for (let i = years.length - 1; i >= 0; i--) if (ECON.countries.some((c) => m.get(c, i) != null)) return years[i];
    return years[years.length - 1];
  };

  function fmt(v, unit) {
    if (v == null || isNaN(v)) return "—";
    const money = unit === "US$";
    const a = Math.abs(v);
    const s = a >= 1e12 ? `${+(v / 1e12).toFixed(2)} trillion` : a >= 1e9 ? `${+(v / 1e9).toFixed(2)} billion` : a >= 1e6 ? `${+(v / 1e6).toFixed(1)} million`
      : a >= 1000 ? Math.round(v).toLocaleString() : +v.toFixed(2) + "";
    return money ? `$${s}` : unit && unit !== "people" ? `${s} ${unit}` : s;
  }
  WOW.economy = { fmt, findCountry, years, latest: (code) => {
    const c = ECON.countries.find((x) => x.code === code) || ECON.aggregates.find((x) => x.code === code);
    if (!c) return null;
    const last = (arr) => { for (let i = arr.length - 1; i >= 0; i--) if (arr[i] != null) return [years[i], arr[i]]; return null; };
    return { pop: last(c.pop), gdp: last(c.gdp) };
  }, byModern: (id) => ECON.countries.find((c) => c.modern === id) };

  // ---- CSV import ---------------------------------------------------------------
  function parseCSV(text) {
    const rows = [];
    let row = [], cell = "", q = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (q) { if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; } else if (ch === '"') q = false; else cell += ch; }
      else if (ch === '"') q = true;
      else if (ch === ",") { row.push(cell); cell = ""; }
      else if (ch === "\n" || ch === "\r") { if (ch === "\r" && text[i + 1] === "\n") i++; row.push(cell); rows.push(row); row = []; cell = ""; }
      else cell += ch;
    }
    if (cell || row.length) { row.push(cell); rows.push(row); }
    return rows.filter((r) => r.some((c) => c.trim()));
  }
  // Works with UNdata exports ("Country or Area","Year","Value"), UN WPP ("Location","Time"…),
  // World Bank long format and similar tables.
  function guessColumns(header) {
    const find = (re) => header.findIndex((x) => re.test(x));
    const country = find(/^(country|country or area|country\/area|area|location|region, subregion, country or area|entity|country name)/i);
    const year = find(/^(year|time|date|period)/i);
    let value = find(/^value$/i);
    if (value < 0) value = header.length - 1;
    return { country: country < 0 ? 0 : country, year: year < 0 ? 1 : year, value };
  }

  function importer(rerender) {
    const file = h("input", { type: "file", accept: ".csv,text/csv" });
    const box = h("div.stack");
    file.addEventListener("change", async () => {
      const f = file.files[0];
      if (!f) return;
      const rows = parseCSV(await f.text());
      if (rows.length < 2) { box.replaceChildren(h("p.small", "That file has no rows.")); return; }
      const header = rows[0].map((x) => x.trim());
      const g = guessColumns(header);
      const pick = (sel) => h("select", { style: { width: "auto" } }, header.map((x, i) => h("option", { value: i, selected: i === sel || null }, x || `Column ${i + 1}`)));
      const cSel = pick(g.country), ySel = pick(g.year), vSel = pick(g.value);
      const title = h("input", { type: "text", value: f.name.replace(/\.csv$/i, "") });
      const unit = h("input", { type: "text", placeholder: "e.g. years, %, index 0–1, US$" });
      const agg = h("select", { style: { width: "auto" } }, h("option", { value: "mean" }, "Average countries (rates, indexes, ages)"), h("option", { value: "sum" }, "Add countries up (counts, money, people)"));
      const link = h("input", { type: "text", placeholder: "Where it came from, e.g. https://data.un.org/…" });
      const preview = h("p.small.muted");
      const read = () => {
        const ci = +cSel.value, yIdx = +ySel.value, vi = +vSel.value;
        const series = {}, unmatched = new Set();
        let n = 0;
        for (const r of rows.slice(1)) {
          const name = (r[ci] || "").trim(), y = parseInt(r[yIdx], 10), v = parseFloat(String(r[vi] || "").replace(/[, ]/g, ""));
          if (!name || isNaN(y) || isNaN(v)) continue;
          (series[name] ||= {})[y] = v;
          n++;
          if (!findCountry(name)) unmatched.add(name);
        }
        return { series, n, unmatched };
      };
      const update = () => {
        const { series, n, unmatched } = read();
        preview.textContent = `${n} values for ${Object.keys(series).length} places. ${unmatched.size ? `Not matched to a country (kept, but not on the map): ${[...unmatched].slice(0, 12).join(", ")}${unmatched.size > 12 ? "…" : ""}` : "Every place matched."}`;
      };
      [cSel, ySel, vSel].forEach((s) => s.addEventListener("change", update));
      update();
      box.replaceChildren(
        h("div.row", h("label.small", "Country column ", cSel), h("label.small", "Year column ", ySel), h("label.small", "Value column ", vSel)),
        h("label.small", "Name ", title), h("label.small", "Unit ", unit), h("label.small", "Across a region ", agg), h("label.small", "Source ", link),
        preview,
        h("button", { onclick: () => {
          const { series, n } = read();
          if (!n) return WOW.toast("No values found — check the columns.");
          store.create("research", { title: title.value || "Imported data", kind: "dataset", source: link.value || f.name, link: link.value, notes: `Imported from ${f.name}: ${n} values.`, tags: ["dataset", "economy"], series, unit: unit.value, agg: agg.value });
          WOW.toast("Imported — it's now a metric here and saved in your Research Pool");
          rerender();
        } }, "Import"));
    });
    return h("details.card", h("summary", "＋ Import UN data (CSV)"),
      h("div.stack", { style: { marginTop: "10px" } },
        h("p.small", "Download a table from ", h("a", { href: "https://data.un.org", target: "_blank", rel: "noopener" }, "UNdata"), ", the ",
          h("a", { href: "https://population.un.org/wpp/", target: "_blank", rel: "noopener" }, "UN World Population Prospects"), ", the ",
          h("a", { href: "https://unstats.un.org/unsd/amaapi/", target: "_blank", rel: "noopener" }, "UN National Accounts"), " or the ",
          h("a", { href: "https://hdr.undp.org/data-center", target: "_blank", rel: "noopener" }, "UNDP Human Development data"),
          " as CSV, then load it here. It becomes a metric on this page and is saved in your Research Pool, so backups carry it to the iPad."),
        file, box));
  }

  // ---- Page ----------------------------------------------------------------------
  V.economy = (params) => {
    const ms = metrics();
    const st = { metric: ms.find((m) => m.id === params.get("metric")) || ms[0], year: +params.get("year") || null, picks: ["WLD"], log: false, region: "", all: false };
    if (!st.year || yi(st.year) < 0) st.year = lastYearWith(st.metric);
    const rerender = () => { location.hash = `#/economy?metric=${st.metric.id}&year=${st.year}&r=${Date.now()}`; };

    const metricRow = h("div.chips"), yearOut = h("div.ta-year"), slider = h("input", { type: "range", min: years[0], max: years[years.length - 1], step: 1, style: { width: "100%" }, "aria-label": "Year" });
    const mapBox = h("div"), tableBox = h("div"), chartBox = h("div"), pickRow = h("div.chips");
    slider.addEventListener("input", () => { st.year = +slider.value; draw(); });

    const series = (code) => ECON.countries.find((c) => c.code === code) || ECON.aggregates.find((c) => c.code === code);
    const COLORS = ["#4B1F7A", "#C9A227", "#D14B3C", "#2F6FB0", "#1E8A6E", "#8E5BD0", "#7A5C2E"];

    function drawMetrics() {
      metricRow.replaceChildren(...ms.map((m) => h("button.chip" + (m === st.metric ? ".on" : ""), { type: "button", onclick: () => {
        st.metric = m;
        st.year = Math.min(st.year, lastYearWith(m));
        drawMetrics(); draw();
      } }, m.label + (m.imported ? " · imported" : ""))));
    }

    function drawMap() {
      const i = yi(st.year), m = st.metric;
      const tiles = WOW.timeAtlas.TILES;
      const vals = Object.fromEntries(Object.keys(tiles).map((p) => [p, p === "diasporas" ? null : regionValue(m, p, i)]));
      const max = Math.max(...Object.entries(vals).filter(([p, v]) => p !== "global" && v != null).map(([, v]) => v), 1);
      const root = svg("svg", { viewBox: "0 0 1000 500", class: "ta-map-svg", role: "img", "aria-label": `${m.label} by region in ${st.year}` });
      for (const [id, [cx, cy]] of Object.entries(tiles)) {
        const v = vals[id];
        const share = id === "global" || v == null ? 0 : v / max;
        const g = svg("g", { class: "ta-tile" + (st.region === id ? " on" : ""), tabindex: 0, role: "button" });
        const pickTile = () => { st.region = st.region === id ? "" : id; drawTable(); drawMap(); };
        g.addEventListener("click", pickTile);
        g.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pickTile(); } });
        g.appendChild(svg("rect", { x: cx * 100 + 4, y: cy * 100 + 4, width: 92, height: 92, rx: 12, fill: id === "global" ? "var(--violet-700)" : "#C9A227", "fill-opacity": id === "global" ? 0.9 : v == null ? 0.08 : 0.15 + share * 0.8,
          stroke: st.region === id ? "var(--violet-600)" : "var(--border)", "stroke-width": st.region === id ? 4 : 1 }));
        const name = id === "global" ? "World" : (REF.culturePools.find((p) => p.id === id)?.region || id).split(" (")[0];
        const words = name.split(/[ ,&]+/).filter(Boolean), lines = [];
        for (const w of words) { if (lines.length && (lines[lines.length - 1] + " " + w).length <= 13) lines[lines.length - 1] += " " + w; else lines.push(w); }
        lines.slice(0, 3).forEach((ln, k) => { const t = svg("text", { x: cx * 100 + 12, y: cy * 100 + 24 + k * 14, "font-size": 12, "font-weight": 600, fill: id === "global" || share > 0.6 ? "#fff" : "var(--text)" }); t.textContent = ln; g.appendChild(t); });
        const t = svg("text", { x: cx * 100 + 12, y: cy * 100 + 84, "font-size": 12, "font-weight": 700, fill: id === "global" || share > 0.6 ? "#fff" : "var(--text)" });
        t.textContent = id === "diasporas" ? "" : fmt(v, m.unit).replace(" trillion", "T").replace(" billion", "B").replace(" million", "M");
        g.appendChild(t);
        const tt = svg("title"); tt.textContent = `${name}: ${fmt(v, m.unit)}`; g.appendChild(tt);
        root.appendChild(g);
      }
      mapBox.replaceChildren(root);
    }

    function drawTable() {
      const i = yi(st.year), m = st.metric, i10 = yi(st.year - 10);
      const world = m.agg === "sum" ? regionValue(m, "global", i) : null;
      const rows = ECON.countries.filter((c) => !st.region || st.region === "global" || c.pool === st.region)
        .map((c) => ({ c, v: m.get(c, i), v10: i10 >= 0 ? m.get(c, i10) : null })).filter((r) => r.v != null).sort((a, b) => b.v - a.v);
      const shown = st.all ? rows : rows.slice(0, 25);
      tableBox.replaceChildren(
        h("div.row.spread", h("h3", { style: { margin: 0 } }, `${m.label}, ${st.year}${st.region ? " · " + (st.region === "global" ? "World" : REF.culturePools.find((p) => p.id === st.region)?.region) : ""}`),
          st.region ? h("button.ghost.small", { onclick: () => { st.region = ""; drawTable(); drawMap(); } }, "All regions") : null),
        rows.length ? h("table.small",
          h("tr", h("th", "#"), h("th", "Country"), h("th", m.label), world ? h("th", "Share of world") : null, h("th", "10 years earlier"), h("th", "")),
          shown.map((r, k) => h("tr",
            h("td.muted", k + 1),
            h("td", r.c.modern ? h("a", { href: `#/lore/modern`, title: "In Modern Cultures" }, r.c.name) : r.c.name),
            h("td", fmt(r.v, m.unit)),
            world ? h("td", `${((r.v / world) * 100).toFixed(1)}%`) : null,
            h("td.muted", r.v10 == null ? "—" : `${fmt(r.v10, m.unit)} (${r.v >= r.v10 ? "+" : ""}${(((r.v - r.v10) / Math.abs(r.v10)) * 100).toFixed(0)}%)`),
            h("td", h("button.ghost.small", { onclick: () => { if (!st.picks.includes(r.c.code)) st.picks = [...st.picks, r.c.code].slice(-6); drawChart(); } }, "＋ chart")))))
          : h("p.small.muted", "No values for this year."),
        rows.length > 25 ? h("button.ghost.small", { onclick: () => { st.all = !st.all; drawTable(); } }, st.all ? "Show top 25" : `Show all ${rows.length}`) : null);
    }

    function drawChart() {
      const m = st.metric, W = 1000, H = 320, P = 48;
      const lines = st.picks.map((code) => series(code)).filter(Boolean).map((c) => ({ c, pts: years.map((y, i) => [y, m.get(c, i)]).filter(([, v]) => v != null) }));
      const all = lines.flatMap((l) => l.pts.map(([, v]) => v)).filter((v) => !st.log || v > 0);
      const root = svg("svg", { viewBox: `0 0 ${W} ${H}`, class: "ta-line-svg", style: { minWidth: "0", cursor: "default" }, role: "img", "aria-label": `${m.label} over time` });
      if (all.length) {
        const lo = st.log ? Math.min(...all) : Math.min(0, ...all), hi = Math.max(...all);
        const Y = (v) => { const f = st.log ? (Math.log10(v) - Math.log10(lo)) / (Math.log10(hi) - Math.log10(lo) || 1) : (v - lo) / (hi - lo || 1); return H - P - f * (H - 2 * P); };
        const X = (y) => P + ((y - years[0]) / (years[years.length - 1] - years[0])) * (W - 2 * P);
        for (let y = 1960; y <= years[years.length - 1]; y += 10) {
          root.appendChild(svg("line", { x1: X(y), x2: X(y), y1: P / 2, y2: H - P, stroke: "var(--border)" }));
          const t = svg("text", { x: X(y), y: H - P + 16, "font-size": 12, "text-anchor": "middle", fill: "var(--muted)" }); t.textContent = y; root.appendChild(t);
        }
        for (const f of [0, 0.5, 1]) {
          const v = st.log ? Math.pow(10, Math.log10(lo) + f * (Math.log10(hi) - Math.log10(lo))) : lo + f * (hi - lo);
          const t = svg("text", { x: 4, y: Y(v) + 4, "font-size": 11, fill: "var(--muted)" }); t.textContent = fmt(v, m.unit).replace(" trillion", "T").replace(" billion", "B").replace(" million", "M"); root.appendChild(t);
        }
        lines.forEach((l, k) => {
          const pts = l.pts.filter(([, v]) => !st.log || v > 0);
          if (pts.length > 1) root.appendChild(svg("polyline", { points: pts.map(([y, v]) => `${X(y)},${Y(v)}`).join(" "), fill: "none", stroke: COLORS[k % COLORS.length], "stroke-width": 3, "stroke-linejoin": "round" }));
        });
        root.appendChild(svg("line", { x1: X(st.year), x2: X(st.year), y1: P / 2, y2: H - P, stroke: "var(--gold-500)", "stroke-width": 2, "stroke-dasharray": "5 4" }));
      }
      pickRow.replaceChildren(...lines.map((l, k) => h("span.chip", { style: { borderColor: COLORS[k % COLORS.length] } }, h("span", { style: { color: COLORS[k % COLORS.length], fontWeight: 700 } }, "● "), l.c.name,
        h("button", { type: "button", "aria-label": "Remove", onclick: () => { st.picks = st.picks.filter((x) => x !== l.c.code); drawChart(); } }, "×"))),
        h("select", { style: { width: "auto" }, onchange: (e) => { if (e.target.value) { st.picks = [...st.picks, e.target.value].slice(-6); drawChart(); } } },
          h("option", { value: "" }, "＋ Add to chart…"),
          h("optgroup", { label: "World, regions & income groups" }, ECON.aggregates.map((a) => h("option", { value: a.code }, a.name))),
          h("optgroup", { label: "Countries" }, ECON.countries.map((c) => h("option", { value: c.code }, c.name)))),
        h("label.small", h("input", { type: "checkbox", checked: st.log || null, onchange: (e) => { st.log = e.target.checked; drawChart(); } }), " Log scale"));
      chartBox.replaceChildren(root);
    }

    function draw() {
      slider.value = st.year;
      yearOut.textContent = String(st.year);
      drawMap(); drawTable(); drawChart();
    }
    drawMetrics();
    draw();

    const imported = datasets();
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Research"), h("h1", "World economy"),
        h("p.muted", `Population and GDP for ${ECON.countries.length} countries and territories from ${years[0]} to today, by region and over time — and any UN dataset you import. Use it to ground your world's wealth, poverty, growth and collapse in real proportions.`)),
        h("a.btn.ghost", { href: `#/timeatlas?year=${st.year}&scale=now` }, "🕰️ This year on the Time Atlas")),
      h("div.card.stack", metricRow, h("div", h("div.tiny.muted", "Year"), yearOut), slider),
      h("div.two-col", h("div.card", h("h3", "By region"), h("p.tiny.muted", "Gold deepens with the region's total; tap a region to rank its countries."), mapBox), h("div.card", h("h3", "Over time"), pickRow, chartBox)),
      h("div.card", tableBox),
      importer(rerender),
      imported.length ? h("div.card", h("h3", "Your imported datasets"), h("div.chips", imported.map((d) => h("a.chip.gold", { href: `#/research/${d.id}` }, d.title || "Dataset")))) : null,
      h("div.card.stack", h("h3", "Sources & care"),
        h("ul.small", ECON.sources.map((s) => h("li", h("strong", s.name), ` — ${s.by}. `, h("a", { href: s.url, target: "_blank", rel: "noopener" }, "Source"), `; bundled via ${s.via}.`))),
        h("p.small.muted", "GDP is in current US dollars: not adjusted for inflation or for what money buys locally, so it understates poorer countries' living standards and makes the past look smaller than it was. It also counts only market activity — not care work, subsistence farming or what is extracted from a place by others. Regions follow this app's culture regions, not the UN's. Before 1960 there is no comparable UN series; for deep history, see the Time Atlas.")));
  };
})(window.WOW);
