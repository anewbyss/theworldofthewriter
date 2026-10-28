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

    // 4. Places across time and space.
    const places = Object.fromEntries((data.places || []).map((p) => [p.id, p]));
    const num = (v) => (v === "" || v == null ? null : Number(v));
    const pname = (p) => p?.name || "Unnamed place";
    const atSeq = {}; // `${charId}|${seq}` -> {place, event}
    for (const ev of orderedEvents(data)) {
      const seq = num(ev.sequence);
      const p = places[ev.place];
      if (!p || seq == null) continue;
      const from = num(p.existsFrom), to = num(p.existsTo);
      if (from != null && seq < from) push("warn", `"${ev.title || "Untitled"}" happens at ${pname(p)} (order ${seq}) before it exists (from ${from}).`, [["events", ev.id], ["places", p.id]]);
      if (to != null && seq > to) push("warn", `"${ev.title || "Untitled"}" happens at ${pname(p)} (order ${seq}) after it's gone (until ${to}).`, [["events", ev.id], ["places", p.id]]);
      for (const cid of ev.characters || []) {
        const key = `${cid}|${seq}`;
        const prev = atSeq[key];
        if (prev && prev.place !== ev.place && !isWithin(prev.place, ev.place) && !isWithin(ev.place, prev.place)) {
          push("bad", `${name(chars[cid])} is in two places at once (order ${seq}): ${pname(places[prev.place])} in "${prev.ev.title || "Untitled"}" and ${pname(p)} in "${ev.title || "Untitled"}".`, [["characters", cid], ["events", prev.ev.id], ["events", ev.id]]);
        } else if (!prev) atSeq[key] = { place: ev.place, ev };
      }
    }
    function isWithin(childId, parentId) {
      let id = places[childId]?.parent;
      for (let i = 0; id && i < 25; i++) { if (id === parentId) return true; id = places[id]?.parent; }
      return false;
    }
    for (const p of data.places || []) {
      let id = p.parent;
      for (let i = 0; id && i < 25; i++) {
        if (id === p.id) { push("warn", `${pname(p)} ends up inside itself — check its parent places.`, [["places", p.id]]); break; }
        id = places[id]?.parent;
      }
      const par = places[p.parent];
      if (par && num(par.existsTo) != null && num(p.existsFrom) != null && num(p.existsFrom) > num(par.existsTo)) {
        push("info", `${pname(p)} starts (${p.existsFrom}) after the place it lies within, ${pname(par)}, is gone (${par.existsTo}).`, [["places", p.id], ["places", par.id]]);
      }
    }
    for (const m of data.maps || []) {
      const ef = num(m.eraFrom), et = num(m.eraTo);
      if (ef == null && et == null) continue;
      for (const f of m.canvas?.features || []) {
        const p = places[f.placeId];
        if (!p) continue;
        const from = num(f.from ?? p.existsFrom), to = num(f.to ?? p.existsTo);
        const overlaps = (from == null || et == null || from <= et) && (to == null || ef == null || to >= ef);
        if (!overlaps) push("info", `Map "${m.title || "Untitled"}" shows ${pname(p)}, which doesn't exist during the map's era.`, [["maps", m.id], ["places", p.id]]);
      }
    }

    // 5. Families, lineages and powers.
    const abilities = Object.fromEntries((data.abilities || []).map((a) => [a.id, a]));
    const systems = Object.fromEntries((data.powerSystems || []).map((s) => [s.id, s]));
    const lineages = Object.fromEntries((data.lineages || []).map((l) => [l.id, l]));
    const aname = (a) => a?.name || "Untitled ability";
    // Ancestors via parents, with cycle detection.
    function ancestors(cid) {
      const out = new Set();
      const stack = [...(chars[cid]?.parents || [])];
      while (stack.length) {
        const p = stack.pop();
        if (out.has(p) || !chars[p]) continue;
        out.add(p);
        stack.push(...(chars[p].parents || []));
      }
      return out;
    }
    const birth = {};
    for (const ev of orderedEvents(data)) if (ev.type === "birth" && num(ev.sequence) != null) for (const cid of ev.characters || []) birth[cid] ??= num(ev.sequence);
    for (const c of data.characters || []) {
      if (ancestors(c.id).has(c.id)) push("bad", `${name(c)} is their own ancestor — check the parent links.`, [["characters", c.id]]);
      for (const pid of c.parents || []) {
        if (birth[pid] != null && birth[c.id] != null && birth[pid] >= birth[c.id]) {
          push("warn", `${name(c)} is born (order ${birth[c.id]}) no later than their parent ${name(chars[pid])} (order ${birth[pid]}).`, [["characters", c.id], ["characters", pid]]);
        }
      }
      for (const aid of c.abilities || []) {
        const a = abilities[aid];
        if (!a) continue;
        for (const pre of a.prerequisites || []) {
          if (abilities[pre] && !(c.abilities || []).includes(pre)) {
            push("warn", `${name(c)} has ${aname(a)} but not its prerequisite ${aname(abilities[pre])}.`, [["characters", c.id], ["abilities", aid], ["abilities", pre]]);
          }
        }
        const lin = lineages[a.lineage];
        if (lin && !(c.lineages || []).includes(lin.id)) {
          const fromKin = [...ancestors(c.id)].some((p) => (chars[p]?.lineages || []).includes(lin.id));
          const fromTeacher = (c.teachers || []).some((t) => (chars[t]?.lineages || []).includes(lin.id) || (chars[t]?.abilities || []).includes(aid));
          if (!fromKin && !fromTeacher) push("info", `${name(c)} holds ${aname(a)}, which passes down through ${lin.name || "a lineage"}, but has no tie to that lineage (membership, ancestor or teacher).`, [["characters", c.id], ["abilities", aid], ["lineages", lin.id]]);
        }
      }
    }
    for (const a of data.abilities || []) {
      // Prerequisite cycles.
      const seen = new Set(), stack = [...(a.prerequisites || [])];
      while (stack.length) {
        const x = stack.pop();
        if (x === a.id) { push("warn", `${aname(a)} ends up requiring itself — check its prerequisites.`, [["abilities", a.id]]); break; }
        if (seen.has(x) || !abilities[x]) continue;
        seen.add(x); stack.push(...(abilities[x].prerequisites || []));
      }
      const sys = systems[a.system];
      if (sys && a.rank && sys.ranks) {
        const ranks = sys.ranks.split("\n").map((r) => r.trim().toLowerCase()).filter(Boolean);
        if (ranks.length && !ranks.includes(a.rank.trim().toLowerCase())) {
          push("info", `${aname(a)} has rank "${a.rank}", which isn't one of ${sys.name || "its system"}'s ranks (${ranks.join(", ")}).`, [["abilities", a.id], ["powerSystems", sys.id]]);
        }
      }
    }
    for (const l of data.lineages || []) {
      if (l.founder && chars[l.founder] && !(chars[l.founder].lineages || []).includes(l.id)) {
        push("info", `${name(chars[l.founder])} founded ${l.name || "a lineage"} but isn't listed as a member of it.`, [["lineages", l.id], ["characters", l.founder]]);
      }
    }
    // Parent cycles in any collection with a "parent" field.
    for (const col of ["powerSystems", "religions", "languages", "cultures"]) {
      const items = Object.fromEntries((data[col] || []).map((x) => [x.id, x]));
      for (const x of data[col] || []) {
        let id = x.parent;
        for (let i = 0; id && i < 25; i++) {
          if (id === x.id) { push("warn", `${x.name || "An entry"} ends up as its own ancestor — check its “parent”.`, [[col, x.id]]); break; }
          id = items[id]?.parent;
        }
      }
    }

    // 6. Duplicate names.
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
    dupes("places", "name");
    dupes("powerSystems", "name");
    dupes("lineages", "name");
    dupes("cultures", "name");
    dupes("religions", "name");
    dupes("languages", "name");

    // 7. Loose threads.
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
