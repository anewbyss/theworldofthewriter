// Lookups into the built-in reference libraries (peoples, faiths, languages,
// writing systems, language features, power concepts, lore lists) for "refdata" fields.
(function (WOW) {
  const REF = window.WOW_REF;

  function groups(source) {
    switch (source) {
      case "religions": {
        const fams = [...new Set(REF.religions.map((r) => r.family))];
        return fams.map((f) => ({
          group: f,
          items: REF.religions.filter((r) => r.family === f).flatMap((r) => [
            { id: r.id, label: r.name, hint: r.origin },
            ...r.branches.map((b) => ({ id: b.id, label: `${r.name} — ${b.name}`, hint: b.note })),
          ]),
        }));
      }
      case "languages":
        return REF.languageFamilies.map((f) => ({ group: f.name, items: f.languages.map((l) => ({ id: l.id, label: l.name, hint: [f.name, l.status].filter(Boolean).join(" · ") })) }));
      case "peoples":
        return REF.culturePools.filter((p) => p.peopleList).map((p) => ({ group: p.region, items: p.peopleList.map((x) => ({ id: x.id, label: x.name, hint: p.region })) }));
      case "langFeatures":
        return [{ group: "Language features", items: REF.langFeatures.map((f) => ({ id: f.id, label: f.name, hint: `${f.description} e.g. ${f.examples}` })) }];
      case "writing": {
        const types = [...new Set(REF.writingSystems.map((w) => w.type))];
        return types.map((t) => ({ group: t, items: REF.writingSystems.filter((w) => w.type === t).map((w) => ({ id: w.id, label: w.name, hint: w.used })) }));
      }
      case "kinship":
        return [{ group: "Kinship & bond traditions", items: REF.kinshipTraditions.map((k) => ({ id: k.id, label: k.name, hint: `${k.roots}. ${k.description}` })) }];
      case "powerArchetypes":
        return [{ group: "Real-world power concepts", items: REF.powerArchetypes.map((a) => ({ id: a.id, label: a.name, hint: `${a.roots}. ${a.summary}` })) }];
      case "animals": case "creatures": case "wars": case "rivalryLore": case "mythHistory":
        return (REF[source] || []).map((g) => ({ group: g.name, items: g.items.map((it) => ({ id: it.id, label: it.name, hint: [it.meta, it.note].filter(Boolean).join(" — ") })) }));
      default:
        return [];
    }
  }

  const cache = {};
  function index(source) {
    if (!cache[source]) {
      cache[source] = new Map();
      for (const g of groups(source)) for (const it of g.items) cache[source].set(it.id, it);
    }
    return cache[source];
  }
  const item = (source, id) => index(source).get(id);
  const label = (source, id) => item(source, id)?.label || id;

  // Reference religion (with branch, if the id names one).
  function religion(id) {
    const [rid] = String(id).split(":");
    const r = REF.religions.find((x) => x.id === rid);
    return { religion: r, branch: r?.branches.find((b) => b.id === id) };
  }
  function language(id) {
    const fid = String(id).split(":")[0];
    const f = REF.languageFamilies.find((x) => x.id === fid);
    return { family: f, language: f?.languages.find((l) => l.id === id) };
  }

  WOW.refdata = { groups, item, label, religion, language };
})(window.WOW);
