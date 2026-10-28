// Fictional heredity for the offspring calculator — simple, transparent rules, not real
// human genetics. Genotypes use T for the trait variant and o for the alternative.
// Mirrored in Heredity.swift.
(function (root) {
  const WOW = root.WOW || (root.WOW = {});

  const isX = (t) => t.mode === "X-linked recessive" || t.mode === "X-linked dominant";
  const pen = (t) => (t.penetrance === "" || t.penetrance == null ? 1 : Math.max(0, Math.min(100, Number(t.penetrance))) / 100);
  const v = (t) => t.variant || t.name || "trait";
  const o = (t) => t.other || "no trait";

  function options(t, chromosomes) {
    switch (t.mode) {
      case "dominant":
        return [["TT", `${v(t)} — pure (TT)`], ["To", `${v(t)} — carries ${o(t)} (To)`], ["T?", `${v(t)} — genotype unknown`], ["oo", `${o(t)} (oo)`], ["?", "unknown"]];
      case "recessive":
        return [["TT", `${v(t)} (TT)`], ["To", `${o(t)} — carrier (To)`], ["o?", `${o(t)} — may carry`], ["oo", `${o(t)} — non-carrier (oo)`], ["?", "unknown"]];
      case "codominant (blend)":
        return [["TT", `${v(t)} (TT)`], ["To", `${t.blend || "blend"} (To)`], ["oo", `${o(t)} (oo)`], ["?", "unknown"]];
      case "X-linked recessive":
      case "X-linked dominant":
        if (chromosomes === "XY") return [["T", `${v(t)} on their X`], ["o", `${o(t)} on their X`], ["?", "unknown"]];
        if (chromosomes === "XX") return [["TT", `${v(t)} on both X (TT)`], ["To", `one ${v(t)} X (To)`], ["oo", `no ${v(t)} (oo)`], ["?", "unknown"]];
        return [["?", "set XX or XY above to use this trait"]];
      case "one parent line":
      case "spirit-chosen (chance)":
        return [["yes", `has ${v(t)}`], ["no", `doesn't have ${v(t)}`]];
      default:
        return [];
    }
  }

  // Probability that a parent passes on the T allele.
  function pT(g) {
    return { TT: 1, To: 0.5, oo: 0, "T?": 2 / 3, "o?": 1 / 3, T: 1, o: 0 }[g] ?? 0.5;
  }

  function shows(t, g) {
    if (t.mode === "dominant" || t.mode === "X-linked dominant") return g.includes("T");
    if (t.mode === "recessive") return g === "TT";
    if (t.mode === "X-linked recessive") return g === "TT" || g === "T";
    if (t.mode === "codominant (blend)") return g !== "oo";
    return false;
  }

  function label(t, g) {
    if (t.mode === "codominant (blend)") return { TT: v(t), To: t.blend || `${v(t)}/${o(t)} blend`, oo: o(t) }[g];
    return shows(t, g) ? v(t) : o(t);
  }

  function autosomal(p1, p2) {
    return { TT: p1 * p2, To: p1 * (1 - p2) + p2 * (1 - p1), oo: (1 - p1) * (1 - p2) };
  }

  const num = (x) => (x === "" || x == null || isNaN(Number(x)) ? null : Number(x));
  function polyParams(t, a, b) {
    const lo = num(t.min) ?? 0, hi = num(t.max) ?? 100;
    const va = num(a) ?? (lo + hi) / 2, vb = num(b) ?? (lo + hi) / 2;
    const sd = num(t.spread) ?? ((hi - lo) / 10 || 5);
    return { lo, hi, mean: (va + vb) / 2, sd };
  }

  // genA/genB: parent genome values; chromA/chromB: "XX" | "XY" | other; opts.lineParent: 1 | 2
  function predict(t, genA, genB, chromA, chromB, opts = {}) {
    const P = pen(t);
    if (t.mode === "polygenic (number)") {
      const { lo, hi, mean, sd } = polyParams(t, genA, genB);
      const r = 1.2816 * sd;
      return { kind: "number", mean, low: Math.max(lo, mean - r), high: Math.min(hi, mean + r), unit: t.unit || "" };
    }
    if (t.mode === "one parent line") {
      const g = opts.lineParent === 2 ? genB : genA;
      const p = (g === "yes" ? 1 : 0) * P;
      return { kind: "chance", manifest: p, outcomes: [[v(t), p], [o(t), 1 - p]] };
    }
    if (t.mode === "spirit-chosen (chance)") {
      const parent = genA === "yes" || genB === "yes";
      const p = (num(parent ? t.chanceIfParent : t.chanceOtherwise) ?? 0) / 100;
      return { kind: "chance", manifest: p, outcomes: [[v(t), p], [o(t), 1 - p]] };
    }
    if (isX(t)) {
      let mother = null, father = null;
      if (chromA === "XX" && chromB === "XY") { mother = genA; father = genB; }
      else if (chromA === "XY" && chromB === "XX") { mother = genB; father = genA; }
      if (mother == null) return { kind: "unavailable", note: "X-linked traits need one XX and one XY parent." };
      const pm = pT(mother), pf = pT(father);
      const daughters = autosomal(pm, pf);
      const sons = { T: pm, o: 1 - pm };
      const dShow = Object.entries(daughters).reduce((s, [g, p]) => s + (shows(t, g) ? p : 0), 0);
      const sShow = shows(t, "T") ? sons.T : 0;
      return {
        kind: "x", daughters, sons,
        manifestDaughter: dShow * P, manifestSon: sShow * P, manifest: ((dShow + sShow) / 2) * P,
        outcomes: [[`XX children: ${v(t)}`, dShow * P], [`XY children: ${v(t)}`, sShow * P]],
      };
    }
    const g = autosomal(pT(genA), pT(genB));
    const showP = Object.entries(g).reduce((s, [k, p]) => s + (shows(t, k) ? p : 0), 0);
    return {
      kind: "mendel", genotypes: g, manifest: showP * P,
      punnett: [[pT(genA), pT(genB)]],
      outcomes: t.mode === "codominant (blend)"
        ? [[label(t, "TT"), g.TT * P], [label(t, "To"), g.To * P], [label(t, "oo"), g.oo + (g.TT + g.To) * (1 - P)]]
        : [[v(t), showP * P], [o(t), 1 - showP * P]],
    };
  }

  function gauss(rand) {
    const u = Math.max(rand(), 1e-9), w = rand();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * w);
  }

  // Roll one child. Returns { value, manifests, label }.
  function sample(t, genA, genB, chromA, chromB, childChrom, opts = {}, rand = Math.random) {
    const P = pen(t);
    if (t.mode === "polygenic (number)") {
      const { lo, hi, mean, sd } = polyParams(t, genA, genB);
      const val = Math.round(Math.max(lo, Math.min(hi, mean + gauss(rand) * sd)) * 10) / 10;
      return { value: val, manifests: true, label: `${val}${t.unit ? " " + t.unit : ""}` };
    }
    if (t.mode === "one parent line" || t.mode === "spirit-chosen (chance)") {
      const p = predict(t, genA, genB, chromA, chromB, opts).manifest;
      const yes = rand() < p;
      return { value: yes ? "yes" : "no", manifests: yes, label: yes ? v(t) : o(t) };
    }
    const allele = (g) => (rand() < pT(g) ? "T" : "o");
    let g;
    if (isX(t)) {
      const mother = chromA === "XX" ? genA : genB, father = chromA === "XX" ? genB : genA;
      if (!((chromA === "XX" && chromB === "XY") || (chromA === "XY" && chromB === "XX"))) return { value: "?", manifests: false, label: "unknown" };
      const fromMother = allele(mother);
      g = childChrom === "XY" ? fromMother : [fromMother, allele(father)].sort().reverse().join("").replace("oT", "To");
    } else {
      g = [allele(genA), allele(genB)].sort().reverse().join("");
    }
    if (g === "oT") g = "To";
    const manifests = shows(t, g) && rand() < P;
    return { value: g, manifests, label: manifests ? label(t, g) : (shows(t, g) ? `${o(t)} (${v(t)} dormant)` : label(t, g)) };
  }

  WOW.heredity = { options, predict, sample, shows, label, isX };
})(typeof window !== "undefined" ? window : globalThis);
