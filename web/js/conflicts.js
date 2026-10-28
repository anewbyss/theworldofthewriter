// Factions, rivalries, wars & past conflicts, and notable figures.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store } = WOW;
  const V = WOW.views;

  const link = (col, id) => h("a", { href: `#/${col}/${id}` }, store.title(col, store.get(col, id)));
  const chip = (col, id, gold, note) => h("a.chip" + (gold ? ".gold" : ""), { href: `#/${col}/${id}` }, store.title(col, store.get(col, id)), note ? h("span.muted", " · " + note) : null);
  const section = (title, ...body) => h("div", { style: { marginTop: "10px" } }, h("strong.small", title), ...body);
  const num = (v) => (v === "" || v == null ? null : Number(v));

  // Is a character part of a side entry ("col:id")? Returns how, or null.
  function involvement(c, ref) {
    const [col, id] = String(ref).split(":");
    switch (col) {
      case "characters": return id === c.id ? "directly" : null;
      case "factions": {
        const f = store.get("factions", id);
        if (!f) return null;
        if ((f.leaders || []).includes(c.id)) return `leads ${f.name || "a faction"}`;
        if ((f.members || []).includes(c.id)) return `member of ${f.name || "a faction"}`;
        return null;
      }
      case "cultures": return (c.peoples || []).includes(id) ? `one of the ${store.title("cultures", store.get("cultures", id))}` : null;
      case "lineages": return (c.lineages || []).includes(id) ? `of ${store.title("lineages", store.get("lineages", id))}` : null;
      case "religions": return (c.religions || []).includes(id) ? `follows ${store.title("religions", store.get("religions", id))}` : null;
      case "places": return c.homeland === id ? `from ${store.title("places", store.get("places", id))}` : null;
      default: return null;
    }
  }
  const sideOf = (c, refs) => (refs || []).map((r) => involvement(c, r)).find(Boolean) || null;
  const refChips = (refs) => h("div.chips", (refs || []).map((r) => { const [c, id] = r.split(":"); return chip(c, id, true, store.byId[c]?.singular); }));

  // Everything one entity ("col:id") takes part in.
  const touches = (refs, col, id) => (refs || []).includes(`${col}:${id}`);

  // ---- Conflict panel ----------------------------------------------------------
  function conflictPanel(w) {
    const start = num(w.start), end = num(w.end);
    const battles = WOW.continuity.orderedEvents(store.state.data).filter((ev) => (w.battles || []).includes(ev.id));
    const inSpan = start != null ? WOW.continuity.orderedEvents(store.state.data).filter((ev) => {
      const s = num(ev.sequence);
      return s != null && s >= start && (end == null || s <= end) && !(w.battles || []).includes(ev.id) && (ev.type === "battle" || (w.places || []).includes(ev.place));
    }) : [];
    const subs = store.list("conflicts").filter((x) => x.parent === w.id);
    const rivals = store.list("rivalries").filter((r) => (r.conflicts || []).includes(w.id));
    const fallen = [...(w.leaders || []), ...(w.figures || [])].filter((id) => store.list("events").some((ev) => ev.type === "death" && (ev.characters || []).includes(id) && num(ev.sequence) != null && start != null && num(ev.sequence) >= start && (end == null || num(ev.sequence) <= end)));
    return h("div.card.stack",
      h("h3", "The conflict at a glance"),
      section("Side A", (w.sideA || []).length ? refChips(w.sideA) : h("p.small.muted", "—")),
      section("Side B", (w.sideB || []).length ? refChips(w.sideB) : h("p.small.muted", "—")),
      (w.others || []).length ? section("Others", refChips(w.others)) : null,
      h("div.small", start != null ? `In-world order ${start}${end != null ? ` – ${end}` : " – ongoing"}` : "Set ‘Began’ and ‘Ended’ to place it on the timeline.", w.era ? ` · ${w.era}` : ""),
      w.parent ? section("Part of", h("div", link("conflicts", w.parent))) : null,
      subs.length ? section("Campaigns & sub-conflicts", h("div.chips", subs.map((x) => chip("conflicts", x.id)))) : null,
      section("Battles & key events", battles.length ? h("ol.small", battles.map((ev) => h("li", link("events", ev.id), ev.sequence != null && ev.sequence !== "" ? h("span.muted", ` · #${ev.sequence}`) : null, ev.place ? [" at ", link("places", ev.place)] : null))) : h("p.small.muted", "None linked yet."),
        h("button.ghost.small", { onclick: () => { const ev = store.create("events", { title: "", type: "battle", sequence: start ?? null }); store.update("conflicts", w.id, { battles: [...(w.battles || []), ev.id] }); location.hash = `#/events/${ev.id}`; } }, "＋ Battle")),
      inSpan.length ? section("Also during this time", h("div.chips", inSpan.map((ev) => chip("events", ev.id)))) : null,
      fallen.length ? section("Fell during the conflict", h("div.chips", fallen.map((id) => chip("characters", id)))) : null,
      rivals.length ? section("Rivalries behind it", h("div.chips", rivals.map((r) => chip("rivalries", r.id)))) : null,
      w.kind === "atrocity (handle with care)" ? h("div.warn.small", "Real atrocities: research carefully, centre survivors' voices, and avoid spectacle.") : null);
  }

  // ---- Rivalry panel -------------------------------------------------------------
  function rivalryPanel(r) {
    const escalations = WOW.continuity.orderedEvents(store.state.data).filter((ev) => (r.escalations || []).includes(ev.id) || ev.id === r.originEvent);
    const heirs = store.list("characters").filter((c) => (c.lineages || []).some((l) => (r.inheritedBy || []).includes(l)));
    return h("div.card.stack",
      h("h3", "Rivalry"),
      h("div.row", { style: { alignItems: "flex-start" } }, h("div", { style: { flex: 1 } }, (r.sideA || []).length ? refChips(r.sideA) : h("span.muted", "—")), h("strong", "⚔"), h("div", { style: { flex: 1 } }, (r.sideB || []).length ? refChips(r.sideB) : h("span.muted", "—"))),
      h("div.small", [r.kind, r.intensity, r.status].filter(Boolean).join(" · ")),
      section("Escalation", escalations.length ? h("ol.small", escalations.map((ev) => h("li", link("events", ev.id), ev.id === r.originEvent ? h("span.muted", " (origin)") : null))) : h("p.small.muted", "Link an origin event and escalations to chart it."),
        h("button.ghost.small", { onclick: () => { const ev = store.create("events", { title: "" }); store.update("rivalries", r.id, { escalations: [...(r.escalations || []), ev.id] }); location.hash = `#/events/${ev.id}`; } }, "＋ Escalation")),
      (r.conflicts || []).length ? section("Wars it fed", h("div.chips", r.conflicts.map((id) => chip("conflicts", id)))) : null,
      heirs.length ? section("Inherited by", h("div.chips", heirs.map((c) => chip("characters", c.id)))) : null);
  }

  // ---- Faction panel -------------------------------------------------------------
  function factionPanel(f) {
    const me = `factions:${f.id}`;
    const wars = store.list("conflicts").filter((w) => [w.sideA, w.sideB, w.others].some((s) => (s || []).includes(me)));
    const rivals = store.list("rivalries").filter((r) => [r.sideA, r.sideB].some((s) => (s || []).includes(me)));
    const subs = store.list("factions").filter((x) => x.parent === f.id);
    const allyBack = (f.allies || []).filter((id) => (store.get("factions", id)?.enemies || []).includes(f.id));
    return h("div.card.stack",
      h("h3", "Faction web"),
      (f.leaders || []).length ? section("Leaders", h("div.chips", f.leaders.map((id) => chip("characters", id, true)))) : null,
      (f.members || []).length ? section("Members", h("div.chips", f.members.map((id) => chip("characters", id)))) : null,
      (f.territory || []).length || f.seat ? section("Territory", h("div.chips", f.seat ? chip("places", f.seat, true, "seat") : null, (f.territory || []).map((id) => chip("places", id)))) : null,
      subs.length ? section("Branches", h("div.chips", subs.map((x) => chip("factions", x.id)))) : null,
      (f.allies || []).length ? section("Allies", h("div.chips", f.allies.map((id) => chip("factions", id)))) : null,
      (f.enemies || []).length ? section("Enemies", h("div.chips", f.enemies.map((id) => chip("factions", id)))) : null,
      allyBack.length ? h("div.warn.small", "One-sided alliance: ", allyBack.map((id, i) => [i ? ", " : "", link("factions", id)]), " counts this faction as an enemy.") : null,
      wars.length ? section("Wars", h("div.chips", wars.map((w) => chip("conflicts", w.id, false, w.status)))) : null,
      rivals.length ? section("Rivalries", h("div.chips", rivals.map((r) => chip("rivalries", r.id)))) : null);
  }

  // ---- Character & place panels ----------------------------------------------------
  function characterConflictPanel(c) {
    const factions = store.list("factions").filter((f) => (f.leaders || []).includes(c.id) || (f.members || []).includes(c.id));
    const rivals = store.list("rivalries").map((r) => {
      const a = sideOf(c, r.sideA), b = sideOf(c, r.sideB);
      const inherited = (c.lineages || []).some((l) => (r.inheritedBy || []).includes(l)) ? "inherited" : null;
      return { r, via: a || b || inherited };
    }).filter((x) => x.via);
    const wars = store.list("conflicts").map((w) => {
      const roles = [];
      if ((w.leaders || []).includes(c.id)) roles.push("leader");
      if ((w.figures || []).includes(c.id)) roles.push("notable figure");
      const side = sideOf(c, w.sideA) ? "side A" : sideOf(c, w.sideB) ? "side B" : sideOf(c, w.others) ? "other party" : null;
      const via = sideOf(c, w.sideA) || sideOf(c, w.sideB) || sideOf(c, w.others);
      return { w, label: [...roles, side && via ? `${side} (${via})` : null].filter(Boolean).join(", ") };
    }).filter((x) => x.label);
    if (!factions.length && !rivals.length && !wars.length && !c.renown) return null;
    return h("div.card.stack",
      h("h3", "Rivalries, wars & renown"),
      c.renown || c.epithet ? h("div.small", c.epithet ? h("strong", c.epithet) : null, c.renown ? h("span.muted", ` · ${c.renown}`) : null) : null,
      factions.length ? section("Factions", h("div.chips", factions.map((f) => chip("factions", f.id, true, (f.leaders || []).includes(c.id) ? "leader" : null)))) : null,
      rivals.length ? section("Rivalries", h("div.stack.small", { style: { gap: "4px" } }, rivals.map(({ r, via }) => h("div", link("rivalries", r.id), h("span.muted", ` — ${via}${r.intensity ? " · " + r.intensity : ""}`))))) : null,
      wars.length ? section("Wars & conflicts", h("div.stack.small", { style: { gap: "4px" } }, wars.map(({ w, label }) => h("div", link("conflicts", w.id), h("span.muted", ` — ${label}`))))) : null);
  }

  function placeConflictPanel(p) {
    const wars = store.list("conflicts").filter((w) => (w.places || []).includes(p.id) || touches(w.sideA, "places", p.id) || touches(w.sideB, "places", p.id));
    const factions = store.list("factions").filter((f) => f.seat === p.id || (f.territory || []).includes(p.id));
    if (!wars.length && !factions.length) return null;
    return h("div.card.stack",
      h("h3", "Power & war here"),
      factions.length ? section("Factions", h("div.chips", factions.map((f) => chip("factions", f.id, true, f.seat === p.id ? "seat" : null)))) : null,
      wars.length ? section("Conflicts", h("div.chips", wars.map((w) => chip("conflicts", w.id, false, w.status)))) : null);
  }

  // ---- Timeline: eras of conflict ----------------------------------------------------
  WOW.conflictSpans = () => {
    const wars = store.list("conflicts").filter((w) => num(w.start) != null).sort((a, b) => num(a.start) - num(b.start));
    if (!wars.length) return null;
    const lo = Math.min(...wars.map((w) => num(w.start))), hi = Math.max(...wars.map((w) => num(w.end) ?? num(w.start)), lo + 1);
    const pct = (x) => ((x - lo) / (hi - lo)) * 100;
    return h("div.card",
      h("h3", "Eras of conflict"),
      h("div.stack", { style: { gap: "6px" } }, wars.map((w) => {
        const s = num(w.start), e = num(w.end) ?? hi;
        return h("a", { href: `#/conflicts/${w.id}`, style: { textDecoration: "none" } },
          h("div.row.spread.small", h("span", w.name || "Untitled conflict"), h("span.muted", `${s}${num(w.end) != null ? "–" + num(w.end) : "–"}`)),
          h("div.meter", h("span", { style: { marginLeft: pct(s) + "%", width: Math.max(2, pct(e) - pct(s)) + "%", background: w.status === "ended" || w.status === "remembered / mythic" ? "var(--violet-400)" : "linear-gradient(90deg, #A23B3B, var(--gold-500))" } })));
      })));
  };

  // ---- Notable figures ------------------------------------------------------------------
  const RENOWN = ["mythic", "legendary", "famous", "infamous", "regional", "local", "forgotten", "unknown"];
  V.figures = () => {
    const chars = store.list("characters");
    const notable = chars.filter((c) => c.renown && !["unknown", ""].includes(c.renown));
    const inWars = new Set(store.list("conflicts").flatMap((w) => [...(w.leaders || []), ...(w.figures || [])]));
    const leaders = new Set(store.list("factions").flatMap((f) => f.leaders || []));
    const roles = (c) => [
      ...store.list("conflicts").filter((w) => (w.leaders || []).includes(c.id)).map((w) => `led in ${w.name || "a war"}`),
      ...store.list("conflicts").filter((w) => (w.figures || []).includes(c.id)).map((w) => `figure of ${w.name || "a war"}`),
      ...store.list("factions").filter((f) => (f.leaders || []).includes(c.id)).map((f) => `leader of ${f.name || "a faction"}`),
    ];
    const card = (c) => h("a.card.link", { href: `#/characters/${c.id}` },
      h("div.list-item", WOW.portrait.render(c.portrait, "mini-portrait"),
        h("div", h("h3", c.name || "Unnamed"), c.epithet ? h("div.small", h("em", c.epithet)) : null, h("div.tiny.muted", [c.renown, c.status].filter(Boolean).join(" · ")))),
      roles(c).length ? h("div.small", { style: { marginTop: "6px" } }, roles(c).slice(0, 3).join(" · ")) : null,
      c.legacy ? h("div.snippet", { style: { marginTop: "6px" } }, c.legacy) : null);
    const unranked = chars.filter((c) => !notable.includes(c) && (inWars.has(c.id) || leaders.has(c.id)));
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Conflict"), h("h1", "Notable figures"),
        h("p.muted", "Heroes, rulers, rebels, martyrs and monsters — by renown, with the wars and factions that made their names.")),
        h("a.btn", { href: "#/characters/new" }, "＋ New figure")),
      notable.length ? RENOWN.map((rn) => {
        const list = notable.filter((c) => c.renown === rn);
        return list.length ? h("div.stack", h("h2", rn[0].toUpperCase() + rn.slice(1)), h("div.grid", list.map(card))) : null;
      }) : h("div.empty", "Set a character's Renown (local, famous, legendary, infamous, mythic…) to see them here."),
      unranked.length ? h("div.stack", h("h2", "In the thick of it (no renown set)"), h("div.grid", unranked.map(card))) : null,
      h("details.card",
        h("summary", "Real-world figures to research, by region"),
        h("p.small.muted", "From the culture atlas. Read about them in their own traditions before drawing on them."),
        h("div.grid.wide", { style: { marginTop: "10px" } }, REF.culturePools.map((p) => h("div",
          h("strong.small", p.region),
          h("div.chips", p.figures.map((f) => h("button.chip", { type: "button", title: "Add to Research Pool", onclick: () => {
            store.create("research", { title: f, kind: "other", cultures: [p.id], notes: `Notable figure from ${p.region}.`, care: p.care, tags: ["notable figure"] });
            WOW.toast("Added to Research Pool");
          } }, f))))))));
  };

  WOW.conflictPanels = (col, e) => {
    switch (col) {
      case "conflicts": return [conflictPanel(e)];
      case "rivalries": return [rivalryPanel(e)];
      case "factions": return [factionPanel(e)];
      case "characters": return [characterConflictPanel(e)].filter(Boolean);
      case "places": return [placeConflictPanel(e)].filter(Boolean);
      default: return [];
    }
  };
  WOW.involvement = involvement;
})(window.WOW);
