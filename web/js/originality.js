// Originality checker — a transparent word-overlap heuristic, not AI.
// It compares your text against a curated list of well-known tropes and
// against everything else you've written, then explains what overlapped.
// The iPad app implements the exact same algorithm (Originality.swift).
(function (root) {
  const WOW = root.WOW || (root.WOW = {});
  const ref = () => root.WOW_REF;

  function stem(w) {
    if (w.length > 5 && w.endsWith("ing")) return w.slice(0, -3);
    if (w.length > 4 && w.endsWith("ed")) return w.slice(0, -2);
    if (w.length > 4 && w.endsWith("es")) return w.slice(0, -2);
    if (w.length > 3 && w.endsWith("s") && !w.endsWith("ss")) return w.slice(0, -1);
    return w;
  }

  let stopSet;
  function tokens(text) {
    stopSet = stopSet || new Set(ref().stopwords);
    return String(text || "")
      .toLowerCase()
      .split(/[^\p{L}\p{N}]+/u)
      .filter((w) => w.length > 1 && !stopSet.has(w))
      .map(stem);
  }

  function bigrams(toks) {
    const out = new Set();
    for (let i = 0; i < toks.length - 1; i++) out.add(toks[i] + " " + toks[i + 1]);
    return out;
  }

  function jaccard(a, b) {
    if (!a.size || !b.size) return 0;
    let inter = 0;
    for (const x of a) if (b.has(x)) inter++;
    return inter / (a.size + b.size - inter);
  }

  function dice(a, b) {
    if (!a.size || !b.size) return 0;
    let inter = 0;
    for (const x of a) if (b.has(x)) inter++;
    return (2 * inter) / (a.size + b.size);
  }

  function tropeSimilarity(set, trope) {
    let hits = 0;
    const matched = [];
    for (const kw of trope.keywords) {
      const kt = tokens(kw);
      if (kt.length && kt.every((t) => set.has(t))) { hits++; matched.push(kw); }
    }
    const tropeTokens = new Set(tokens([trope.name, ...trope.keywords].join(" ")));
    let inter = 0;
    for (const t of tropeTokens) if (set.has(t)) inter++;
    const containment = tropeTokens.size ? inter / tropeTokens.size : 0;
    const kwScore = Math.min(1, hits * 0.34);
    return { sim: Math.min(1, kwScore * 0.8 + containment * 0.4), hits, matched };
  }

  // others: [{ key, label, text }] — your other entries.
  function check(text, others) {
    const toks = tokens(text);
    const set = new Set(toks);
    const grams = bigrams(toks);

    const tropeMatches = [];
    const representation = [];
    for (const t of ref().tropes) {
      const r = tropeSimilarity(set, t);
      if (t.kind === "representation") {
        if (r.hits >= 2 || r.sim >= 0.4) representation.push({ trope: t, ...r });
      } else if (r.sim >= 0.15) {
        tropeMatches.push({ trope: t, ...r });
      }
    }
    tropeMatches.sort((a, b) => b.sim - a.sim);

    const ownMatches = [];
    for (const o of others || []) {
      const ot = tokens(o.text);
      if (ot.length < 3) continue;
      const sim = 0.6 * jaccard(set, new Set(ot)) + 0.4 * dice(grams, bigrams(ot));
      if (sim >= 0.2) {
        const shared = [...new Set(ot)].filter((w) => set.has(w)).slice(0, 8);
        ownMatches.push({ ...o, sim, shared });
      }
    }
    ownMatches.sort((a, b) => b.sim - a.sim);

    const topTrope = tropeMatches[0]?.sim || 0;
    const topOwn = ownMatches[0]?.sim || 0;
    const score = toks.length < 3 ? null : Math.round(100 * (1 - Math.max(topTrope * 0.9, topOwn)));
    const label = score == null ? "Write a little more to check" : score >= 75 ? "Fresh" : score >= 50 ? "Familiar territory" : "Well-worn";

    // Deterministic twist suggestions so the same text gives the same prompts.
    const twists = ref().twists;
    let hash = 0;
    for (const ch of toks.join(" ")) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
    const suggestions = [0, 1, 2].map((i) => twists[(hash + i * 3) % twists.length]);

    return {
      score, label,
      tropeMatches: tropeMatches.slice(0, 5),
      representation,
      ownMatches: ownMatches.slice(0, 5),
      suggestions,
      wordCount: toks.length,
    };
  }

  WOW.originality = { check, tokens };
})(typeof window !== "undefined" ? window : globalThis);
