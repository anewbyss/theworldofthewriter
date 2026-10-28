// Gear, curses & blessings management; intentional paradoxes; heredity traits
// and the offspring calculator.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store } = WOW;
  const V = WOW.views;

  const link = (col, id) => h("a", { href: `#/${col}/${id}` }, store.title(col, store.get(col, id)));
  const chip = (col, id, gold, note) => h("a.chip" + (gold ? ".gold" : ""), { href: `#/${col}/${id}`, title: note || "" }, store.title(col, store.get(col, id)), note ? h("span.muted", " · " + note) : null);
  const section = (title, ...body) => h("div", { style: { marginTop: "10px" } }, h("strong.small", title), ...body);
  const pct = (p) => `${Math.round(p * 1000) / 10}%`;

  // ---- What affects a character or place ------------------------------------
  function effectsOn(col, list, target) {
    // Returns [{ entry, via }] for curses or blessings touching a character or place.
    const out = [];
    for (const x of store.list(col)) {
      if (target.kind === "character") {
        const c = target.entity;
        if ((x.characters || []).includes(c.id)) out.push({ entry: x, via: "directly" });
        else if ((x.lineages || []).some((l) => (c.lineages || []).includes(l))) out.push({ entry: x, via: "through lineage " + (x.lineages || []).filter((l) => (c.lineages || []).includes(l)).map((l) => store.title("lineages", store.get("lineages", l))).join(", ") });
        else {
          const held = store.list("gear").filter((g) => g.owner === c.id && (x.gear || []).includes(g.id));
          if (held.length) out.push({ entry: x, via: "through " + held.map((g) => g.name || "gear").join(", ") });
        }
      } else {
        const p = target.entity;
        if ((x.places || []).includes(p.id)) out.push({ entry: x, via: "directly" });
        else {
          let id = p.parent;
          for (let i = 0; id && i < 25; i++) {
            if ((x.places || []).includes(id)) { out.push({ entry: x, via: "within " + store.title("places", store.get("places", id)) }); break; }
            id = store.get("places", id)?.parent;
          }
        }
      }
    }
    return out;
  }

  // A select of existing entries plus "new…", calling onPick(entity).
  function picker(col, placeholder, onPick, filter) {
    return h("select", { style: { maxWidth: "260px" }, onchange: (e) => {
      const v = e.target.value;
      e.target.value = "";
      if (!v) return;
      if (v === "__new") {
        const name = prompt(`Name the new ${store.byId[col].singular.toLowerCase()}:`);
        if (!name) return;
        onPick(store.create(col, { [store.byId[col].titleField]: name }));
      } else onPick(store.get(col, v));
    } },
      h("option", { value: "" }, placeholder),
      store.list(col).filter((x) => !filter || filter(x)).map((x) => h("option", { value: x.id }, store.title(col, x))),
      h("option", { value: "__new" }, "＋ New…"));
  }

  function inventoryPanel(c, rerender) {
    const gear = store.list("gear").filter((g) => g.owner === c.id);
    const curses = effectsOn("curses", null, { kind: "character", entity: c });
    const blessings = effectsOn("blessings", null, { kind: "character", entity: c });
    const add = (col, key, x) => { store.update(col, x.id, { [key]: [...new Set([...(x[key] || []), c.id])] }); rerender(); };
    return h("div.card.stack",
      h("h3", "Gear, curses & blessings"),
      section("Carrying", gear.length ? h("div.chips", gear.map((g) => chip("gear", g.id, true, g.rarity))) : h("p.small.muted", "Nothing yet."),
        picker("gear", "＋ Give gear…", (g) => {
          if (g.owner && g.owner !== c.id && !confirm(`${g.name} is held by ${store.title("characters", store.get("characters", g.owner))}. Move it?`)) return;
          store.update("gear", g.id, { owner: c.id });
          rerender();
        }, (g) => g.owner !== c.id)),
      section("Curses", curses.length ? h("div.stack.small", { style: { gap: "4px" } }, curses.map(({ entry, via }) => h("div", link("curses", entry.id), h("span.muted", ` — ${via}${entry.status && entry.status !== "active" ? " · " + entry.status : ""}`)))) : h("p.small.muted", "None."),
        picker("curses", "＋ Lay a curse…", (x) => add("curses", "characters", x))),
      section("Blessings", blessings.length ? h("div.stack.small", { style: { gap: "4px" } }, blessings.map(({ entry, via }) => h("div", link("blessings", entry.id), h("span.muted", ` — ${via}${entry.status && entry.status !== "active" ? " · " + entry.status : ""}`)))) : h("p.small.muted", "None."),
        picker("blessings", "＋ Bestow a blessing…", (x) => add("blessings", "characters", x))));
  }

  function placeInventoryPanel(p, rerender) {
    const gear = store.list("gear").filter((g) => g.location === p.id);
    const curses = effectsOn("curses", null, { kind: "place", entity: p });
    const blessings = effectsOn("blessings", null, { kind: "place", entity: p });
    const add = (col, x) => { store.update(col, x.id, { places: [...new Set([...(x.places || []), p.id])] }); rerender(); };
    return h("div.card.stack",
      h("h3", "Kept here, cursed & blessed"),
      section("Gear kept here", gear.length ? h("div.chips", gear.map((g) => chip("gear", g.id, true))) : h("p.small.muted", "Nothing."),
        picker("gear", "＋ Store gear here…", (g) => { store.update("gear", g.id, { location: p.id }); rerender(); })),
      section("Curses", curses.length ? h("div.stack.small", curses.map(({ entry, via }) => h("div", link("curses", entry.id), h("span.muted", " — " + via)))) : h("p.small.muted", "None."), picker("curses", "＋ Curse this place…", (x) => add("curses", x))),
      section("Blessings", blessings.length ? h("div.stack.small", blessings.map(({ entry, via }) => h("div", link("blessings", entry.id), h("span.muted", " — " + via)))) : h("p.small.muted", "None."), picker("blessings", "＋ Bless this place…", (x) => add("blessings", x))));
  }

  function gearPanel(g) {
    const trail = WOW.continuity.orderedEvents(store.state.data).filter((ev) => ev.item === g.id);
    const curses = store.list("curses").filter((x) => (x.gear || []).includes(g.id));
    const blessings = store.list("blessings").filter((x) => (x.gear || []).includes(g.id));
    return h("div.card.stack",
      h("h3", "Custody & enchantments"),
      section("Now", h("div.small", g.owner ? ["Held by ", link("characters", g.owner)] : "Not held by anyone", g.location ? [" · kept at ", link("places", g.location)] : null)),
      (g.powers || []).length ? section("Grants", h("div.chips", g.powers.map((id) => chip("abilities", id)))) : null,
      curses.length ? section("Curses on it", h("div.chips", curses.map((x) => chip("curses", x.id)))) : null,
      blessings.length ? section("Blessings on it", h("div.chips", blessings.map((x) => chip("blessings", x.id, true)))) : null,
      section("Chain of custody (timeline)", trail.length ? h("ol.small", trail.map((ev) => h("li", link("events", ev.id), h("span.muted", ` · ${ev.type || "event"}${ev.timeline ? " · " + ev.timeline : ""}`), (ev.characters || []).length ? [" — ", (ev.characters || []).map((id, i) => [i ? ", " : "", link("characters", id)])] : null)))
        : h("p.small.muted", "Add timeline events of type “gains item” / “loses item” with this gear to trace who held it when.")),
      h("button.ghost.small", { onclick: () => { const ev = store.create("events", { title: "", type: "gains item", item: g.id }); location.hash = `#/events/${ev.id}`; } }, "＋ Custody event"));
  }

  function effectPanel(col, x) {
    const direct = (x.characters || []).filter((id) => store.get("characters", id));
    const viaLineage = store.list("characters").filter((c) => !direct.includes(c.id) && (x.lineages || []).some((l) => (c.lineages || []).includes(l)));
    const viaGear = store.list("gear").filter((g) => (x.gear || []).includes(g.id) && g.owner).map((g) => [g.owner, g]);
    const evType = col === "curses" ? "curse" : "blessing";
    const events = WOW.continuity.orderedEvents(store.state.data).filter((ev) => ev[evType] === x.id);
    return h("div.card.stack",
      h("h3", col === "curses" ? "Who and what is cursed" : "Who and what is blessed"),
      direct.length ? section("Directly", h("div.chips", direct.map((id) => chip("characters", id, true)))) : null,
      viaLineage.length ? section("Through their lineage", h("div.chips", viaLineage.map((c) => chip("characters", c.id)))) : null,
      viaGear.length ? section("Through gear they hold", h("div.chips", viaGear.map(([cid, g]) => chip("characters", cid, false, g.name)))) : null,
      (x.places || []).length ? section("Places", h("div.chips", x.places.map((id) => chip("places", id)))) : null,
      !direct.length && !viaLineage.length && !viaGear.length && !(x.places || []).length ? h("p.small.muted", "Not on anyone or anything yet.") : null,
      section("On the timeline", events.length ? h("ol.small", events.map((ev) => h("li", link("events", ev.id), h("span.muted", ` · ${ev.type}`)))) : h("p.small.muted", "No events yet."),
        h("button.ghost.small", { onclick: () => { const ev = store.create("events", { title: "", type: col === "curses" ? "cursed" : "blessed", [evType]: x.id, characters: direct.slice(0, 1) }); location.hash = `#/events/${ev.id}`; } }, "＋ Event")));
  }

  // ---- Paradoxes -----------------------------------------------------------
  function markParadox(issue, rerender) {
    return picker("paradoxes", "∞ Intentional paradox…", (p) => {
      const add = (key, ids) => [...new Set([...(p[key] || []), ...ids])];
      const of = (col) => issue.refs.filter(([c]) => c === col).map(([, id]) => id);
      store.update("paradoxes", p.id, {
        issueKeys: add("issueKeys", [issue.key]), status: p.status || "intentional", scope: p.scope || "only the notes I mark",
        characters: add("characters", of("characters")), events: add("events", of("events")), places: add("places", of("places")), abilities: add("abilities", of("abilities")),
      });
      WOW.toast("Marked as part of the story");
      rerender();
    });
  }

  function paradoxPanel(p) {
    const covered = WOW.continuity.check(store.state.data).filter((i) => i.paradox === p.id);
    return h("div.card.stack",
      h("h3", "What this paradox explains"),
      covered.length ? h("div.stack", covered.map((i) => h("div.warn.info.small", i.message))) : h("p.small.muted", "No continuity notes yet. Mark them from Timeline & Continuity, or set “What it covers” to include every note involving its linked entries."),
      h("p.tiny.muted", "Paradoxes never break anything — they just move matching notes out of the warnings list."));
  }

  function issueKeysField(v, set) {
    const all = Object.fromEntries(WOW.continuity.check(store.state.data).map((i) => [i.key, i]));
    let cur = [...(v || [])];
    const wrap = h("div.stack", { style: { gap: "6px" } });
    const draw = () => wrap.replaceChildren(
      ...(cur.length ? cur.map((k) => h("div.row.spread.small", { style: { flexWrap: "nowrap" } },
        h("span", all[k] ? all[k].message : h("span.muted", "(no longer happening) " + k)),
        h("button.ghost.small", { type: "button", onclick: () => { cur = cur.filter((x) => x !== k); set(cur); draw(); } }, "×")))
        : [h("p.small.muted", "Mark notes from Timeline & Continuity.")]),
      h("a.small", { href: "#/continuity" }, "Open Timeline & Continuity →"));
    draw();
    return wrap;
  }

  // ---- Heredity: genome editor ---------------------------------------------
  function genomeField(entity, set) {
    const traits = store.list("traits");
    if (!traits.length) return h("div.small.muted", "No heredity traits yet. ", h("a", { href: "#/traits" }, "Create traits →"));
    let cur = { ...(entity.genome || {}) };
    return h("div.stack", { style: { gap: "8px" } },
      h("table.small", traits.map((t) => {
        let control;
        if (t.mode === "polygenic (number)") {
          control = h("input", { type: "number", value: cur[t.id] ?? "", placeholder: `${t.min ?? ""}–${t.max ?? ""} ${t.unit || ""}`, style: { maxWidth: "160px" },
            oninput: (e) => { cur = { ...cur, [t.id]: e.target.value === "" ? null : Number(e.target.value) }; set(cur); } });
        } else {
          control = h("select", { style: { maxWidth: "320px" }, onchange: (e) => { cur = { ...cur, [t.id]: e.target.value || null }; set(cur); } },
            h("option", { value: "" }, "—"),
            WOW.heredity.options(t, entity.heredityChromosomes).map(([val, lab]) => h("option", { value: val, selected: cur[t.id] === val || null }, lab)));
        }
        return h("tr", h("td", h("a", { href: `#/traits/${t.id}` }, t.name || "Trait"), h("div.tiny.muted", t.mode || "")), h("td", control));
      })),
      h("a.small", { href: `#/offspring?a=${entity.id}` }, "🧬 Offspring calculator with this character →"));
  }

  // ---- Heredity: traits page extras ------------------------------------------
  WOW.traitTemplates = () => h("details.card",
    h("summary", "Start from a template"),
    h("p.small.muted", "Simple, fictional rules to build on. Real human traits such as skin or eye colour come from many genes — no single trait defines a people, and race is not a genetic category."),
    h("div.grid", REF.traitTemplates.map((t) => h("div.card",
      h("h3", t.name), h("div.tiny.muted", t.mode), h("p.small", t.description),
      h("button.ghost.small", { onclick: () => { const made = store.create("traits", { ...t }); location.hash = `#/traits/${made.id}`; } }, "＋ Add")))));

  // ---- Offspring calculator --------------------------------------------------
  function related(aId, bId) {
    if (!aId || !bId) return null;
    if (aId === bId) return "These are the same person — a bootstrap paradox is allowed, but the maths treats them as two copies.";
    const anc = (id) => {
      const out = new Set(), stack = [...(store.get("characters", id)?.parents || [])];
      while (stack.length) { const x = stack.pop(); if (out.has(x)) continue; out.add(x); stack.push(...(store.get("characters", x)?.parents || [])); }
      return out;
    };
    const A = anc(aId), B = anc(bId);
    if (A.has(bId) || B.has(aId)) return "One parent is an ancestor of the other (perhaps through time travel). The calculator still runs.";
    if ([...A].some((x) => B.has(x))) return "These parents share an ancestor.";
    return null;
  }

  V.offspring = (params) => {
    let aId = params.get("a") || "", bId = params.get("b") || "";
    const out = h("div.stack");
    const chars = store.list("characters");
    const sel = (cur, on) => h("select", { style: { maxWidth: "280px" }, onchange: (e) => on(e.target.value) }, h("option", { value: "" }, "— choose a parent —"), chars.map((c) => h("option", { value: c.id, selected: c.id === cur || null }, c.name || "Unnamed")));
    const lineParent = {};
    const draw = () => {
      const A = store.get("characters", aId), B = store.get("characters", bId);
      if (!A || !B) { out.replaceChildren(h("div.empty", "Choose two parents.")); return; }
      const traits = store.list("traits");
      const gA = A.genome || {}, gB = B.genome || {};
      const rel = related(aId, bId);
      const rows = traits.map((t) => {
        const r = WOW.heredity.predict(t, gA[t.id], gB[t.id], A.heredityChromosomes, B.heredityChromosomes, { lineParent: lineParent[t.id] || 1 });
        let body;
        if (r.kind === "number") body = h("div.small", `Expected about `, h("strong", `${Math.round(r.mean * 10) / 10} ${r.unit}`), ` — 80% of children between ${Math.round(r.low * 10) / 10} and ${Math.round(r.high * 10) / 10} ${r.unit}`);
        else if (r.kind === "unavailable") body = h("div.small.muted", r.note);
        else body = h("div.stack", { style: { gap: "4px" } }, r.outcomes.map(([lab, p]) => h("div", h("div.row.spread.small", h("span", lab), h("strong", pct(p))), h("div.meter", h("span", { style: { width: Math.round(p * 100) + "%" } })))),
          r.kind === "mendel" ? h("div.tiny.muted", `Genotypes: TT ${pct(r.genotypes.TT)} · To ${pct(r.genotypes.To)} · oo ${pct(r.genotypes.oo)}`) : null,
          r.kind === "x" ? h("div.tiny.muted", `XX children — TT ${pct(r.daughters.TT)}, To ${pct(r.daughters.To)} (carriers), oo ${pct(r.daughters.oo)}; XY children — ${pct(r.sons.T)} carry it`) : null);
        const lineToggle = t.mode === "one parent line" ? h("label.row.tiny", "Line passes through ",
          h("select", { style: { width: "auto" }, onchange: (e) => { lineParent[t.id] = Number(e.target.value); draw(); } },
            h("option", { value: 1, selected: (lineParent[t.id] || 1) === 1 || null }, A.name || "Parent 1"), h("option", { value: 2, selected: lineParent[t.id] === 2 || null }, B.name || "Parent 2"))) : null;
        return h("div.card",
          h("div.row.spread", h("h3", t.name || "Trait"), h("span.chip", t.mode || "")),
          h("div.tiny.muted", `${A.name || "Parent 1"}: ${gA[t.id] ?? "unset"} · ${B.name || "Parent 2"}: ${gB[t.id] ?? "unset"}${t.penetrance != null && t.penetrance !== "" && Number(t.penetrance) < 100 ? ` · manifests in ${t.penetrance}% of those who inherit it` : ""}`),
          lineToggle, body,
          t.ability && r.manifest ? h("div.small", "Manifesting grants ", link("abilities", t.ability)) : null);
      });

      // Lineages, cultural inheritance, generational curses & blessings
      const lineages = [...new Set([...(A.lineages || []), ...(B.lineages || [])])].map((id) => store.get("lineages", id)).filter(Boolean);
      const childLineages = new Set(lineages.map((l) => l.id));
      const generational = (col) => store.list(col).filter((x) => (x.lineages || []).some((l) => childLineages.has(l)));
      const cultural = (key, col) => [...new Set([...(A[key] || []), ...(B[key] || [])])].map((id) => chip(col, id));

      const count = h("input", { type: "number", min: 1, max: 12, value: 3, style: { width: "80px" } });
      const sims = h("div.stack");
      const simulate = () => {
        const n = Math.max(1, Math.min(12, Number(count.value) || 1));
        const kids = [];
        for (let i = 0; i < n; i++) {
          const xx = (A.heredityChromosomes === "XX" && B.heredityChromosomes === "XY") || (A.heredityChromosomes === "XY" && B.heredityChromosomes === "XX");
          const childChrom = xx ? (Math.random() < 0.5 ? "XX" : "XY") : "";
          const res = traits.map((t) => [t, WOW.heredity.sample(t, gA[t.id], gB[t.id], A.heredityChromosomes, B.heredityChromosomes, childChrom, { lineParent: lineParent[t.id] || 1 })]);
          kids.push({ childChrom, res });
        }
        sims.replaceChildren(h("table.small",
          h("tr", h("th", "#"), xxHeader(), ...traits.map((t) => h("th", t.name || "Trait")), h("th", "")),
          kids.map((k, i) => h("tr",
            h("td", i + 1), h("td", k.childChrom || "—"),
            ...k.res.map(([, r]) => h("td", r.manifests ? h("strong", r.label) : r.label)),
            h("td", h("button.ghost.small", { onclick: () => createChild(k) }, "Create"))))));
      };
      const xxHeader = () => h("th", "Chromosomes");
      const createChild = (k) => {
        const genome = Object.fromEntries(k.res.map(([t, r]) => [t.id, r.value]));
        const abilities = [...new Set(k.res.filter(([t, r]) => r.manifests && t.ability).map(([t]) => t.ability))];
        const pa = A.portrait || {}, pb = B.portrait || {};
        const skins = REF.portrait.skinTones.length;
        const skin = Math.max(0, Math.min(skins - 1, Math.round(((pa.skin ?? 3) + (pb.skin ?? 3)) / 2) + WOW.pick([-1, 0, 0, 1])));
        const portrait = { ...WOW.portrait.randomParams(), skin, hairColor: WOW.pick([pa.hairColor ?? 0, pb.hairColor ?? 0]), hair: WOW.pick([pa.hair || "coils", pb.hair || "coils"]) };
        const chosen = [...out.querySelectorAll("input[data-lineage]:checked")].map((x) => x.dataset.lineage);
        const made = store.create("characters", {
          name: "", parents: [A.id, B.id], genome, heredityChromosomes: k.childChrom || null, abilities, lineages: chosen,
          peoples: [...new Set([...(A.peoples || []), ...(B.peoples || [])])], portrait, tags: ["offspring"],
        });
        location.hash = `#/characters/${made.id}`;
      };

      out.replaceChildren(
        rel ? h("div.warn.info", rel) : null,
        traits.length ? h("div.grid.wide", rows) : h("div.empty", "No heredity traits yet. ", h("a", { href: "#/traits" }, "Create or add template traits"), ", then set each parent's genome on their character page."),
        h("div.grid.wide",
          h("div.card", h("h3", "Lineages the child may join"),
            lineages.length ? h("div.stack.small", lineages.map((l) => h("label.row", h("input", { type: "checkbox", checked: true, "data-lineage": l.id }), link("lineages", l.id), h("span.muted", l.inheritance ? ` · ${l.inheritance}` : "")))) : h("p.small.muted", "Neither parent belongs to a lineage."),
            h("p.tiny.muted", "Untick lineages the child shouldn't join under your world's rules.")),
          h("div.card", h("h3", "Generational curses & blessings"),
            generational("curses").length || generational("blessings").length
              ? h("div.chips", generational("curses").map((x) => chip("curses", x.id, false, "curse")), generational("blessings").map((x) => chip("blessings", x.id, true, "blessing")))
              : h("p.small.muted", "None pass down through these lineages.")),
          h("div.card", h("h3", "Cultural inheritance"), h("p.tiny.muted", "Passed on by upbringing, not genes."),
            h("div.chips", cultural("peoples", "cultures"), cultural("religions", "religions"), cultural("languages", "languages")))),
        h("div.card", h("div.row.spread", h("h2", "Roll children"), h("div.row", count, h("button.gold", { onclick: simulate }, "🎲 Roll"))),
          h("p.small.muted", "Each roll is random within the odds above. Bold traits manifest. “Create” makes the child, with parents, genome, lineages and peoples filled in."),
          sims));
    };
    const head = h("div.page-head", h("div", h("div.eyebrow", "Heredity"), h("h1", "Offspring calculator"),
      h("p.muted", "Fictional heredity for your characters' children: Punnett-style odds, awakenings, X-linked traits, blended numbers, family lines and the spirits' choice.")));
    const pickers = h("div.card.row", h("span", "Parent 1"), sel(aId, (v) => { aId = v; draw(); }), h("span", "Parent 2"), sel(bId, (v) => { bId = v; draw(); }));
    draw();
    return h("div.stack", head,
      h("div.warn.info.small", "Simplified, fictional rules — not real human genetics. Real traits like skin and eye colour come from many genes, and race is not a genetic category."),
      pickers, out);
  };

  // ---- Panels registry -------------------------------------------------------
  WOW.heirloomPanels = (col, e, rerender) => {
    switch (col) {
      case "characters": return [inventoryPanel(e, rerender)];
      case "places": return [placeInventoryPanel(e, rerender)];
      case "gear": return [gearPanel(e)];
      case "curses": return [effectPanel("curses", e)];
      case "blessings": return [effectPanel("blessings", e)];
      case "paradoxes": return [paradoxPanel(e)];
      default: return [];
    }
  };

  Object.assign(WOW, { markParadox, issueKeysField, genomeField });
})(window.WOW);
