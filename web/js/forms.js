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
        control = h("select", { onchange: (e) => set(e.target.value || null) },
          h("option", { value: "" }, "—"),
          f.options.map((o) => h("option", { value: o, selected: v === o || null }, o)));
        break;
      case "style":
        control = h("select", { onchange: (e) => { set(e.target.value || null); rerender && rerender(); } },
          h("option", { value: "" }, "— choose a narrative style —"),
          groupBy(REF.narrativeStyles, "region").map(([region, styles]) =>
            h("optgroup", { label: region }, styles.map((s) => h("option", { value: s.id, selected: v === s.id || null }, s.name)))));
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
          onSave: (png) => set({ ...(entity[f.key] || {}), png }),
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
      default:
        control = h("span.muted", "Unsupported field");
    }
    const wide = ["textarea", "stages", "portrait", "ink", "cultures", "rasas", "refs"].includes(f.type);
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

  // Full editor for one entity.
  function editor(col, entity, rerender) {
    const c = store.byId[col];
    const set = (key) => (v) => { store.update(col, entity.id, { [key]: v }); };
    return h("div.form-grid", c.fields.map((f) => field(f, entity, set(f.key), rerender)));
  }

  WOW.forms = { editor, field, autosize };
})(window.WOW);
