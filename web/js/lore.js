// Lore libraries (animals, mythic beings, wars, rivalries, history & myth,
// empires & colonialism, genocides & atrocities, catastrophes, modern cultures),
// the opening screen and the "ways to begin" doors.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store, views: V } = WOW;

  const SOURCES = [
    { id: "animals", label: "Real animals", icon: "🐾", blurb: "Real animals and the lore people tell about them.", uses: [["species", "realAnimals"], ["pets", "realAnimals"]] },
    { id: "creatures", label: "Mythic & fictional beings", icon: "🐉", blurb: "Beings from myth and folklore by region, plus public-domain fiction and kinds of being to invent from.", uses: [["species", "mythicRoots"], ["pets", "mythicRoots"]] },
    { id: "wars", label: "Wars", icon: "🛡️", blurb: "Sacred and mythic wars alongside real wars from every continent.", uses: [["conflicts", "basedOn"], ["events", "mythTies"]] },
    { id: "rivalryLore", label: "Rivalries", icon: "⚔️", blurb: "Mythic, historical, artistic and scholarly rivalries.", uses: [["rivalries", "basedOn"]] },
    { id: "mythHistory", label: "History & myth", icon: "🏺", blurb: "Places and people where history and legend meet.", uses: [["events", "mythTies"], ["places", "historyTies"], ["characters", "historyTies"]] },
    { id: "colonialism", label: "Empires & colonialism", icon: "👑", blurb: "Empires and colonial powers from Akkad to today, settler colonialism, and territories still disputed or administered from afar.", uses: [["factions", "basedOn"], ["conflicts", "basedOn"], ["places", "historyTies"]],
      care: "Tell colonial history from the side of the colonised as well as the coloniser. Many of these stories are still being lived." },
    { id: "atrocities", label: "Genocides & atrocities", icon: "🕯️", blurb: "Genocides, mass atrocities and enslavement, past and present, with who recognises them.", uses: [["conflicts", "basedOn"], ["events", "mythTies"], ["places", "historyTies"]],
      care: "Real people suffered and survivors and descendants are alive. Read survivor testimony and scholarship, centre the people harmed rather than the perpetrators, and never use atrocity as spectacle or as a plot twist. Where recognition is contested, the note says so." },
    { id: "catastrophes", label: "Catastrophes", icon: "🌋", blurb: "Long-term catastrophes across Earth's and humanity's history: extinctions, ice ages, plagues, famines, eruptions and climate change.", uses: [["conflicts", "basedOn"], ["events", "mythTies"], ["places", "historyTies"]] },
    { id: "villains", label: "Perpetrators & groups", icon: "⚠️", blurb: "Real-world tyrants, perpetrators, regimes, militias, extremist groups, companies and cartels, past and present — as the documented record describes them.", uses: [["characters", "historyTies"], ["factions", "basedOn"]],
      care: "These are real people and groups, and their victims are real. Use them to understand how power, ideology and complicity work — never to glamorise. For living people, stick to the documented record (convictions, indictments, official findings), as these entries do, and say when a finding is disputed." },
    { id: "modern", label: "Modern cultures", icon: "🌐", blurb: "Every sovereign state, plus territories, stateless nations and Indigenous nations, and contemporary scenes and subcultures.", uses: [["characters", "modernCultures"], ["cultures", "modernCultures"], ["places", "historyTies"]],
      care: "A country isn't a culture: most hold many peoples. Use the Culture Atlas and Peoples index to go deeper." },
  ];
  const source = (id) => SOURCES.find((s) => s.id === id) || SOURCES[0];

  const poolsOf = (it) => (it.pools && it.pools.length ? it.pools : it.group?.pool ? [it.group.pool] : []);
  const NOW = new Date().getFullYear();
  // "66 million years ago", "1274 BCE", "1914" — readable at any scale.
  function fmtYear(y) {
    if (y == null) return "";
    const ago = NOW - y;
    if (ago >= 1e9) return `${+(ago / 1e9).toFixed(2)} billion years ago`;
    if (ago >= 1e6) return `${+(ago / 1e6).toFixed(1)} million years ago`;
    if (ago >= 20000) return `${Math.round(ago / 1000).toLocaleString()},000 years ago`;
    return y < 0 ? `${-Math.round(y)} BCE` : `${Math.round(y)}`;
  }
  const span = (it) => it.start == null ? "" : it.ongoing ? `${fmtYear(it.start)} – today` : it.end != null ? `${fmtYear(it.start)} – ${fmtYear(it.end)}` : fmtYear(it.start);
  const flat = (sid) => (REF[sid] || []).flatMap((g) => g.items.map((it) => ({ ...it, group: g })));
  const usedBy = (sid, id) => source(sid).uses.flatMap(([col, key]) => store.list(col).filter((e) => (e[key] || []).includes(id)).map((e) => [col, e]));
  const echo = (it) => [it.name, it.meta ? `(${it.meta})` : "", it.note].filter(Boolean).join(" ");
  const CARE = "Read the tradition this comes from, credit it, and make your version your own.";

  // Ways to turn a lore entry into one of your own entries.
  function starts(sid, it) {
    const pool = poolsOf(it);
    const years = { start: it.start ?? "", end: it.ongoing ? "" : it.end ?? it.start ?? "" };
    const mythic = !it.group.pool && it.group.id.startsWith("mythic");
    switch (sid) {
      case "animals": return [
        ["species", "＋ Species", { name: it.name, kind: "animal", sapience: "animal", realAnimals: [it.id], roots: echo(it) }],
        ["pets", "＋ Companion", { name: it.name, realAnimals: [it.id], status: "alive", kind: "pet", origin: echo(it) }]];
      case "creatures": return [
        ["species", "＋ Species", { name: it.name, mythicRoots: [it.id], cultures: pool, roots: `${it.group.name}: ${echo(it)}`, care: pool.length ? CARE : "" }],
        ["pets", "＋ Companion", { name: it.name, mythicRoots: [it.id], status: "alive", kind: "familiar", origin: `${it.group.name}: ${echo(it)}` }]];
      case "wars": return [["conflicts", "＋ War", { name: it.name, kind: "war", status: mythic ? "remembered / mythic" : "ended", basedOn: [it.id], era: it.meta, ...years, cultures: pool, parallels: `Echoes ${echo(it)}` }]];
      case "colonialism": return [
        ["factions", "＋ Empire / power", { name: it.name, kind: "empire / kingdom", status: it.ongoing ? "dominant" : "dissolved", basedOn: [it.id], cultures: pool, founded: it.start ?? "", dissolved: it.ongoing ? "" : it.end ?? "", history: echo(it) }],
        ["conflicts", "＋ Colonial conflict", { name: `Resistance to ${it.name}`, kind: "occupation", status: it.ongoing ? "ongoing" : "ended", basedOn: [it.id], ...years, cultures: pool, parallels: `Echoes ${echo(it)}` }]];
      case "atrocities": return [
        ["events", "＋ To my timeline", { title: it.name, mythTies: [it.id], when: span(it), description: echo(it) }],
        ["conflicts", "＋ Conflict (with care)", { name: it.name, kind: "atrocity (handle with care)", status: it.ongoing ? "ongoing" : "remembered / mythic", basedOn: [it.id], ...years, cultures: pool, memory: echo(it) }]];
      case "catastrophes": return [
        ["events", "＋ To my timeline", { title: it.name, mythTies: [it.id], when: span(it), description: echo(it) }],
        ["places", "＋ Place it marked", { name: it.name, historyTies: [it.id], cultures: pool, history: echo(it) }]];
      case "villains": {
        const group = /regimes|companies/.test(it.group.id);
        return group
          ? [["factions", "＋ Faction it echoes", { name: "", kind: "army / warrior order", status: it.ongoing ? "dominant" : "dissolved", basedOn: [it.id], cultures: pool, history: `Draws on ${echo(it)}` }]]
          : [["characters", "＋ Antagonist it echoes", { name: "", role: "antagonist", historyTies: [it.id], cultures: pool, inspiration: `Draws on ${echo(it)}`, portrait: WOW.portrait.randomParams() }],
            ["factions", "＋ Their regime", { name: "", kind: "empire / kingdom", basedOn: [it.id], cultures: pool, history: `Draws on ${echo(it)}` }]];
      }
      case "modern": return [
        ["cultures", "＋ People", { name: it.name, kind: "real people (portrayed respectfully)", modernCultures: [it.id], cultures: pool }],
        ["characters", "＋ Character from here", { name: "", modernCultures: [it.id], cultures: pool, portrait: WOW.portrait.randomParams() }]];
      case "rivalryLore": return [["rivalries", "＋ Rivalry", { name: it.name, basedOn: [it.id], origin: `Echoes ${echo(it)}` }]];
      case "mythHistory": return [["events", "＋ To my timeline", { title: it.name, mythTies: [it.id], when: it.meta, description: echo(it) }]];
      default: return [];
    }
  }
  function toResearch(sid, it) {
    store.create("research", { title: it.name, kind: "other", cultures: poolsOf(it), source: [span(it), it.meta].filter(Boolean).join(" · "), notes: it.note, care: source(sid).care || "", tags: [source(sid).label.toLowerCase()] });
    WOW.toast("Sent to your Research Pool");
  }

  // ---- Library page ----------------------------------------------------------
  V.lore = (sid) => {
    const s = source(sid);
    const groups = REF[s.id] || [];
    const total = groups.reduce((n, g) => n + g.items.length, 0);
    const q = h("input", { type: "search", placeholder: `Filter ${s.label.toLowerCase()}…`, style: { maxWidth: "320px" } });
    const gsel = h("select", { style: { width: "auto" } }, h("option", { value: "" }, "All groups"), groups.map((g) => h("option", { value: g.id }, `${g.name} (${g.items.length})`)));
    const list = h("div.stack");
    const card = (it) => {
      const used = usedBy(s.id, it.id);
      return h("div.card" + (used.length ? ".accent" : ""),
        h("h3", it.name),
        it.start != null && !it.meta.includes(String(Math.abs(it.start))) ? h("div.tiny", { style: { color: "var(--gold-700)" } }, span(it)) : null,
        it.meta ? h("div.tiny.muted", it.meta) : null,
        it.note ? h("p.small", { style: { margin: "6px 0" } }, it.note) : null,
        used.length ? h("div.chips", { style: { marginBottom: "6px" } }, used.map(([col, e]) => h("a.chip.gold", { href: `#/${col}/${e.id}` }, store.title(col, e)))) : null,
        h("div.row", { style: { gap: "6px" } },
          starts(s.id, it).map(([col, label, fields]) => h("button.ghost.small", { onclick: () => { const made = store.create(col, fields); location.hash = `#/${col}/${made.id}`; } }, label)),
          h("button.ghost.small", { title: "Send to Research Pool", onclick: () => toResearch(s.id, it) }, "🔖"),
          it.start != null ? h("a.btn.ghost.small", { href: `#/timeatlas?year=${it.start}&focus=${encodeURIComponent(it.id)}`, title: "See it on the Time Atlas" }, "🕰️") : null));
    };
    const draw = () => {
      const t = q.value.toLowerCase();
      const shown = groups.filter((g) => !gsel.value || g.id === gsel.value).map((g) => [g, g.items.filter((it) => !t || `${it.name} ${it.meta} ${it.note}`.toLowerCase().includes(t))]).filter(([, its]) => its.length);
      list.replaceChildren(...(shown.length ? shown.map(([g, its]) => h("div.stack",
        h("h2", g.name, g.pool ? h("a.small", { href: `#/atlas/${g.pool}`, style: { marginLeft: "10px", fontWeight: 400 } }, "atlas →") : null),
        h("div.grid.wide", its.map((it) => card({ ...it, group: g }))))) : [h("div.empty", "No matches.")]));
    };
    q.addEventListener("input", draw);
    gsel.addEventListener("change", draw);
    draw();
    return h("div.stack",
      h("div.page-head", h("div", h("div.eyebrow", "Lore library"), h("h1", s.label), h("p.muted", `${total} entries. ${s.blurb} Gold edges mark ones your world already draws on.`))),
      h("div.chips", SOURCES.map((x) => h("a.chip" + (x.id === s.id ? ".on" : ""), { href: `#/lore/${x.id}` }, `${x.icon} ${x.label}`))),
      h("div.warn.info", "A starting index, never a complete one. Many of these beings and events belong to living peoples. Start from them to learn, then build something your own and credit what inspired it."),
      s.care ? h("div.warn", h("strong", "Care: "), s.care) : null,
      h("div.row", q, gsel), list);
  };

  // ---- Daily inspiration -----------------------------------------------------
  const day = () => Math.floor(Date.now() / 864e5);
  const daily = (arr, salt) => (arr.length ? arr[(day() * 7919 + salt * 104729) % arr.length] : null);
  function inspirations() {
    const creature = daily(flat("creatures").filter((x) => x.group.pool), 1);
    const place = daily(flat("mythHistory"), 2);
    const style = daily(REF.narrativeStyles, 3);
    const clash = day() % 2 ? daily(flat("wars"), 4) : daily(flat("rivalryLore"), 5);
    const animal = daily(flat("animals"), 6);
    return { creature, place, style, clash, animal, clashSource: day() % 2 ? "wars" : "rivalryLore" };
  }
  const libraryStats = () => [
    [flat("animals").length, "real animals"], [flat("creatures").length, "mythic beings"], [REF.culturePools.reduce((n, p) => n + (p.peopleList || []).length, 0), "peoples"],
    [REF.religions.length, "faiths"], [REF.narrativeStyles.length, "story shapes"], [flat("wars").length + flat("rivalryLore").length, "wars & rivalries"]];

  const DOORS = [
    ["👤", "Meet a character", "Portrait, powers, people, family.", "#/characters/new"],
    ["🗺️", "Draw a world", "Maps from village to cosmos.", "#/maps/new"],
    ["🐉", "Start from a myth", "Beings from every region's folklore.", "#/lore/creatures"],
    ["🏺", "Start from history", "Wars, rivalries, legends made real.", "#/lore/wars"],
    ["📜", "Choose a story shape", "Kishōtenketsu, griot epic, blues form…", "#/styles"],
    ["🌍", "Wander the atlas", "21 regions of peoples and ideas.", "#/atlas"],
    ["🐾", "Find a creature", "Real animals and their lore.", "#/lore/animals"],
    ["🎲", "Roll a spark", "Dice tables for when the page is blank.", "#/spark"],
  ];
  WOW.doors = (onGo) => h("div.doors", DOORS.map(([icon, title, sub, href]) => h("a.door", { href, onclick: onGo }, h("span.door-icon", icon), h("strong", title), h("span.small", sub))));

  function inspirationCards(onGo) {
    const i = inspirations();
    const card = (eyebrow, title, sub, href) => h("a.inspo", { href, onclick: onGo }, h("div.eyebrow", eyebrow), h("h3", title), h("p.small", sub));
    return h("div.inspos",
      i.creature ? card(`Being of the day · ${i.creature.group.name}`, i.creature.name, i.creature.note, "#/lore/creatures") : null,
      i.place ? card("Where myth meets history", i.place.name, [i.place.meta, i.place.note].filter(Boolean).join(" — "), "#/lore/mythHistory") : null,
      i.style ? card(`Story shape · ${i.style.region}`, i.style.name, i.style.summary, `#/styles/${i.style.id}`) : null,
      i.clash ? card(i.clashSource === "wars" ? "A war remembered" : "A famous rivalry", i.clash.name, [i.clash.meta, i.clash.note].filter(Boolean).join(" — "), `#/lore/${i.clashSource}`) : null);
  }
  WOW.inspirationCards = inspirationCards;

  // ---- Opening screen --------------------------------------------------------
  const PREF = "wow-show-opening";
  const wantsOpening = () => { try { return localStorage.getItem(PREF) !== "off"; } catch { return true; } };

  function showOpening() {
    const counts = store.counts();
    const total = Object.entries(counts).filter(([c]) => c !== "links" && c !== "labels").reduce((n, [, v]) => n + v, 0);
    const recent = store.recent(1)[0];
    let spark = WOW.pick(REF.sparkTables.storySpark);
    const sparkText = h("p.opening-spark", spark);
    const close = () => { overlay.classList.add("leaving"); setTimeout(() => overlay.remove(), 250); document.getElementById("view")?.focus(); };
    const keep = h("input", { type: "checkbox", checked: wantsOpening(), onchange: (e) => { try { localStorage.setItem(PREF, e.target.checked ? "on" : "off"); } catch {} } });
    const summary = Object.entries(counts).filter(([c, n]) => n && c !== "links" && c !== "labels").sort((a, b) => b[1] - a[1]).slice(0, 4)
      .map(([c, n]) => `${n} ${(n === 1 ? store.byId[c].singular : store.byId[c].label).toLowerCase()}`).join(" · ");
    const overlay = h("div.opening", { role: "dialog", "aria-modal": "true", "aria-label": "Welcome to WOW Brainstorm" },
      h("div.opening-inner",
        h("div.opening-brand", h("span.brand-mark", "W"), h("div", h("div.opening-title", "WOW Brainstorm"), h("div.opening-tag", "The world of the writer · every culture, every myth, every thread"))),
        h("p.opening-lede", "Build worlds from the whole of human story, then keep every book, show and song in continuity. Nothing here writes for you. Your words, your world."),
        total
          ? h("div.opening-continue",
            h("div", h("div.eyebrow", "Your world so far"), h("div", summary), recent ? h("div.small", "Last touched: ", h("strong", store.title(recent.col, recent.e))) : null),
            h("div.row", recent ? h("a.btn.gold", { href: `#/${recent.col}/${recent.e.id}`, onclick: close }, "Pick up where you left off") : null, h("a.btn.ghost", { href: "#/", onclick: close }, "Go to home")))
          : null,
        h("div.opening-section", h("div.eyebrow", "Today's inspiration"), inspirationCards(close)),
        h("div.opening-section", h("div.eyebrow", "Spark"), sparkText,
          h("div.row", h("button.ghost.small", { onclick: () => { spark = WOW.pick(REF.sparkTables.storySpark); sparkText.textContent = spark; } }, "🎲 Roll again"),
            h("button.ghost.small", { onclick: () => { const n = store.create("notes", { title: "Spark", text: spark, tags: ["spark"] }); close(); location.hash = `#/notes/${n.id}`; } }, "✍️ Write from this"))),
        h("div.opening-section", h("div.eyebrow", total ? "Or begin something new" : "Ways to begin"), WOW.doors(close)),
        h("div.opening-stats", libraryStats().map(([n, l]) => h("span", h("strong", String(n)), " ", l))),
        h("div.opening-foot",
          h("button.gold", { onclick: close }, "Enter WOW Brainstorm"),
          h("label.small", keep, " Show this screen when I open the app"))));
    overlay.addEventListener("keydown", (e) => { if (e.key === "Escape") close(); });
    document.body.append(overlay);
    overlay.querySelector("button.gold").focus({ preventScroll: true });
  }

  WOW.lore = { SOURCES, flat, usedBy, starts, toResearch, poolsOf, fmtYear, span, NOW, inspirations, libraryStats, showOpening, wantsOpening };
})(window.WOW);
