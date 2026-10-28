// Parametric character portraits — built from simple shapes you choose.
// Shape recipes live in shared/library.json so the iPad app draws the same figure.
(function (WOW) {
  const P = window.WOW_REF.portrait;
  const { h, svg } = WOW;

  function normalize(params) {
    return Object.assign({}, P.defaults, params || {});
  }

  function colors(p) {
    return {
      skin: P.skinTones[p.skin] || P.skinTones[0],
      hair: P.hairColors[p.hairColor] || P.hairColors[0],
      garment: P.garmentColors[p.garment] || P.garmentColors[0],
      accent: P.accentColors[p.accent] || P.accentColors[0],
      bg: P.backgrounds[p.background] || P.backgrounds[0],
      dark: "#1B1030",
    };
  }

  // Order matters: back to front.
  function layers(p) {
    const parts = P.parts;
    return [
      parts.aura[p.aura],
      parts.hairBack[p.hair],
      parts.head,
      parts.build[p.build],
      parts.face,
      parts.eyes[p.eyes],
      parts.hairFront[p.hair],
      parts.symbol[p.symbol],
    ].filter(Boolean).flat();
  }

  function render(params, className) {
    const p = normalize(params);
    const c = colors(p);
    const paint = (key) => (key === "none" ? "none" : c[key] || key);
    const root = svg("svg", { viewBox: `0 0 ${P.width} ${P.height}`, class: className || "portrait-svg", role: "img", "aria-label": "Character portrait" });
    root.appendChild(svg("rect", { x: 0, y: 0, width: P.width, height: P.height, fill: c.bg }));
    for (const s of layers(p)) {
      const common = {
        fill: paint(s.fill || "none"),
        stroke: s.stroke ? paint(s.stroke) : null,
        "stroke-width": s.sw || null,
        opacity: s.opacity ?? null,
      };
      if (s.t === "ellipse") {
        root.appendChild(svg("ellipse", { cx: s.cx, cy: s.cy, rx: s.rx, ry: s.ry, ...common }));
      } else if (s.t === "rect") {
        const cx = s.x + s.w / 2, cy = s.y + s.h / 2;
        root.appendChild(svg("rect", {
          x: s.x, y: s.y, width: s.w, height: s.h, rx: s.r || 0, ...common,
          transform: s.rot ? `rotate(${s.rot} ${cx} ${cy})` : null,
        }));
      }
    }
    return root;
  }

  function randomParams() {
    const r = (n) => Math.floor(Math.random() * n);
    const o = P.options;
    return {
      build: WOW.pick(o.build), hair: WOW.pick(o.hair), eyes: WOW.pick(o.eyes), aura: WOW.pick(o.aura), symbol: WOW.pick(o.symbol),
      skin: r(P.skinTones.length), hairColor: r(P.hairColors.length), garment: r(P.garmentColors.length),
      accent: r(P.accentColors.length), background: r(P.backgrounds.length),
    };
  }

  // Builder UI. onChange(params) is called on every tweak.
  function builder(params, onChange) {
    let p = normalize(params);
    const preview = h("div");
    const redraw = () => { preview.replaceChildren(render(p)); };
    const set = (k, v) => { p = { ...p, [k]: v }; redraw(); onChange(p); renderControls(); };

    const controls = h("div.stack");
    function optionRow(key, label) {
      return h("div.field", h("label", label),
        h("div.chips", P.options[key].map((opt) =>
          h("span.chip.toggle" + (p[key] === opt ? ".on" : ""), { onclick: () => set(key, opt) }, opt))));
    }
    function swatchRow(key, label, palette) {
      return h("div.field", h("label", label),
        h("div.swatches", palette.map((col, i) =>
          h("button.swatch" + (p[key] === i ? ".on" : ""), { type: "button", style: { background: col }, title: col, "aria-label": `${label} ${i + 1}`, onclick: () => set(key, i) }))));
    }
    function renderControls() {
      controls.replaceChildren(
        swatchRow("skin", "Skin tone", P.skinTones),
        optionRow("build", "Build & clothing"),
        swatchRow("garment", "Garment colour", P.garmentColors),
        optionRow("hair", "Hair & head covering"),
        swatchRow("hairColor", "Hair colour", P.hairColors),
        optionRow("eyes", "Eyes"),
        optionRow("aura", "Aura"),
        optionRow("symbol", "Emblem"),
        swatchRow("accent", "Accent / power colour", P.accentColors),
        swatchRow("background", "Background", P.backgrounds),
        h("div.row", h("button.ghost.small", { type: "button", onclick: () => { p = randomParams(); redraw(); onChange(p); renderControls(); } }, "🎲 Shuffle"))
      );
    }
    redraw();
    renderControls();
    return h("div.portrait-builder", h("div", preview, h("p.tiny.muted", "Shape-built placeholder — sketch your real design on an Ink page.")), controls);
  }

  WOW.portrait = { render, builder, randomParams };
})(window.WOW);
