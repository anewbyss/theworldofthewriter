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

  const timelineOf = (ev) => (ev.timeline || "").trim().toLowerCase() || "main";
  const issueKey = (rule, refs) => rule + ":" + refs.map(([c, id]) => `${c}/${id}`).join(",");

  // Rules that can describe a deliberate paradox rather than a mistake.
  const PARADOX_RULES = new Set(["after-death", "two-places", "own-ancestor", "parent-younger", "birth-after-appearance", "prerequisite-cycle",
    "place-cycle", "parent-cycle", "place-not-yet", "place-gone", "map-era", "alive-but-dead", "place-parent-gone", "self-bond",
    "leader-dead", "battle-outside-war", "faction-not-existing", "self-rivalry"]);

  function covers(p, issue) {
    if ((p.issueKeys || []).includes(issue.key)) return true;
    if (p.scope === "every note involving its linked entries") {
      const linked = new Set([...(p.characters || []).map((id) => "characters/" + id), ...(p.events || []).map((id) => "events/" + id),
        ...(p.places || []).map((id) => "places/" + id), ...(p.abilities || []).map((id) => "abilities/" + id)]);
      return issue.refs.some(([c, id]) => linked.has(`${c}/${id}`)) && PARADOX_RULES.has(issue.rule);
    }
    return false;
  }

  function check(data) {
    const issues = [];
    const chars = Object.fromEntries((data.characters || []).map((c) => [c.id, c]));
    const works = Object.fromEntries((data.works || []).map((w) => [w.id, w]));
    const name = (c) => c?.name || "Unnamed character";
    const push = (level, rule, message, refs) => issues.push({ level, rule, message, refs: refs || [], key: issueKey(rule, refs || []) });

    // 1. Timeline life & death order.
    // Tracked per character *per timeline* so alternate branches never clash.
    // Time-travel events count as a return and excuse early appearances.
    const dead = {}; // `${charId}|${timeline}` -> event
    const seen = {};
    const lastDeath = {}; // charId -> latest death event in the main timeline
    const travellers = new Set((data.events || []).filter((e) => e.type === "time travel").flatMap((e) => e.characters || []));
    for (const ev of orderedEvents(data)) {
      const tl = timelineOf(ev);
      for (const cid of ev.characters || []) {
        const c = chars[cid];
        if (!c) continue;
        const k = `${cid}|${tl}`;
        if (ev.type === "birth") {
          if (seen[k] && !travellers.has(cid)) push("warn", "birth-after-appearance", `${name(c)} is born in "${ev.title}" but already appeared earlier in "${seen[k].title}".`, [["characters", cid], ["events", ev.id]]);
        }
        if (dead[k] && !["return", "transformation", "time travel"].includes(ev.type)) {
          push("bad", "after-death", `${name(c)} appears in "${ev.title}" after dying in "${dead[k].title}" with no return, transformation or time-travel event between.`, [["characters", cid], ["events", ev.id]]);
        }
        if (ev.type === "death") { dead[k] = ev; if (tl === "main") lastDeath[cid] = ev; }
        if (["return", "transformation", "time travel"].includes(ev.type)) { delete dead[k]; if (tl === "main") delete lastDeath[cid]; }
        if (!seen[k]) seen[k] = ev;

        if (ev.type === "acquires ability" && ev.ability && !(c.abilities || []).includes(ev.ability)) {
          push("info", "acquire-unlisted", `${name(c)} acquires an ability in "${ev.title}" that isn't listed on their profile.`, [["characters", cid], ["abilities", ev.ability]]);
        }
        if (ev.work && works[ev.work] && !(c.works || []).includes(ev.work)) {
          push("info", "work-missing-event", `${name(c)} is in "${ev.title}" (shown in ${works[ev.work].title}) but that work isn't in their media appearances.`, [["characters", cid], ["works", ev.work]]);
        }
      }
    }

    // 2. Status vs. timeline.
    for (const c of data.characters || []) {
      if (c.status === "dead" && !(data.events || []).some((e) => e.type === "death" && (e.characters || []).includes(c.id))) {
        push("info", "dead-no-event", `${name(c)} is marked dead but has no death event on the timeline.`, [["characters", c.id]]);
      }
      if (c.status === "alive" && lastDeath[c.id]) {
        push("warn", "alive-but-dead", `${name(c)} is marked alive but the timeline ends with their death in "${lastDeath[c.id].title}".`, [["characters", c.id], ["events", lastDeath[c.id].id]]);
      }
    }

    // 3. Storylines vs. media appearances.
    for (const s of data.storylines || []) {
      if (!s.work || !works[s.work]) continue;
      for (const cid of s.characters || []) {
        const c = chars[cid];
        if (c && !(c.works || []).includes(s.work)) {
          push("info", "work-missing-storyline", `${name(c)} is in storyline "${s.title || "Untitled"}" for ${works[s.work].title}, but that work isn't in their media appearances.`, [["characters", cid], ["storylines", s.id]]);
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
      if (from != null && seq < from) push("warn", "place-not-yet", `"${ev.title || "Untitled"}" happens at ${pname(p)} (order ${seq}) before it exists (from ${from}).`, [["events", ev.id], ["places", p.id]]);
      if (to != null && seq > to) push("warn", "place-gone", `"${ev.title || "Untitled"}" happens at ${pname(p)} (order ${seq}) after it's gone (until ${to}).`, [["events", ev.id], ["places", p.id]]);
      for (const cid of ev.characters || []) {
        const key = `${cid}|${seq}|${timelineOf(ev)}`;
        const prev = atSeq[key];
        const travel = prev && (prev.ev.type === "time travel" || ev.type === "time travel");
        if (prev && !travel && prev.place !== ev.place && !isWithin(prev.place, ev.place) && !isWithin(ev.place, prev.place)) {
          push("bad", "two-places", `${name(chars[cid])} is in two places at once (order ${seq}): ${pname(places[prev.place])} in "${prev.ev.title || "Untitled"}" and ${pname(p)} in "${ev.title || "Untitled"}".`, [["characters", cid], ["events", prev.ev.id], ["events", ev.id]]);
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
        if (id === p.id) { push("warn", "place-cycle", `${pname(p)} ends up inside itself — check its parent places.`, [["places", p.id]]); break; }
        id = places[id]?.parent;
      }
      const par = places[p.parent];
      if (par && num(par.existsTo) != null && num(p.existsFrom) != null && num(p.existsFrom) > num(par.existsTo)) {
        push("info", "place-parent-gone", `${pname(p)} starts (${p.existsFrom}) after the place it lies within, ${pname(par)}, is gone (${par.existsTo}).`, [["places", p.id], ["places", par.id]]);
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
        if (!overlaps) push("info", "map-era", `Map "${m.title || "Untitled"}" shows ${pname(p)}, which doesn't exist during the map's era.`, [["maps", m.id], ["places", p.id]]);
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
      if (ancestors(c.id).has(c.id)) push("bad", "own-ancestor", `${name(c)} is their own ancestor — check the parent links.`, [["characters", c.id]]);
      for (const pid of c.parents || []) {
        if (birth[pid] != null && birth[c.id] != null && birth[pid] >= birth[c.id]) {
          push("warn", "parent-younger", `${name(c)} is born (order ${birth[c.id]}) no later than their parent ${name(chars[pid])} (order ${birth[pid]}).`, [["characters", c.id], ["characters", pid]]);
        }
      }
      for (const aid of c.abilities || []) {
        const a = abilities[aid];
        if (!a) continue;
        for (const pre of a.prerequisites || []) {
          if (abilities[pre] && !(c.abilities || []).includes(pre)) {
            push("warn", "missing-prerequisite", `${name(c)} has ${aname(a)} but not its prerequisite ${aname(abilities[pre])}.`, [["characters", c.id], ["abilities", aid], ["abilities", pre]]);
          }
        }
        const lin = lineages[a.lineage];
        if (lin && !(c.lineages || []).includes(lin.id)) {
          const fromKin = [...ancestors(c.id)].some((p) => (chars[p]?.lineages || []).includes(lin.id));
          const bondKin = (data.bonds || []).filter((b) => b.to === c.id && b.status !== "ended" && b.status !== "broken").map((b) => b.from);
          const fromTeacher = [...(c.teachers || []), ...bondKin].some((t) => (chars[t]?.lineages || []).includes(lin.id) || (chars[t]?.abilities || []).includes(aid));
          if (!fromKin && !fromTeacher) push("info", "lineage-untied", `${name(c)} holds ${aname(a)}, which passes down through ${lin.name || "a lineage"}, but has no tie to that lineage (membership, ancestor or teacher).`, [["characters", c.id], ["abilities", aid], ["lineages", lin.id]]);
        }
      }
    }
    for (const a of data.abilities || []) {
      // Prerequisite cycles.
      const seen = new Set(), stack = [...(a.prerequisites || [])];
      while (stack.length) {
        const x = stack.pop();
        if (x === a.id) { push("warn", "prerequisite-cycle", `${aname(a)} ends up requiring itself — check its prerequisites.`, [["abilities", a.id]]); break; }
        if (seen.has(x) || !abilities[x]) continue;
        seen.add(x); stack.push(...(abilities[x].prerequisites || []));
      }
      const sys = systems[a.system];
      if (sys && a.rank && sys.ranks) {
        const ranks = sys.ranks.split("\n").map((r) => r.trim().toLowerCase()).filter(Boolean);
        if (ranks.length && !ranks.includes(a.rank.trim().toLowerCase())) {
          push("info", "rank-mismatch", `${aname(a)} has rank "${a.rank}", which isn't one of ${sys.name || "its system"}'s ranks (${ranks.join(", ")}).`, [["abilities", a.id], ["powerSystems", sys.id]]);
        }
      }
    }
    for (const l of data.lineages || []) {
      if (l.founder && chars[l.founder] && !(chars[l.founder].lineages || []).includes(l.id)) {
        push("info", "founder-not-member", `${name(chars[l.founder])} founded ${l.name || "a lineage"} but isn't listed as a member of it.`, [["lineages", l.id], ["characters", l.founder]]);
      }
    }
    // Parent cycles in any collection with a "parent" field.
    for (const col of ["powerSystems", "religions", "languages", "cultures"]) {
      const items = Object.fromEntries((data[col] || []).map((x) => [x.id, x]));
      for (const x of data[col] || []) {
        let id = x.parent;
        for (let i = 0; id && i < 25; i++) {
          if (id === x.id) { push("warn", "parent-cycle", `${x.name || "An entry"} ends up as its own ancestor — check its “parent”.`, [[col, x.id]]); break; }
          id = items[id]?.parent;
        }
      }
    }

    // 6. Gear custody and curses / blessings over time.
    for (const g of data.gear || []) {
      const holder = chars[g.owner];
      if (holder && holder.status === "dead") push("info", "gear-dead-holder", `${g.name || "Gear"} is still held by ${name(holder)}, who is dead.`, [["gear", g.id], ["characters", holder.id]]);
      let last = null;
      for (const ev of orderedEvents(data)) {
        if (ev.item !== g.id || timelineOf(ev) !== "main") continue;
        if (ev.type === "gains item") last = (ev.characters || [])[0] || null;
        if (ev.type === "loses item" && (ev.characters || []).includes(last)) last = null;
      }
      if (last && g.owner && last !== g.owner && chars[last]) {
        push("info", "gear-custody", `The timeline ends with ${name(chars[last])} holding ${g.name || "this gear"}, but its current holder is ${name(holder)}.`, [["gear", g.id], ["characters", last]]);
      }
    }
    for (const [col, endType, endStatus] of [["curses", "curse lifted", "lifted"], ["blessings", "blessing lost", "revoked"]]) {
      const key = col === "curses" ? "curse" : "blessing";
      for (const x of data[col] || []) {
        const ended = (data.events || []).some((ev) => ev[key] === x.id && ev.type === endType);
        if (ended && (x.status === "active" || !x.status)) push("info", `${key}-status`, `${x.name || "This " + key} ends on the timeline but is still marked active.`, [[col, x.id]]);
      }
    }

    // 7. Bonds and heirlooms.
    for (const b of data.bonds || []) {
      if (b.from && b.from === b.to && chars[b.from]) push("info", "self-bond", `${name(chars[b.from])} has a bond with themselves (${b.type || "bond"}) — a time-loop, perhaps?`, [["characters", b.from], ["bonds", b.id]]);
    }
    const lineageOk = (cid, lid) => {
      const c = chars[cid];
      if (!c) return false;
      if ((c.lineages || []).includes(lid)) return true;
      // Adopted, fostered or sworn into a member's household also counts.
      return (data.bonds || []).some((b) => (b.to === cid || b.from === cid) && b.status !== "broken" && ((chars[b.to === cid ? b.from : b.to]?.lineages) || []).includes(lid));
    };
    for (const g of data.gear || []) {
      if (!g.heirloomOf) continue;
      const lin = lineages[g.heirloomOf];
      const ln = lin?.name || "its family";
      if (g.owner && chars[g.owner] && !lineageOk(g.owner, g.heirloomOf)) push("info", "heirloom-outside", `The heirloom ${g.name || "gear"} is held by ${name(chars[g.owner])}, outside ${ln}. Lost, stolen or gifted?`, [["gear", g.id], ["characters", g.owner]]);
      if (g.heir && chars[g.heir]) {
        if (chars[g.heir].status === "dead") push("warn", "heir-dead", `${name(chars[g.heir])}, heir to ${g.name || "the heirloom"}, is dead.`, [["gear", g.id], ["characters", g.heir]]);
        else if (!lineageOk(g.heir, g.heirloomOf)) push("info", "heir-outside", `${name(chars[g.heir])} is heir to ${g.name || "the heirloom"} but has no tie to ${ln}.`, [["gear", g.id], ["characters", g.heir]]);
      }
    }

    // 8. Wars, rivalries and factions.
    const sidesOf = (w) => [w.sideA || [], w.sideB || [], w.others || []];
    for (const w of data.conflicts || []) {
      const start = num(w.start), end = num(w.end);
      const wn = w.name || "a conflict";
      if (start != null && end != null && end < start) push("warn", "war-reversed", `${wn} ends (${end}) before it begins (${start}).`, [["conflicts", w.id]]);
      for (const ev of data.events || []) {
        if (!(w.battles || []).includes(ev.id)) continue;
        const s = num(ev.sequence);
        if (s != null && start != null && (s < start || (end != null && s > end))) push("warn", "battle-outside-war", `"${ev.title || "A battle"}" (order ${s}) falls outside ${wn} (${start}–${end ?? "ongoing"}).`, [["events", ev.id], ["conflicts", w.id]]);
      }
      for (const id of w.leaders || []) {
        const died = (data.events || []).find((ev) => ev.type === "death" && (ev.characters || []).includes(id) && num(ev.sequence) != null && start != null && num(ev.sequence) < start);
        if (died && chars[id]) push("warn", "leader-dead", `${name(chars[id])} leads in ${wn} but died earlier ("${died.title || "death"}").`, [["characters", id], ["conflicts", w.id], ["events", died.id]]);
      }
      const both = (w.sideA || []).filter((r) => (w.sideB || []).includes(r));
      if (both.length && w.kind !== "civil war") push("info", "both-sides", `${wn} has ${both.map((r) => r.split(":")[1]).length} participant(s) on both sides — a civil war, defection or double agent?`, [["conflicts", w.id]]);
      for (const ref of sidesOf(w).flat()) {
        const [col, id] = ref.split(":");
        if (col !== "factions") continue;
        const f = (data.factions || []).find((x) => x.id === id);
        const fd = num(f?.dissolved), ff = num(f?.founded);
        if (f && start != null && ((fd != null && fd < start) || (ff != null && ff > (end ?? start)))) push("warn", "faction-not-existing", `${f.name || "A faction"} fights in ${wn} but doesn't exist then (${ff ?? "?"}–${fd ?? "now"}).`, [["factions", f.id], ["conflicts", w.id]]);
      }
    }
    for (const f of data.factions || []) {
      for (const a of f.allies || []) {
        const other = (data.factions || []).find((x) => x.id === a);
        if (other && (other.enemies || []).includes(f.id)) push("info", "one-sided-alliance", `${f.name || "A faction"} counts ${other.name || "another faction"} as an ally, but they count it as an enemy.`, [["factions", f.id], ["factions", other.id]]);
      }
    }
    for (const r of data.rivalries || []) {
      if ((r.sideA || []).some((x) => (r.sideB || []).includes(x))) push("info", "self-rivalry", `${r.name || "A rivalry"} has someone on both sides — an inner rivalry, or a time-loop?`, [["rivalries", r.id]]);
    }

    // 9. Duplicate names.
    const dupes = (col, field) => {
      const seenNames = {};
      for (const e of data[col] || []) {
        const n = (e[field] || "").trim().toLowerCase();
        if (!n) continue;
        if (seenNames[n]) push("warn", "duplicate-name", `Two ${col} share the name "${e[field]}".`, [[col, seenNames[n]], [col, e.id]]);
        else seenNames[n] = e.id;
      }
    };
    dupes("characters", "name");
    dupes("abilities", "name");
    dupes("works", "title");
    dupes("places", "name");
    dupes("factions", "name");
    dupes("conflicts", "name");
    dupes("powerSystems", "name");
    dupes("lineages", "name");
    dupes("cultures", "name");
    dupes("religions", "name");
    dupes("languages", "name");

    // 10. Loose threads.
    for (const c of data.characters || []) {
      if (!(c.works || []).length) push("info", "no-works", `${name(c)} doesn't appear in any book or media yet.`, [["characters", c.id]]);
    }
    for (const a of data.abilities || []) {
      if (!(data.characters || []).some((c) => (c.abilities || []).includes(a.id))) {
        push("info", "ability-unheld", `Ability "${a.name || "Untitled"}" isn't held by any character.`, [["abilities", a.id]]);
      }
    }
    // Intentional paradoxes: matching notes become part of the story, not errors.
    for (const i of issues) {
      const p = (data.paradoxes || []).find((x) => covers(x, i));
      if (p) { i.paradox = p.id; i.originalLevel = i.level; i.level = "paradox"; }
    }
    const order = { bad: 0, warn: 1, info: 2, paradox: 3 };
    return issues.sort((a, b) => order[a.level] - order[b.level]);
  }

  WOW.continuity = { check, orderedEvents, PARADOX_RULES };
})(typeof window !== "undefined" ? window : globalThis);
