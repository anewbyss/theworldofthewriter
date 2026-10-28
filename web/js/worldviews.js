// World-building views: power tracing, family trees, peoples, faiths, languages,
// the reference libraries, and the world coverage / gaps report.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store } = WOW;
  const V = WOW.views;

  const link = (col, id) => h("a", { href: `#/${col}/${id}` }, store.title(col, store.get(col, id)));
  const chipLink = (col, id, gold) => h("a.chip" + (gold ? ".gold" : ""), { href: `#/${col}/${id}` }, store.title(col, store.get(col, id)));
  const section = (title, ...body) => h("div", { style: { marginTop: "10px" } }, h("strong.small", title), ...body);
  const chars = () => store.list("characters");

  // ---- Shared genealogy helpers ---------------------------------------------
  const childrenOf = (id) => chars().filter((c) => (c.parents || []).includes(id));
  const studentsOf = (id) => chars().filter((c) => (c.teachers || []).includes(id));
  function ancestorsOf(id) {
    const out = [], seen = new Set(), stack = [...(store.get("characters", id)?.parents || [])];
    while (stack.length) {
      const p = stack.pop();
      if (seen.has(p) || p === id) continue;
      seen.add(p);
      const c = store.get("characters", p);
      if (!c) continue;
      out.push(c);
      stack.push(...(c.parents || []));
    }
    return out;
  }

  // How did a character come to hold an ability? Returns readable reasons.
  function howHeld(c, a) {
    const reasons = [];
    if (a.lineage && (c.lineages || []).includes(a.lineage)) reasons.push(["lineage", "through ", link("lineages", a.lineage)]);
    for (const anc of ancestorsOf(c.id)) if ((anc.abilities || []).includes(a.id)) { reasons.push(["kin", "inherited from ", link("characters", anc.id)]); break; }
    for (const t of c.teachers || []) if ((store.get("characters", t)?.abilities || []).includes(a.id)) reasons.push(["teacher", "taught by ", link("characters", t)]);
    for (const t of WOW.bonds?.teachersOf(c.id) || []) if ((store.get("characters", t.id)?.abilities || []).includes(a.id)) reasons.push(["bond", `${t.type.replace(" of", "").replace(" (apprentice)", "")}: `, link("characters", t.id)]);
    for (const p of WOW.bonds?.adoptiveParents(c.id) || []) if ((store.get("characters", p.id)?.abilities || []).includes(a.id)) reasons.push(["bond", `from ${p.type.replace(" of", "")} `, link("characters", p.id)]);
    for (const ev of store.list("events")) {
      if (ev.type === "acquires ability" && ev.ability === a.id && (ev.characters || []).includes(c.id)) reasons.push(["event", "acquired in ", link("events", ev.id)]);
    }
    if (c.origin && store.get("origins", c.origin)) reasons.push(["origin", "origin: ", link("origins", c.origin)]);
    return reasons;
  }

  // ---- Ability trace ---------------------------------------------------------
  function abilityTrace(a) {
    const sysChain = [];
    let s = store.get("powerSystems", a.system);
    for (let i = 0; s && i < 25; i++) { sysChain.push(s); s = store.get("powerSystems", s.parent); }
    const prereqTree = (id, depth, seen) => {
      const x = store.get("abilities", id);
      if (!x) return null;
      if (seen.has(id)) return h("li", x.name || "Untitled", " (loop!)");
      const next = new Set(seen).add(id);
      return h("li", link("abilities", id), x.rank ? h("span.muted", ` · ${x.rank}`) : null,
        (x.prerequisites || []).length && depth < 8 ? h("ul", x.prerequisites.map((p) => prereqTree(p, depth + 1, next))) : null);
    };
    const unlocks = store.list("abilities").filter((x) => (x.prerequisites || []).includes(a.id));
    const counters = store.list("abilities").filter((x) => (x.counters || []).includes(a.id));
    const holders = chars().filter((c) => (c.abilities || []).includes(a.id));
    const lin = store.get("lineages", a.lineage);
    return h("div.card.stack",
      h("h3", "Trace this power"),
      section("System", sysChain.length ? h("div.small", sysChain.reverse().map((x, i) => [i ? " › " : "", link("powerSystems", x.id)])) : h("p.small.muted", "Not part of a power system yet."),
        a.rank ? h("div.small", "Rank: ", h("strong", a.rank)) : null),
      (a.archetypes || []).length ? section("Real-world roots", h("div.chips", a.archetypes.map((id) => h("span.chip", { title: WOW.refdata.item("powerArchetypes", id)?.hint }, WOW.refdata.label("powerArchetypes", id))))) : null,
      lin ? section("Lineage", h("div.small", link("lineages", lin.id), lin.inheritance ? ` · ${lin.inheritance}` : "", lin.founder ? [" · founded by ", link("characters", lin.founder)] : null)) : null,
      a.religion ? section("Faith", h("div.small", link("religions", a.religion))) : null,
      (a.prerequisites || []).length ? section("Builds on", h("ul.small", a.prerequisites.map((p) => prereqTree(p, 0, new Set([a.id]))))) : null,
      unlocks.length ? section("Unlocks", h("div.chips", unlocks.map((x) => chipLink("abilities", x.id)))) : null,
      (a.counters || []).length || counters.length ? section("Counters",
        (a.counters || []).length ? h("div.small", "Countered by: ", a.counters.map((id, i) => [i ? ", " : "", link("abilities", id)])) : null,
        counters.length ? h("div.small", "Counters: ", counters.map((x, i) => [i ? ", " : "", link("abilities", x.id)])) : null) : null,
      section(`Holders (${holders.length})`, holders.length ? h("ul.small", holders.map((c) => {
        const why = howHeld(c, a);
        return h("li", link("characters", c.id), why.length ? h("span.muted", " — ", why.map((r, i) => [i ? "; " : "", ...r.slice(1)])) : h("span.muted", " — source untraced"));
      })) : h("p.small.muted", "No one holds this yet.")));
  }

  // ---- Power system panel ----------------------------------------------------
  function systemPanel(s) {
    const ranks = (s.ranks || "").split("\n").map((r) => r.trim()).filter(Boolean);
    const abilities = store.list("abilities").filter((a) => a.system === s.id);
    const byRank = new Map(ranks.map((r) => [r.toLowerCase(), []]));
    const unranked = [];
    for (const a of abilities) (byRank.get((a.rank || "").trim().toLowerCase()) || unranked).push(a);
    const subs = store.list("powerSystems").filter((x) => x.parent === s.id);
    const practitioners = chars().filter((c) => (c.abilities || []).some((id) => abilities.some((a) => a.id === id)));
    const lineages = store.list("lineages").filter((l) => (l.systems || []).includes(s.id) || (s.lineages || []).includes(l.id));
    return h("div.card.stack",
      h("h3", "System map"),
      ranks.length ? section("Ladder", h("ol.small", ranks.map((r) => h("li", h("strong", r), byRank.get(r.toLowerCase()).length ? [" — ", byRank.get(r.toLowerCase()).map((a, i) => [i ? ", " : "", link("abilities", a.id)])] : h("span.muted", " — no abilities yet")))))
        : h("p.small.muted", "List ranks (one per line) to see the ladder."),
      unranked.length ? section("Other abilities", h("div.chips", unranked.map((a) => chipLink("abilities", a.id)))) : null,
      h("button.ghost.small", { onclick: () => { const a = store.create("abilities", { name: "", system: s.id, rank: ranks[0] || "" }); location.hash = `#/abilities/${a.id}`; } }, "＋ Ability in this system"),
      subs.length ? section("Branches / schools", h("div.chips", subs.map((x) => chipLink("powerSystems", x.id)))) : null,
      lineages.length ? section("Lineages", h("div.chips", lineages.map((l) => chipLink("lineages", l.id, true)))) : null,
      practitioners.length ? section("Practitioners", h("div.chips", practitioners.map((c) => chipLink("characters", c.id, true)))) : null,
      (s.archetypes || []).length ? section("Real-world roots", h("ul.tiny.muted", s.archetypes.map((id) => h("li", WOW.refdata.item("powerArchetypes", id)?.hint || id)))) : null);
  }

  // ---- Family tree -----------------------------------------------------------
  function treeOf(rootIds, memberSet, withStudents) {
    const build = (id, seen) => {
      if (seen.has(id)) return null;
      const next = new Set(seen).add(id);
      const kids = childrenOf(id).filter((k) => !memberSet || memberSet.has(k.id));
      const adopted = (WOW.bonds?.adoptedChildren(id) || []).filter((k) => store.get("characters", k.id) && (!memberSet || memberSet.has(k.id)) && !kids.some((x) => x.id === k.id));
      const studs = withStudents ? studentsOf(id).filter((k) => !memberSet || memberSet.has(k.id)) : [];
      const c = store.get("characters", id);
      return h("li", link("characters", id), c?.status && c.status !== "alive" ? h("span.muted", ` (${c.status})`) : null,
        kids.length || studs.length || adopted.length ? h("ul", kids.map((k) => build(k.id, next)),
          adopted.map((k) => h("li", h("span.muted", `◇ ${WOW.bonds.INVERSE[k.type] || "bonded"}: `), link("characters", k.id))),
          studs.map((k) => h("li", "✦ student: ", link("characters", k.id)))) : null);
    };
    return h("ul.family-tree", rootIds.map((id) => build(id, new Set())));
  }

  function lineagePanel(l) {
    const members = chars().filter((c) => (c.lineages || []).includes(l.id));
    const set = new Set(members.map((m) => m.id));
    if (l.founder) set.add(l.founder);
    const roots = [...set].filter((id) => !(store.get("characters", id)?.parents || []).some((p) => set.has(p)));
    const inherited = (l.abilities || []).map((id) => store.get("abilities", id)).filter(Boolean);
    const teaching = ["teaching lineage", "initiation / priesthood line"].includes(l.kind) || ["by teaching", "by initiation"].includes(l.inheritance);
    return h("div.card.stack",
      h("h3", "Family tree"),
      set.size ? treeOf(roots.length ? roots : [...set], set, teaching) : h("p.small.muted", "Add this lineage to characters (and set their parents) to grow the tree."),
      inherited.length ? section("Inherited powers", h("ul.small", inherited.map((a) => {
        const lacking = members.filter((m) => !(m.abilities || []).includes(a.id));
        return h("li", link("abilities", a.id), h("span.muted", ` — held by ${members.length - lacking.length}/${members.length} members`));
      }))) : null,
      l.seat ? section("Seat", h("div.small", link("places", l.seat))) : null,
      h("button.ghost.small", { onclick: () => { const c = store.create("characters", { name: "", lineages: [l.id], portrait: WOW.portrait.randomParams() }); location.hash = `#/characters/${c.id}`; } }, "＋ New member"));
  }

  function familyPanel(c) {
    const parents = (c.parents || []).filter((p) => store.get("characters", p));
    const kids = childrenOf(c.id);
    const siblings = chars().filter((x) => x.id !== c.id && (x.parents || []).some((p) => parents.includes(p)));
    const studs = studentsOf(c.id);
    const lineagePowers = (c.lineages || []).flatMap((lid) => (store.get("lineages", lid)?.abilities || []).map((aid) => [lid, aid]))
      .filter(([, aid]) => store.get("abilities", aid));
    return h("div.card.stack",
      h("h3", "Family & lineage"),
      parents.length ? section("Parents", h("div.chips", parents.map((p) => chipLink("characters", p, true)))) : null,
      siblings.length ? section("Siblings", h("div.chips", siblings.map((s) => chipLink("characters", s.id)))) : null,
      kids.length ? section("Children", h("div.chips", kids.map((k) => chipLink("characters", k.id)))) : null,
      (c.teachers || []).length ? section("Teachers", h("div.chips", c.teachers.map((t) => chipLink("characters", t)))) : null,
      studs.length ? section("Students", h("div.chips", studs.map((s) => chipLink("characters", s.id)))) : null,
      (c.lineages || []).length ? section("Lineages", h("div.chips", c.lineages.map((l) => chipLink("lineages", l, true)))) : null,
      lineagePowers.length ? section("Lineage powers", h("ul.small", lineagePowers.map(([lid, aid]) =>
        h("li", link("abilities", aid), " from ", link("lineages", lid), (c.abilities || []).includes(aid) ? " ✓" : h("span.muted", " (not awakened)"))))) : null,
      (() => {
        const anc = ancestorsOf(c.id);
        return anc.length ? section("Family tree (descendants of the eldest known ancestor)", treeOf(anc.filter((a) => !(a.parents || []).some((p) => store.get("characters", p))).map((a) => a.id), null, false)) : null;
      })(),
      !parents.length && !kids.length && !(c.lineages || []).length && !(WOW.bonds?.of(c.id) || []).length ? h("p.small.muted", "Set parents, teachers and lineages above, or add bonds below, to trace family lines and inherited powers.") : null,
      (WOW.bonds?.adoptiveParents(c.id) || []).length ? section("Raised by", h("div.chips", WOW.bonds.adoptiveParents(c.id).map((p) => h("a.chip.gold", { href: `#/characters/${p.id}` }, `${store.title("characters", store.get("characters", p.id))} · ${p.type.replace(" of", "")}`)))) : null);
  }

  // ---- Peoples, faiths, languages panels --------------------------------------
  const refCard = (title, lines) => h("div.warn.info.small", h("strong", title), lines.filter(Boolean).map((l) => h("div", l)));

  function culturePanel(p) {
    const members = chars().filter((c) => (c.peoples || []).includes(p.id));
    const subs = store.list("cultures").filter((x) => x.parent === p.id);
    const placesHere = store.list("places").filter((x) => (x.peoples || []).includes(p.id));
    return h("div.card.stack",
      h("h3", "People web"),
      (p.realPeoples || []).length ? section("Drawn from", h("div.chips", p.realPeoples.map((id) => h("span.chip", { title: WOW.refdata.item("peoples", id)?.hint }, WOW.refdata.label("peoples", id))))) : null,
      subs.length ? section("Branches", h("div.chips", subs.map((x) => chipLink("cultures", x.id)))) : null,
      members.length ? section("Characters", h("div.chips", members.map((c) => chipLink("characters", c.id, true)))) : h("p.small.muted", "No characters belong to this people yet."),
      placesHere.length ? section("Lives in", h("div.chips", placesHere.map((x) => chipLink("places", x.id)))) : null,
      p.care ? null : h("div.warn.small", "Tip: note your sources and anyone you consulted in “Sources, consultation & care”."));
  }

  function religionPanel(r) {
    const followers = chars().filter((c) => (c.religions || []).includes(r.id));
    const branches = store.list("religions").filter((x) => x.parent === r.id);
    const abilities = store.list("abilities").filter((a) => a.religion === r.id);
    return h("div.card.stack",
      h("h3", "Faith web"),
      ...(r.basedOn || []).map((id) => {
        const { religion, branch } = WOW.refdata.religion(id);
        if (!religion) return null;
        return refCard(branch ? `${religion.name} — ${branch.name}` : religion.name, [
          branch ? branch.note : religion.origin,
          "Key ideas: " + religion.concepts.join("; "),
          religion.care,
          h("a", { href: `#/faiths/${religion.id}` }, "Open in Faiths library →"),
        ]);
      }),
      branches.length ? section("Branches / sects in your world", h("div.chips", branches.map((x) => chipLink("religions", x.id)))) : null,
      followers.length ? section("Followers", h("div.chips", followers.map((c) => chipLink("characters", c.id, true)))) : null,
      abilities.length ? section("Powers it grants", h("div.chips", abilities.map((a) => chipLink("abilities", a.id)))) : null);
  }

  function languagePanel(l) {
    const daughters = store.list("languages").filter((x) => x.parent === l.id);
    const chain = [];
    let p = store.get("languages", l.parent);
    for (let i = 0; p && i < 25; i++) { chain.unshift(p); p = store.get("languages", p.parent); }
    const speakers = chars().filter((c) => (c.languages || []).includes(l.id));
    const lexicon = (l.lexicon || "").split("\n").map((x) => x.split("=")).filter((x) => x.length >= 2 && x[0].trim());
    return h("div.card.stack",
      h("h3", "Language web"),
      chain.length ? section("Descends from", h("div.small", chain.map((x, i) => [i ? " › " : "", link("languages", x.id)]))) : null,
      daughters.length ? section("Daughter languages", h("div.chips", daughters.map((x) => chipLink("languages", x.id)))) : null,
      ...(l.basedOn || []).map((id) => {
        const { family, language } = WOW.refdata.language(id);
        if (!language) return null;
        return refCard(`${language.name} (${family.name})`, [
          language.features.length ? "Features: " + language.features.map((f) => WOW.refdata.label("langFeatures", f)).join(", ") : null,
          language.scripts.length ? "Scripts: " + language.scripts.map((s) => WOW.refdata.label("writing", s)).join(", ") : null,
          language.status ? "Status: " + language.status : null,
        ]);
      }),
      speakers.length ? section("Speakers", h("div.chips", speakers.map((c) => chipLink("characters", c.id, true)))) : null,
      lexicon.length ? section(`Lexicon (${lexicon.length})`, h("table.small", lexicon.slice(0, 40).map(([w, ...m]) => h("tr", h("td", h("strong", w.trim())), h("td", m.join("=").trim()))))) : null);
  }

  WOW.worldPanels = function (col, e) {
    switch (col) {
      case "abilities": return [abilityTrace(e)];
      case "powerSystems": return [systemPanel(e)];
      case "lineages": return [lineagePanel(e)];
      case "characters": return [familyPanel(e)];
      case "cultures": return [culturePanel(e)];
      case "religions": return [religionPanel(e)];
      case "languages": return [languagePanel(e)];
      default: return [];
    }
  };

  // ---- Faiths library --------------------------------------------------------
  const usedReligionIds = () => new Set(store.list("religions").flatMap((r) => r.basedOn || []).map((id) => id.split(":")[0]));

  V.faiths = () => {
    const used = usedReligionIds();
    const q = h("input", { type: "search", placeholder: "Filter faiths and branches…", style: { maxWidth: "320px" } });
    const list = h("div.stack");
    const draw = () => {
      const s = q.value.toLowerCase();
      const fams = [...new Set(REF.religions.map((r) => r.family))];
      list.replaceChildren(...fams.map((f) => {
        const rs = REF.religions.filter((r) => r.family === f && (!s || (r.name + r.branches.map((b) => b.name).join(" ") + r.concepts.join(" ")).toLowerCase().includes(s)));
        return rs.length ? h("div.stack", h("h2", f), h("div.grid.wide", rs.map((r) => h("a.card.link" + (used.has(r.id) ? ".accent" : ""), { href: `#/faiths/${r.id}` },
          h("h3", r.name), h("div.tiny.muted", r.origin + (r.living ? "" : " · historical")),
          r.branches.length ? h("p.snippet", { style: { marginTop: "6px" } }, r.branches.map((b) => b.name).join(" · ")) : h("p.snippet", { style: { marginTop: "6px" } }, r.concepts.join(" · ")))))) : null;
      }));
    };
    q.addEventListener("input", draw);
    draw();
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Reference"), h("h1", "Faiths library"), h("p.muted", `${REF.religions.length} real religions and philosophies with ${REF.religions.reduce((n, r) => n + r.branches.length, 0)} prominent branches. Gold edges mark ones your world draws on.`)),
        h("a.btn", { href: "#/religions/new" }, "＋ Create your own faith")),
      h("div.warn.info", "These are real, living traditions held by real people. Use them to understand, to portray respectfully, or to inspire something new — and say which you're doing in each faith's ‘Kind’."),
      q, list);
  };

  V.faith = (id) => {
    const r = REF.religions.find((x) => x.id === id);
    if (!r) return h("div.empty", "Unknown faith.");
    const mine = store.list("religions").filter((x) => (x.basedOn || []).some((b) => b.split(":")[0] === r.id));
    const make = (basedOn, name) => () => {
      const made = store.create("religions", { name, kind: "inspired by real faiths", basedOn: [basedOn] });
      location.hash = `#/religions/${made.id}`;
    };
    return h("div.stack",
      h("a", { href: "#/faiths" }, "← Faiths library"),
      h("div.page-head", h("div", h("div.eyebrow", r.family), h("h1", r.name), h("p.muted", r.origin + (r.living ? "" : " · historical"))),
        h("button.gold", { onclick: make(r.id, `Faith inspired by ${r.name}`) }, "＋ Faith based on this")),
      h("div.warn", h("strong", "Care: "), r.care),
      h("div.two-col",
        h("div.stack",
          h("div.card", h("h3", "Key ideas"), h("ul", r.concepts.map((c) => h("li", c)))),
          r.branches.length ? h("div.card", h("h3", "Prominent branches"), h("div.stack", r.branches.map((b) => h("div.row.spread", { style: { flexWrap: "nowrap" } },
            h("div", h("strong", b.name), h("div.small.muted", b.note)),
            h("button.ghost.small", { onclick: make(b.id, b.name) }, "＋ Use"))))) : null),
        h("div.stack",
          h("div.card", h("h3", "Where it lives"), h("div.chips", r.regions.map((p) => h("a.chip", { href: `#/atlas/${p}` }, REF.culturePools.find((x) => x.id === p)?.region || p)))),
          r.sources.length ? h("div.card", h("h3", "Read & listen"), h("ul.small", r.sources.map((s) => h("li", s)))) : null,
          h("div.card", h("h3", "Your faiths drawing on it"), mine.length ? h("div.chips", mine.map((x) => chipLink("religions", x.id, true))) : h("p.small.muted", "None yet.")))));
  };

  // ---- Languages library -----------------------------------------------------
  V.tongues = () => {
    const usedLang = new Set(store.list("languages").flatMap((l) => l.basedOn || []));
    const usedFeat = new Set(store.list("languages").flatMap((l) => l.features || []));
    const q = h("input", { type: "search", placeholder: "Filter languages…", style: { maxWidth: "320px" } });
    const list = h("div.stack");
    const draw = () => {
      const s = q.value.toLowerCase();
      list.replaceChildren(...REF.languageFamilies.map((f) => {
        const ls = f.languages.filter((l) => !s || (l.name + " " + f.name).toLowerCase().includes(s));
        if (!ls.length) return null;
        return h("details.card", { open: s ? true : null },
          h("summary", `${f.name} · ${f.languages.length}`), f.note ? h("p.small.muted", f.note) : null,
          h("table.small", ls.map((l) => h("tr",
            h("td", h("strong", l.name), usedLang.has(l.id) ? " ✓" : null, l.status ? h("div.tiny.muted", l.status) : null),
            h("td", h("div.chips", l.features.map((x) => h("span.chip", { title: REF.langFeatures.find((y) => y.id === x)?.description }, WOW.refdata.label("langFeatures", x))))),
            h("td.tiny", l.scripts.map((x) => WOW.refdata.label("writing", x)).join(", ")),
            h("td", h("button.ghost.small", { onclick: () => {
              const made = store.create("languages", { name: "", kind: "conlang inspired by real languages", basedOn: [l.id], features: [...l.features], scripts: [...l.scripts] });
              location.hash = `#/languages/${made.id}`;
            } }, "＋ Inspire"))))));
      }));
    };
    q.addEventListener("input", draw);
    draw();
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Reference"), h("h1", "Languages library"), h("p.muted", `${REF.languageFamilies.reduce((n, f) => n + f.languages.length, 0)} real languages in ${REF.languageFamilies.length} families, ${REF.writingSystems.length} writing systems and ${REF.langFeatures.length} features to build your own.`)),
        h("a.btn", { href: "#/languages/new" }, "＋ Create a language")),
      h("div.card", h("h2", "Features to design with"), h("div.grid", REF.langFeatures.map((f) => h("div",
        h("strong", f.name, usedFeat.has(f.id) ? " ✓" : ""), h("div.small", f.description), h("div.tiny.muted", "e.g. " + f.examples))))),
      h("div.card", h("h2", "Writing systems"), h("div.grid", REF.writingSystems.map((w) => h("div.small", h("strong", w.name), h("div.tiny.muted", `${w.type} · ${w.used}`))))),
      h("div.row.spread", h("h2", "Language families"), q),
      list);
  };

  // ---- Power concepts on the Power Systems page ------------------------------
  WOW.powerRoots = () => h("details.card",
    h("summary", "Real-world power concepts to start from"),
    h("div.grid.wide", { style: { marginTop: "10px" } }, REF.powerArchetypes.map((a) => h("div.card",
      h("h3", a.name), h("div.tiny.muted", a.roots), h("p.small", a.summary),
      h("p.small", h("strong", "Structure: "), a.structure), h("p.small", h("strong", "Ask: "), a.prompts),
      a.care ? h("div.tiny", { style: { color: "var(--gold-700)" } }, "Care: " + a.care) : null,
      h("button.ghost.small", { onclick: () => {
        const made = store.create("powerSystems", { name: "", archetypes: [a.id], source: a.summary });
        location.hash = `#/powerSystems/${made.id}`;
      } }, "＋ Start a system from this")))));

  // ---- Atlas additions -------------------------------------------------------
  WOW.atlasExtras = (p) => {
    const faiths = REF.religions.filter((r) => r.regions.includes(p.id));
    const langs = REF.languageFamilies.flatMap((f) => f.languages.filter((l) => l.regions.includes(p.id)).map((l) => ({ l, f })));
    const zones = REF.contactZones.filter((z) => z.connects.includes(p.id));
    const myPeoples = store.list("cultures");
    return [
      p.peopleList ? h("div.card",
        h("h3", `Peoples (${p.peopleList.length})`),
        h("p.small.muted", "A starting index — far from complete. Add any people you research to your own Peoples & Cultures."),
        h("div.chips", p.peopleList.map((x) => {
          const used = myPeoples.some((c) => (c.realPeoples || []).includes(x.id));
          return h("button.chip" + (used ? ".gold" : ""), { type: "button", title: "Create a people drawing on this", onclick: () => {
            const made = store.create("cultures", { name: x.name, kind: "real people (portrayed respectfully)", realPeoples: [x.id], cultures: [p.id] });
            location.hash = `#/cultures/${made.id}`;
          } }, x.name);
        }))) : null,
      faiths.length ? h("div.card", h("h3", "Faiths present"), h("div.chips", faiths.map((r) => h("a.chip", { href: `#/faiths/${r.id}` }, r.name)))) : null,
      langs.length ? h("div.card", h("h3", "Languages"), h("div.chips", langs.map(({ l, f }) => h("span.chip", { title: f.name + (l.status ? " · " + l.status : "") }, l.name)))) : null,
      zones.length ? h("div.card", h("h3", "Contact zones"), h("div.stack.small", zones.map((z) => h("div",
        h("strong", z.name), h("span.muted", ` · ${z.era}`), h("div", z.flows),
        h("div.chips", z.connects.filter((c) => c !== p.id).map((c) => h("a.chip", { href: `#/atlas/${c}` }, REF.culturePools.find((x) => x.id === c)?.region || c))))))) : null,
    ];
  };

  // ---- World coverage & gaps -------------------------------------------------
  function regionUse() {
    const use = Object.fromEntries(REF.culturePools.map((p) => [p.id, { direct: [], via: [] }]));
    for (const c of store.collections) {
      const fields = c.fields.filter((f) => f.type === "cultures");
      for (const e of store.list(c.id)) for (const f of fields) for (const pid of e[f.key] || []) use[pid]?.direct.push([c.id, e]);
    }
    // Peoples count toward the pool that lists them (ids keep their old prefix when a people moves pools).
    const poolOf = new Map(REF.culturePools.flatMap((p) => (p.peopleList || []).map((x) => [x.id, p.id])));
    for (const e of store.list("cultures")) for (const id of e.realPeoples || []) use[poolOf.get(id) || id.split(":")[0]]?.via.push(["cultures", e]);
    for (const e of store.list("religions")) for (const id of e.basedOn || []) for (const pid of WOW.refdata.religion(id).religion?.regions || []) use[pid]?.via.push(["religions", e]);
    for (const e of store.list("languages")) for (const id of e.basedOn || []) for (const pid of WOW.refdata.language(id).language?.regions || []) use[pid]?.via.push(["languages", e]);
    // Lore lists (mythic beings, wars…) count toward the region their group belongs to.
    const lorePool = new Map(WOW.lore.SOURCES.flatMap((s) => (REF[s.id] || []).flatMap((g) => g.items.map((it) => [it.id, g.pool]))));
    for (const s of WOW.lore.SOURCES) for (const [col, key] of s.uses) for (const e of store.list(col)) for (const id of e[key] || []) if (lorePool.get(id)) use[lorePool.get(id)]?.via.push([col, e]);
    return use;
  }

  V.coverage = () => {
    const use = regionUse();
    const used = (pid) => use[pid].direct.length + use[pid].via.length > 0;
    const bridges = [], gaps = [];
    for (const z of REF.contactZones) {
      const inUse = z.connects.filter(used), missing = z.connects.filter((c) => !used(c));
      if (inUse.length && missing.length) gaps.push({ z, inUse, missing });
      else if (inUse.length >= 2) bridges.push({ z, inUse });
    }
    const regionName = (id) => REF.culturePools.find((x) => x.id === id)?.region || id;
    const famUsed = new Set(store.list("religions").flatMap((r) => r.basedOn || []).map((id) => WOW.refdata.religion(id).religion?.family).filter(Boolean));
    const langFamUsed = new Set(store.list("languages").flatMap((l) => l.basedOn || []).map((id) => id.split(":")[0]));
    const archUsed = new Set([...store.list("abilities"), ...store.list("powerSystems")].flatMap((x) => x.archetypes || []));
    const featUsed = new Set(store.list("languages").flatMap((l) => l.features || []));
    const pct = (a, b) => (b ? Math.round((a / b) * 100) : 0);
    const meter = (a, b, label) => h("div", h("div.row.spread.small", h("span", label), h("strong", `${a} / ${b}`)), h("div.meter", h("span", { style: { width: pct(a, b) + "%" } })));
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Research"), h("h1", "World coverage & gaps"), h("p.muted", "Which parts of the real world your fiction draws on, and where history suggests natural connections you haven't made yet."))),
      h("div.warn.info", "Gaps aren't quotas. Write what you can research well and portray with care. These are prompts for curiosity, not checkboxes."),
      h("div.grid",
        h("div.card", meter(REF.culturePools.filter((p) => used(p.id)).length, REF.culturePools.length, "Regions drawn on")),
        h("div.card", meter(famUsed.size, new Set(REF.religions.map((r) => r.family)).size, "Faith families")),
        h("div.card", meter(langFamUsed.size, REF.languageFamilies.length, "Language families")),
        h("div.card", meter(archUsed.size, REF.powerArchetypes.length, "Power concepts")),
        h("div.card", meter(featUsed.size, REF.langFeatures.length, "Language features"))),
      h("div.card",
        h("h2", "Natural gaps"),
        h("p.small.muted", "Your world draws on one side of a real historical contact zone but not the other. These are places where stories naturally cross."),
        gaps.length ? h("div.stack", gaps.map(({ z, inUse, missing }) => h("div.warn",
          h("strong", z.name), h("span.small", ` · ${z.era}`),
          h("div.small", "You draw on ", inUse.map(regionName).join(", "), " — but not ", missing.map((m, i) => [i ? ", " : "", h("a", { href: `#/atlas/${m}` }, regionName(m))]), "."),
          h("div.small", h("em", "What flowed: "), z.flows),
          h("div.small", h("em", "Story hook: "), z.hook))))
          : h("p.small.muted", store.list("characters").length ? "No gaps along the contact zones — or tag more entries with regions to find some." : "Tag characters, abilities, peoples and places with regions to see gaps.")),
      bridges.length ? h("div.card", h("h2", "Bridges you can use"), h("p.small.muted", "You already draw on both sides of these contact zones. Connect them."),
        h("div.stack", bridges.map(({ z, inUse }) => h("div.warn.info", h("strong", z.name), h("div.small", inUse.map(regionName).join(" ⇄ ")), h("div.small", h("em", "Story hook: "), z.hook))))) : null,
      h("div.card",
        h("h2", "Regions"),
        h("table", h("tr", h("th", "Region"), h("th", "Tagged entries"), h("th", "Via peoples, faiths & languages"), h("th", "")),
          REF.culturePools.map((p) => h("tr",
            h("td", h("a", { href: `#/atlas/${p.id}` }, p.region)),
            h("td", use[p.id].direct.length || h("span.muted", "—")),
            h("td", use[p.id].via.length || h("span.muted", "—")),
            h("td", used(p.id) ? "" : h("span.chip", "gap")))))),
      h("div.grid.wide",
        h("div.card", h("h3", "Faith families not yet drawn on"), h("div.chips", [...new Set(REF.religions.map((r) => r.family))].filter((f) => !famUsed.has(f)).map((f) => h("a.chip", { href: "#/faiths" }, f)))),
        h("div.card", h("h3", "Language families not yet drawn on"), h("div.chips", REF.languageFamilies.filter((f) => !langFamUsed.has(f.id)).map((f) => h("a.chip", { href: "#/tongues" }, f.name)))),
        h("div.card", h("h3", "Power concepts not yet used"), h("div.chips", REF.powerArchetypes.filter((a) => !archUsed.has(a.id)).map((a) => h("span.chip", { title: a.summary }, a.name))))));
  };
})(window.WOW);
