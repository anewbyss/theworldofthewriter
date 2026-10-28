// Non-blood family and bonds (found family, mentors, adoption…), heirlooms that pass
// through families, and the labels & tags manager.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store } = WOW;
  const V = WOW.views;

  const link = (col, id) => h("a", { href: `#/${col}/${id}` }, store.title(col, store.get(col, id)));
  const section = (title, ...body) => h("div", { style: { marginTop: "10px" } }, h("strong.small", title), ...body);

  // ---- Bond semantics ----------------------------------------------------------
  const PARENT_LIKE = ["adoptive parent of", "foster parent of", "guardian of", "step-parent of", "spiritual parent of"];
  const TEACHING = ["mentor of", "teacher of", "master of (apprentice)", "initiator of"];
  const INVERSE = {
    "adoptive parent of": "adopted child of", "foster parent of": "foster child of", "guardian of": "ward of", "step-parent of": "step-child of",
    "spiritual parent of": "spiritual child of", "godparent / sponsor of": "godchild of", "mentor of": "mentee of", "teacher of": "student of",
    "master of (apprentice)": "apprentice of", "initiator of": "initiate of", "chosen elder of": "chosen younger kin of",
  };
  const active = (b) => b.status !== "ended" && b.status !== "broken";

  const bonds = {
    PARENT_LIKE, TEACHING, INVERSE,
    // Every bond touching a character, phrased from their side.
    of(id) {
      return store.list("bonds").filter((b) => b.from === id || b.to === id).map((b) => {
        const mine = b.from === id;
        const type = b.type || "bond";
        return { bond: b, other: mine ? b.to : b.from, label: mine ? type : (INVERSE[type] || type), giver: mine };
      });
    },
    adoptiveParents: (id) => store.list("bonds").filter((b) => b.to === id && PARENT_LIKE.includes(b.type)).map((b) => ({ id: b.from, type: b.type })),
    adoptedChildren: (id) => store.list("bonds").filter((b) => b.from === id && PARENT_LIKE.includes(b.type)).map((b) => ({ id: b.to, type: b.type })),
    teachersOf: (id) => store.list("bonds").filter((b) => b.to === id && TEACHING.includes(b.type)).map((b) => ({ id: b.from, type: b.type })),
  };
  WOW.bonds = bonds;

  function bondsPanel(c, rerender) {
    const all = bonds.of(c.id);
    const groups = [
      ["Parents & guardians (not by blood)", (x) => !x.giver && (PARENT_LIKE.includes(x.bond.type) || x.bond.type === "godparent / sponsor of")],
      ["In their care", (x) => x.giver && (PARENT_LIKE.includes(x.bond.type) || x.bond.type === "godparent / sponsor of")],
      ["Mentors & teachers", (x) => !x.giver && (TEACHING.includes(x.bond.type) || x.bond.type === "chosen elder of")],
      ["Students & apprentices", (x) => x.giver && (TEACHING.includes(x.bond.type) || x.bond.type === "chosen elder of")],
      ["Chosen & sworn kin", (x) => ["found family with", "sworn sibling of", "milk kin of", "age-set mate of", "co-parent / compadre of", "study partner of", "other"].includes(x.bond.type)],
      ["Partners", (x) => ["partner / spouse of", "betrothed to"].includes(x.bond.type)],
    ];
    const typeSel = h("select", { style: { maxWidth: "200px" } }, REF.collections.find((x) => x.id === "bonds").fields.find((f) => f.key === "type").options.map((o) => h("option", { value: o }, o)));
    const whoSel = h("select", { style: { maxWidth: "200px" } }, h("option", { value: "" }, "— who —"),
      store.list("characters").filter((x) => x.id !== c.id).map((x) => h("option", { value: x.id }, x.name || "Unnamed")), h("option", { value: "__new" }, "＋ New character…"));
    const tradSel = h("select", { style: { maxWidth: "200px" } }, h("option", { value: "" }, "— tradition (optional) —"), REF.kinshipTraditions.map((k) => h("option", { value: k.id, title: k.roots }, k.name)));
    tradSel.addEventListener("change", () => { const k = REF.kinshipTraditions.find((x) => x.id === tradSel.value); if (k) typeSel.value = k.bond; });
    return h("div.card.stack",
      h("h3", "Chosen family, mentors & bonds"),
      all.length ? groups.map(([title, test]) => {
        const items = all.filter(test);
        return items.length ? section(title, h("div.stack.small", { style: { gap: "4px" } }, items.map((x) => h("div",
          link("characters", x.other), h("span.muted", ` — ${x.label}`),
          (x.bond.tradition || []).length ? h("span.chip", { style: { marginLeft: "6px" } }, x.bond.tradition.map((t) => WOW.refdata.label("kinship", t)).join(", ")) : null,
          x.bond.people ? h("span.muted", " · ", link("cultures", x.bond.people)) : null,
          x.bond.status && x.bond.status !== "active" ? h("span.muted", ` · ${x.bond.status}`) : null,
          " ", h("a.tiny", { href: `#/bonds/${x.bond.id}` }, "edit"))))) : null;
      }) : h("p.small.muted", "No bonds yet. Add adoptive parents, mentors, found family, sworn siblings and more."),
      h("details", h("summary.small", "＋ Add a bond"),
        h("div.stack", { style: { marginTop: "8px" } },
          h("div.small", h("strong", c.name || "This character"), " is…"), typeSel, whoSel, tradSel,
          h("button.small", { onclick: () => {
            let other = whoSel.value;
            if (!other) return;
            if (other === "__new") {
              const name = prompt("Name:");
              if (!name) return;
              other = store.create("characters", { name, portrait: WOW.portrait.randomParams() }).id;
            }
            store.create("bonds", { from: c.id, type: typeSel.value, to: other, tradition: tradSel.value ? [tradSel.value] : [], status: "active" });
            rerender();
          } }, "Add bond"))));
  }

  function bondPanel(b) {
    const trad = (b.tradition || []).map((id) => REF.kinshipTraditions.find((k) => k.id === id)).filter(Boolean);
    return h("div.card.stack",
      h("h3", "This bond"),
      b.from && b.to ? h("p", link("characters", b.from), ` is ${b.type || "bonded to"} `, link("characters", b.to), ".") : h("p.small.muted", "Choose both people."),
      b.to && INVERSE[b.type] ? h("p.small.muted", `${store.title("characters", store.get("characters", b.to))} is ${INVERSE[b.type]} ${store.title("characters", store.get("characters", b.from))}.`) : null,
      ...trad.map((k) => h("div.warn.info.small", h("strong", k.name), h("div", k.roots), h("div", k.description))));
  }

  // ---- Heirlooms ------------------------------------------------------------------
  function birthOrder() {
    const out = {};
    for (const ev of WOW.continuity.orderedEvents(store.state.data)) {
      if (ev.type === "birth" && ev.sequence !== "" && ev.sequence != null) for (const id of ev.characters || []) out[id] ??= Number(ev.sequence);
    }
    return out;
  }

  // Who should receive this heirloom next, by its succession rule.
  function suggestedHeir(g) {
    const holder = g.owner;
    const births = birthOrder();
    const alive = (id) => store.get("characters", id) && store.get("characters", id).status !== "dead";
    const byBirth = (ids, desc) => ids.filter(alive).sort((a, b) => {
      const x = births[a] ?? Infinity, y = births[b] ?? Infinity;
      return desc ? (y === Infinity ? -1 : x === Infinity ? 1 : y - x) : x - y;
    });
    const children = holder ? [...new Set([
      ...store.list("characters").filter((c) => (c.parents || []).includes(holder)).map((c) => c.id),
      ...bonds.adoptedChildren(holder).map((x) => x.id),
    ])] : [];
    switch (g.succession) {
      case "eldest child": return byBirth(children)[0] ? { id: byBirth(children)[0], why: "eldest living child of the holder" } : null;
      case "youngest child": return byBirth(children, true)[0] ? { id: byBirth(children, true)[0], why: "youngest living child of the holder" } : null;
      case "next in the lineage": {
        if (!g.heirloomOf) return null;
        const held = new Set([...(g.pastHolders || []), holder]);
        const next = byBirth(store.list("characters").filter((c) => (c.lineages || []).includes(g.heirloomOf) && !held.has(c.id)).map((c) => c.id))[0];
        return next ? { id: next, why: "next living lineage member who hasn't held it" } : null;
      }
      default:
        return g.heir ? { id: g.heir, why: "designated heir" } : null;
    }
  }

  function heirloomPanel(g) {
    if (!g.heirloomOf && !g.heir && !(g.pastHolders || []).length) {
      return h("div.card.small.muted", "Not an heirloom. Set “Heirloom of” to track it through a family.");
    }
    const trail = WOW.continuity.orderedEvents(store.state.data).filter((ev) => ev.item === g.id && ev.type === "gains item").map((ev) => (ev.characters || [])[0]).filter(Boolean);
    const line = [...new Set([...(g.pastHolders || []), ...trail, ...(g.owner ? [g.owner] : [])])];
    const next = suggestedHeir(g);
    return h("div.card.stack",
      h("h3", "Heirloom line"),
      g.heirloomOf ? h("div.small", "Belongs to ", link("lineages", g.heirloomOf), g.succession ? ` · passes on: ${g.succession}` : "") : null,
      line.length ? h("ol.small", line.map((id) => h("li", link("characters", id), id === g.owner ? h("strong", " — holds it now") : null))) : h("p.small.muted", "No holders recorded yet."),
      h("div.small", "Next: ", next ? [link("characters", next.id), h("span.muted", ` (${next.why})`)] : h("span.muted", "no heir yet")),
      g.heir && next && next.id !== g.heir ? h("div.small", "Designated heir: ", link("characters", g.heir)) : null);
  }

  function lineageHeirlooms(l) {
    const items = store.list("gear").filter((g) => g.heirloomOf === l.id);
    if (!items.length) return null;
    return h("div.card.stack",
      h("h3", "Heirlooms"),
      h("div.stack.small", items.map((g) => {
        const next = suggestedHeir(g);
        return h("div", link("gear", g.id), h("span.muted", " — "), g.owner ? ["held by ", link("characters", g.owner)] : "unheld", next ? [h("span.muted", " · next: "), link("characters", next.id)] : null);
      })));
  }

  function characterHeirlooms(c) {
    const held = store.list("gear").filter((g) => g.owner === c.id && g.heirloomOf);
    const due = store.list("gear").filter((g) => g.owner !== c.id && suggestedHeir(g)?.id === c.id);
    if (!held.length && !due.length) return null;
    return h("div.card.stack",
      h("h3", "Heirlooms"),
      held.length ? section("Holds", h("div.chips", held.map((g) => h("a.chip.gold", { href: `#/gear/${g.id}` }, g.name || "Heirloom")))) : null,
      due.length ? section("Next in line for", h("div.chips", due.map((g) => h("a.chip", { href: `#/gear/${g.id}` }, g.name || "Heirloom")))) : null);
  }

  // ---- Labels & tags ----------------------------------------------------------------
  const COLORS = { violet: "#8E5BD0", gold: "#E1AD01", teal: "#2C7A7B", rose: "#C05680", green: "#38A169", blue: "#2B6CB0", grey: "#718096" };
  function tagChip(t) {
    const l = store.labelFor(t);
    const color = l?.color ? COLORS[l.color] : null;
    return h("span.chip.toggle", {
      title: l?.description || "", style: color ? { borderColor: color, boxShadow: `inset 3px 0 0 ${color}` } : null,
      onclick: (ev) => { ev.preventDefault(); ev.stopPropagation(); location.hash = `#/tag/${encodeURIComponent(t)}`; },
    }, "#" + t);
  }
  WOW.tagChip = tagChip;

  function renameTag(from, to) {
    for (const c of store.collections) for (const e of store.list(c.id)) {
      if ((e.tags || []).includes(from)) store.update(c.id, e.id, { tags: [...new Set(e.tags.map((t) => (t === from ? to : t)))] });
    }
    const l = store.labelFor(from);
    if (l) store.update("labels", l.id, { name: to });
  }

  V.labels = (rerender) => {
    const tags = [...store.tagIndex().entries()].sort((a, b) => b[1].length - a[1].length);
    const selectFields = store.collections.flatMap((c) => c.fields.filter((f) => f.type === "select").map((f) => ({ col: c, f })));
    const menuSel = h("select", { style: { maxWidth: "320px" } }, selectFields.map(({ col, f }) => h("option", { value: `${col.id}.${f.key}` }, `${col.label} → ${f.label}`)));
    const optName = h("input", { type: "text", placeholder: "New option", style: { maxWidth: "220px" } });
    const custom = store.list("labels").filter((l) => l.kind === "menu option");
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Organise"), h("h1", "Labels & tags"),
        h("p.muted", "Rename, merge, colour and describe every tag, and add your own options to any menu in the app."))),
      h("div.card",
        h("h2", `Tags · ${tags.length}`),
        tags.length ? h("table", h("tr", h("th", "Tag"), h("th", "Used"), h("th", "Colour"), h("th", "Meaning"), h("th", "")),
          tags.map(([t, uses]) => {
            const l = store.labelFor(t);
            const upsert = (patch) => { if (l) store.update("labels", l.id, patch); else store.create("labels", { name: t, kind: "tag", ...patch }); };
            return h("tr",
              h("td", tagChip(t)),
              h("td.small", `${uses.length} · ${[...new Set(uses.map((u) => store.byId[u.col].label))].join(", ")}`),
              h("td", h("select", { style: { width: "auto" }, onchange: (e) => { upsert({ color: e.target.value || null }); rerender(); } },
                h("option", { value: "" }, "—"), Object.keys(COLORS).map((c) => h("option", { value: c, selected: l?.color === c || null }, c)))),
              h("td", h("input", { type: "text", value: l?.description || "", placeholder: "What this tag means", oninput: WOW.debounce((e) => upsert({ description: e.target.value }), 400) })),
              h("td.row", { style: { flexWrap: "nowrap" } },
                h("button.ghost.small", { onclick: () => { const to = (prompt(`Rename #${t} to:`, t) || "").trim(); if (to && to !== t) { renameTag(t, to); rerender(); } } }, "Rename"),
                h("button.ghost.small", { onclick: () => {
                  const to = (prompt(`Merge #${t} into which tag?`) || "").trim();
                  if (to && to !== t) { renameTag(t, to); WOW.toast(`Merged into #${to}`); rerender(); }
                } }, "Merge"),
                h("button.danger.small", { onclick: () => {
                  if (!confirm(`Remove #${t} from ${uses.length} entries?`)) return;
                  for (const u of uses) store.update(u.col, u.e.id, { tags: (u.e.tags || []).filter((x) => x !== t) });
                  if (l) store.remove("labels", l.id);
                  rerender();
                } }, "Delete")));
          })) : h("p.muted", "No tags yet. Add tags to any entry.")),
      h("div.card.stack",
        h("h2", "Your own menu options"),
        h("p.small.muted", "Every dropdown also has “＋ Add option…”. Options you add appear here."),
        h("div.row", menuSel, optName, h("button.small", { onclick: () => {
          const name = optName.value.trim();
          if (!name) return;
          store.create("labels", { name, kind: "menu option", field: menuSel.value });
          rerender();
        } }, "Add option")),
        custom.length ? h("table", h("tr", h("th", "Menu"), h("th", "Option"), h("th", "Meaning"), h("th", "")),
          custom.map((l) => {
            const [colId, key] = (l.field || ".").split(".");
            const col = store.byId[colId], f = col?.fields.find((x) => x.key === key);
            return h("tr",
              h("td.small", col && f ? `${col.label} → ${f.label}` : l.field),
              h("td", h("strong", l.name)),
              h("td", h("input", { type: "text", value: l.description || "", oninput: WOW.debounce((e) => store.update("labels", l.id, { description: e.target.value }), 400) })),
              h("td.row", { style: { flexWrap: "nowrap" } },
                h("button.ghost.small", { onclick: () => {
                  const to = (prompt("Rename option to:", l.name) || "").trim();
                  if (!to || to === l.name || !col) return;
                  for (const e of store.list(col.id)) if (e[key] === l.name) store.update(col.id, e.id, { [key]: to });
                  store.update("labels", l.id, { name: to });
                  rerender();
                } }, "Rename"),
                h("button.danger.small", { onclick: () => { if (confirm("Remove this option? Entries keep their current value.")) { store.remove("labels", l.id); rerender(); } } }, "Delete")));
          })) : null));
  };

  V.tag = (name) => {
    const uses = store.tagIndex().get(name) || [];
    const l = store.labelFor(name);
    return h("div.stack",
      h("a", { href: "#/labels" }, "← Labels & tags"),
      h("div.page-head", h("div", h("div.eyebrow", "Tag"), h("h1", "#" + name), l?.description ? h("p.muted", l.description) : null)),
      uses.length ? store.collections.map((c) => {
        const items = uses.filter((u) => u.col === c.id);
        return items.length ? h("div.stack", h("h2", c.label), h("div.chips", items.map((u) => h("a.chip.gold", { href: `#/${u.col}/${u.e.id}` }, store.title(u.col, u.e))))) : null;
      }) : h("div.empty", "Nothing carries this tag."));
  };

  // ---- Panels registry --------------------------------------------------------------
  WOW.kinPanels = (col, e, rerender) => {
    switch (col) {
      case "characters": return [bondsPanel(e, rerender), characterHeirlooms(e)].filter(Boolean);
      case "bonds": return [bondPanel(e)];
      case "gear": return [heirloomPanel(e)];
      case "lineages": return [lineageHeirlooms(e)].filter(Boolean);
      default: return [];
    }
  };
  WOW.suggestedHeir = suggestedHeir;
})(window.WOW);
