// Schema-driven editors. Field definitions come from shared/schemas.json,
// so the web and iPad apps always edit the same shape of data.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store } = WOW;

  function autosize(ta) {
    const fit = () => { ta.style.height = "auto"; ta.style.height = Math.max(84, ta.scrollHeight + 2) + "px"; };
    ta.addEventListener("input", fit);
    requestAnimationFrame(fit);
    return ta;
  }

  function options(col) {
    return store.list(col).map((e) => ({ id: e.id, label: store.title(col, e) }))
      .sort((a, b) => a.label.localeCompare(b.label));
  }

  // Renders one field. `get()` returns the current value; `set(v)` saves it.
  function field(f, entity, set, rerender) {
    const v = entity[f.key];
    const label = h("label", f.label);
    let control;
    switch (f.type) {
      case "text":
        control = h("input", { type: "text", value: v || "", oninput: (e) => set(e.target.value) });
        break;
      case "number":
        control = h("input", { type: "number", value: v ?? "", oninput: (e) => set(e.target.value === "" ? null : Number(e.target.value)) });
        break;
      case "textarea":
        control = autosize(h("textarea", { value: v || "", oninput: (e) => set(e.target.value) }));
        break;
      case "select":
        // Chromosomes change which genome options apply, so refresh the form.
        control = h("select", { onchange: (e) => {
          if (e.target.value === "__add") {
            const name = (prompt(`Add your own option to “${f.label}”:`) || "").trim();
            const col = currentCol(entity);
            if (name && col) {
              if (!store.optionsFor(col, f).includes(name)) store.create("labels", { name, kind: "menu option", field: `${col}.${f.key}` });
              set(name);
            }
            rerender && rerender();
            return;
          }
          set(e.target.value || null);
          if (f.key === "heredityChromosomes" && rerender) rerender();
        } },
          h("option", { value: "" }, "—"),
          store.optionsFor(currentCol(entity), f).map((o) => h("option", { value: o, selected: v === o || null }, o)),
          v && !store.optionsFor(currentCol(entity), f).includes(v) ? h("option", { value: v, selected: true }, v) : null,
          h("option", { value: "__add" }, "＋ Add option…"));
        break;
      case "style":
        control = h("select", { onchange: (e) => { set(e.target.value || null); rerender && rerender(); } },
          h("option", { value: "" }, "— choose a narrative style —"),
          groupBy(REF.narrativeStyles, "region").map(([region, styles]) =>
            h("optgroup", { label: region }, styles.map((s) => h("option", { value: s.id, selected: v === s.id || null }, s.name)))));
        break;
      case "mapstyle": {
        const cur = WOW.maps.styleOf(v);
        control = h("div.stack", { style: { gap: "6px" } },
          h("select", { onchange: (e) => { set(e.target.value); rerender && rerender(); } },
            REF.mapStyles.map((s) => h("option", { value: s.id, selected: s.id === cur.id || null }, s.name))),
          h("div.tiny.muted", cur.inspiration),
          cur.care ? h("div.tiny", { style: { color: "var(--gold-700)" } }, "Care: " + cur.care) : null);
        break;
      }
      case "genome":
        control = WOW.genomeField(entity, set);
        break;
      case "issuekeys":
        control = WOW.issueKeysField(v, set);
        break;
      case "refdata":
        control = refdataPicker(f, v || [], set);
        break;
      case "mapcanvas":
        control = h("p.small.muted", "Edited in the map designer above.");
        break;
      case "ref":
        control = refPicker(f, v, set, rerender);
        break;
      case "refs":
        control = refsPicker(f, v || [], set, rerender);
        break;
      case "cultures":
        control = toggleChips(REF.culturePools.map((p) => ({ id: p.id, label: p.region })), v || [], set);
        break;
      case "rasas":
        control = toggleChips(REF.rasas.map((r) => ({ id: r.id, label: `${r.name} · ${r.meaning}` })), v || [], set);
        break;
      case "tags":
        control = h("input", { type: "text", value: (v || []).join(", "), placeholder: "comma, separated, tags",
          oninput: (e) => set(e.target.value.split(",").map((t) => t.trim()).filter(Boolean)) });
        break;
      case "stages":
        control = stages(entity, v || {}, set);
        break;
      case "portrait":
        control = WOW.portrait.builder(v, set);
        break;
      case "ink":
        control = WOW.ink.pad({
          png: v && v.png,
          scale: v && v.scale,
          // Saving from the web keeps only the PNG; the iPad app then shows it beneath new Pencil strokes.
          onSave: (png) => set({ png, scale: window.devicePixelRatio || 1 }),
          onText: (text) => {
            const current = entity.text ? entity.text + "\n" : "";
            store.update(currentCol(entity), entity.id, { text: current + text });
            rerender && rerender();
            WOW.toast("Handwriting converted and added to Text.");
          },
        });
        break;
      case "anyref":
        control = anyRef(v, set);
        break;
      case "anyrefs":
        control = anyRefs(v || [], set);
        break;
      default:
        control = h("span.muted", "Unsupported field");
    }
    const wide = ["textarea", "stages", "portrait", "ink", "cultures", "rasas", "refs", "refdata", "genome", "issuekeys", "anyrefs"].includes(f.type);
    return h("div.field" + (wide ? ".full" : ""), label, control);
  }

  // The collection an entity belongs to (needed by the ink converter).
  function currentCol(entity) {
    return store.collections.find((c) => store.list(c.id).includes(entity))?.id;
  }

  function groupBy(arr, key) {
    const m = new Map();
    for (const x of arr) { if (!m.has(x[key])) m.set(x[key], []); m.get(x[key]).push(x); }
    return [...m.entries()];
  }

  function refPicker(f, v, set, rerender) {
    const sel = h("select", { onchange: (e) => {
      if (e.target.value === "__new") {
        const name = prompt(`New ${store.byId[f.collection].singular.toLowerCase()} name:`);
        if (name) {
          const tf = store.byId[f.collection].titleField;
          const created = store.create(f.collection, { [tf]: name });
          set(created.id);
        }
        rerender && rerender();
        return;
      }
      set(e.target.value || null);
    } },
      h("option", { value: "" }, "—"),
      options(f.collection).map((o) => h("option", { value: o.id, selected: v === o.id || null }, o.label)),
      h("option", { value: "__new" }, `＋ New ${store.byId[f.collection].singular.toLowerCase()}…`));
    const open = v ? h("a.tiny", { href: `#/${f.collection}/${v}` }, "Open →") : null;
    return h("div.stack", { style: { gap: "4px" } }, sel, open);
  }

  function refsPicker(f, ids, set, rerender) {
    const chips = h("div.chips", ids.map((id) => {
      const e = store.get(f.collection, id);
      return h("span.chip.gold",
        h("a", { href: `#/${f.collection}/${id}` }, store.title(f.collection, e)),
        h("button", { type: "button", "aria-label": "Remove", onclick: () => { set(ids.filter((x) => x !== id)); rerender && rerender(); } }, "×"));
    }));
    const add = h("select", { style: { maxWidth: "320px" }, onchange: (e) => {
      const val = e.target.value;
      if (!val) return;
      if (val === "__new") {
        const name = prompt(`New ${store.byId[f.collection].singular.toLowerCase()} name:`);
        if (name) {
          const created = store.create(f.collection, { [store.byId[f.collection].titleField]: name });
          set([...ids, created.id]);
        }
      } else set([...ids, val]);
      rerender && rerender();
    } },
      h("option", { value: "" }, `＋ Add ${store.byId[f.collection].singular.toLowerCase()}`),
      options(f.collection).filter((o) => !ids.includes(o.id)).map((o) => h("option", { value: o.id }, o.label)),
      h("option", { value: "__new" }, "＋ Create new…"));
    return h("div.stack", { style: { gap: "8px" } }, chips, add);
  }

  // Multi-select from a built-in reference library, grouped, with descriptions.
  function refdataPicker(f, ids, set) {
    let cur = [...ids];
    const wrap = h("div.stack", { style: { gap: "8px" } });
    const filter = h("input", { type: "search", placeholder: "Filter…", style: { maxWidth: "220px" } });
    const draw = () => {
      const q = filter.value.toLowerCase();
      const showHints = ["langFeatures", "powerArchetypes", "religions", "animals", "creatures", "wars", "rivalryLore", "mythHistory"].some((s) => f.source.split(",").includes(s));
      wrap.replaceChildren(...[
        h("div.chips", cur.map((id) => {
          const it = WOW.refdata.item(f.source, id);
          return h("span.chip.gold", { title: it?.hint || "" }, it?.label || id,
            h("button", { type: "button", "aria-label": "Remove", onclick: () => { cur = cur.filter((x) => x !== id); set(cur); draw(); } }, "×"));
        })),
        showHints && cur.length ? h("ul.tiny.muted", { style: { margin: 0, paddingLeft: "18px" } }, cur.map((id) => {
          const it = WOW.refdata.item(f.source, id);
          return it?.hint ? h("li", h("strong", it.label + ": "), it.hint) : null;
        })) : null,
        h("div.row", { style: { flexWrap: "nowrap" } },
          filter,
          h("select", { onchange: (e) => { if (e.target.value) { cur = [...cur, e.target.value]; set(cur); draw(); } } },
            h("option", { value: "" }, "＋ Add from the library…"),
            WOW.refdata.groups(f.source).map((g) => {
              const items = g.items.filter((it) => !cur.includes(it.id) && (!q || (it.label + " " + g.group).toLowerCase().includes(q)));
              return items.length ? h("optgroup", { label: g.group }, items.map((it) => h("option", { value: it.id, title: it.hint || "" }, it.label))) : null;
            })))].filter(Boolean));
      if (q) filter.focus();
    };
    filter.addEventListener("input", draw);
    draw();
    return wrap;
  }

  function toggleChips(items, selected, set) {
    let cur = [...selected];
    const wrap = h("div.chips");
    const draw = () => wrap.replaceChildren(...items.map((it) =>
      h("span.chip.toggle" + (cur.includes(it.id) ? ".on" : ""), {
        onclick: () => { cur = cur.includes(it.id) ? cur.filter((x) => x !== it.id) : [...cur, it.id]; set(cur); draw(); },
      }, it.label)));
    draw();
    return wrap;
  }

  function stages(entity, values, set) {
    const style = REF.narrativeStyles.find((s) => s.id === entity.style);
    if (!style) return h("div.empty", "Choose a narrative style above to lay out its beats here.");
    let cur = { ...values };
    return h("div.stack",
      h("div.warn.info", h("strong", style.name), " — ", style.summary, " ", h("a", { href: `#/styles/${style.id}` }, "Learn more →")),
      style.care ? h("div.warn", "Cultural care: ", style.care) : null,
      style.stages.map((st) => h("div.stage",
        h("strong", st.name),
        h("div.prompt", st.prompt),
        autosize(h("textarea", { value: cur[st.id] || "", oninput: (e) => { cur = { ...cur, [st.id]: e.target.value }; set(cur); } })))));
  }

  function anyRef(v, set) {
    const [col, id] = (v || ":").split(":");
    const colSel = h("select", { onchange: () => { entSel.replaceChildren(...entOptions(colSel.value, null)); set(null); } },
      h("option", { value: "" }, "— type —"),
      store.collections.filter((c) => c.id !== "links").map((c) => h("option", { value: c.id, selected: c.id === col || null }, c.singular)));
    const entOptions = (c, selected) => [h("option", { value: "" }, "—"),
      ...(c ? options(c).map((o) => h("option", { value: o.id, selected: o.id === selected || null }, o.label)) : [])];
    const entSel = h("select", { onchange: () => set(entSel.value ? `${colSel.value}:${entSel.value}` : null) }, ...entOptions(col, id));
    return h("div.row", { style: { flexWrap: "nowrap" } }, colSel, entSel);
  }

  // Several entries of any type (e.g. the sides of a war: factions, peoples, characters…).
  function anyRefs(values, set) {
    let cur = [...values];
    const wrap = h("div.stack", { style: { gap: "8px" } });
    const draw = () => {
      const colSel = h("select", { style: { maxWidth: "180px" } },
        store.collections.filter((c) => ["characters", "factions", "cultures", "lineages", "religions", "places", "powerSystems"].includes(c.id))
          .map((c) => h("option", { value: c.id, selected: c.id === "factions" || null }, c.singular)));
      const entSel = h("select", { style: { maxWidth: "240px" } });
      const fill = () => entSel.replaceChildren(h("option", { value: "" }, "＋ Add…"),
        ...options(colSel.value).filter((o) => !cur.includes(`${colSel.value}:${o.id}`)).map((o) => h("option", { value: o.id }, o.label)),
        h("option", { value: "__new" }, "＋ Create new…"));
      colSel.addEventListener("change", fill);
      entSel.addEventListener("change", () => {
        let id = entSel.value;
        if (!id) return;
        if (id === "__new") {
          const name = prompt(`New ${store.byId[colSel.value].singular.toLowerCase()} name:`);
          if (!name) { entSel.value = ""; return; }
          id = store.create(colSel.value, { [store.byId[colSel.value].titleField]: name }).id;
        }
        cur = [...cur, `${colSel.value}:${id}`];
        set(cur);
        draw();
      });
      fill();
      wrap.replaceChildren(
        h("div.chips", cur.map((ref) => {
          const [c, id] = ref.split(":");
          return h("span.chip.gold", h("a", { href: `#/${c}/${id}` }, store.anyTitle(ref)), h("span.muted", " · " + (store.byId[c]?.singular || c)),
            h("button", { type: "button", "aria-label": "Remove", onclick: () => { cur = cur.filter((x) => x !== ref); set(cur); draw(); } }, "×"));
        })),
        h("div.row", { style: { flexWrap: "nowrap" } }, colSel, entSel));
    };
    draw();
    return wrap;
  }

  // Full editor for one entity.
  function editor(col, entity, rerender) {
    const c = store.byId[col];
    const set = (key) => (v) => { store.update(col, entity.id, { [key]: v }); };
    return h("div.form-grid", c.fields.map((f) => field(f, entity, set(f.key), rerender)));
  }

  WOW.forms = { editor, field, autosize };
})(window.WOW);
