// Continuity checks across characters, works, storylines and the timeline.
// Pure function of the data so the same rules run in the iPad app (Continuity.swift).
(function (root) {
  const WOW = root.WOW || (root.WOW = {});

  // Events sorted by in-world order; unsequenced events fall back to the
  // order of the work they appear in, then creation time.
  function orderedEvents(data) {
    const workOrder = Object.fromEntries((data.works || []).map((w) => [w.id, Number(w.order) || 0]));
    return [...(data.events || [])].sort((a, b) => {
      const sa = a.sequence === "" || a.sequence == null ? Infinity : Number(a.sequence);
      const sb = b.sequence === "" || b.sequence == null ? Infinity : Number(b.sequence);
      if (sa !== sb) return sa - sb;
      const wa = workOrder[a.work] || 0, wb = workOrder[b.work] || 0;
      if (wa !== wb) return wa - wb;
      return (a.createdAt || "").localeCompare(b.createdAt || "");
    });
  }

  function check(data) {
    const issues = [];
    const chars = Object.fromEntries((data.characters || []).map((c) => [c.id, c]));
    const works = Object.fromEntries((data.works || []).map((w) => [w.id, w]));
    const name = (c) => c?.name || "Unnamed character";
    const push = (level, message, refs) => issues.push({ level, message, refs: refs || [] });

    // 1. Timeline life & death order.
    const dead = {}; // charId -> event
    const born = {};
    const seen = {};
    for (const ev of orderedEvents(data)) {
      for (const cid of ev.characters || []) {
        const c = chars[cid];
        if (!c) continue;
        if (ev.type === "birth") {
          if (seen[cid]) push("warn", `${name(c)} is born in "${ev.title}" but already appeared earlier in "${seen[cid].title}".`, [["characters", cid], ["events", ev.id]]);
          born[cid] = ev;
        }
        if (dead[cid] && ev.type !== "return" && ev.type !== "transformation") {
          push("bad", `${name(c)} appears in "${ev.title}" after dying in "${dead[cid].title}" with no return or transformation event between.`, [["characters", cid], ["events", ev.id]]);
        }
        if (ev.type === "death") dead[cid] = ev;
        if (ev.type === "return" || ev.type === "transformation") delete dead[cid];
        if (!seen[cid]) seen[cid] = ev;

        if (ev.type === "acquires ability" && ev.ability && !(c.abilities || []).includes(ev.ability)) {
          push("info", `${name(c)} acquires an ability in "${ev.title}" that isn't listed on their profile.`, [["characters", cid], ["abilities", ev.ability]]);
        }
        if (ev.work && works[ev.work] && !(c.works || []).includes(ev.work)) {
          push("info", `${name(c)} is in "${ev.title}" (shown in ${works[ev.work].title}) but that work isn't in their media appearances.`, [["characters", cid], ["works", ev.work]]);
        }
      }
    }

    // 2. Status vs. timeline.
    for (const c of data.characters || []) {
      if (c.status === "dead" && !(data.events || []).some((e) => e.type === "death" && (e.characters || []).includes(c.id))) {
        push("info", `${name(c)} is marked dead but has no death event on the timeline.`, [["characters", c.id]]);
      }
      if (c.status === "alive" && dead[c.id]) {
        push("warn", `${name(c)} is marked alive but the timeline ends with their death in "${dead[c.id].title}".`, [["characters", c.id], ["events", dead[c.id].id]]);
      }
    }

    // 3. Storylines vs. media appearances.
    for (const s of data.storylines || []) {
      if (!s.work || !works[s.work]) continue;
      for (const cid of s.characters || []) {
        const c = chars[cid];
        if (c && !(c.works || []).includes(s.work)) {
          push("info", `${name(c)} is in storyline "${s.title || "Untitled"}" for ${works[s.work].title}, but that work isn't in their media appearances.`, [["characters", cid], ["storylines", s.id]]);
        }
      }
    }

    // 4. Duplicate names.
    const dupes = (col, field) => {
      const seenNames = {};
      for (const e of data[col] || []) {
        const n = (e[field] || "").trim().toLowerCase();
        if (!n) continue;
        if (seenNames[n]) push("warn", `Two ${col} share the name "${e[field]}".`, [[col, seenNames[n]], [col, e.id]]);
        else seenNames[n] = e.id;
      }
    };
    dupes("characters", "name");
    dupes("abilities", "name");
    dupes("works", "title");

    // 5. Loose threads.
    for (const c of data.characters || []) {
      if (!(c.works || []).length) push("info", `${name(c)} doesn't appear in any book or media yet.`, [["characters", c.id]]);
    }
    for (const a of data.abilities || []) {
      if (!(data.characters || []).some((c) => (c.abilities || []).includes(a.id))) {
        push("info", `Ability "${a.name || "Untitled"}" isn't held by any character.`, [["abilities", a.id]]);
      }
    }
    const order = { bad: 0, warn: 1, info: 2 };
    return issues.sort((a, b) => order[a.level] - order[b.level]);
  }

  WOW.continuity = { check, orderedEvents };
})(typeof window !== "undefined" ? window : globalThis);
