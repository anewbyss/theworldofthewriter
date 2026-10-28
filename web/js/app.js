// Router, navigation and start-up.
(function (WOW) {
  const { h, store, views } = WOW;

  const NAV = [
    ["Write", [["#/", "🏠", "Home"], ["#/characters", "👤", "Characters", "characters"], ["#/storylines", "🧭", "Storylines", "storylines"], ["#/works", "📚", "Books & Media", "works"], ["#/notes", "✍️", "Ink Pages", "notes"]]],
    ["Beings", [["#/species", "🐾", "Species", "species"], ["#/pets", "🐕", "Pets & Companions", "pets"]]],
    ["Powers", [["#/abilities", "✨", "Abilities", "abilities"], ["#/powerSystems", "⚡", "Power Systems", "powerSystems"], ["#/gear", "🗡️", "Gear & Artifacts", "gear"], ["#/curses", "🕸", "Curses", "curses"], ["#/blessings", "🌟", "Blessings", "blessings"], ["#/origins", "🌱", "Origins", "origins"]]],
    ["Bloodlines", [["#/lineages", "🌳", "Lineages & Families", "lineages"], ["#/bonds", "🤝", "Family & Bonds", "bonds"], ["#/traits", "🧬", "Heredity Traits", "traits"], ["#/offspring", "👶", "Offspring Calculator"]]],
    ["Conflict", [["#/factions", "🚩", "Factions & Orders", "factions"], ["#/rivalries", "⚔️", "Rivalries", "rivalries"], ["#/conflicts", "🛡️", "Wars & Conflicts", "conflicts"], ["#/figures", "👑", "Notable Figures"]]],
    ["World", [["#/cultures", "🧑‍🤝‍🧑", "Peoples & Cultures", "cultures"], ["#/religions", "📿", "Faiths", "religions"], ["#/languages", "🔤", "Languages", "languages"], ["#/places", "📍", "Places", "places"], ["#/maps", "🗺️", "Maps", "maps"]]],
    ["Track", [["#/continuity", "🧵", "Timeline & Continuity", "events"], ["#/paradoxes", "∞", "Paradoxes", "paradoxes"], ["#/graph", "🕸️", "Connection Web", "links"], ["#/originality", "🔍", "Originality"]]],
    ["Research", [["#/coverage", "🧭", "World Coverage & Gaps"], ["#/atlas", "🌍", "Culture Atlas"], ["#/faiths", "🕊️", "Faiths Library"], ["#/tongues", "📖", "Languages Library"], ["#/styles", "📜", "Narrative Styles"], ["#/lore/creatures", "🐉", "Bestiary"], ["#/lore/wars", "🏺", "History & Myth"], ["#/timeatlas", "🕰️", "Time Atlas"], ["#/lore/modern", "🌐", "Modern Cultures"], ["#/research", "🔖", "Research Pool", "research"], ["#/spark", "🎲", "Spark Dice"]]],
    ["Keep", [["#/labels", "🏷️", "Labels & Tags"], ["#/bible", "📖", "Series Bible"], ["#/backup", "💾", "Backups & Data"]]],
  ];

  function renderNav() {
    const counts = store.counts();
    const current = location.hash || "#/";
    const nav = document.getElementById("nav");
    nav.replaceChildren(...NAV.flatMap(([group, items]) => [
      h("div.nav-group", group),
      ...items.map(([href, icon, label, col]) => {
        const lore = href.startsWith("#/lore/");
        const active = href === "#/" ? current === "#/" || current === ""
          : lore ? (href.endsWith("wars") ? /^#\/lore\/(wars|rivalryLore|mythHistory|colonialism|atrocities|catastrophes)/ : href.endsWith("modern") ? /^#\/lore\/modern/ : /^#\/lore\/(creatures|animals)/).test(current) : current.startsWith(href);
        return h("a" + (active ? ".active" : ""), { href }, h("span", icon), label, col && counts[col] ? h("span.count", counts[col]) : null);
      }),
    ]));
  }

  function route() {
    const hash = location.hash || "#/";
    const [pathPart, query] = hash.slice(2).split("?");
    const parts = pathPart.split("/").map(decodeURIComponent);
    const params = new URLSearchParams(query || "");
    const view = document.getElementById("view");
    const rerender = () => route();
    let node;

    if (parts[0] === "" ) node = views.dashboard();
    else if (parts[0] === "search") node = views.search(parts.slice(1).join("/"));
    else if (parts[0] === "styles") node = parts[1] ? views.style(parts[1]) : views.styles();
    else if (parts[0] === "atlas") node = parts[1] ? views.atlasRegion(parts[1]) : views.atlas();
    else if (parts[0] === "spark") node = views.spark();
    else if (parts[0] === "faiths") node = parts[1] ? views.faith(parts[1]) : views.faiths();
    else if (parts[0] === "tongues") node = views.tongues();
    else if (parts[0] === "lore") node = views.lore(parts[1]);
    else if (parts[0] === "timeatlas") node = views.timeatlas(params);
    else if (parts[0] === "coverage") node = views.coverage();
    else if (parts[0] === "originality") node = views.originality();
    else if (parts[0] === "continuity") node = views.continuity(rerender);
    else if (parts[0] === "offspring") node = views.offspring(params);
    else if (parts[0] === "figures") node = views.figures();
    else if (parts[0] === "labels" && !parts[1]) node = views.labels(rerender);
    else if (parts[0] === "tag") node = views.tag(parts.slice(1).join("/"));
    else if (parts[0] === "graph") node = views.graph();
    else if (parts[0] === "backup") node = views.backup(rerender);
    else if (parts[0] === "bible") node = views.bible();
    else if (parts[0] === "breakdown") node = views.breakdown(parts[1]);
    else if (store.byId[parts[0]]) {
      const col = parts[0];
      if (parts[1] === "new") {
        const c = store.byId[col];
        const fields = col === "characters" ? { portrait: WOW.portrait.randomParams() }
          : col === "maps" ? { scale: "region", mapStyle: "wow", canvas: WOW.maps.emptyCanvas("region") } : {};
        const made = store.create(col, { [c.titleField]: "", ...fields });
        location.replace(`#/${col}/${made.id}`);
        return;
      }
      node = parts[1] ? views.entity(col, parts[1], rerender, params) : views.list(col);
    } else node = h("div.empty", "Page not found. ", h("a", { href: "#/" }, "Go home"));

    view.replaceChildren(node);
    renderNav();
    document.getElementById("sidebar").classList.remove("open");
  }

  function theme() {
    const saved = localStorage.getItem("wow-theme");
    if (saved) document.documentElement.dataset.theme = saved;
    document.getElementById("themeToggle").addEventListener("click", () => {
      const isDark = document.documentElement.dataset.theme === "dark" ||
        (!document.documentElement.dataset.theme && matchMedia("(prefers-color-scheme: dark)").matches);
      const next = isDark ? "light" : "dark";
      document.documentElement.dataset.theme = next;
      localStorage.setItem("wow-theme", next);
    });
  }

  async function start() {
    theme();
    await store.load();
    // Keep the sidebar counts live without re-rendering the page you're typing in.
    store.onChange(WOW.debounce(renderNav, 300));
    window.addEventListener("hashchange", () => { route(); window.scrollTo(0, 0); });
    document.getElementById("menuBtn").addEventListener("click", () => document.getElementById("sidebar").classList.toggle("open"));
    const gs = document.getElementById("globalSearch");
    gs.addEventListener("keydown", (e) => {
      const q = gs.value.trim();
      if (e.key !== "Enter" || !q) return;
      location.hash = q.startsWith("#") && q.length > 1 ? "#/tag/" + encodeURIComponent(q.slice(1)) : "#/search/" + encodeURIComponent(q);
    });
    route();
    if ((location.hash || "#/") === "#/" && WOW.lore.wantsOpening()) WOW.lore.showOpening();
    if ("serviceWorker" in navigator && location.protocol.startsWith("http")) {
      navigator.serviceWorker.register("sw.js").catch(() => {});
    }
  }

  start();
})(window.WOW);
