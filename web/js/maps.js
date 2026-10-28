// Map designer: renders map entries (styles, stamps, regions, paths, labels) as SVG
// and ties them to places, events, characters and other maps across in-world time.
// The iPad app draws from the same shared recipes (MapRenderer.swift).
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, svg, store } = WOW;
  const FONTS = { serif: '"Iowan Old Style", Palatino, Georgia, serif', sans: "system-ui, -apple-system, sans-serif" };
  const PATH_STYLES = ["solid", "dashed", "dotted", "double", "footprints"];
  const SWATCHES = ["land", "water", "ink", "accent", "paper", "#2F6B3F", "#A23B3B", "#1F3A5F", "#C9A227", "#8E5BD0"];

  const styleOf = (id) => REF.mapStyles.find((s) => s.id === id) || REF.mapStyles[0];
  const sizeFor = (scale) => REF.mapSizes[scale] || REF.mapSizes.region;
  function emptyCanvas(scale) {
    const [width, height] = sizeFor(scale);
    return { width, height, features: [] };
  }
  function canvasOf(map) {
    const c = map.canvas || emptyCanvas(map.scale);
    c.features = c.features || [];
    return c;
  }

  // ---- Geometry & time ------------------------------------------------------
  function anchor(f) {
    if (f.kind === "path" || f.kind === "region") {
      const pts = f.points || [];
      if (!pts.length) return [0, 0];
      if (f.kind === "path") return pts[Math.floor(pts.length / 2)];
      return [pts.reduce((s, p) => s + p[0], 0) / pts.length, pts.reduce((s, p) => s + p[1], 0) / pts.length];
    }
    return [f.x || 0, f.y || 0];
  }

  // A feature's time window: its own from/to, otherwise its linked place's.
  function windowOf(f) {
    const place = f.placeId ? store.get("places", f.placeId) : null;
    const num = (v) => (v === "" || v == null ? null : Number(v));
    return { from: num(f.from ?? place?.existsFrom), to: num(f.to ?? place?.existsTo) };
  }
  function visibleAt(f, time) {
    if (time == null) return true;
    const w = windowOf(f);
    return (w.from == null || w.from <= time) && (w.to == null || time <= w.to);
  }

  // Walk up the place hierarchy until we reach a place drawn on this map.
  function placeOnMap(placeId, placesOnMap) {
    let id = placeId;
    for (let depth = 0; id && depth < 25; depth++) {
      if (placesOnMap.has(id)) return id;
      id = store.get("places", id)?.parent;
    }
    return null;
  }

  // Footprints along a polyline: alternating left/right prints every `spacing` units.
  function footprints(points, spacing) {
    const out = [];
    let carry = 0, i = 0;
    for (let s = 1; s < points.length; s++) {
      const [x1, y1] = points[s - 1], [x2, y2] = points[s];
      const len = Math.hypot(x2 - x1, y2 - y1);
      if (!len) continue;
      const ux = (x2 - x1) / len, uy = (y2 - y1) / len;
      let d = spacing - carry;
      while (d <= len) {
        const side = i % 2 ? 4 : -4;
        out.push({ x: x1 + ux * d - uy * side, y: y1 + uy * d + ux * side, angle: Math.atan2(uy, ux) * 180 / Math.PI });
        i++;
        d += spacing;
      }
      carry = len - (d - spacing);
    }
    return out;
  }

  // Park–Miller generator so stars land in the same place on every device.
  function rng(seed) {
    let s = seed;
    return () => { s = (s * 16807) % 2147483647; return s / 2147483647; };
  }

  // ---- Rendering ------------------------------------------------------------
  function paletteFor(style) { return { ...style.colors }; }
  function colorOf(key, pal, fallback) {
    const k = key || fallback;
    if (!k || k === "none") return "none";
    return pal[k] || k;
  }

  function shape(s, pal, fill, g) {
    const paint = (k) => (k === "fill" ? fill : colorOf(k, pal));
    const common = {
      fill: s.fill ? paint(s.fill) : "none",
      stroke: s.stroke ? paint(s.stroke) : null,
      "stroke-width": s.sw || null,
      opacity: s.opacity ?? null,
      "stroke-linejoin": "round", "stroke-linecap": "round",
    };
    if (s.t === "ellipse") g.appendChild(svg("ellipse", { cx: s.cx, cy: s.cy, rx: s.rx, ry: s.ry, ...common }));
    else if (s.t === "rect") g.appendChild(svg("rect", { x: s.x, y: s.y, width: s.w, height: s.h, rx: s.r || 0, ...common }));
    else if (s.t === "poly") g.appendChild(svg("polygon", { points: s.points.map((p) => p.join(",")).join(" "), ...common }));
    else if (s.t === "line") g.appendChild(svg("polyline", { points: s.points.map((p) => p.join(",")).join(" "), ...common, fill: "none" }));
  }

  function pattern(style, W, H, pal, root) {
    const g = svg("g", { "pointer-events": "none" });
    const ink = pal.ink, acc = pal.accent;
    if (style.pattern === "grid") {
      for (let x = 50; x < W; x += 50) g.appendChild(svg("line", { x1: x, y1: 0, x2: x, y2: H, stroke: ink, "stroke-opacity": 0.07 }));
      for (let y = 50; y < H; y += 50) g.appendChild(svg("line", { x1: 0, y1: y, x2: W, y2: y, stroke: ink, "stroke-opacity": 0.07 }));
    } else if (style.pattern === "dots") {
      for (let x = 20; x < W; x += 40) for (let y = 20; y < H; y += 40) g.appendChild(svg("circle", { cx: x, cy: y, r: 1.5, fill: acc, "fill-opacity": 0.25 }));
    } else if (style.pattern === "rings") {
      const cx = W / 2, cy = H / 2;
      for (let r = 70; r < Math.max(W, H); r += 70) g.appendChild(svg("circle", { cx, cy, r, fill: "none", stroke: acc, "stroke-opacity": 0.22 }));
    } else if (style.pattern === "stars") {
      const r = rng(12345);
      const n = Math.round((W * H) / 9000);
      for (let i = 0; i < n; i++) g.appendChild(svg("circle", { cx: r() * W, cy: r() * H, r: 0.6 + r() * 1.6, fill: ink, "fill-opacity": 0.7 }));
    } else if (style.pattern === "hatch") {
      for (let d = -H; d < W; d += 24) g.appendChild(svg("line", { x1: d, y1: H, x2: d + H, y2: 0, stroke: ink, "stroke-opacity": 0.1 }));
    }
    root.appendChild(g);
  }

  function frame(style, W, H, pal, root) {
    const g = svg("g", { "pointer-events": "none" });
    if (style.frame === "simple") {
      g.appendChild(svg("rect", { x: 10, y: 10, width: W - 20, height: H - 20, fill: "none", stroke: pal.ink, "stroke-width": 2 }));
    } else if (style.frame === "double") {
      g.appendChild(svg("rect", { x: 10, y: 10, width: W - 20, height: H - 20, fill: "none", stroke: pal.ink, "stroke-width": 3 }));
      g.appendChild(svg("rect", { x: 18, y: 18, width: W - 36, height: H - 36, fill: "none", stroke: pal.accent, "stroke-width": 1.5 }));
    } else if (style.frame === "band") {
      const b = 24;
      g.appendChild(svg("path", { d: `M0 0H${W}V${H}H0Z M${b} ${b}V${H - b}H${W - b}V${b}Z`, fill: pal.ink, "fill-opacity": 0.85, "fill-rule": "evenodd" }));
      for (let x = 40; x < W - 30; x += 60) {
        g.appendChild(svg("rect", { x, y: 8, width: 20, height: 8, fill: pal.accent }));
        g.appendChild(svg("rect", { x, y: H - 16, width: 20, height: 8, fill: pal.accent }));
      }
    } else if (style.frame === "circle") {
      const r = Math.min(W, H) / 2 - 20;
      g.appendChild(svg("path", { d: `M0 0H${W}V${H}H0Z M${W / 2 - r} ${H / 2}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0Z`, fill: "#000", "fill-opacity": 0.35, "fill-rule": "evenodd" }));
      g.appendChild(svg("circle", { cx: W / 2, cy: H / 2, r, fill: "none", stroke: pal.accent, "stroke-width": 3 }));
    }
    root.appendChild(g);
  }

  function compass(style, W, pal, root) {
    const o = style.orientation;
    if (!o) return;
    const cw = { N: "E", E: "S", S: "W", W: "N" }, opp = { N: "S", S: "N", E: "W", W: "E" };
    const cx = W - 90, cy = 95, r = 42;
    const g = svg("g", { "pointer-events": "none", "font-family": FONTS[style.font] || FONTS.serif, "font-weight": 700 });
    g.appendChild(svg("circle", { cx, cy, r, fill: pal.paper, "fill-opacity": 0.8, stroke: pal.ink, "stroke-width": 1.5 }));
    g.appendChild(svg("polygon", { points: `${cx},${cy - r + 6} ${cx + 8},${cy} ${cx},${cy + r - 6} ${cx - 8},${cy}`, fill: pal.accent, stroke: pal.ink }));
    const letters = [[o, cx, cy - r - 6], [opp[o], cx, cy + r + 18], [cw[o], cx + r + 12, cy + 5], [opp[cw[o]], cx - r - 12, cy + 5]];
    for (const [t, x, y] of letters) {
      const el = svg("text", { x, y, "text-anchor": "middle", fill: pal.ink, "font-size": t === o ? 18 : 13 });
      el.textContent = t;
      g.appendChild(el);
    }
    root.appendChild(g);
  }

  function cartouche(map, style, pal, root) {
    const title = map.title || "Untitled map";
    const sub = [map.era, map.scaleNote].filter(Boolean).join(" · ");
    const inset = style.frame === "band" ? 40 : 32;
    const w = Math.max(240, Math.max(title.length * 13, sub.length * 7) + 40);
    const g = svg("g", { "pointer-events": "none", "font-family": FONTS[style.font] || FONTS.serif });
    g.appendChild(svg("rect", { x: inset, y: inset, width: w, height: sub ? 66 : 46, rx: 6, fill: pal.paper, "fill-opacity": 0.88, stroke: pal.ink, "stroke-width": 1.5 }));
    const t = svg("text", { x: inset + 18, y: inset + 31, fill: pal.ink, "font-size": 24, "font-weight": 700 });
    t.textContent = title;
    g.appendChild(t);
    if (sub) {
      const s = svg("text", { x: inset + 18, y: inset + 53, fill: pal.ink, "font-size": 13, opacity: 0.8 });
      s.textContent = sub;
      g.appendChild(s);
    }
    root.appendChild(g);
  }

  function drawPath(f, pal, style, g, editing) {
    const pts = f.points || [];
    if (pts.length < 2) return;
    const color = colorOf(f.color, pal, "ink");
    const width = f.width || 3;
    const ps = f.pathStyle || style.pathStyle;
    const line = (attrs) => g.appendChild(svg("polyline", { points: pts.map((p) => p.join(",")).join(" "), fill: "none", "stroke-linecap": "round", "stroke-linejoin": "round", ...attrs }));
    if (editing) line({ stroke: "transparent", "stroke-width": 16 });
    if (ps === "footprints") {
      for (const fp of footprints(pts, 22)) {
        g.appendChild(svg("ellipse", { cx: fp.x, cy: fp.y, rx: width + 3, ry: (width + 3) / 1.8, fill: color, transform: `rotate(${fp.angle} ${fp.x} ${fp.y})` }));
      }
    } else if (ps === "double") {
      line({ stroke: color, "stroke-width": width * 2.4 });
      line({ stroke: pal.paper, "stroke-width": width * 0.9 });
    } else {
      line({ stroke: color, "stroke-width": width, "stroke-dasharray": ps === "dashed" ? `${width * 4} ${width * 2.5}` : ps === "dotted" ? `0.1 ${width * 3}` : null });
    }
  }

  function label(text, x, y, size, pal, style, g, halo) {
    const attrs = { x, y, "text-anchor": "middle", "font-size": size, "font-family": FONTS[style.font] || FONTS.serif, fill: pal.ink, "font-weight": 600 };
    if (halo) g.appendChild(Object.assign(svg("text", { ...attrs, stroke: pal.paper, "stroke-width": 4, "stroke-linejoin": "round", opacity: 0.85 }), { textContent: text }));
    g.appendChild(Object.assign(svg("text", attrs), { textContent: text }));
  }

  function drawFeature(f, pal, style, editing) {
    const g = svg("g", { "data-fid": f.id, style: editing ? "cursor:pointer" : null });
    if (f.kind === "region") {
      const pts = f.points || [];
      if (pts.length >= 3) {
        g.appendChild(svg("polygon", { points: pts.map((p) => p.join(",")).join(" "), fill: colorOf(f.color, pal, "land"), "fill-opacity": f.opacity ?? 0.8, stroke: pal.ink, "stroke-width": 1.5, "stroke-linejoin": "round" }));
      }
      if (f.label) { const [x, y] = anchor(f); label(f.label, x, y, 18, pal, style, g, true); }
    } else if (f.kind === "path") {
      drawPath(f, pal, style, g, editing);
      if (f.label) { const [x, y] = anchor(f); label(f.label, x, y - 10, 14, pal, style, g, true); }
    } else if (f.kind === "label") {
      label(f.text || "Label", f.x, f.y, f.size || 22, pal, style, g, false);
    } else {
      const def = REF.mapStamps[f.stamp] || REF.mapStamps.pin;
      const size = f.size || 40;
      const inner = svg("g", { transform: `translate(${f.x - size / 2} ${f.y - size / 2}) scale(${size / 40})` });
      if (editing) inner.appendChild(svg("rect", { x: 0, y: 0, width: 40, height: 40, fill: "transparent" }));
      const fill = colorOf(f.color, pal, def.color);
      def.shapes.forEach((s) => shape(s, pal, fill, inner));
      g.appendChild(inner);
      if (f.label) label(f.label, f.x, f.y + size / 2 + 15, 14, pal, style, g, true);
    }
    return g;
  }

  // Events at each feature (via place, including sub-places), filtered by time.
  function eventsByFeature(features, time) {
    const byPlace = new Map();
    for (const f of features) if (f.placeId && !byPlace.has(f.placeId)) byPlace.set(f.placeId, f);
    const placesOnMap = new Set(byPlace.keys());
    const out = new Map();
    for (const ev of WOW.continuity.orderedEvents(store.state.data)) {
      if (!ev.place) continue;
      const seq = ev.sequence === "" || ev.sequence == null ? null : Number(ev.sequence);
      if (time != null && (seq == null || seq > time)) continue;
      const pid = placeOnMap(ev.place, placesOnMap);
      if (!pid) continue;
      const f = byPlace.get(pid);
      if (!out.has(f.id)) out.set(f.id, []);
      out.get(f.id).push(ev);
    }
    return out;
  }

  // Conflicts touching each feature (via their places), active at this time.
  function conflictsByFeature(features, time) {
    const byPlace = new Map();
    for (const f of features) if (f.placeId && !byPlace.has(f.placeId)) byPlace.set(f.placeId, f);
    const placesOnMap = new Set(byPlace.keys());
    const num = (v) => (v === "" || v == null ? null : Number(v));
    const out = new Map();
    for (const c of store.list("conflicts")) {
      const from = num(c.start), to = num(c.end);
      if (time != null && ((from != null && time < from) || (to != null && time > to))) continue;
      const places = [...(c.places || []), ...(c.battles || []).map((id) => store.get("events", id)?.place).filter(Boolean)];
      for (const pid of new Set(places.map((p) => placeOnMap(p, placesOnMap)).filter(Boolean))) {
        const f = byPlace.get(pid);
        if (!out.has(f.id)) out.set(f.id, []);
        out.get(f.id).push(c);
      }
    }
    return out;
  }

  // Ordered stops for a character: homeland, then each event place on this map.
  function journey(charId, features, time) {
    const byPlace = new Map();
    for (const f of features) if (f.placeId && !byPlace.has(f.placeId)) byPlace.set(f.placeId, f);
    const placesOnMap = new Set(byPlace.keys());
    const stops = [];
    const c = store.get("characters", charId);
    const home = c?.homeland && placeOnMap(c.homeland, placesOnMap);
    if (home) stops.push({ f: byPlace.get(home), label: "Home" });
    for (const ev of WOW.continuity.orderedEvents(store.state.data)) {
      if (!(ev.characters || []).includes(charId) || !ev.place) continue;
      const seq = ev.sequence === "" || ev.sequence == null ? null : Number(ev.sequence);
      if (time != null && (seq == null || seq > time)) continue;
      const pid = placeOnMap(ev.place, placesOnMap);
      if (!pid) continue;
      const f = byPlace.get(pid);
      if (stops.length && stops[stops.length - 1].f === f) continue;
      stops.push({ f, label: ev.title || "" });
    }
    return stops;
  }

  // opts: { time, journeyId, selectedId, editing, draft:{kind, points}, layers, className }
  function render(map, opts = {}) {
    const c = canvasOf(map);
    const W = c.width, H = c.height;
    const style = styleOf(map.mapStyle);
    const pal = paletteFor(style);
    const layers = Object.assign({ regions: true, paths: true, stamps: true, labels: true, events: true, conflicts: true, decor: true }, opts.layers || {});
    const root = svg("svg", { viewBox: `0 0 ${W} ${H}`, class: opts.className || "map-svg", xmlns: "http://www.w3.org/2000/svg" });
    root.appendChild(svg("rect", { x: 0, y: 0, width: W, height: H, fill: pal.paper }));
    pattern(style, W, H, pal, root);

    const order = { region: 0, path: 1, stamp: 2, label: 3 };
    const layerOf = { region: "regions", path: "paths", stamp: "stamps", label: "labels" };
    const feats = c.features.slice().sort((a, b) => (order[a.kind] ?? 2) - (order[b.kind] ?? 2));
    for (const f of feats) {
      if (!layers[layerOf[f.kind] || "stamps"]) continue;
      const vis = visibleAt(f, opts.time);
      if (!vis && !opts.editing) continue;
      const g = drawFeature(f, pal, style, opts.editing);
      if (!vis) g.setAttribute("opacity", 0.15);
      root.appendChild(g);
    }

    if (opts.journeyId) {
      const stops = journey(opts.journeyId, c.features, opts.time);
      const pts = stops.map((s) => anchor(s.f));
      const g = svg("g", { "pointer-events": "none" });
      if (pts.length > 1) g.appendChild(svg("polyline", { points: pts.map((p) => p.join(",")).join(" "), fill: "none", stroke: pal.accent, "stroke-width": 5, "stroke-dasharray": "14 8", "stroke-linecap": "round", opacity: 0.9 }));
      pts.forEach(([x, y], i) => {
        g.appendChild(svg("circle", { cx: x, cy: y, r: 13, fill: pal.accent, stroke: pal.ink, "stroke-width": 2 }));
        const t = svg("text", { x, y: y + 5, "text-anchor": "middle", "font-size": 13, "font-weight": 700, fill: pal.ink, "font-family": FONTS.sans });
        t.textContent = i + 1;
        g.appendChild(t);
      });
      root.appendChild(g);
    }

    if (layers.conflicts) {
      const war = "#C0392B";
      const g = svg("g", { "pointer-events": "none" });
      for (const [fid, list] of conflictsByFeature(c.features, opts.time)) {
        const f = c.features.find((x) => x.id === fid);
        if (!visibleAt(f, opts.time)) continue;
        const [x, y] = anchor(f);
        g.appendChild(svg("circle", { cx: x, cy: y, r: 34, fill: war, "fill-opacity": 0.12, stroke: war, "stroke-width": 3, "stroke-dasharray": "8 5" }));
        g.appendChild(svg("circle", { cx: x - 22, cy: y - 22, r: 12, fill: war, stroke: pal.paper, "stroke-width": 2 }));
        const t = svg("text", { x: x - 22, y: y - 17, "text-anchor": "middle", "font-size": 13, fill: "#fff", "font-family": FONTS.sans });
        t.textContent = "⚔";
        g.appendChild(t);
        const lbl = svg("text", { x, y: y + 52, "text-anchor": "middle", "font-size": 13, "font-weight": 700, fill: war, stroke: pal.paper, "stroke-width": 4, "paint-order": "stroke", "font-family": FONTS.sans });
        lbl.textContent = list.map((x) => x.name || "Conflict").slice(0, 2).join(" · ") + (list.length > 2 ? ` +${list.length - 2}` : "");
        g.appendChild(lbl);
      }
      root.appendChild(g);
    }

    if (layers.events) {
      const evs = eventsByFeature(c.features, opts.time);
      const g = svg("g", { "pointer-events": "none" });
      for (const f of c.features) {
        const list = evs.get(f.id);
        if (!list || !visibleAt(f, opts.time)) continue;
        const [x, y] = anchor(f);
        const now = opts.time != null && list.some((e) => Number(e.sequence) === opts.time);
        g.appendChild(svg("circle", { cx: x + 20, cy: y - 22, r: 11, fill: now ? pal.accent : pal.ink, stroke: pal.paper, "stroke-width": 2 }));
        const t = svg("text", { x: x + 20, y: y - 18, "text-anchor": "middle", "font-size": 12, "font-weight": 700, fill: now ? pal.ink : pal.paper, "font-family": FONTS.sans });
        t.textContent = list.length;
        g.appendChild(t);
      }
      root.appendChild(g);
    }

    if (opts.draft && opts.draft.points.length) {
      const pts = opts.draft.points;
      const g = svg("g", { "pointer-events": "none" });
      const attrs = { points: pts.map((p) => p.join(",")).join(" "), stroke: pal.accent, "stroke-width": 3, "stroke-dasharray": "6 5" };
      g.appendChild(svg(opts.draft.kind === "region" ? "polygon" : "polyline", { ...attrs, fill: opts.draft.kind === "region" ? pal.accent : "none", "fill-opacity": 0.2 }));
      pts.forEach(([x, y]) => g.appendChild(svg("circle", { cx: x, cy: y, r: 5, fill: pal.accent, stroke: pal.ink })));
      root.appendChild(g);
    }

    if (opts.selectedId) {
      const f = c.features.find((x) => x.id === opts.selectedId);
      if (f) {
        const g = svg("g", { "pointer-events": "none" });
        if (f.kind === "path" || f.kind === "region") {
          (f.points || []).forEach(([x, y]) => g.appendChild(svg("circle", { cx: x, cy: y, r: 6, fill: "#fff", stroke: "#6C3DB0", "stroke-width": 2 })));
        } else {
          const s = f.kind === "label" ? (f.size || 22) * 1.4 : (f.size || 40) * 0.75;
          g.appendChild(svg("circle", { cx: f.x, cy: f.kind === "label" ? f.y - (f.size || 22) / 3 : f.y, r: s, fill: "none", stroke: "#6C3DB0", "stroke-width": 2.5, "stroke-dasharray": "6 4" }));
        }
        root.appendChild(g);
      }
    }

    if (layers.decor) {
      frame(style, W, H, pal, root);
      compass(style, W, pal, root);
      cartouche(map, style, pal, root);
    }
    return root;
  }

  // ---- Designer -------------------------------------------------------------
  function newId() { return "f-" + Math.random().toString(36).slice(2, 10); }

  function timeRange() {
    const nums = [];
    for (const e of store.list("events")) if (e.sequence !== "" && e.sequence != null) nums.push(Number(e.sequence));
    for (const p of store.list("places")) for (const k of ["existsFrom", "existsTo"]) if (p[k] !== "" && p[k] != null) nums.push(Number(p[k]));
    for (const m of store.list("maps")) for (const k of ["eraFrom", "eraTo"]) if (m[k] !== "" && m[k] != null) nums.push(Number(m[k]));
    for (const x of store.list("conflicts")) for (const k of ["start", "end"]) if (x[k] !== "" && x[k] != null) nums.push(Number(x[k]));
    if (!nums.length) return [0, 10];
    const lo = Math.min(...nums), hi = Math.max(...nums);
    return lo === hi ? [lo - 1, hi + 1] : [lo, hi];
  }

  function designer(map, params, rerenderPage) {
    const c = canvasOf(map);
    if (!map.canvas) store.update("maps", map.id, { canvas: c });
    const st = {
      tool: "select", stamp: "pin", selectedId: params.get("focus") || null, draft: null, zoom: 0,
      time: null, journeyId: params.get("journey") || "", drag: null,
      layers: { regions: true, paths: true, stamps: true, labels: true, events: true, conflicts: true, decor: true },
    };
    const save = WOW.debounce(() => store.update("maps", map.id, { canvas: c }), 250);
    const selected = () => c.features.find((f) => f.id === st.selectedId);

    const holder = h("div.map-stage");
    const inspector = h("div.card.stack.map-inspector");
    const toolbar = h("div.map-toolbar");
    const timebar = h("div.map-toolbar");

    function fitZoom() {
      const w = holder.clientWidth || 800;
      return Math.max(0.15, (w - 4) / c.width);
    }
    function draw() {
      if (!st.zoom) st.zoom = fitZoom();
      const el = render(map, { time: st.time, journeyId: st.journeyId, selectedId: st.selectedId, editing: true, draft: st.draft, layers: st.layers });
      el.setAttribute("width", Math.round(c.width * st.zoom));
      el.setAttribute("height", Math.round(c.height * st.zoom));
      el.style.cursor = st.tool === "select" ? "default" : "crosshair";
      el.addEventListener("pointerdown", down);
      el.addEventListener("dblclick", (e) => { e.preventDefault(); finishDraft(); });
      holder.replaceChildren(el);
    }
    function pointFrom(ev) {
      const el = holder.querySelector("svg");
      const pt = el.createSVGPoint();
      pt.x = ev.clientX; pt.y = ev.clientY;
      const p = pt.matrixTransform(el.getScreenCTM().inverse());
      return [Math.round(p.x), Math.round(p.y)];
    }
    function down(ev) {
      const p = pointFrom(ev);
      if (st.tool === "select") {
        const hit = ev.target.closest("[data-fid]");
        st.selectedId = hit ? hit.getAttribute("data-fid") : null;
        const f = selected();
        if (f) {
          st.drag = { start: p, orig: JSON.parse(JSON.stringify(f)) };
          // The SVG is re-rendered while dragging, so listen on the window.
          window.addEventListener("pointermove", move);
          window.addEventListener("pointerup", up, { once: true });
          ev.preventDefault();
        }
        draw(); drawInspector();
      } else if (st.tool === "stamp") {
        const f = { id: newId(), kind: "stamp", stamp: st.stamp, x: p[0], y: p[1], size: 40 };
        c.features.push(f); st.selectedId = f.id; save(); draw(); drawInspector();
      } else if (st.tool === "label") {
        const text = prompt("Label text:");
        if (text) { const f = { id: newId(), kind: "label", text, x: p[0], y: p[1], size: 24 }; c.features.push(f); st.selectedId = f.id; save(); }
        draw(); drawInspector();
      } else if (st.tool === "path" || st.tool === "region") {
        if (!st.draft) st.draft = { kind: st.tool, points: [] };
        const last = st.draft.points[st.draft.points.length - 1];
        if (!last || Math.hypot(last[0] - p[0], last[1] - p[1]) > 3) st.draft.points.push(p);
        draw(); drawInspector();
      }
    }
    function move(ev) {
      if (!st.drag) return;
      const p = pointFrom(ev);
      const dx = p[0] - st.drag.start[0], dy = p[1] - st.drag.start[1];
      const f = selected(), o = st.drag.orig;
      if (f.points) f.points = o.points.map(([x, y]) => [x + dx, y + dy]);
      else { f.x = o.x + dx; f.y = o.y + dy; }
      draw();
    }
    function up() {
      window.removeEventListener("pointermove", move);
      st.drag = null; save(); draw();
    }
    function finishDraft() {
      if (!st.draft) return;
      const need = st.draft.kind === "region" ? 3 : 2;
      if (st.draft.points.length >= need) {
        const f = { id: newId(), kind: st.draft.kind, points: st.draft.points };
        if (f.kind === "region") f.color = "land";
        c.features.push(f); st.selectedId = f.id; save();
      }
      st.draft = null; draw(); drawInspector();
    }
    holder.tabIndex = 0;
    holder.addEventListener("keydown", (e) => {
      if (e.key === "Enter") finishDraft();
      if (e.key === "Escape") { st.draft = null; draw(); drawInspector(); }
      if ((e.key === "Delete" || e.key === "Backspace") && st.selectedId && document.activeElement === holder) {
        c.features = c.features.filter((f) => f.id !== st.selectedId); st.selectedId = null; save(); draw(); drawInspector();
      }
    });

    // Toolbar
    function drawToolbar() {
      const tools = [["select", "↖ Select / move"], ["stamp", "◉ Stamp"], ["path", "〰 Path / route"], ["region", "⬠ Region"], ["label", "A Label"]];
      toolbar.replaceChildren(
        ...tools.map(([id, label]) => h("button.small" + (st.tool === id ? ".gold" : ".ghost"), { onclick: () => { st.tool = id; if (id !== "path" && id !== "region") st.draft = null; drawToolbar(); draw(); drawInspector(); } }, label)),
        h("span.spacer"),
        h("button.ghost.small", { title: "Zoom out", onclick: () => { st.zoom = Math.max(0.1, st.zoom / 1.25); draw(); } }, "−"),
        h("button.ghost.small", { title: "Fit", onclick: () => { st.zoom = fitZoom(); draw(); } }, "Fit"),
        h("button.ghost.small", { title: "Zoom in", onclick: () => { st.zoom = Math.min(4, st.zoom * 1.25); draw(); } }, "+"),
        h("button.ghost.small", { onclick: () => exportSVG() }, "SVG"),
        h("button.ghost.small", { onclick: () => exportPNG() }, "PNG"));
      if (st.tool === "stamp") {
        toolbar.appendChild(h("div.stamp-palette", Object.entries(REF.mapStamps).map(([id, def]) => {
          const pal = paletteFor(styleOf(map.mapStyle));
          const icon = svg("svg", { viewBox: "0 0 40 40", width: 30, height: 30 });
          def.shapes.forEach((s) => shape(s, pal, colorOf(def.color, pal), icon));
          return h("button.stamp-btn" + (st.stamp === id ? ".on" : ""), { title: def.label, style: { background: pal.paper }, onclick: () => { st.stamp = id; drawToolbar(); } }, icon, h("span.tiny", def.label));
        })));
      }
      if (st.tool === "path" || st.tool === "region") {
        toolbar.appendChild(h("div.row.small", { style: { width: "100%" } },
          h("span.muted", st.tool === "region" ? "Tap points around the area, then Finish (or double-tap / Enter)." : "Tap points along the route, then Finish (or double-tap / Enter)."),
          h("button.small", { onclick: finishDraft }, "Finish"),
          h("button.ghost.small", { onclick: () => { st.draft = null; draw(); } }, "Cancel")));
      }
    }

    function drawTimebar() {
      const [lo, hi] = timeRange();
      const on = st.time != null;
      const slider = h("input", { type: "range", min: lo, max: hi, step: 1, value: on ? st.time : hi, disabled: !on || null, style: { flex: 1, minWidth: "160px" },
        oninput: (e) => { st.time = Number(e.target.value); readout.textContent = describeTime(st.time); draw(); drawInspector(); } });
      const readout = h("span.small", on ? describeTime(st.time) : "All of time");
      const journeySel = h("select", { style: { width: "auto" }, onchange: (e) => { st.journeyId = e.target.value; draw(); } },
        h("option", { value: "" }, "Trace a character's journey…"),
        store.list("characters").map((ch) => h("option", { value: ch.id, selected: ch.id === st.journeyId || null }, ch.name || "Unnamed")));
      timebar.replaceChildren(
        h("label.row.small", h("input", { type: "checkbox", checked: on || null, onchange: (e) => { st.time = e.target.checked ? (map.eraFrom ?? hi) : null; drawTimebar(); draw(); drawInspector(); } }), "Time travel"),
        slider, readout, journeySel,
        h("details.layers", h("summary.small", "Layers"),
          h("div.stack.small", { style: { gap: "4px", marginTop: "6px" } }, Object.keys(st.layers).map((k) =>
            h("label.row", h("input", { type: "checkbox", checked: st.layers[k] || null, onchange: (e) => { st.layers[k] = e.target.checked; draw(); } }), k)))));
    }
    function describeTime(t) {
      const evs = store.list("events").filter((e) => Number(e.sequence) === t && e.sequence !== "" && e.sequence != null);
      return `In-world order ${t}` + (evs.length ? ` — ${evs.map((e) => e.title).filter(Boolean).slice(0, 2).join(", ")}` : "");
    }

    // Inspector
    function drawInspector() {
      const f = selected();
      if (st.draft) {
        inspector.replaceChildren(h("h3", st.draft.kind === "region" ? "Drawing a region" : "Drawing a route"), h("p.small.muted", `${st.draft.points.length} point(s). Finish when done.`));
        return;
      }
      if (!f) { inspector.replaceChildren(...overview().filter(Boolean)); return; }
      const upd = (patch, redraw = true) => { Object.assign(f, patch); for (const k in patch) if (patch[k] === null || patch[k] === "") delete f[k]; save(); if (redraw) draw(); };
      const place = f.placeId ? store.get("places", f.placeId) : null;
      const kindName = f.kind === "stamp" ? (REF.mapStamps[f.stamp]?.label || "Stamp") : f.kind[0].toUpperCase() + f.kind.slice(1);
      const els = [h("div.row.spread", h("h3", kindName), h("button.ghost.small", { onclick: () => { st.selectedId = null; draw(); drawInspector(); } }, "Done"))];

      if (f.kind === "label") {
        els.push(h("div.field", h("label", "Text"), h("input", { type: "text", value: f.text || "", oninput: (e) => upd({ text: e.target.value }) })));
      } else {
        els.push(h("div.field", h("label", "Label on map"), h("input", { type: "text", value: f.label || "", oninput: (e) => upd({ label: e.target.value }) })));
      }
      if (f.kind === "stamp") {
        els.push(h("div.field", h("label", "Stamp"), h("select", { onchange: (e) => upd({ stamp: e.target.value }) },
          Object.entries(REF.mapStamps).map(([id, d]) => h("option", { value: id, selected: id === f.stamp || null }, d.label)))));
      }

      // Place link
      const placeSel = h("select", { onchange: (e) => { upd({ placeId: e.target.value || null }); drawInspector(); } },
        h("option", { value: "" }, "— not linked —"),
        store.list("places").map((p) => h("option", { value: p.id, selected: p.id === f.placeId || null }, p.name || "Unnamed place")));
      els.push(h("div.field", h("label", "Place"), placeSel,
        h("div.row.small",
          place ? h("a", { href: `#/places/${place.id}` }, "Open place →") : h("button.ghost.small", { onclick: () => {
            const kind = { city: "city", village: "town / village", temple: "sacred site", fort: "landmark", market: "landmark", mountain: "mountain / range", volcano: "mountain / range", forest: "forest / wild", "sacred-tree": "sacred site", lake: "sea / river / lake", island: "island / archipelago", cave: "otherworld location", spirit: "otherworld location", tomb: "sacred site" }[f.stamp]
              || (f.kind === "region" ? "region" : f.kind === "path" ? "route / road" : null);
            const made = store.create("places", { name: f.label || f.text || "New place", kind, parent: map.place || null, existsFrom: map.eraFrom ?? null });
            upd({ placeId: made.id }); drawInspector(); WOW.toast("Place created and linked");
          } }, "＋ New place from this"))));

      // Drill-down
      const autoMap = place ? store.list("maps").find((m) => m.place === place.id && m.id !== map.id) : null;
      const childSel = h("select", { onchange: (e) => { upd({ mapId: e.target.value || null }); drawInspector(); } },
        h("option", { value: "" }, autoMap ? `Auto: ${autoMap.title || "Untitled"}` : "— none —"),
        store.list("maps").filter((m) => m.id !== map.id).map((m) => h("option", { value: m.id, selected: m.id === f.mapId || null }, m.title || "Untitled map")));
      const target = f.mapId ? store.get("maps", f.mapId) : autoMap;
      els.push(h("div.field", h("label", "Zoom into map"), childSel,
        h("div.row.small",
          target ? h("a.btn.small", { href: `#/maps/${target.id}` }, `Open “${target.title || "Untitled"}” →`) : null,
          h("button.ghost.small", { onclick: () => {
            const scales = REF.collections.find((x) => x.id === "maps").fields.find((x) => x.key === "scale").options;
            const next = scales[Math.min(scales.indexOf(map.scale) + 1, scales.length - 2)] || "city";
            const made = store.create("maps", { title: (f.label || place?.name || "Detail") + " map", scale: next, mapStyle: map.mapStyle, place: f.placeId || null, work: map.work || null, eraFrom: map.eraFrom ?? null, eraTo: map.eraTo ?? null, canvas: emptyCanvas(next) });
            upd({ mapId: made.id }); location.hash = `#/maps/${made.id}`;
          } }, "＋ New detail map"))));

      // Time window
      const w = windowOf({ ...f, from: undefined, to: undefined });
      els.push(h("div.field", h("label", "Exists on this map (in-world order)"),
        h("div.row", { style: { flexWrap: "nowrap" } },
          h("input", { type: "number", value: f.from ?? "", placeholder: w.from != null ? `from ${w.from} (place)` : "from", oninput: (e) => upd({ from: e.target.value === "" ? null : Number(e.target.value) }) }),
          h("input", { type: "number", value: f.to ?? "", placeholder: w.to != null ? `to ${w.to} (place)` : "to", oninput: (e) => upd({ to: e.target.value === "" ? null : Number(e.target.value) }) }))));

      // Look
      const pal = paletteFor(styleOf(map.mapStyle));
      els.push(h("div.field", h("label", "Colour"), h("div.swatches", SWATCHES.map((k) =>
        h("button.swatch" + (f.color === k ? ".on" : ""), { type: "button", title: k, style: { background: pal[k] || k }, onclick: () => { upd({ color: k }); drawInspector(); } })))));
      if (f.kind === "stamp" || f.kind === "label") {
        const key = "size", min = f.kind === "label" ? 10 : 16, max = f.kind === "label" ? 90 : 200;
        els.push(h("div.field", h("label", "Size"), h("input", { type: "range", min, max, value: f[key] || (f.kind === "label" ? 22 : 40), oninput: (e) => upd({ [key]: Number(e.target.value) }) })));
      }
      if (f.kind === "path") {
        els.push(h("div.field", h("label", "Route style"), h("select", { onchange: (e) => upd({ pathStyle: e.target.value || null }) },
          h("option", { value: "" }, `Map default (${styleOf(map.mapStyle).pathStyle})`),
          PATH_STYLES.map((s) => h("option", { value: s, selected: f.pathStyle === s || null }, s)))));
        els.push(h("div.field", h("label", "Width"), h("input", { type: "range", min: 1, max: 12, value: f.width || 3, oninput: (e) => upd({ width: Number(e.target.value) }) })));
      }
      if (f.kind === "region") {
        els.push(h("div.field", h("label", "Opacity"), h("input", { type: "range", min: 10, max: 100, value: Math.round((f.opacity ?? 0.8) * 100), oninput: (e) => upd({ opacity: Number(e.target.value) / 100 }) })));
      }
      els.push(h("div.row",
        h("button.ghost.small", { onclick: () => { c.features = c.features.filter((x) => x !== f); c.features.push(f); save(); draw(); } }, "Bring forward"),
        h("button.ghost.small", { onclick: () => { c.features = c.features.filter((x) => x !== f); c.features.unshift(f); save(); draw(); } }, "Send back"),
        h("button.ghost.small", { onclick: () => {
          const copy = JSON.parse(JSON.stringify(f)); copy.id = newId();
          if (copy.points) copy.points = copy.points.map(([x, y]) => [x + 30, y + 30]); else { copy.x += 30; copy.y += 30; }
          c.features.push(copy); st.selectedId = copy.id; save(); draw(); drawInspector();
        } }, "Duplicate"),
        h("button.danger.small", { onclick: () => { c.features = c.features.filter((x) => x !== f); st.selectedId = null; save(); draw(); drawInspector(); } }, "Delete")));

      // What's here
      if (place) els.push(...hereSection(place, f));
      inspector.replaceChildren(...els.filter(Boolean));
    }

    function hereSection(place, f) {
      const evs = (eventsByFeature(c.features, st.time).get(f.id) || []);
      const people = new Set([...(place.characters || [])]);
      store.list("characters").forEach((ch) => { if (ch.homeland === place.id) people.add(ch.id); });
      evs.forEach((e) => (e.characters || []).forEach((id) => people.add(id)));
      return [
        h("hr"),
        h("strong.small", `What happens here${st.time != null ? " (up to now)" : ""}`),
        evs.length ? h("div.stack.small", { style: { gap: "4px" } }, evs.map((e) => h("a", { href: `#/events/${e.id}` }, `${e.sequence != null && e.sequence !== "" ? "#" + e.sequence + " " : ""}${e.title || "Untitled"}`)))
          : h("p.small.muted", "No timeline events here yet."),
        h("button.ghost.small", { onclick: () => {
          const made = store.create("events", { title: "", place: place.id, sequence: st.time ?? null });
          location.hash = `#/events/${made.id}`;
        } }, "＋ Event here"),
        people.size ? h("div", h("strong.small", "People"), h("div.chips", [...people].map((id) => h("a.chip.gold", { href: `#/characters/${id}` }, store.title("characters", store.get("characters", id)))))) : null,
      ];
    }

    function overview() {
      const placeIds = [...new Set(c.features.map((f) => f.placeId).filter(Boolean))];
      const style = styleOf(map.mapStyle);
      return [
        h("h3", "Map designer"),
        h("p.small.muted", "Pick a tool, then tap the map. Select anything to link it to a place, set when it exists, or zoom into a detail map. Works with Apple Pencil, touch or mouse."),
        h("div.small", h("strong", style.name), " — ", style.inspiration),
        style.care ? h("div.warn.small", style.care) : null,
        h("div.small", `Canvas ${c.width} × ${c.height}`, " · ",
          h("a", { href: "#", onclick: (e) => {
            e.preventDefault();
            const [w, hh] = sizeFor(map.scale);
            if (confirm(`Resize canvas to ${w} × ${hh} for “${map.scale || "region"}” scale? Features keep their positions.`)) { c.width = w; c.height = hh; save(); st.zoom = 0; draw(); drawInspector(); }
          } }, "resize to scale")),
        placeIds.length ? h("div", h("strong.small", "Places on this map"), h("div.chips", placeIds.map((id) => h("a.chip.gold", { href: `#/places/${id}` }, store.title("places", store.get("places", id)))))) : null,
        (() => {
          const parents = store.list("maps").filter((m) => m.id !== map.id && canvasOf(m).features.some((f) => f.mapId === map.id || (map.place && f.placeId === map.place)));
          return parents.length ? h("div", h("strong.small", "Zoom out to"), h("div.chips", parents.map((m) => h("a.chip", { href: `#/maps/${m.id}` }, "↑ " + (m.title || "Untitled"))))) : null;
        })(),
      ];
    }

    function exportSVG() {
      const el = render(map, { time: st.time, journeyId: st.journeyId, layers: st.layers });
      WOW.download(`${(map.title || "map").replace(/\W+/g, "-")}.svg`, new XMLSerializer().serializeToString(el), "image/svg+xml");
    }
    function exportPNG() {
      const el = render(map, { time: st.time, journeyId: st.journeyId, layers: st.layers });
      el.setAttribute("width", c.width); el.setAttribute("height", c.height);
      const img = new Image();
      img.onload = () => {
        const cv = document.createElement("canvas");
        cv.width = c.width; cv.height = c.height;
        cv.getContext("2d").drawImage(img, 0, 0);
        cv.toBlob((b) => WOW.download(`${(map.title || "map").replace(/\W+/g, "-")}.png`, b));
      };
      img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(new XMLSerializer().serializeToString(el));
    }

    drawToolbar();
    drawTimebar();
    drawInspector();
    requestAnimationFrame(draw);
    return h("div.stack", toolbar, timebar, h("div.map-layout", holder, inspector));
  }

  // Maps in which a place appears.
  function mapsWithPlace(placeId) {
    return store.list("maps").filter((m) => canvasOf(m).features.some((f) => f.placeId === placeId));
  }

  WOW.maps = { render, designer, emptyCanvas, styleOf, canvasOf, mapsWithPlace, journey, anchor, windowOf };
})(window.WOW);
