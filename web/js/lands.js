// Lands & stewards: who has lived on, cared for and ruled each land across time.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, svg, store, views: V } = WOW;
  const L = WOW.lore;
  const NOW = L.NOW;
  const regionName = (id) => REF.culturePools.find((p) => p.id === id)?.region || id;
  const spanOf = (s) => (s.ongoing ? `${L.fmtYear(s.start)} – today` : s.end != null ? `${L.fmtYear(s.start)} – ${L.fmtYear(s.end)}` : L.fmtYear(s.start));

  // Words that identify a land in other entries: "Palestine / the Land of Israel" → Palestin, Israe.
  const SKIP = new Set(["Land", "Valley", "Islands", "Island", "Plain", "Highlands", "Central", "Great", "Black", "Hills", "Kingdom"]);
  const keywords = (land) => [...new Set(land.name.split(/[\s/&(),]+/).filter((w) => /^[A-ZĀ-Ż]/.test(w) && w.length >= 4 && !SKIP.has(w)).map((w) => w.slice(0, Math.max(4, w.length - 1))))];
  function related(land) {
    const keys = keywords(land);
    const out = [];
    for (const s of L.SOURCES) {
      if (s.id === "animals" || s.id === "creatures") continue;
      const xs = L.flat(s.id).filter((it) => keys.some((k) => `${it.group.name} ${it.name} ${it.meta} ${it.note}`.includes(k)));
      if (xs.length) out.push([s, xs]);
    }
    return out;
  }
  const placesOn = (land) => store.list("places").filter((p) => (p.realLand || []).includes(land.id));

  V.lands = () => {
    const q = h("input", { type: "search", placeholder: "Filter lands and stewards…", style: { maxWidth: "320px" } });
    const list = h("div.stack");
    const draw = () => {
      const t = q.value.toLowerCase();
      const pools = [...new Set(REF.lands.map((l) => l.pools[0]))];
      list.replaceChildren(...pools.map((p) => {
        const ls = REF.lands.filter((l) => l.pools[0] === p && (!t || `${l.name} ${l.stewards.map((s) => s.name).join(" ")}`.toLowerCase().includes(t)));
        return ls.length ? h("div.stack", h("h2", regionName(p)), h("div.grid.wide", ls.map((l) => h("a.card.link" + (placesOn(l).length ? ".accent" : ""), { href: `#/lands/${encodeURIComponent(l.id)}` },
          h("h3", l.name), h("div.tiny.muted", `${l.stewards.length} stewards · from ${L.fmtYear(Math.min(...l.stewards.map((s) => s.start)))}`),
          h("p.snippet", { style: { marginTop: "6px" } }, l.stewards.map((s) => s.name).join(" → ")))))) : null;
      }));
    };
    q.addEventListener("input", draw);
    draw();
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Research"), h("h1", "Lands & stewards"),
        h("p.muted", `${REF.lands.length} lands traced through the peoples who lived on them, cared for them and ruled them — from Indigenous custodians tens of thousands of years ago to today's states. Gold edges mark lands your places draw on.`)),
        h("a.btn.ghost", { href: "#/timeatlas" }, "🕰️ Time Atlas")),
      h("div.warn.info", "Stewardship is more than rule: many peoples cared for land long before, under and after the powers that claimed it. Overlapping bars are often the point — occupation, shared custody and contested claims. Dates are approximate."),
      q, list);
  };

  function chart(land) {
    const lo = Math.min(...land.stewards.map((s) => s.start));
    const sc = lo < -6000 ? { lo: lo * 1.1, log: true } : { lo: lo - (NOW - lo) * 0.03, log: false };
    const L10 = Math.log10(NOW - sc.lo);
    const X = (y) => (sc.log ? 1 - Math.log10(Math.max(NOW - y, 1)) / L10 : (y - sc.lo) / (NOW - sc.lo));
    const W = 1000, ROW = 30, TOP = 22, H = TOP + land.stewards.length * ROW + 8;
    const root = svg("svg", { viewBox: `0 0 ${W} ${H}`, class: "ta-line-svg", role: "img", "aria-label": `Stewards of ${land.name} over time` });
    const ticks = sc.log ? [1e5, 3e4, 1e4, 3000, 1000, 300, 100].filter((a) => a < NOW - sc.lo).map((a) => { const y = Math.round((NOW - a) / 100) * 100; return [y, L.fmtYear(y)]; })
      : (() => { const span = NOW - sc.lo; const step = [10, 25, 50, 100, 250, 500, 1000, 2000].find((s) => span / s <= 9) || 5000; const out = []; for (let y = Math.ceil(sc.lo / step) * step; y <= NOW; y += step) out.push([y, y < 0 ? `${-y} BCE` : `${y}`]); return out; })();
    for (const [ty, label] of ticks) {
      const x = X(ty) * W;
      root.appendChild(svg("line", { x1: x, x2: x, y1: 16, y2: H, stroke: "var(--border)" }));
      const t = svg("text", { x: x + 3, y: 12, "font-size": 11, fill: "var(--muted)" });
      t.textContent = label;
      root.appendChild(t);
    }
    land.stewards.forEach((s, i) => {
      const x1 = X(s.start) * W, x2 = X(s.ongoing ? NOW : s.end ?? s.start) * W;
      const y = TOP + i * ROW;
      const bw = Math.max(5, x2 - x1);
      const g = svg("a", { href: `#/timeatlas?year=${s.start}&scale=${sc.log ? "human" : s.start < -3500 ? "human" : s.start < 1500 ? "recorded" : "modern"}` });
      g.appendChild(svg("rect", { x: x1, y, width: bw, height: ROW - 10, rx: 4, fill: s.ongoing ? "var(--gold-500)" : "#7A5C2E", opacity: 0.85 }));
      const right = x1 + bw + 6 + s.name.length * 6.6 < W;
      const t = svg("text", { x: right ? x1 + bw + 6 : x1 - 6, y: y + 14, "font-size": 12, "text-anchor": right ? "start" : "end", fill: "var(--text)" });
      t.textContent = s.name;
      g.appendChild(t);
      const tt = svg("title");
      tt.textContent = `${s.name} · ${spanOf(s)}${s.note ? " — " + s.note : ""}`;
      g.appendChild(tt);
      root.appendChild(g);
    });
    return root;
  }

  V.land = (id) => {
    const land = REF.lands.find((l) => l.id === decodeURIComponent(id));
    if (!land) return h("div.empty", "Unknown land. ", h("a", { href: "#/lands" }, "All lands"));
    const mine = placesOn(land);
    const rel = related(land);
    const makePlace = () => {
      const made = store.create("places", { name: land.name, kind: "region", realLand: [land.id], cultures: land.pools,
        history: land.stewards.map((s) => `${s.name} (${spanOf(s)})${s.note ? ": " + s.note : ""}`).join("\n") });
      location.hash = `#/places/${made.id}`;
    };
    return h("div.stack",
      h("a", { href: "#/lands" }, "← Lands & stewards"),
      h("div.page-head", h("div", h("div.eyebrow", land.pools.map(regionName).join(" · ")), h("h1", land.name), land.summary ? h("p.muted", land.summary) : null),
        h("button.gold", { onclick: makePlace }, "＋ Place based on this land")),
      land.care ? h("div.warn", h("strong", "Care: "), land.care) : null,
      h("div.card", h("h3", "Stewards across time"), h("p.tiny.muted", "Tap a bar to see that moment on the Time Atlas. Gold bars continue today."), h("div.ta-line", chart(land))),
      h("div.two-col",
        h("div.card", h("h3", "In order"),
          h("table.small", h("tr", h("th", "Steward"), h("th", "When"), h("th", "")),
            land.stewards.map((s) => h("tr", h("td", h("strong", s.name)), h("td", { style: { whiteSpace: "nowrap" } }, spanOf(s)), h("td.muted", s.note || ""))))),
        h("div.stack",
          h("div.card", h("h3", "Your places drawing on it"), mine.length ? h("div.chips", mine.map((p) => h("a.chip.gold", { href: `#/places/${p.id}` }, store.title("places", p)))) : h("p.small.muted", "None yet.")),
          land.sources.length ? h("div.card", h("h3", "Read further"), h("ul.small", land.sources.map((s) => h("li", s)))) : null,
          h("div.card", h("h3", "Regions"), h("div.chips", land.pools.map((p) => h("a.chip", { href: `#/atlas/${p}` }, regionName(p))))))),
      rel.length ? h("div.card.stack", h("h3", "In the libraries"),
        rel.map(([s, xs]) => h("div", h("div.tiny", { style: { fontWeight: 700, textTransform: "uppercase", letterSpacing: ".06em" } }, `${s.icon} ${s.label}`),
          h("div.chips", xs.map((it) => h("a.chip", { href: it.start != null ? `#/timeatlas?year=${it.start}&focus=${encodeURIComponent(it.id)}` : `#/lore/${s.id}`, title: it.note }, it.name)))))) : null);
  };
})(window.WOW);
