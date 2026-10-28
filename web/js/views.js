// Every page of the app. Each view returns a DOM node for #view.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store } = WOW;
  const V = {};

  const culture = (id) => REF.culturePools.find((p) => p.id === id);
  const styleOf = (id) => REF.narrativeStyles.find((s) => s.id === id);

  function head(eyebrow, title, sub, ...actions) {
    return h("div.page-head",
      h("div", h("div.eyebrow", eyebrow), h("h1", title), sub ? h("p.muted", sub) : null),
      h("div.row.no-print", ...actions));
  }

  function subtitle(col, e) {
    switch (col) {
      case "characters": return [e.role, e.status, (e.cultures || []).map((c) => culture(c)?.region).join(", ")].filter(Boolean).join(" · ");
      case "origins": return [e.kind, e.place].filter(Boolean).join(" · ");
      case "works": return [e.medium, e.status, e.order != null ? `#${e.order}` : null].filter(Boolean).join(" · ");
      case "storylines": return [store.displayValue({ type: "ref", collection: "works" }, e.work), styleOf(e.style)?.name].filter(Boolean).join(" · ");
      case "events": return [e.when, e.type, store.displayValue({ type: "ref", collection: "works" }, e.work)].filter(Boolean).join(" · ");
      case "research": return [e.kind, e.source].filter(Boolean).join(" · ");
      case "places": return [e.kind, e.realm, e.era, store.get("places", e.parent) ? "in " + store.title("places", store.get("places", e.parent)) : null].filter(Boolean).join(" · ");
      case "maps": return [e.scale, WOW.maps.styleOf(e.mapStyle).name, e.era].filter(Boolean).join(" · ");
      case "powerSystems": return [e.kind, e.hardness].filter(Boolean).join(" · ");
      case "gear": return [e.kind, e.rarity, store.get("characters", e.owner) ? "held by " + store.title("characters", store.get("characters", e.owner)) : null].filter(Boolean).join(" · ");
      case "curses": return [e.kind, e.severity, e.status].filter(Boolean).join(" · ");
      case "blessings": return [e.kind, e.strength, e.status].filter(Boolean).join(" · ");
      case "traits": return [e.kind, e.mode].filter(Boolean).join(" · ");
      case "paradoxes": return [e.kind, e.status].filter(Boolean).join(" · ");
      case "factions": return [e.kind, e.status, store.get("places", e.seat) ? "seat: " + store.title("places", store.get("places", e.seat)) : null].filter(Boolean).join(" · ");
      case "rivalries": return [e.kind, e.intensity, e.status].filter(Boolean).join(" · ");
      case "conflicts": return [e.kind, e.status, e.start != null && e.start !== "" ? `#${e.start}${e.end != null && e.end !== "" ? "–" + e.end : "–"}` : e.era].filter(Boolean).join(" · ");
      case "bonds": return [(e.tradition || []).map((id) => WOW.refdata.label("kinship", id)).join(", "), e.status].filter(Boolean).join(" · ");
      case "labels": return [e.kind, e.field, e.color].filter(Boolean).join(" · ");
      case "lineages": return [e.kind, e.inheritance].filter(Boolean).join(" · ");
      case "cultures": return [e.kind, (e.realPeoples || []).map((id) => WOW.refdata.label("peoples", id)).join(", ")].filter(Boolean).join(" · ");
      case "religions": return [e.kind, (e.basedOn || []).map((id) => WOW.refdata.label("religions", id)).join(", ")].filter(Boolean).join(" · ");
      case "languages": return [e.kind, (e.basedOn || []).map((id) => WOW.refdata.label("languages", id)).join(", ")].filter(Boolean).join(" · ");
      case "abilities": return [e.category, store.get("powerSystems", e.system)?.name, e.rank].filter(Boolean).join(" · ");
      case "links": return `${store.anyTitle(e.from)} → ${store.anyTitle(e.to)}`;
      default: return "";
    }
  }

  function snippet(col, e) {
    return store.textOf(col, e).replace(/\s+/g, " ").slice(0, 220);
  }

  function entityCard(col, e) {
    return h("a.card.link", { href: `#/${col}/${e.id}` },
      h("div.list-item",
        col === "characters" ? WOW.portrait.render(e.portrait, "mini-portrait") : null,
        col === "maps" ? WOW.maps.render(e, { className: "mini-map", layers: { decor: false, events: false } }) : null,
        h("div", { style: { minWidth: 0 } },
          h("h3", store.title(col, e)),
          h("div.tiny.muted", subtitle(col, e)))),
      h("div.snippet", { style: { marginTop: "8px" } }, snippet(col, e)),
      (e.tags || []).length ? h("div.chips", { style: { marginTop: "8px" }, onclick: (ev) => ev.stopPropagation() }, e.tags.slice(0, 6).map((t) => WOW.tagChip(t))) : null);
  }

  // ---- Dashboard -----------------------------------------------------------
  V.dashboard = () => {
    const counts = store.counts();
    const spark = WOW.pick(REF.sparkTables.storySpark);
    const quickTitle = h("input", { type: "text", placeholder: "Title" });
    const quickText = WOW.forms.autosize(h("textarea", { placeholder: "Catch the idea before it flies — type, dictate, or Scribble with your Pencil…" }));
    const lastExport = store.state.meta.lastExport;
    const dayMs = 86400000;

    return h("div.stack",
      head("Welcome back", "WOW Brainstorm", "Write, track, research and build continuity across every book and medium."),
      (!lastExport || Date.now() - Date.parse(lastExport) > 7 * dayMs) && Object.values(counts).some(Boolean)
        ? h("div.warn", "You haven't exported a backup ", lastExport ? "in over a week" : "yet", ". ", h("a", { href: "#/backup" }, "Back up now →"))
        : null,
      h("div.grid",
        store.collections.filter((c) => c.id !== "links").map((c) =>
          h("a.card.link.stat", { href: `#/${c.id}` }, h("div.num", counts[c.id]), h("div.muted", c.label)))),
      h("div.two-col",
        h("div.stack",
          h("div.card.accent",
            h("h2", "Quick capture"),
            h("div.stack", quickTitle, quickText,
              h("div.row",
                h("button", { onclick: () => {
                  if (!quickTitle.value && !quickText.value) return;
                  store.create("notes", { title: quickTitle.value || "Quick note", text: quickText.value, tags: ["capture"] });
                  quickTitle.value = ""; quickText.value = "";
                  WOW.toast("Saved to Ink Pages");
                } }, "Save note"),
                h("a.btn.ghost", { href: "#/notes/new" }, "✍️ Handwrite instead")))),
          h("div.card",
            h("h2", "Recently touched"),
            store.recent(8).length
              ? h("div.stack", store.recent(8).map(({ col, e }) =>
                h("a", { href: `#/${col}/${e.id}`, class: "row spread", style: { textDecoration: "none" } },
                  h("span", store.title(col, e)), h("span.chip", store.byId[col].singular))))
              : h("p.muted", "Nothing yet. Start with a character, a power, or a story spark."))),
        h("div.stack",
          h("div.card.violet",
            h("div.eyebrow", { style: { color: "var(--gold-500)" } }, "Story spark"),
            h("h3", { style: { fontFamily: "var(--serif)" } }, spark),
            h("p.muted.small", "From the dice tables — your job is to make it yours."),
            h("a.btn.gold.small", { href: "#/spark" }, "Roll more")),
          h("div.card",
            h("h3", "Explore"),
            h("div.stack",
              h("a", { href: "#/styles" }, "📜 Narrative styles from around the world"),
              h("a", { href: "#/atlas" }, "🌍 Culture & inspiration atlas"),
              h("a", { href: "#/continuity" }, "🧵 Timeline & continuity check"),
              h("a", { href: "#/graph" }, "🕸️ Connection web"),
              h("a", { href: "#/originality" }, "🔍 Originality checker"),
              h("a", { href: "#/bible" }, "📖 Series bible (print / PDF)"))))));
  };

  // ---- Collection list -----------------------------------------------------
  V.list = (col) => {
    const c = store.byId[col];
    const searchBox = h("input", { type: "search", placeholder: `Filter ${c.label.toLowerCase()}…`, style: { maxWidth: "320px" } });
    const tagSel = h("select", { style: { width: "auto" } }, h("option", { value: "" }, "All tags"),
      [...new Set(store.list(col).flatMap((e) => e.tags || []))].sort().map((t) => h("option", { value: t }, t)));
    const results = h("div.grid");
    const draw = () => {
      const q = searchBox.value.toLowerCase();
      const items = store.list(col).filter((e) =>
        (!q || (store.title(col, e) + " " + store.textOf(col, e)).toLowerCase().includes(q)) &&
        (!tagSel.value || (e.tags || []).includes(tagSel.value)));
      if (col === "works") items.sort((a, b) => (a.order ?? 1e9) - (b.order ?? 1e9));
      if (col === "events") items.splice(0, items.length, ...WOW.continuity.orderedEvents({ ...store.state.data, events: items }));
      results.replaceChildren(...(items.length ? items.map((e) => entityCard(col, e))
        : [h("div.empty", { style: { gridColumn: "1/-1" } }, store.list(col).length ? "No matches." : `No ${c.label.toLowerCase()} yet.`)]));
    };
    searchBox.addEventListener("input", draw);
    tagSel.addEventListener("change", draw);
    draw();

    const extra = {
      abilities: h("a.btn.ghost", { href: "#/spark" }, "🎲 Ability dice"),
      storylines: h("a.btn.ghost", { href: "#/styles" }, "📜 Pick a style"),
      events: h("a.btn.ghost", { href: "#/continuity" }, "🧵 Continuity"),
      links: h("a.btn.ghost", { href: "#/graph" }, "🕸️ Web view"),
      research: h("a.btn.ghost", { href: "#/atlas" }, "🌍 Atlas"),
      places: h("a.btn.ghost", { href: "#/maps" }, "🗺️ Maps"),
      traits: h("a.btn.ghost", { href: "#/offspring" }, "🧬 Offspring calculator"),
      paradoxes: h("a.btn.ghost", { href: "#/continuity" }, "🧵 Continuity"),
      conflicts: h("a.btn.ghost", { href: "#/continuity" }, "🧵 Eras on the timeline"),
      religions: h("a.btn.ghost", { href: "#/faiths" }, "📿 Faiths library"),
      languages: h("a.btn.ghost", { href: "#/tongues" }, "🔤 Languages library"),
      cultures: h("a.btn.ghost", { href: "#/atlas" }, "🌍 Atlas"),
      maps: h("a.btn.ghost", { href: "#/places" }, "📍 Places"),
    }[col];

    return h("div.stack",
      head("Library", c.label, null, extra, h("a.btn", { href: `#/${col}/new` }, `＋ New ${c.singular.toLowerCase()}`)),
      col === "powerSystems" ? WOW.powerRoots() : null,
      col === "traits" ? WOW.traitTemplates() : null,
      h("div.row", searchBox, tagSel),
      results);
  };

  // ---- Entity editor -------------------------------------------------------
  V.entity = (col, id, rerender, params) => {
    const c = store.byId[col];
    const e = store.get(col, id);
    if (!e) return h("div.empty", "This entry no longer exists. ", h("a", { href: `#/${col}` }, "Back"));
    if (col === "maps") return mapPage(e, rerender, params || new URLSearchParams());

    const side = h("div.stack.sticky");
    const checkable = CHECKABLE.includes(col);
    if (col === "places") side.appendChild(placePanel(e));
    if (col === "characters") side.appendChild(journeyPanel(e));
    WOW.worldPanels(col, e).forEach((p) => side.appendChild(p));
    WOW.heirloomPanels(col, e, rerender).forEach((p) => side.appendChild(p));
    WOW.kinPanels(col, e, rerender).forEach((p) => side.appendChild(p));
    WOW.conflictPanels(col, e).forEach((p) => side.appendChild(p));
    if (checkable) side.appendChild(originalityPanel(col, e));
    side.appendChild(connectionsPanel(col, e, rerender));
    if (col === "characters") side.appendChild(appearancesPanel(e));

    return h("div.stack",
      h("div.row.spread.no-print",
        h("a", { href: `#/${col}` }, `← ${c.label}`),
        h("div.row",
          col === "characters" ? h("a.btn.ghost.small", { href: `#/breakdown/${e.id}` }, "Character breakdown") : null,
          h("button.ghost.small", { onclick: () => {
            const copy = JSON.parse(JSON.stringify(e));
            delete copy.id;
            copy[c.titleField] = (copy[c.titleField] || "") + " (copy)";
            const made = store.create(col, copy);
            location.hash = `#/${col}/${made.id}`;
          } }, "Duplicate"),
          h("button.danger.small", { onclick: () => {
            if (confirm(`Delete "${store.title(col, e)}"? A snapshot is kept in Backups.`)) {
              store.snapshot("Before delete").then(() => { store.remove(col, id); location.hash = `#/${col}`; });
            }
          } }, "Delete"))),
      h("div.eyebrow", c.singular),
      h("div.two-col",
        h("div.card", WOW.forms.editor(col, e, rerender)),
        side));
  };

  const CHECKABLE = ["characters", "abilities", "powerSystems", "origins", "places", "storylines", "works"];

  function entityActions(col, e) {
    const c = store.byId[col];
    return h("div.row",
      h("button.ghost.small", { onclick: () => {
        const copy = JSON.parse(JSON.stringify(e));
        delete copy.id;
        copy[c.titleField] = (copy[c.titleField] || "") + " (copy)";
        const made = store.create(col, copy);
        location.hash = `#/${col}/${made.id}`;
      } }, "Duplicate"),
      h("button.danger.small", { onclick: () => {
        if (confirm(`Delete "${store.title(col, e)}"? A snapshot is kept in Backups.`)) {
          store.snapshot("Before delete").then(() => { store.remove(col, e.id); location.hash = `#/${col}`; });
        }
      } }, "Delete"));
  }

  function mapPage(m, rerender, params) {
    return h("div.stack",
      h("div.row.spread.no-print", h("a", { href: "#/maps" }, "← Maps"), entityActions("maps", m)),
      h("div.eyebrow", "Map · " + (m.scale || "region")),
      WOW.maps.designer(m, params, rerender),
      h("div.two-col",
        h("div.card", WOW.forms.editor("maps", m, rerender)),
        h("div.stack", connectionsPanel("maps", m, rerender))));
  }

  function placePanel(p) {
    const chain = [];
    let cur = store.get("places", p.parent);
    for (let i = 0; cur && i < 25; i++) { chain.unshift(cur); cur = store.get("places", cur.parent); }
    const children = store.list("places").filter((x) => x.parent === p.id);
    const maps = WOW.maps.mapsWithPlace(p.id);
    const detail = store.list("maps").filter((m) => m.place === p.id);
    const events = WOW.continuity.orderedEvents(store.state.data).filter((ev) => ev.place === p.id);
    const people = new Set(p.characters || []);
    store.list("characters").forEach((c) => { if (c.homeland === p.id) people.add(c.id); });
    events.forEach((ev) => (ev.characters || []).forEach((id) => people.add(id)));
    const feature = (m) => WOW.maps.canvasOf(m).features.find((f) => f.placeId === p.id);
    return h("div.card.stack",
      h("h3", "Place web"),
      chain.length ? h("div.small", "Within: ", chain.map((x, i) => [i ? " › " : "", h("a", { href: `#/places/${x.id}` }, store.title("places", x))])) : null,
      children.length ? h("div", h("strong.small", "Contains"), h("div.chips", children.map((x) => h("a.chip", { href: `#/places/${x.id}` }, store.title("places", x))))) : null,
      h("div", h("strong.small", "On maps"),
        maps.length || detail.length ? h("div.chips",
          maps.map((m) => h("a.chip.gold", { href: `#/maps/${m.id}?focus=${feature(m)?.id || ""}` }, "📍 " + (m.title || "Untitled"))),
          detail.map((m) => h("a.chip", { href: `#/maps/${m.id}` }, "🔍 " + (m.title || "Untitled") + " (detail)")))
          : h("p.small.muted", "Not on a map yet."),
        h("button.ghost.small", { onclick: () => {
          const made = store.create("maps", { title: (p.name || "Place") + " map", scale: "city", mapStyle: "wow", place: p.id, canvas: WOW.maps.emptyCanvas("city") });
          location.hash = `#/maps/${made.id}`;
        } }, "＋ New map of this place")),
      h("div", h("strong.small", "Events here"),
        events.length ? h("div.stack.small", { style: { gap: "4px" } }, events.map((ev) => h("a", { href: `#/events/${ev.id}` }, `${ev.sequence != null && ev.sequence !== "" ? "#" + ev.sequence + " " : ""}${ev.title || "Untitled"}`)))
          : h("p.small.muted", "No timeline events set here.")),
      people.size ? h("div", h("strong.small", "People"), h("div.chips", [...people].map((id) => h("a.chip.gold", { href: `#/characters/${id}` }, store.title("characters", store.get("characters", id)))))) : null);
  }

  function journeyPanel(c) {
    const stops = [];
    if (c.homeland && store.get("places", c.homeland)) stops.push({ place: c.homeland, label: "Home" });
    for (const ev of WOW.continuity.orderedEvents(store.state.data)) {
      if ((ev.characters || []).includes(c.id) && ev.place && store.get("places", ev.place)) stops.push({ place: ev.place, label: ev.title || "Untitled", ev });
    }
    const related = new Set();
    for (const s of stops) {
      let id = s.place;
      for (let i = 0; id && i < 25; i++) { related.add(id); id = store.get("places", id)?.parent; }
    }
    const maps = store.list("maps").filter((m) => WOW.maps.canvasOf(m).features.some((f) => related.has(f.placeId)));
    return h("div.card",
      h("h3", "Journey"),
      stops.length ? h("ol.small", stops.map((s) => h("li", h("a", { href: `#/places/${s.place}` }, store.title("places", store.get("places", s.place))), " — ", s.ev ? h("a", { href: `#/events/${s.ev.id}` }, s.label) : s.label)))
        : h("p.small.muted", "Give them a homeland and put timeline events at places to trace their journey."),
      maps.length ? h("div.chips", maps.map((m) => h("a.chip.gold", { href: `#/maps/${m.id}?journey=${c.id}` }, "🗺️ Trace on " + (m.title || "map")))) : null);
  }

  function othersFor(col, e) {
    const out = [];
    for (const c of store.collections) {
      if (!CHECKABLE.includes(c.id)) continue;
      for (const o of store.list(c.id)) {
        if (o.id === e.id) continue;
        out.push({ key: `${c.id}:${o.id}`, label: `${store.title(c.id, o)} (${c.singular})`, href: `#/${c.id}/${o.id}`, text: store.title(c.id, o) + " " + store.textOf(c.id, o) });
      }
    }
    return out;
  }

  function originalityPanel(col, e) {
    const out = h("div");
    const run = () => out.replaceChildren(resultView(WOW.originality.check(store.title(col, e) + " " + store.textOf(col, e), othersFor(col, e))));
    return h("div.card",
      h("div.row.spread", h("h3", "Originality"), h("button.gold.small", { onclick: run }, "Check")),
      h("p.tiny.muted", "Compares this entry with common tropes and your own work. A heuristic, not legal advice."),
      out);
  }

  function resultView(r) {
    return h("div.stack",
      r.score == null ? h("p.muted", r.label) : h("div",
        h("div.row.spread", h("span.score", r.score), h("strong", r.label)),
        h("div.meter", h("span", { style: { width: r.score + "%" } }))),
      r.representation.length ? h("div.stack", r.representation.map((m) =>
        h("div.warn.bad", h("strong", "Representation check: " + m.trope.name), h("div.small", m.trope.note)))) : null,
      r.tropeMatches.length ? h("div", h("strong.small", "Close to familiar tropes"),
        h("div.stack", { style: { gap: "6px", marginTop: "6px" } }, r.tropeMatches.map((m) =>
          h("div.small", h("span.chip", Math.round(m.sim * 100) + "%"), " ", m.trope.name,
            m.matched.length ? h("span.muted", " — matched: " + m.matched.join(", ")) : null)))) : null,
      r.ownMatches.length ? h("div", h("strong.small", "Echoes of your own entries"),
        h("div.stack", { style: { gap: "6px", marginTop: "6px" } }, r.ownMatches.map((m) =>
          h("div.small", h("span.chip", Math.round(m.sim * 100) + "%"), " ", h("a", { href: m.href }, m.label),
            m.shared.length ? h("span.muted", " — shared: " + m.shared.join(", ")) : null)))) : null,
      h("div", h("strong.small", "Ways to twist it"),
        h("ul.small", r.suggestions.map((s) => h("li", s)))));
  }

  function connectionsPanel(col, e, rerender) {
    const me = `${col}:${e.id}`;
    const links = store.list("links").filter((l) => l.from === me || l.to === me);
    const label = h("input", { type: "text", placeholder: "Relationship (e.g. rival, teacher of, inspired by)" });
    const typeSel = h("select", { onchange: () => fill() },
      store.collections.filter((c) => c.id !== "links").map((c) => h("option", { value: c.id, selected: c.id === "characters" || null }, c.singular)));
    const target = h("select");
    const fill = () => target.replaceChildren(...store.list(typeSel.value).filter((x) => x.id !== e.id)
      .map((x) => h("option", { value: x.id }, store.title(typeSel.value, x))));
    fill();
    return h("div.card",
      h("h3", "Connections"),
      links.length ? h("div.stack", { style: { gap: "6px" } }, links.map((l) => {
        const other = l.from === me ? l.to : l.from;
        const [oc, oid] = (other || ":").split(":");
        return h("div.row.spread.small",
          h("span", l.from === me ? "→ " : "← ", h("em", l.label || "linked"), " ", h("a", { href: `#/${oc}/${oid}` }, store.anyTitle(other))),
          h("a.tiny", { href: `#/links/${l.id}` }, "edit"));
      })) : h("p.small.muted", "No connections yet."),
      h("details", h("summary.small", "＋ Add connection"),
        h("div.stack", { style: { marginTop: "8px" } }, label, typeSel, target,
          h("button.small", { onclick: () => {
            if (!target.value) return;
            store.create("links", { from: me, to: `${typeSel.value}:${target.value}`, label: label.value || "connected to" });
            rerender();
          } }, "Connect"))));
  }

  function appearancesPanel(e) {
    const works = (e.works || []).map((id) => store.get("works", id)).filter(Boolean).sort((a, b) => (a.order ?? 1e9) - (b.order ?? 1e9));
    const events = WOW.continuity.orderedEvents(store.state.data).filter((ev) => (ev.characters || []).includes(e.id));
    return h("div.card",
      h("h3", "Across your media"),
      works.length ? h("div.chips", works.map((w) => h("a.chip.gold", { href: `#/works/${w.id}` }, `${w.order != null ? "#" + w.order + " " : ""}${w.title}`))) : h("p.small.muted", "Not in any work yet."),
      events.length ? h("div.stack.small", { style: { marginTop: "10px", gap: "4px" } }, events.map((ev) =>
        h("a", { href: `#/events/${ev.id}` }, `${ev.when ? ev.when + " — " : ""}${ev.title}${ev.type && ev.type !== "event" ? " (" + ev.type + ")" : ""}`))) : null);
  }

  // ---- Character breakdown (printable) ------------------------------------
  V.breakdown = (id) => {
    const e = store.get("characters", id);
    if (!e) return h("div.empty", "Character not found.");
    const f = (key) => store.byId.characters.fields.find((x) => x.key === key);
    const row = (key) => {
      const val = store.displayValue(f(key), e[key]);
      return val ? h("section", h("h3", f(key).label), h("p", { style: { whiteSpace: "pre-wrap" } }, val)) : null;
    };
    const abilities = (e.abilities || []).map((a) => store.get("abilities", a)).filter(Boolean);
    const origin = store.get("origins", e.origin);
    return h("div.stack.bible",
      h("div.row.spread.no-print", h("a", { href: `#/characters/${id}` }, "← Back to editor"), h("button", { onclick: () => print() }, "Print / save PDF")),
      h("div.card",
        h("div.row", { style: { alignItems: "flex-start", gap: "20px" } },
          h("div", { style: { width: "180px" } }, WOW.portrait.render(e.portrait)),
          h("div", { style: { flex: 1, minWidth: "240px" } },
            h("div.eyebrow", "Character breakdown"),
            h("h1", e.name || "Unnamed"),
            e.aliases ? h("p.muted", e.aliases) : null,
            h("p", subtitle("characters", e)),
            e.universe ? h("p.small", "World: ", e.universe) : null)),
        ["homeland", "personality", "motivation", "wound", "contradiction", "arc", "community", "appearance", "voice"].map(row),
        origin ? h("section", h("h3", "Origin — " + origin.name), h("p", { style: { whiteSpace: "pre-wrap" } }, origin.description || "")) : null,
        abilities.length ? h("section", h("h3", "Abilities"), abilities.map((a) => h("div", { style: { marginBottom: "10px" } },
          h("strong", a.name), a.category ? h("span.muted", " · " + a.category) : null,
          a.description ? h("p", a.description) : null,
          a.limits ? h("p.small", h("em", "Limits: "), a.limits) : null,
          a.cost ? h("p.small", h("em", "Cost: "), a.cost) : null))) : null,
        ["works", "inspiration", "notes"].map(row)));
  };

  // ---- Narrative styles ----------------------------------------------------
  V.styles = () => {
    const regions = [...new Set(REF.narrativeStyles.map((s) => s.region))];
    return h("div.stack",
      head("Story shapes", "Narrative styles", "Structures from oral, theatrical and literary traditions worldwide. Euro-American forms are included only for comparison."),
      regions.map((r) => h("div.stack",
        h("h2", r),
        h("div.grid.wide", REF.narrativeStyles.filter((s) => s.region === r).map((s) =>
          h("a.card.link" + (s.region.includes("comparison") ? "" : ".accent"), { href: `#/styles/${s.id}` },
            h("h3", s.name), h("div.tiny.muted", s.origin), h("p.snippet", { style: { marginTop: "6px" } }, s.summary)))))));
  };

  V.style = (id) => {
    const s = styleOf(id);
    if (!s) return h("div.empty", "Unknown style.");
    const used = store.list("storylines").filter((x) => x.style === id);
    return h("div.stack",
      h("a.no-print", { href: "#/styles" }, "← Narrative styles"),
      head(s.region, s.name, s.origin,
        h("button.gold", { onclick: () => {
          const made = store.create("storylines", { title: `New ${s.name} storyline`, style: s.id, stages: {} });
          location.hash = `#/storylines/${made.id}`;
        } }, "Start a storyline with this style")),
      h("div.two-col",
        h("div.stack",
          h("div.card", h("p", s.summary), h("p.small", h("strong", "Good for: "), s.whenToUse)),
          s.care ? h("div.warn", h("strong", "Cultural care: "), s.care) : null,
          h("div.card", h("h2", "Beats"),
            h("div.stack", s.stages.map((st, i) => h("div.stage", h("strong", `${i + 1}. ${st.name}`), h("div.prompt", st.prompt)))))),
        h("div.stack",
          h("div.card", h("h3", "Learn from the source"), h("ul.small", s.sources.map((x) => h("li", x)))),
          h("div.card", h("h3", "Your storylines in this style"),
            used.length ? h("div.stack.small", used.map((u) => h("a", { href: `#/storylines/${u.id}` }, u.title || "Untitled"))) : h("p.small.muted", "None yet.")),
          s.id === "rasa" ? h("div.card", h("h3", "The nine rasas"), h("div.stack.small", REF.rasas.map((r) =>
            h("div.row", h("span", { style: { width: "12px", height: "12px", borderRadius: "50%", background: r.color, display: "inline-block" } }), h("strong", r.name), r.meaning)))) : null)));
  };

  // ---- Culture atlas -------------------------------------------------------
  V.atlas = () => h("div.stack",
    head("Information pools", "Culture & inspiration atlas", "Starting points for research — not a substitute for reading, listening, and crediting people from these cultures."),
    h("div.warn.info", "Each region lists storytelling forms, cosmology, power concepts, figures, crafts and further reading, plus a care note. Tap ＋ on anything to drop it into your Research Pool."),
    h("div.grid.wide", REF.culturePools.map((p) => h("a.card.link.accent", { href: `#/atlas/${p.id}` },
      h("h3", p.region), h("div.tiny.muted", p.peoples),
      h("p.snippet", { style: { marginTop: "6px" } }, p.powerConcepts.slice(0, 3).join(" · "))))));

  V.atlasRegion = (id) => {
    const p = culture(id);
    if (!p) return h("div.empty", "Unknown region.");
    const section = (title, items, kind) => h("div.card",
      h("h3", title),
      h("div.stack", { style: { gap: "6px" } }, items.map((it) => h("div.row.spread.small", { style: { flexWrap: "nowrap", alignItems: "flex-start" } },
        h("span", it),
        h("button.ghost.small", { title: "Add to Research Pool", onclick: () => {
          store.create("research", { title: it, kind: kind === "research" ? "book" : "other", cultures: [p.id], notes: `From the atlas — ${p.region}: ${title}.`, care: p.care, tags: [title.toLowerCase()] });
          WOW.toast("Added to Research Pool");
        } }, "＋")))));
    const mine = ["characters", "abilities", "powerSystems", "lineages", "origins", "cultures", "places", "research"].flatMap((col) =>
      store.list(col).filter((e) => (e.cultures || []).includes(id)).map((e) => ({ col, e })));
    return h("div.stack",
      h("a.no-print", { href: "#/atlas" }, "← Atlas"),
      head("Culture pool", p.region, p.peoples),
      h("div.warn", h("strong", "Care: "), p.care),
      h("div.grid.wide",
        section("Storytelling forms", p.storytelling),
        section("Cosmology & ideas", p.cosmology),
        section("Power concepts", p.powerConcepts),
        section("Figures (myth & history)", p.figures),
        section("Crafts & arts", p.crafts),
        section("Read & listen", p.research, "research")),
      h("div.grid.wide", WOW.atlasExtras(p)),
      h("div.card", h("h3", "Your entries rooted here"),
        mine.length ? h("div.chips", mine.map(({ col, e }) => h("a.chip.gold", { href: `#/${col}/${e.id}` }, `${store.title(col, e)} · ${store.byId[col].singular}`)))
          : h("p.small.muted", "Tag characters, abilities, origins and sources with this culture to see them here.")));
  };

  // ---- Spark dice ----------------------------------------------------------
  V.spark = () => {
    const T = REF.sparkTables;
    const state = {};
    const block = (title, rows, save) => {
      const lines = h("div");
      const draw = () => lines.replaceChildren(...rows.map(([key, label]) => h("div.dice-line", { title: "Tap to re-roll", onclick: () => { state[key] = WOW.pick(T[key]); draw(); } },
        h("span.label", label), h("span.value", state[key]))));
      rows.forEach(([key]) => { state[key] = WOW.pick(T[key]); });
      draw();
      return h("div.card.accent",
        h("div.row.spread", h("h2", title),
          h("div.row", h("button.ghost.small", { onclick: () => { rows.forEach(([k]) => { state[k] = WOW.pick(T[k]); }); draw(); } }, "🎲 Roll all"),
            h("button.small", { onclick: save }, "Save as draft"))),
        lines);
    };
    return h("div.stack",
      head("Dice tables", "Spark", "Old-fashioned random tables to jolt your imagination. Tap any line to re-roll it. Nothing is written for you — they're prompts."),
      block("Ability", [["abilitySource", "Source"], ["abilityExpression", "Expressed"], ["abilityEffect", "Effect"], ["abilityCost", "Cost"]], () => {
        const made = store.create("abilities", { name: "New ability", description: `Comes from ${state.abilitySource}; ${state.abilityExpression}; ${state.abilityEffect}.`, cost: state.abilityCost, tags: ["spark"] });
        location.hash = `#/abilities/${made.id}`;
      }),
      block("Character", [["characterWant", "Wants"], ["characterWound", "Wound"], ["characterContradiction", "Contradiction"]], () => {
        const made = store.create("characters", { name: "New character", motivation: state.characterWant, wound: state.characterWound, contradiction: state.characterContradiction, portrait: WOW.portrait.randomParams(), tags: ["spark"] });
        location.hash = `#/characters/${made.id}`;
      }),
      block("Place", [["placeKind", "Place"], ["placeFeature", "Feature"], ["placeSecret", "Secret"], ["placeEra", "When"]], () => {
        const made = store.create("places", { name: "New place", description: `${state.placeKind[0].toUpperCase() + state.placeKind.slice(1)} ${state.placeFeature}.`, lore: `Secret: ${state.placeSecret}.`, era: state.placeEra, tags: ["spark"] });
        location.hash = `#/places/${made.id}`;
      }),
      block("Conflict", [["conflictCause", "Cause"], ["conflictStakes", "Stakes"], ["conflictTwist", "Twist"]], () => {
        const made = store.create("conflicts", { name: "New conflict", cause: state.conflictCause[0].toUpperCase() + state.conflictCause.slice(1) + ".", stakes: state.conflictStakes[0].toUpperCase() + state.conflictStakes.slice(1) + ".", memory: `Twist: ${state.conflictTwist}.`, status: "brewing", tags: ["spark"] });
        location.hash = `#/conflicts/${made.id}`;
      }),
      block("Story", [["storySpark", "Premise"]], () => {
        const made = store.create("storylines", { title: "New storyline", summary: state.storySpark, tags: ["spark"] });
        location.hash = `#/storylines/${made.id}`;
      }));
  };

  // ---- Originality ---------------------------------------------------------
  V.originality = () => {
    const ta = WOW.forms.autosize(h("textarea", { placeholder: "Paste or write an ability, character concept or storyline…", style: { minHeight: "160px" } }));
    const out = h("div");
    const table = h("div");
    return h("div.stack",
      head("Check yourself", "Originality checker", "Transparent word-overlap scoring against ~80 well-known tropes and everything in your own library. It shows exactly what matched so you can decide."),
      h("div.two-col",
        h("div.card.stack", ta, h("div.row", h("button.gold", { onclick: () => out.replaceChildren(resultView(WOW.originality.check(ta.value, othersFor(null, {})))) }, "Check text"))),
        h("div.card", out)),
      h("div.card",
        h("div.row.spread", h("h2", "Scan my whole library"), h("button.small", { onclick: () => {
          const rows = [];
          for (const col of CHECKABLE) {
            for (const e of store.list(col)) {
              const r = WOW.originality.check(store.title(col, e) + " " + store.textOf(col, e), othersFor(col, e));
              rows.push({ col, e, r });
            }
          }
          rows.sort((a, b) => (a.r.score ?? 101) - (b.r.score ?? 101));
          table.replaceChildren(rows.length ? h("table",
            h("tr", h("th", "Entry"), h("th", "Score"), h("th", "Closest")),
            rows.map(({ col, e, r }) => h("tr",
              h("td", h("a", { href: `#/${col}/${e.id}` }, store.title(col, e)), h("div.tiny.muted", store.byId[col].singular)),
              h("td", r.score ?? "—", h("div.tiny.muted", r.label)),
              h("td.small", [r.tropeMatches[0]?.trope.name, r.ownMatches[0]?.label].filter(Boolean).join(" · "),
                r.representation.length ? h("div.tiny", { style: { color: "var(--danger)" } }, "Representation check: " + r.representation.map((x) => x.trope.name).join(", ")) : null))))
            : h("p.muted", "Your library is empty."));
        } }, "Scan")),
        table));
  };

  // ---- Timeline & continuity ----------------------------------------------
  V.continuity = (rerender) => {
    const all = WOW.continuity.check(store.state.data);
    const issues = all.filter((i) => i.level !== "paradox");
    const paradoxNotes = all.filter((i) => i.level === "paradox");
    const events = WOW.continuity.orderedEvents(store.state.data);
    const workFilter = h("select", { style: { width: "auto" } }, h("option", { value: "" }, "All works"),
      store.list("works").map((w) => h("option", { value: w.id }, w.title)));
    const charFilter = h("select", { style: { width: "auto" } }, h("option", { value: "" }, "All characters"),
      store.list("characters").map((c) => h("option", { value: c.id }, c.name)));
    const tl = h("div.timeline");
    const draw = () => {
      const evs = events.filter((e) => (!workFilter.value || e.work === workFilter.value) && (!charFilter.value || (e.characters || []).includes(charFilter.value)));
      tl.replaceChildren(...(evs.length ? evs.map((ev) => h("div.tl-item", h("a.card.link", { href: `#/events/${ev.id}` },
        h("div.row.spread", h("strong", ev.title || "Untitled"), h("span.chip" + (ev.type === "death" ? "" : ".gold"), ev.type || "event")),
        h("div.tiny.muted", [ev.sequence != null ? "#" + ev.sequence : null, ev.when, store.displayValue({ type: "ref", collection: "works" }, ev.work)].filter(Boolean).join(" · ")),
        (ev.characters || []).length ? h("div.small", store.displayValue({ type: "refs", collection: "characters" }, ev.characters)) : null)))
        : [h("div.empty", "No events yet. Add births, deaths, meetings, reveals and battles to track continuity.")]));
    };
    workFilter.addEventListener("change", draw);
    charFilter.addEventListener("change", draw);
    draw();
    const lv = { bad: "warn bad", warn: "warn", info: "warn info" };
    return h("div.stack",
      head("Continuity", "Timeline & continuity", "One in-world timeline across every book, film, comic and game.", h("a.btn", { href: "#/events/new" }, "＋ New event")),
      h("div.two-col",
        h("div.stack", WOW.conflictSpans(), h("div.row", workFilter, charFilter), tl),
        h("div.card.sticky",
          h("h3", `Continuity check · ${issues.length} note${issues.length === 1 ? "" : "s"}`),
          issues.length ? h("div.stack", { style: { gap: "8px" } }, issues.map((i) => h("div", { class: lv[i.level] },
            h("div.small", i.message),
            h("div.chips", { style: { marginTop: "6px" } }, i.refs.map(([col, id]) => h("a.chip", { href: `#/${col}/${id}` }, store.title(col, store.get(col, id))))),
            WOW.continuity.PARADOX_RULES.has(i.rule) ? h("div", { style: { marginTop: "6px" } }, WOW.markParadox(i, rerender)) : null)))
            : h("p.small.muted", "No continuity problems found."),
          paradoxNotes.length ? h("details", { style: { marginTop: "12px" } },
            h("summary.small", `∞ Intentional paradoxes · ${paradoxNotes.length}`),
            h("div.stack", { style: { gap: "6px", marginTop: "6px" } }, paradoxNotes.map((i) => h("div.warn.info.small",
              h("a", { href: `#/paradoxes/${i.paradox}` }, store.title("paradoxes", store.get("paradoxes", i.paradox))), " — ", i.message)))) : null,
          h("p.tiny.muted", { style: { marginTop: "10px" } }, "Time loops, bilocation and bootstrap ancestry never break the app. Put alternate branches in an event's “Timeline / branch”, use “time travel” events, or mark notes as intentional paradoxes."))));
  };

  // ---- Connection web ------------------------------------------------------
  V.graph = () => {
    const implicitToggle = h("input", { type: "checkbox", checked: true });
    const holder = h("div");
    const colors = { characters: "#6C3DB0", abilities: "#E1AD01", origins: "#1E6F5C", places: "#D35400", maps: "#2A1640", powerSystems: "#B7791F", lineages: "#805AD5", gear: "#4A5568", bonds: "#DD6B20", factions: "#2D3748", rivalries: "#E53E3E", conflicts: "#742A2A", curses: "#9B2C2C", blessings: "#D69E2E", traits: "#38A169", paradoxes: "#6B46C1", cultures: "#2C7A7B", religions: "#C05621", languages: "#2B6CB0", works: "#A23B3B", storylines: "#1F3A5F", events: "#8C5A2B", research: "#38B2AC", notes: "#888" };
    const draw = () => {
      const nodes = new Map();
      const edges = [];
      const node = (col, id) => {
        const key = `${col}:${id}`;
        const e = store.get(col, id);
        if (!e) return null;
        if (!nodes.has(key)) nodes.set(key, { key, col, id, label: store.title(col, e), x: Math.random() * 800, y: Math.random() * 600, vx: 0, vy: 0 });
        return nodes.get(key);
      };
      for (const l of store.list("links")) {
        const [ac, ai] = (l.from || ":").split(":"), [bc, bi] = (l.to || ":").split(":");
        const a = node(ac, ai), b = node(bc, bi);
        if (a && b) edges.push({ a, b, explicit: true, label: l.label });
      }
      if (implicitToggle.checked) {
        for (const c of store.collections) {
          if (c.id === "links") continue;
          for (const e of store.list(c.id)) {
            for (const f of c.fields) {
              const targets = f.type === "ref" ? [e[f.key]] : f.type === "refs" ? e[f.key] || [] : [];
              for (const t of targets) {
                if (!t) continue;
                const a = node(c.id, e.id), b = node(f.collection, t);
                if (a && b) edges.push({ a, b, explicit: false });
              }
              if (f.type === "anyrefs") {
                for (const ref of e[f.key] || []) {
                  const [tc, tid] = ref.split(":");
                  const a = node(c.id, e.id), b = node(tc, tid);
                  if (a && b) edges.push({ a, b, explicit: false });
                }
              }
            }
          }
        }
      }
      if (implicitToggle.checked) {
        for (const m of store.list("maps")) {
          for (const f of WOW.maps.canvasOf(m).features) {
            const a = node("maps", m.id);
            const b = f.placeId ? node("places", f.placeId) : null;
            if (a && b) edges.push({ a, b, explicit: false });
            const d = f.mapId ? node("maps", f.mapId) : null;
            if (a && d) edges.push({ a, b: d, explicit: false });
          }
        }
      }
      const W = 900, H = 640;
      const ns = [...nodes.values()];
      // Simple force layout: repulsion + springs + centring.
      for (let it = 0; it < 300; it++) {
        for (let i = 0; i < ns.length; i++) for (let j = i + 1; j < ns.length; j++) {
          const a = ns[i], b = ns[j];
          let dx = a.x - b.x, dy = a.y - b.y; const d2 = dx * dx + dy * dy + 0.01;
          const f = 1800 / d2; const d = Math.sqrt(d2);
          dx /= d; dy /= d;
          a.vx += dx * f; a.vy += dy * f; b.vx -= dx * f; b.vy -= dy * f;
        }
        for (const e of edges) {
          const dx = e.b.x - e.a.x, dy = e.b.y - e.a.y; const d = Math.sqrt(dx * dx + dy * dy) || 1;
          const f = (d - 110) * 0.05;
          e.a.vx += dx / d * f; e.a.vy += dy / d * f;
          e.b.vx -= dx / d * f; e.b.vy -= dy / d * f;
        }
        for (const n of ns) {
          n.vx += (W / 2 - n.x) * 0.002; n.vy += (H / 2 - n.y) * 0.002;
          n.x += Math.max(-20, Math.min(20, n.vx)); n.y += Math.max(-20, Math.min(20, n.vy));
          n.vx *= 0.6; n.vy *= 0.6;
          n.x = Math.max(30, Math.min(W - 30, n.x)); n.y = Math.max(20, Math.min(H - 20, n.y));
        }
      }
      const s = WOW.svg("svg", { viewBox: `0 0 ${W} ${H}`, class: "graph" });
      for (const e of edges) {
        s.appendChild(WOW.svg("line", { x1: e.a.x, y1: e.a.y, x2: e.b.x, y2: e.b.y, class: e.explicit ? "explicit" : "" }));
        if (e.explicit && e.label) {
          const t = WOW.svg("text", { x: (e.a.x + e.b.x) / 2, y: (e.a.y + e.b.y) / 2 - 3, "text-anchor": "middle", opacity: 0.75 });
          t.textContent = e.label; s.appendChild(t);
        }
      }
      for (const n of ns) {
        const c = WOW.svg("circle", { cx: n.x, cy: n.y, r: n.col === "characters" ? 11 : 8, fill: colors[n.col] || "#999" });
        c.addEventListener("click", () => { location.hash = `#/${n.col}/${n.id}`; });
        const title = WOW.svg("title"); title.textContent = `${n.label} (${store.byId[n.col].singular})`; c.appendChild(title);
        s.appendChild(c);
        const t = WOW.svg("text", { x: n.x + 13, y: n.y + 4 }); t.textContent = n.label; s.appendChild(t);
      }
      holder.replaceChildren(ns.length ? s : h("div.empty", "Nothing connected yet. Link characters to abilities, works and each other."));
    };
    implicitToggle.addEventListener("change", draw);
    draw();
    return h("div.stack",
      head("Connections", "Connection web", "Gold lines are relationships you defined; thin lines come from references (abilities, origins, appearances).",
        h("button.ghost", { onclick: draw }, "Re-arrange"), h("a.btn", { href: "#/links/new" }, "＋ New connection")),
      h("label.row.small", implicitToggle, "Show reference links"),
      h("div.chips", Object.entries(colors).map(([col, c]) => h("span.chip", h("span", { style: { width: "10px", height: "10px", borderRadius: "50%", background: c, display: "inline-block" } }), store.byId[col].label))),
      holder);
  };

  // ---- Backup --------------------------------------------------------------
  V.backup = (rerender) => {
    const fileInput = h("input", { type: "file", accept: ".json,application/json", style: { display: "none" } });
    let mode = "merge";
    fileInput.addEventListener("change", async () => {
      const file = fileInput.files[0];
      if (!file) return;
      try {
        const obj = JSON.parse(await file.text());
        await store.importObject(obj, mode);
        WOW.toast(mode === "merge" ? "Backup merged" : "Backup restored");
        rerender();
      } catch (e) { alert(e.message); }
      fileInput.value = "";
    });
    const snapList = h("div", h("p.muted.small", "Loading…"));
    store.snapshots().then((snaps) => snapList.replaceChildren(snaps.length ? h("table",
      h("tr", h("th", "When"), h("th", "Why"), h("th", "Contents"), h("th", "")),
      snaps.map((s) => h("tr",
        h("td.small", WOW.fmtDate(s.at)), h("td.small", s.label),
        h("td.tiny.muted", Object.entries(s.counts).filter(([, n]) => n).map(([k, n]) => `${n} ${k}`).join(", ")),
        h("td.row", h("button.ghost.small", { onclick: () => WOW.download(`wow-brainstorm-snapshot-${s.at.slice(0, 19)}.json`, JSON.stringify(s.backup, null, 2)) }, "Download"),
          h("button.ghost.small", { onclick: async () => { if (confirm("Restore this snapshot? Your current state is snapshotted first.")) { await store.restoreSnapshot(s.id); WOW.toast("Snapshot restored"); rerender(); } } }, "Restore")))))
      : h("p.muted.small", "Snapshots are taken automatically every 10 minutes of work, on start-up, and before imports, restores and deletes.")));

    return h("div.stack",
      head("Safety", "Backups & data", "Everything lives on this device. Export regularly, and keep copies in iCloud Drive, Files, a USB stick or email."),
      h("div.grid.wide",
        h("div.card.accent.stack",
          h("h2", "Export"),
          h("p.small", "A single JSON file with everything — readable by both the web app and the iPad app."),
          store.state.meta.lastExport ? h("p.tiny.muted", "Last export: " + WOW.fmtDate(store.state.meta.lastExport)) : null,
          h("div.row",
            h("button", { onclick: () => { WOW.download(`wow-brainstorm-${WOW.stamp()}.json`, store.exportJSON()); WOW.toast("Backup downloaded"); } }, "Download full backup"),
            h("button.ghost", { onclick: () => store.snapshot("Manual").then(() => { WOW.toast("Snapshot saved"); rerender(); }) }, "Snapshot now"))),
        h("div.card.stack",
          h("h2", "Import"),
          h("p.small", "Merge keeps the newest version of each entry. Replace swaps your whole library (a snapshot is taken first)."),
          h("div.row",
            h("button.gold", { onclick: () => { mode = "merge"; fileInput.click(); } }, "Merge a backup"),
            h("button.ghost", { onclick: () => { mode = "replace"; fileInput.click(); } }, "Replace with backup")),
          fileInput),
        h("div.card.stack",
          h("h2", "Spreadsheets"),
          h("p.small", "CSV files open in Numbers, Excel or Google Sheets."),
          h("div.chips", store.collections.map((c) => h("button.ghost.small", { onclick: () => WOW.download(`wow-${c.id}-${WOW.stamp()}.csv`, store.csv(c.id), "text/csv") }, c.label))))),
      h("div.card", h("h2", "Snapshots on this device"), snapList),
      h("div.card",
        h("h3", "The data format"),
        h("p.small", "Backups are plain JSON (", h("code", "format: \"wow-brainstorm\", formatVersion: 1"), "). Field definitions live in ", h("code", "shared/schemas.json"), " in the project, so you can always read or convert your work without this app.")));
  };

  // ---- Series bible --------------------------------------------------------
  V.bible = () => {
    const sec = (col) => {
      const c = store.byId[col];
      const items = store.list(col);
      if (!items.length) return null;
      return h("div.stack", h("h2", c.label), items.map((e) => h("div.card",
        col === "maps" ? WOW.maps.render(e, { className: "map-svg" }) : null,
        h("div.list-item", col === "characters" ? WOW.portrait.render(e.portrait, "mini-portrait") : null,
          h("div", h("h3", store.title(col, e)), h("div.tiny.muted", subtitle(col, e)))),
        c.fields.filter((f) => !["portrait", "ink", "stages", "mapcanvas", "genome", "issuekeys"].includes(f.type) && f.key !== c.titleField).map((f) => {
          const v = store.displayValue(f, e[f.key]);
          return v ? h("p.small", { style: { whiteSpace: "pre-wrap" } }, h("strong", f.label + ": "), v) : null;
        }),
        col === "storylines" && e.style ? styleOf(e.style)?.stages.map((st) => e.stages?.[st.id] ? h("p.small", h("strong", st.name + ": "), e.stages[st.id]) : null) : null)));
    };
    return h("div.stack.bible",
      head("Everything in one place", "Series bible", "Print or save as PDF to share with collaborators.", h("button", { onclick: () => print() }, "Print / save PDF")),
      ["works", "characters", "lineages", "traits", "abilities", "powerSystems", "gear", "curses", "blessings", "origins", "cultures", "religions", "languages", "factions", "rivalries", "conflicts", "places", "maps", "storylines", "events", "paradoxes", "research"].map(sec));
  };

  // ---- Search --------------------------------------------------------------
  V.search = (q) => {
    const results = store.search(q);
    return h("div.stack",
      head("Search", `“${q}”`, `${results.length} result${results.length === 1 ? "" : "s"}`),
      results.length ? h("div.grid", results.map(({ col, e }) => entityCard(col, e))) : h("div.empty", "Nothing found."));
  };

  WOW.views = V;
})(window.WOW);
