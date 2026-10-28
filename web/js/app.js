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
    ["Research", [["#/coverage", "🧭", "World Coverage & Gaps"], ["#/atlas", "🌍", "Culture Atlas"], ["#/faiths", "🕊️", "Faiths Library"], ["#/tongues", "📖", "Languages Library"], ["#/styles", "📜", "Narrative Styles"], ["#/lore/creatures", "🐉", "Bestiary"], ["#/lore/wars", "🏺", "History & Myth"], ["#/timeatlas", "🕰️", "Time Atlas"], ["#/lands", "🏞️", "Lands & Stewards"], ["#/economy", "📈", "World Economy"], ["#/lore/modern", "🌐", "Modern Cultures"], ["#/research", "🔖", "Research Pool", "research"], ["#/spark", "🎲", "Spark Dice"]]],
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
          : lore ? (href.endsWith("wars") ? /^#\/lore\/(wars|rivalryLore|mythHistory|colonialism|atrocities|catastrophes|villains)/ : href.endsWith("modern") ? /^#\/lore\/modern/ : /^#\/lore\/(creatures|animals)/).test(current) : current.startsWith(href);
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
    else if (parts[0] === "economy") node = views.economy(params);
    else if (parts[0] === "lands") node = parts[1] ? views.land(parts[1]) : views.lands();
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

  // ---- Install & offline help ------------------------------------------------
  let installPrompt = null;
  window.addEventListener("beforeinstallprompt", (e) => { e.preventDefault(); installPrompt = e; });
  const installed = () => matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;

  function installDialog() {
    const d = h("dialog.install-dialog", { "aria-labelledby": "installTitle" });
    const status = h("p");
    const showStatus = () => {
      const ready = !!navigator.serviceWorker?.controller;
      status.replaceChildren(...[
        installed() ? h("strong", "✓ You're using the installed app.") : null,
        installed() ? " " : null,
        location.protocol === "file:" ? "Opened from a file: everything works offline already, but a browser can only install it from a web address."
          : ready ? h("span", h("strong", "✓ Ready to work offline."), " This device has saved the app; it opens and works with no connection.")
          : "Getting ready to work offline — keep this page open for a moment while you're connected."].filter(Boolean));
    };
    showStatus();
    navigator.serviceWorker?.addEventListener("controllerchange", showStatus);
    const url = location.href.split("#")[0].replace(/index\.html$/, "");
    const ios = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
    d.append(
      h("h2#installTitle", "📲 Install & use offline"),
      status,
      installPrompt && !installed() ? h("button.gold", { onclick: async () => { installPrompt.prompt(); await installPrompt.userChoice; installPrompt = null; d.close(); } }, "Install WOW Brainstorm") : null,
      h("ul.small.stack", { style: { gap: "6px", paddingLeft: "18px" } },
        h("li" + (ios ? ".strong" : ""), h("strong", "iPad & iPhone: "), "open this page in Safari, tap Share ", h("span", { "aria-hidden": "true" }, "⬆︎"), ", then Add to Home Screen."),
        h("li", h("strong", "Android: "), "in Chrome, open the ⋮ menu and choose Install app (or Add to Home screen)."),
        h("li", h("strong", "Computer: "), "in Chrome or Edge, click the install icon at the right of the address bar.")),
      h("div.row", h("input", { type: "text", readonly: true, value: url, "aria-label": "Address of this app", onfocus: (e) => e.target.select() }),
        h("button.ghost.small", { onclick: async () => { try { await navigator.clipboard.writeText(url); WOW.toast("Link copied"); } catch { WOW.toast("Select the address and copy it"); } } }, "Copy link")),
      h("p.small.muted", "Your writing is saved in this browser on this device — it never leaves unless you export it. To move it, use ", h("a", { href: "#/backup", onclick: () => d.close() }, "Backups & Data"), " → Export, then Import on the other device."),
      h("div.row", { style: { justifyContent: "flex-end" } }, h("button", { onclick: () => d.close() }, "Done")));
    d.addEventListener("close", () => d.remove());
    document.body.append(d);
    d.showModal();
  }

  async function start() {
    theme();
    await store.load();
    // Keep the sidebar counts live without re-rendering the page you're typing in.
    store.onChange(WOW.debounce(renderNav, 300));
    window.addEventListener("hashchange", () => { route(); window.scrollTo(0, 0); });
    document.getElementById("installBtn").addEventListener("click", installDialog);
    if (installed()) document.getElementById("installBtn").querySelector(".install-label").textContent = "Offline";
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
