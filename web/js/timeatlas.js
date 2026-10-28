// Time Atlas: real history and Earth's history on one scalable timeline, with a
// world map of regions showing what was happening where in any chosen year.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, svg, store, views: V } = WOW;
  const L = WOW.lore;

  const CATS = [
    { id: "catastrophes", label: "Catastrophes & Earth", color: "#2F6FB0" },
    { id: "colonialism", label: "Empires & colonialism", color: "#C9A227" },
    { id: "atrocities", label: "Genocides & atrocities", color: "#7A1F2B" },
    { id: "wars", label: "Wars", color: "#D14B3C" },
    { id: "rivalryLore", label: "Rivalries", color: "#8E5BD0" },
    { id: "mythHistory", label: "History & myth", color: "#1E8A6E" },
    { id: "villains", label: "Perpetrators & groups", color: "#3A3A3A" },
    { id: "stewards", label: "Land stewards", color: "#7A5C2E" },
    { id: "mine", label: "Your conflicts & powers", color: "#6C3DB0" },
  ];
  const SCALES = [
    { id: "earth", label: "Earth · 4.5 billion years", lo: -4.6e9, log: true },
    { id: "life", label: "Complex life · 540 million years", lo: -5.4e8, log: true },
    { id: "human", label: "Humankind · 300,000 years", lo: -3e5, log: true },
    { id: "recorded", label: "Recorded history · 5,500 years", lo: -3500 },
    { id: "modern", label: "Last 500 years", lo: 1500 },
    { id: "now", label: "1900 – today", lo: 1900 },
  ];
  // Regions laid out roughly where they sit on the globe (column, row).
  const TILES = {
    global: [0, 0], arctic: [4, 0],
    "indigenous-americas": [1, 1], "african-america": [2, 1], europe: [5, 1], caucasus: [6, 1], "central-asia": [7, 1], himalaya: [8, 1], "east-asia": [9, 1],
    "caribbean-diaspora": [2, 2], "north-africa": [5, 2], "persia-middle-east": [6, 2], "south-asia": [7, 2], "southeast-asia": [8, 2],
    "latin-america": [1, 3], "afro-latin": [2, 3], "west-africa": [4, 3], "east-africa": [6, 3], pacific: [9, 3],
    diasporas: [0, 4], "southern-africa": [5, 4], "indian-ocean": [7, 4],
  };
  const NOW = L.NOW;
  WOW.timeAtlas = { TILES };
  const num = (v) => (v === "" || v == null || isNaN(Number(v)) ? null : Number(v));
  const regionName = (id) => (id === "global" ? "Global / whole Earth" : REF.culturePools.find((p) => p.id === id)?.region || id);

  // Scale maths: linear for recent history, log of "years ago" for deep time.
  function axis(sc) {
    if (!sc.log) return { x: (y) => (y - sc.lo) / (NOW - sc.lo), y: (x) => sc.lo + x * (NOW - sc.lo) };
    const L10 = Math.log10(NOW - sc.lo);
    return { x: (y) => 1 - Math.log10(Math.max(NOW - y, 1)) / L10, y: (x) => NOW - Math.pow(10, (1 - x) * L10) };
  }
  function ticks(sc) {
    if (sc.log) {
      return [4e9, 1e9, 5e8, 1e8, 1e7, 1e6, 1e5, 3e4, 1e4, 3000, 1000, 300, 100, 30, 10].filter((a) => a < NOW - sc.lo)
        .map((a) => [NOW - a, a >= 1e9 ? `${a / 1e9} bn ya` : a >= 1e6 ? `${a / 1e6} m ya` : a >= 1e4 ? `${a / 1e3}k ya` : `${a} ya`]);
    }
    const span = NOW - sc.lo;
    const step = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000].find((s) => span / s <= 10) || 5000;
    const out = [];
    for (let y = Math.ceil(sc.lo / step) * step; y <= NOW; y += step) out.push([y, y < 0 ? `${-y} BCE` : `${y}`]);
    return out;
  }

  function allItems() {
    const out = [];
    for (const c of CATS) {
      if (c.id === "mine" || c.id === "stewards") continue;
      for (const it of L.flat(c.id)) {
        if (it.start == null) continue;
        out.push({ cat: c.id, id: it.id, name: it.name, start: it.start, end: it.ongoing ? NOW : it.end ?? null, ongoing: !!it.ongoing, pools: L.poolsOf(it), note: it.note, meta: it.meta, lore: it });
      }
    }
    for (const l of REF.lands) for (const [i, s] of l.stewards.entries()) {
      out.push({ cat: "stewards", id: `${l.id}#${i}`, name: `${s.name} · ${l.name.split(" (")[0]}`, start: s.start, end: s.ongoing ? NOW : s.end ?? null, ongoing: !!s.ongoing, pools: l.pools, note: s.note, meta: l.name, href: `#/lands/${encodeURIComponent(l.id)}` });
    }
    for (const e of store.list("conflicts")) {
      const s = num(e.start);
      if (s == null) continue;
      out.push({ cat: "mine", id: e.id, name: e.name || "Untitled conflict", start: s, end: num(e.end) ?? (e.status === "ongoing" ? NOW : null), pools: e.cultures || [], note: e.stakes || e.cause || "", meta: e.kind || "", href: `#/conflicts/${e.id}` });
    }
    for (const f of store.list("factions")) {
      const s = num(f.founded);
      if (s == null) continue;
      out.push({ cat: "mine", id: f.id, name: f.name || "Untitled faction", start: s, end: num(f.dissolved) ?? NOW, pools: f.cultures || [], note: f.goals || "", meta: f.kind || "", href: `#/factions/${f.id}` });
    }
    return out;
  }
  const spanText = (it) => (it.end != null && it.end !== it.start ? `${L.fmtYear(it.start)} – ${it.ongoing ? "today" : L.fmtYear(it.end)}` : L.fmtYear(it.start));

  V.timeatlas = (params) => {
    const st = {
      scale: SCALES.find((s) => s.id === params.get("scale")) || null,
      year: num(params.get("year")) ?? NOW,
      cats: new Set(CATS.map((c) => c.id).filter((c) => c !== "stewards" && c !== "villains")),
      region: "", q: "", selected: params.get("focus") || "",
    };
    // Pick the narrowest scale that holds the requested year.
    if (!st.scale) st.scale = [...SCALES].reverse().find((s) => s.lo <= st.year) || SCALES[0];
    const items = allItems();

    const yearOut = h("div.ta-year");
    const slider = h("input", { type: "range", min: 0, max: 1000, step: 1, style: { width: "100%" }, "aria-label": "Year",
      oninput: (e) => { st.year = Math.round(axis(st.scale).y(Number(e.target.value) / 1000)); draw(false); } });
    const mapBox = h("div.ta-map");
    const activeBox = h("div.ta-active");
    const lineBox = h("div.ta-line");
    const detail = h("div");
    const scaleRow = h("div.chips");
    const catRow = h("div.chips");
    const search = h("input", { type: "search", placeholder: "Find an event…", style: { maxWidth: "240px" }, oninput: (e) => { st.q = e.target.value.toLowerCase(); draw(true); } });

    const visible = () => items.filter((it) => st.cats.has(it.cat) && (!st.q || it.name.toLowerCase().includes(st.q)));
    const tolerance = () => (st.scale.log ? Math.max(1, (NOW - st.year) * 0.03) : (NOW - st.scale.lo) * 0.006);
    const activeAt = (it) => {
      const tol = it.end == null || it.end === it.start ? tolerance() : 0;
      return st.year >= it.start - tol && st.year <= (it.end ?? it.start) + tol;
    };
    const color = (cat) => CATS.find((c) => c.id === cat).color;

    function drawControls() {
      scaleRow.replaceChildren(...SCALES.map((s) => h("button.chip" + (s === st.scale ? ".on" : ""), { type: "button", onclick: () => {
        st.scale = s;
        if (st.year < s.lo) st.year = s.lo;
        draw(true);
      } }, s.label)));
      catRow.replaceChildren(...CATS.map((c) => h("button.chip" + (st.cats.has(c.id) ? ".on" : ""), { type: "button", style: st.cats.has(c.id) ? { background: c.color, borderColor: c.color, color: "#fff" } : { borderColor: c.color }, onclick: () => {
        st.cats.has(c.id) ? st.cats.delete(c.id) : st.cats.add(c.id);
        draw(true);
      } }, c.label)));
    }

    function drawMap(active) {
      const byRegion = new Map(Object.keys(TILES).map((k) => [k, []]));
      for (const it of active) for (const p of it.pools.length ? it.pools : ["global"]) byRegion.get(p)?.push(it);
      const W = 1000, CW = 100, CH = 100;
      const root = svg("svg", { viewBox: `0 0 ${W} ${CH * 5}`, class: "ta-map-svg", role: "img", "aria-label": `World at ${L.fmtYear(st.year)}` });
      for (const [id, [cx, cy]] of Object.entries(TILES)) {
        const list = byRegion.get(id);
        const counts = CATS.map((c) => [c, list.filter((x) => x.cat === c.id).length]).filter(([, n]) => n);
        const top = counts.sort((a, b) => b[1] - a[1])[0];
        const g = svg("g", { class: "ta-tile" + (st.region === id ? " on" : ""), tabindex: 0, role: "button", "aria-label": `${regionName(id)}: ${list.length} active` });
        g.addEventListener("click", () => { st.region = st.region === id ? "" : id; draw(false); });
        g.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); st.region = st.region === id ? "" : id; draw(false); } });
        g.appendChild(svg("rect", { x: cx * CW + 4, y: cy * CH + 4, width: CW - 8, height: CH - 8, rx: 12,
          fill: top ? top[0].color : "var(--surface-2)", "fill-opacity": top ? Math.min(0.25 + list.length * 0.12, 0.9) : 1,
          stroke: st.region === id ? "var(--gold-500)" : "var(--border)", "stroke-width": st.region === id ? 4 : 1 }));
        const words = regionName(id).replace(/\(.*\)/, "").split(/[ ,&]+/).filter(Boolean);
        const lines = [];
        for (const w of words) { if (lines.length && (lines[lines.length - 1] + " " + w).length <= 13) lines[lines.length - 1] += " " + w; else lines.push(w); }
        lines.slice(0, 3).forEach((ln, i) => {
          const t = svg("text", { x: cx * CW + 12, y: cy * CH + 24 + i * 14, "font-size": 12, "font-weight": 600, fill: top && list.length > 2 ? "#fff" : "var(--text)" });
          t.textContent = ln;
          g.appendChild(t);
        });
        counts.slice(0, 4).forEach(([c, n], i) => {
          g.appendChild(svg("circle", { cx: cx * CW + 18 + i * 22, cy: cy * CH + 80, r: 8, fill: c.color, stroke: "#fff", "stroke-width": 1.5 }));
          const t = svg("text", { x: cx * CW + 18 + i * 22, y: cy * CH + 84, "font-size": 10, "font-weight": 700, "text-anchor": "middle", fill: "#fff" });
          t.textContent = n > 9 ? "9+" : n;
          g.appendChild(t);
        });
        const title = svg("title");
        title.textContent = `${regionName(id)} — ${list.length ? list.map((x) => x.name).join(", ") : "nothing recorded"}`;
        g.appendChild(title);
        root.appendChild(g);
      }
      mapBox.replaceChildren(root);
    }

    function econLine() {
      if (!WOW.economy || st.year < WOW.economy.years[0]) return null;
      const y = Math.min(Math.round(st.year), WOW.economy.years[WOW.economy.years.length - 1]);
      const w = window.WOW_ECON.aggregates.find((a) => a.code === "WLD"), i = WOW.economy.years.indexOf(y);
      if (i < 0) return null;
      return h("div.small", { style: { marginBottom: "6px" } }, h("strong", `World economy, ${y}: `), `${WOW.economy.fmt(w.pop[i], "people")} people`,
        w.gdp[i] != null ? ` · GDP ${WOW.economy.fmt(w.gdp[i] * 1e6, "US$")}` : "", " · ", h("a", { href: `#/economy?year=${y}` }, "explore →"));
    }

    function drawActive(active) {
      const list = st.region ? active.filter((it) => (it.pools.length ? it.pools : ["global"]).includes(st.region)) : active;
      activeBox.replaceChildren(
        econLine(),
        h("h3", st.region ? `${regionName(st.region)} in ${L.fmtYear(st.year)}` : `The world in ${L.fmtYear(st.year)}`,
          st.region ? h("button.ghost.small", { style: { marginLeft: "8px" }, onclick: () => { st.region = ""; draw(false); } }, "All regions") : null),
        list.length
          ? h("div.stack", { style: { gap: "4px" } }, CATS.map((c) => {
            const xs = list.filter((x) => x.cat === c.id);
            return xs.length ? h("div", h("div.tiny", { style: { color: c.color, fontWeight: 700, textTransform: "uppercase", letterSpacing: ".06em" } }, c.label),
              xs.slice(0, 25).map((x) => h("button.ta-item", { type: "button", onclick: () => { st.selected = x.id; drawDetail(); detail.scrollIntoView({ behavior: "smooth", block: "nearest" }); } },
                h("span", x.name), h("span.tiny.muted", " " + spanText(x)))),
              xs.length > 25 ? h("div.tiny.muted", `+${xs.length - 25} more`) : null) : null;
          }))
          : h("p.small.muted", "Nothing recorded here at this moment in the reference library — a gap to research, or room for your own story."));
    }

    function drawLine(vis) {
      const ax = axis(st.scale), W = 1000, ROW = 18, LANE_HEAD = 20;
      const inRange = vis.filter((it) => (it.end ?? it.start) >= st.scale.lo);
      let y = 26;
      const root = svg("svg", { class: "ta-line-svg", width: "100%" });
      const g = svg("g");
      for (const c of CATS) {
        if (!st.cats.has(c.id)) continue;
        const xs = inRange.filter((it) => it.cat === c.id).sort((a, b) => a.start - b.start);
        const head = svg("text", { x: 4, y: y + 13, "font-size": 12, "font-weight": 700, fill: c.color });
        head.textContent = `${c.label} (${xs.length})`;
        const headRef = head;
        g.appendChild(head);
        y += LANE_HEAD;
        if (c.id === "stewards") { y = drawLands(g, xs, y, ax, W, c.color); continue; }
        const rows = [];
        let hidden = 0;
        for (const it of xs) {
          const x1 = Math.max(0, ax.x(it.start) * W), x2 = Math.min(W, ax.x(it.end ?? it.start) * W);
          const bw = Math.max(4, x2 - x1);
          const labelW = it.name.length * 6.4 + 8;
          const inside = bw > labelW;
          const end = inside ? x1 + bw : x1 + bw + labelW;
          // Prefer a row with room for the name; when rows run out, fit the bar alone (name on hover).
          let showLabel = true;
          let r = rows.findIndex((last) => last + 4 < x1);
          if (r < 0 && rows.length < 60) { rows.push(0); r = rows.length - 1; }
          if (r < 0) { showLabel = inside; r = rows.findIndex((last) => last + 2 < x1); }
          if (r < 0) { hidden++; continue; }
          rows[r] = showLabel ? end : x1 + bw;
          const by = y + r * ROW;
          const bar = svg("g", { class: "ta-bar" + (it.id === st.selected ? " on" : ""), tabindex: 0, role: "button", "aria-label": `${it.name}, ${spanText(it)}` });
          const pick = () => { st.selected = it.id; drawDetail(); drawLine(visible()); };
          bar.addEventListener("click", (e) => { e.stopPropagation(); pick(); });
          bar.addEventListener("keydown", (e) => { if (e.key === "Enter") pick(); });
          bar.appendChild(svg("rect", { x: x1, y: by, width: bw, height: ROW - 4, rx: 3, fill: c.color, opacity: it.cat === "mine" ? 0.85 : 0.75 }));
          if (showLabel) {
            const t = svg("text", { x: inside ? x1 + 4 : x1 + bw + 4, y: by + 11, "font-size": 11, fill: inside ? "#fff" : "var(--text)" });
            t.textContent = it.name;
            bar.appendChild(t);
          }
          const tt = svg("title");
          tt.textContent = `${it.name} · ${spanText(it)}${it.note ? " — " + it.note : ""}`;
          bar.appendChild(tt);
          g.appendChild(bar);
        }
        if (hidden) headRef.textContent += ` — ${hidden} more don't fit; zoom to a narrower scale or search`;
        y += Math.max(1, rows.length) * ROW + 8;
      }
      const H = y + 10;
      root.setAttribute("viewBox", `0 0 ${W} ${H}`);
      root.appendChild(svg("rect", { x: 0, y: 0, width: W, height: H, fill: "transparent" }));
      for (const [ty, label] of ticks(st.scale)) {
        const x = ax.x(ty) * W;
        root.appendChild(svg("line", { x1: x, x2: x, y1: 16, y2: H, stroke: "var(--border)", "stroke-width": 1 }));
        const t = svg("text", { x: x + 3, y: 12, "font-size": 11, fill: "var(--muted)" });
        t.textContent = label;
        root.appendChild(t);
      }
      root.appendChild(g);
      const cx = ax.x(st.year) * W;
      root.appendChild(svg("line", { x1: cx, x2: cx, y1: 0, y2: H, stroke: "var(--gold-500)", "stroke-width": 3 }));
      // Click empty space to move the year there.
      root.addEventListener("click", (e) => {
        const r = root.getBoundingClientRect();
        st.year = Math.round(ax.y(Math.min(1, Math.max(0, (e.clientX - r.left) / r.width))));
        draw(false);
      });
      lineBox.replaceChildren(root);
    }

    // Stewards: one row per land; stewards that overlap in time share the row in two halves.
    function drawLands(g, xs, y, ax, W, color) {
      const ROW = 22;
      const lands = [...new Set(xs.map((it) => it.meta))];
      for (const land of lands) {
        const ends = [-Infinity, -Infinity];
        for (const it of xs.filter((x) => x.meta === land)) {
          const x1 = Math.max(0, ax.x(it.start) * W), x2 = Math.min(W, ax.x(it.end ?? it.start) * W);
          const half = ends[0] <= x1 + 1 ? 0 : ends[1] <= x1 + 1 ? 1 : ends[0] <= ends[1] ? 0 : 1;
          ends[half] = x2;
          const bar = svg("g", { class: "ta-bar" + (it.id === st.selected ? " on" : ""), tabindex: 0, role: "button", "aria-label": `${it.name}, ${spanText(it)}` });
          const pick = () => { st.selected = it.id; drawDetail(); drawLine(visible()); };
          bar.addEventListener("click", (e) => { e.stopPropagation(); pick(); });
          bar.addEventListener("keydown", (e) => { if (e.key === "Enter") pick(); });
          bar.appendChild(svg("rect", { x: x1, y: y + half * 9, width: Math.max(4, x2 - x1), height: 8, rx: 2, fill: it.ongoing ? "#C9A227" : color, opacity: 0.85, stroke: "var(--surface)", "stroke-width": 1 }));
          const tt = svg("title");
          tt.textContent = `${it.name} · ${spanText(it)}${it.note ? " — " + it.note : ""}`;
          bar.appendChild(tt);
          g.appendChild(bar);
        }
        const t = svg("text", { x: 4, y: y + 15, "font-size": 10, fill: "var(--text)", stroke: "var(--surface)", "stroke-width": 3, "paint-order": "stroke", "pointer-events": "none" });
        t.textContent = land.split(" (")[0];
        g.appendChild(t);
        y += ROW;
      }
      return y + 8;
    }

    function drawDetail() {
      const it = items.find((x) => x.id === st.selected);
      if (!it) { detail.replaceChildren(); return; }
      const cat = CATS.find((c) => c.id === it.cat);
      const src = L.SOURCES.find((s) => s.id === it.cat);
      detail.replaceChildren(h("div.card.stack", { style: { borderLeft: `5px solid ${cat.color}` } },
        h("div.row.spread", h("div", h("div.eyebrow", { style: { color: cat.color } }, cat.label), h("h2", { style: { margin: 0 } }, it.name)),
          h("button.ghost.small", { onclick: () => { st.selected = ""; drawDetail(); drawLine(visible()); } }, "Close")),
        h("div.small", h("strong", spanText(it)), it.meta ? " · " + it.meta : ""),
        it.note ? h("p", { style: { margin: 0 } }, it.note) : null,
        src?.care ? h("div.warn", h("strong", "Care: "), src.care) : null,
        it.pools.length ? h("div.chips", it.pools.map((p) => h("a.chip", { href: `#/atlas/${p}` }, regionName(p)))) : null,
        h("div.row",
          h("button.ghost.small", { onclick: () => { st.year = it.start; draw(true); } }, "Jump to its start"),
          it.href ? h("a.btn.small", { href: it.href }, it.cat === "stewards" ? "See the land's stewards" : "Open") : null,
          it.lore ? L.starts(it.cat, it.lore).map(([col, label, fields]) => h("button.ghost.small", { onclick: () => { const made = store.create(col, fields); location.hash = `#/${col}/${made.id}`; } }, label)) : null,
          it.lore ? h("button.ghost.small", { onclick: () => L.toResearch(it.cat, it.lore) }, "🔖 Research") : null,
          it.lore ? h("a.btn.ghost.small", { href: `#/lore/${it.cat}` }, "In the library →") : null)));
    }

    function draw(full) {
      const ax = axis(st.scale);
      st.year = Math.min(NOW, Math.max(st.scale.lo, st.year));
      slider.value = Math.round(ax.x(st.year) * 1000);
      yearOut.textContent = L.fmtYear(st.year) + (st.year === NOW ? " · today" : "");
      const vis = visible();
      const active = vis.filter(activeAt);
      drawMap(active);
      drawActive(active);
      drawLine(vis);
      if (full) drawControls();
    }

    draw(true);
    drawDetail();
    const mine = items.filter((x) => x.cat === "mine").length;
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Research"), h("h1", "Time Atlas"),
        h("p.muted", "Earth's history and humanity's on one scalable timeline: empires and colonial powers past and present, genocides and atrocities, long catastrophes, wars, rivalries and legends. Move through time and the world map shows what was happening where."))),
      h("div.warn", h("strong", "Care: "), "These are real people's histories, many still unfolding. Where recognition of a genocide is contested, the entry says who recognises it. Dates are approximate and some regions are far better documented than others — gaps are a prompt to research, not a sign that nothing happened."),
      h("div.card.stack",
        scaleRow,
        h("div.row.spread", { style: { alignItems: "end" } }, h("div", h("div.tiny.muted", "Year"), yearOut), search),
        slider,
        catRow,
        mine ? h("div.tiny.muted", `${mine} of your conflicts and factions sit on this scale using their own start and end years, read as real years.`)
          : h("div.tiny.muted", "Give your conflicts a start and end, or your factions a founding year, to see them here.")),
      detail,
      h("div.two-col", h("div.card", h("h3", "World map at this moment"), h("p.tiny.muted", "Tap a region to list what was happening there. Colour shows the most common kind of event; dots count each kind."), mapBox), h("div.card", activeBox)),
      h("div.card", h("h3", "Timeline"), h("p.tiny.muted", "Tap a bar for details, or tap empty space to move the year there."), lineBox));
  };
})(window.WOW);
