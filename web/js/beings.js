// Species and pets & companions.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store } = WOW;

  const link = (col, id) => h("a", { href: `#/${col}/${id}` }, store.title(col, store.get(col, id)));
  const chip = (col, id, gold, note) => h("a.chip" + (gold ? ".gold" : ""), { href: `#/${col}/${id}` }, store.title(col, store.get(col, id)), note ? h("span.muted", " · " + note) : null);
  const section = (title, ...body) => h("div", { style: { marginTop: "10px" } }, h("strong.small", title), ...body);

  // Species of any being: characters list several, pets have one.
  const speciesOf = (e) => (Array.isArray(e?.species) ? e.species : e?.species ? [e.species] : []);
  // Can beings of these species have children together (by the writer's rules)?
  function compatible(a, b) {
    const A = speciesOf(a), B = speciesOf(b);
    if (!A.length || !B.length) return true;
    if (A.some((s) => B.includes(s))) return true;
    return A.some((x) => B.some((y) => (store.get("species", x)?.interbreeds || []).includes(y) || (store.get("species", y)?.interbreeds || []).includes(x)));
  }

  function speciesPanel(s) {
    const members = store.list("characters").filter((c) => speciesOf(c).includes(s.id));
    const pets = store.list("pets").filter((p) => p.species === s.id);
    const subs = store.list("species").filter((x) => x.parent === s.id);
    const chain = [];
    let p = store.get("species", s.parent);
    for (let i = 0; p && i < 25; i++) { chain.unshift(p); p = store.get("species", p.parent); }
    const interbreedsBack = store.list("species").filter((x) => x.id !== s.id && (x.interbreeds || []).includes(s.id) && !(s.interbreeds || []).includes(x.id));
    return h("div.card.stack",
      h("h3", "Species web"),
      chain.length ? h("div.small", "Variant of ", chain.map((x, i) => [i ? " › " : "", link("species", x.id)])) : null,
      subs.length ? section("Subspecies & variants", h("div.chips", subs.map((x) => chip("species", x.id)))) : null,
      h("div.small", [s.kind, s.sapience, s.lifespan ? `lives ~${s.lifespan} years` : null, s.reproduction].filter(Boolean).join(" · ")),
      (s.abilities || []).length ? section("Innate abilities", h("div.chips", s.abilities.map((id) => chip("abilities", id)))) : null,
      (s.interbreeds || []).length || interbreedsBack.length ? section("Can have children with",
        h("div.chips", (s.interbreeds || []).map((id) => chip("species", id)), interbreedsBack.map((x) => chip("species", x.id, false, "their rule")))) : null,
      members.length ? section(`Characters (${members.length})`, h("div.chips", members.map((c) => chip("characters", c.id, true, speciesOf(c).length > 1 ? "mixed" : null)))) : h("p.small.muted", "No characters of this species yet."),
      pets.length ? section(`Companions (${pets.length})`, h("div.chips", pets.map((x) => chip("pets", x.id)))) : null,
      (s.habitat || []).length ? section("Habitat", h("div.chips", s.habitat.map((id) => chip("places", id)))) : null,
      (s.peoples || []).length ? section("Peoples", h("div.chips", s.peoples.map((id) => chip("cultures", id)))) : null);
  }

  function characterBeingPanel(c, rerender) {
    const species = speciesOf(c).map((id) => store.get("species", id)).filter(Boolean);
    const pets = store.list("pets").filter((p) => (p.bondedTo || []).includes(c.id));
    const missing = species.flatMap((s) => (s.abilities || []).filter((a) => !(c.abilities || []).includes(a)).map((a) => [s, a]));
    const pick = h("select", { style: { maxWidth: "260px" }, onchange: (e) => {
      const v = e.target.value;
      e.target.value = "";
      if (!v) return;
      if (v === "__new") {
        const name = prompt("Companion's name:");
        if (!name) return;
        store.create("pets", { name, bondedTo: [c.id], status: "alive", bond: "partner" });
      } else {
        const p = store.get("pets", v);
        store.update("pets", v, { bondedTo: [...new Set([...(p.bondedTo || []), c.id])] });
      }
      rerender();
    } }, h("option", { value: "" }, "＋ Bond a companion…"),
      store.list("pets").filter((p) => !(p.bondedTo || []).includes(c.id)).map((p) => h("option", { value: p.id }, p.name || "Unnamed")),
      h("option", { value: "__new" }, "＋ New companion…"));
    const lifespans = species.map((s) => Number(s.lifespan)).filter((x) => x > 0);
    return h("div.card.stack",
      h("h3", "Species & companions"),
      species.length ? h("div.chips", species.map((s) => chip("species", s.id, true, s.kind))) : h("p.small.muted", "No species set."),
      lifespans.length ? h("div.small.muted", species.length > 1 ? `Mixed heritage — lifespan somewhere between ${Math.min(...lifespans)} and ${Math.max(...lifespans)} years.` : `Typical lifespan ~${lifespans[0]} years.`) : null,
      missing.length ? section("Species gifts not yet on their profile", h("div.chips", missing.map(([s, a]) => h("button.chip", { type: "button", title: `Innate to ${s.name}`, onclick: () => {
        store.update("characters", c.id, { abilities: [...new Set([...(c.abilities || []), a])] });
        rerender();
      } }, "＋ ", store.title("abilities", store.get("abilities", a)))))) : null,
      section("Companions", pets.length ? h("div.stack.small", { style: { gap: "4px" } }, pets.map((p) => h("div", link("pets", p.id),
        h("span.muted", ` — ${[store.get("species", p.species)?.name, p.kind, p.bond, p.status && p.status !== "alive" ? p.status : null].filter(Boolean).join(" · ")}`)))) : h("p.small.muted", "None yet."), pick));
  }

  function petPanel(p) {
    const s = store.get("species", p.species);
    const kids = store.list("pets").filter((x) => (x.parents || []).includes(p.id));
    return h("div.card.stack",
      h("h3", "Companion"),
      s ? h("div.small", link("species", s.id), [s.kind, s.lifespan ? `~${s.lifespan} years` : null].filter(Boolean).map((x) => " · " + x)) : h("p.small.muted", "No species set."),
      (p.bondedTo || []).length ? section("Bonded to", h("div.chips", p.bondedTo.map((id) => chip("characters", id, true)))) : h("p.small.muted", "Not bonded to anyone yet."),
      (p.parents || []).length ? section("Parents", h("div.chips", p.parents.map((id) => chip("pets", id)))) : null,
      kids.length ? section("Offspring", h("div.chips", kids.map((x) => chip("pets", x.id)))) : null,
      h("a.small", { href: `#/offspring?kind=pets&a=${p.id}` }, "🧬 Breeding calculator with this companion →"));
  }

  function placeBeingPanel(p) {
    const species = store.list("species").filter((s) => (s.habitat || []).includes(p.id));
    const pets = store.list("pets").filter((x) => x.home === p.id);
    if (!species.length && !pets.length) return null;
    return h("div.card.stack",
      h("h3", "Beings here"),
      species.length ? section("Species living here", h("div.chips", species.map((s) => chip("species", s.id)))) : null,
      pets.length ? section("Companions at home here", h("div.chips", pets.map((x) => chip("pets", x.id)))) : null);
  }

  WOW.speciesTemplates = () => h("details.card",
    h("summary", "Start from folklore"),
    h("p.small.muted", "Starting points from real folklore. Read their traditions first, credit them, and make your version your own."),
    h("div.grid", { style: { marginTop: "10px" } }, REF.speciesTemplates.map((t) => h("div.card",
      h("h3", t.name), h("div.tiny.muted", [t.kind, t.sapience].filter(Boolean).join(" · ")), h("p.small", t.roots),
      t.care ? h("div.tiny", { style: { color: "var(--gold-700)" } }, "Care: " + t.care) : null,
      h("button.ghost.small", { onclick: () => { const made = store.create("species", { ...t }); location.hash = `#/species/${made.id}`; } }, "＋ Start from this")))));

  WOW.beingPanels = (col, e, rerender) => {
    switch (col) {
      case "species": return [speciesPanel(e)];
      case "characters": return [characterBeingPanel(e, rerender)];
      case "pets": return [petPanel(e)];
      case "places": return [placeBeingPanel(e)].filter(Boolean);
      default: return [];
    }
  };
  WOW.species = { speciesOf, compatible };
})(window.WOW);
