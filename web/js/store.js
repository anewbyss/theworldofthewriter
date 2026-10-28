// Local-first storage: IndexedDB holds the working database and rolling snapshots.
// The exported JSON format is identical to the iPad app's, so backups move freely.
(function (WOW) {
  const REF = window.WOW_REF;
  const DB_NAME = "wow-brainstorm";
  const MAX_SNAPSHOTS = 20;
  const SNAPSHOT_EVERY_MS = 10 * 60 * 1000;

  const collections = REF.collections;
  const byId = Object.fromEntries(collections.map((c) => [c.id, c]));

  function emptyData() {
    return Object.fromEntries(collections.map((c) => [c.id, []]));
  }

  const state = {
    data: emptyData(),
    meta: { lastExport: null, lastSnapshot: null, created: new Date().toISOString() },
    dirtySinceSnapshot: false,
  };
  const listeners = new Set();

  // ---- IndexedDB key/value -------------------------------------------------
  let dbPromise;
  function idb() {
    if (!dbPromise) {
      dbPromise = new Promise((resolve, reject) => {
        const req = indexedDB.open(DB_NAME, 1);
        req.onupgradeneeded = () => req.result.createObjectStore("kv");
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      });
    }
    return dbPromise;
  }
  async function kvGet(key) {
    const db = await idb();
    return new Promise((resolve, reject) => {
      const req = db.transaction("kv").objectStore("kv").get(key);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }
  async function kvSet(key, value) {
    const db = await idb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction("kv", "readwrite");
      tx.objectStore("kv").put(value, key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  }

  // ---- Load / save -------------------------------------------------------
  async function load() {
    try {
      const saved = await kvGet("db");
      if (saved && saved.data) {
        state.data = Object.assign(emptyData(), saved.data);
        state.meta = Object.assign(state.meta, saved.meta || {});
      }
    } catch (e) {
      console.warn("IndexedDB unavailable, falling back to localStorage", e);
      const raw = localStorage.getItem("wow-db");
      if (raw) {
        const saved = JSON.parse(raw);
        state.data = Object.assign(emptyData(), saved.data);
        state.meta = Object.assign(state.meta, saved.meta || {});
      }
    }
    await snapshotIfDue(true);
    setInterval(() => snapshotIfDue(false), 60 * 1000);
  }

  const persist = WOW.debounce(async () => {
    const payload = { data: state.data, meta: state.meta };
    try {
      await kvSet("db", payload);
    } catch (e) {
      localStorage.setItem("wow-db", JSON.stringify(payload));
    }
    setSaveState("Saved " + new Date().toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" }));
  }, 400);

  function setSaveState(text) {
    const el = document.getElementById("saveState");
    if (el) el.textContent = text;
  }

  function changed() {
    state.dirtySinceSnapshot = true;
    setSaveState("Saving…");
    persist();
    listeners.forEach((fn) => fn());
  }

  function onChange(fn) { listeners.add(fn); return () => listeners.delete(fn); }

  // ---- CRUD ----------------------------------------------------------------
  function list(col) { return state.data[col] || []; }
  function get(col, id) { return list(col).find((e) => e.id === id); }
  function title(col, entity) {
    if (!entity) return "(missing)";
    const f = byId[col]?.titleField || "title";
    if (!entity[f] && col === "bonds") {
      const who = (id) => get("characters", id)?.name || "Someone";
      return `${who(entity.from)} — ${entity.type || "bond"} — ${who(entity.to)}`;
    }
    return entity[f] || "Untitled " + (byId[col]?.singular || "").toLowerCase();
  }

  // Built-in options for a select field plus any the writer has added.
  function optionsFor(col, f) {
    const custom = list("labels").filter((l) => l.kind === "menu option" && l.field === `${col}.${f.key}` && l.name).map((l) => l.name);
    return [...(f.options || []), ...custom.filter((c) => !(f.options || []).includes(c))];
  }

  // Every tag in use, with the entries carrying it.
  function tagIndex() {
    const out = new Map();
    for (const c of collections) {
      for (const e of list(c.id)) for (const t of e.tags || []) {
        if (!out.has(t)) out.set(t, []);
        out.get(t).push({ col: c.id, e });
      }
    }
    return out;
  }
  function labelFor(name, kind = "tag") { return list("labels").find((l) => l.kind === kind && l.name === name); }
  function create(col, fields) {
    const now = new Date().toISOString();
    const entity = { id: WOW.uid(), createdAt: now, updatedAt: now, ...fields };
    list(col).unshift(entity);
    changed();
    return entity;
  }
  function update(col, id, patch) {
    const e = get(col, id);
    if (!e) return;
    Object.assign(e, patch, { updatedAt: new Date().toISOString() });
    changed();
    return e;
  }
  function remove(col, id) {
    state.data[col] = list(col).filter((e) => e.id !== id);
    // Clean references so continuity stays tidy.
    for (const c of collections) {
      for (const e of list(c.id)) {
        for (const f of c.fields) {
          if (f.type === "ref" && f.collection === col && e[f.key] === id) e[f.key] = null;
          if (f.type === "refs" && f.collection === col && Array.isArray(e[f.key])) e[f.key] = e[f.key].filter((x) => x !== id);
        }
      }
    }
    state.data.links = list("links").filter((l) => l.from !== `${col}:${id}` && l.to !== `${col}:${id}`);
    for (const c of collections) {
      for (const f of c.fields.filter((x) => x.type === "anyrefs")) {
        for (const e of list(c.id)) if (Array.isArray(e[f.key])) e[f.key] = e[f.key].filter((r) => r !== `${col}:${id}`);
      }
    }
    // Unlink map features that pointed at a deleted place or map.
    for (const m of list("maps")) {
      for (const f of m.canvas?.features || []) {
        if (col === "places" && f.placeId === id) delete f.placeId;
        if (col === "maps" && f.mapId === id) delete f.mapId;
      }
    }
    changed();
  }

  function recent(n) {
    const all = [];
    for (const c of collections) for (const e of list(c.id)) all.push({ col: c.id, e });
    return all.sort((a, b) => (b.e.updatedAt || "").localeCompare(a.e.updatedAt || "")).slice(0, n);
  }

  // Plain text of an entity — used for search and originality.
  function textOf(col, e) {
    const c = byId[col];
    const parts = [];
    for (const f of c.fields) {
      const v = e[f.key];
      if (v == null) continue;
      if (["text", "textarea"].includes(f.type)) parts.push(v);
      else if (f.type === "tags" && Array.isArray(v)) parts.push(v.join(" "));
      else if (f.type === "stages" && typeof v === "object") parts.push(Object.values(v).join(" "));
    }
    return parts.join("\n");
  }

  function search(q) {
    q = q.trim().toLowerCase();
    if (!q) return [];
    const out = [];
    for (const c of collections) {
      for (const e of list(c.id)) {
        if (textOf(c.id, e).toLowerCase().includes(q)) out.push({ col: c.id, e });
      }
    }
    return out;
  }

  // ---- Export / import -----------------------------------------------------
  function exportObject() {
    return {
      format: REF.formatName,
      formatVersion: REF.formatVersion,
      app: "web",
      exportedAt: new Date().toISOString(),
      data: state.data,
    };
  }
  function exportJSON() {
    state.meta.lastExport = new Date().toISOString();
    persist();
    return JSON.stringify(exportObject(), null, 2);
  }

  function validate(obj) {
    if (!obj || obj.format !== REF.formatName || typeof obj.data !== "object") {
      throw new Error("This file is not a WOW Brainstorm backup.");
    }
    if (obj.formatVersion > REF.formatVersion) {
      throw new Error("This backup was made by a newer version of WOW Brainstorm.");
    }
  }

  // mode: "merge" keeps the newer copy of each entry by id; "replace" swaps everything.
  async function importObject(obj, mode) {
    validate(obj);
    await snapshot("Before import");
    if (mode === "replace") {
      state.data = Object.assign(emptyData(), obj.data);
    } else {
      for (const c of collections) {
        const incoming = obj.data[c.id] || [];
        const current = list(c.id);
        for (const e of incoming) {
          const idx = current.findIndex((x) => x.id === e.id);
          if (idx === -1) current.push(e);
          else if ((e.updatedAt || "") > (current[idx].updatedAt || "")) current[idx] = e;
        }
        state.data[c.id] = current;
      }
    }
    changed();
  }

  // ---- Snapshots -----------------------------------------------------------
  async function snapshots() { return (await kvGet("snapshots").catch(() => null)) || []; }
  async function snapshot(label) {
    const snaps = await snapshots();
    snaps.unshift({ id: WOW.uid(), at: new Date().toISOString(), label: label || "Auto", counts: counts(), backup: exportObject() });
    while (snaps.length > MAX_SNAPSHOTS) snaps.pop();
    await kvSet("snapshots", snaps).catch((e) => console.warn("snapshot failed", e));
    state.meta.lastSnapshot = new Date().toISOString();
    state.dirtySinceSnapshot = false;
    persist();
  }
  async function snapshotIfDue(onStart) {
    const last = state.meta.lastSnapshot ? Date.parse(state.meta.lastSnapshot) : 0;
    const hasData = collections.some((c) => list(c.id).length);
    if (!hasData) return;
    if (onStart ? Date.now() - last > SNAPSHOT_EVERY_MS : state.dirtySinceSnapshot && Date.now() - last > SNAPSHOT_EVERY_MS) {
      await snapshot(onStart ? "Session start" : "Auto");
    }
  }
  async function restoreSnapshot(id) {
    const snap = (await snapshots()).find((s) => s.id === id);
    if (!snap) return;
    await snapshot("Before restore");
    state.data = Object.assign(emptyData(), snap.backup.data);
    changed();
  }

  function counts() { return Object.fromEntries(collections.map((c) => [c.id, list(c.id).length])); }

  // ---- CSV -----------------------------------------------------------------
  function csv(col) {
    const c = byId[col];
    const fields = c.fields.filter((f) => !["portrait", "ink", "stages", "mapcanvas", "genome", "issuekeys"].includes(f.type));
    const cell = (v) => {
      const s = v == null ? "" : String(v);
      return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
    };
    const rows = [["id", ...fields.map((f) => f.label)].map(cell).join(",")];
    for (const e of list(col)) {
      rows.push([e.id, ...fields.map((f) => cell(displayValue(f, e[f.key])))].join(","));
    }
    return rows.join("\n");
  }

  function displayValue(f, v) {
    if (v == null || v === "") return "";
    switch (f.type) {
      case "ref": return title(f.collection, get(f.collection, v));
      case "refs": return (v || []).map((id) => title(f.collection, get(f.collection, id))).join("; ");
      case "cultures": return (v || []).map((id) => REF.culturePools.find((p) => p.id === id)?.region || id).join("; ");
      case "style": return REF.narrativeStyles.find((s) => s.id === v)?.name || v;
      case "rasas": return (v || []).map((id) => REF.rasas.find((r) => r.id === id)?.name || id).join("; ");
      case "tags": return (v || []).join("; ");
      case "anyref": return anyTitle(v);
      case "anyrefs": return (v || []).map(anyTitle).join("; ");
      case "refdata": return (v || []).map((id) => WOW.refdata.label(f.source, id)).join("; ");
      case "mapstyle": return REF.mapStyles.find((s) => s.id === v)?.name || v;
      default: return v;
    }
  }

  function anyTitle(ref) {
    if (!ref) return "";
    const [col, id] = ref.split(":");
    return title(col, get(col, id));
  }

  WOW.store = {
    state, collections, byId, load, onChange, list, get, title, optionsFor, tagIndex, labelFor, create, update, remove, recent, textOf, search,
    exportJSON, exportObject, importObject, snapshots, snapshot, restoreSnapshot, counts, csv, displayValue, anyTitle,
  };
})(window.WOW);
