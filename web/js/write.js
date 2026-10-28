// Focused writing page: one big text area for typing or Apple Pencil Scribble,
// with the spark or prompt kept above it rather than inside your words.
(function (WOW) {
  const REF = window.WOW_REF;
  const { h, store, views: V } = WOW;

  const words = (s) => (String(s || "").trim().match(/\S+/g) || []).length;

  // Start a new page from a prompt and open it for writing.
  WOW.writeFrom = (prompt, tags = ["spark"]) => {
    const n = store.create("notes", { title: "", prompt: prompt || "", text: "", tags });
    location.hash = `#/write/${n.id}`;
  };

  V.write = (id) => {
    const note = store.get("notes", id);
    if (!note) return h("div.empty", "This page no longer exists. ", h("a", { href: "#/notes" }, "Ink Pages"));
    const status = h("span.tiny.muted");
    const count = h("span.tiny.muted");
    const showCount = (t) => { const n = words(t); count.textContent = `${n} ${n === 1 ? "word" : "words"}`; };
    // One delayed save per field, so a quick switch from title to text never drops either.
    const saver = (key) => WOW.debounce((v) => { store.update("notes", id, { [key]: v }); status.textContent = "Saved"; }, 300);
    const saveTitle = saver("title"), saveText = saver("text");
    const dirty = () => { status.textContent = "Saving…"; };

    const title = h("input.write-title", { type: "text", value: note.title || "", placeholder: "Title (optional)", "aria-label": "Title",
      oninput: (e) => { dirty(); saveTitle(e.target.value); } });
    const body = WOW.forms.autosize(h("textarea.write-body", {
      value: note.text || "", placeholder: "Start writing — type, dictate, or write with Apple Pencil (Scribble)…", "aria-label": "Your writing",
      spellcheck: true, autocapitalize: "sentences",
      oninput: (e) => { dirty(); showCount(e.target.value); saveText(e.target.value); } }));
    showCount(note.text);

    const promptText = h("p.write-prompt-text", note.prompt || "");
    const promptCard = h("div.write-prompt" + (note.prompt ? "" : ".hidden"),
      h("div.eyebrow", "Spark"), promptText,
      h("div.row",
        h("button.ghost.small", { type: "button", onclick: () => {
          const p = WOW.pick(REF.sparkTables.storySpark);
          promptText.textContent = p;
          store.update("notes", id, { prompt: p });
        } }, "🎲 Another spark"),
        h("button.ghost.small", { type: "button", onclick: () => { store.update("notes", id, { prompt: "" }); promptCard.classList.add("hidden"); } }, "Hide")));

    // Put the cursor at the end of what's there, ready to write.
    setTimeout(() => { body.focus({ preventScroll: true }); body.setSelectionRange(body.value.length, body.value.length); }, 60);

    return h("div.write-page",
      h("div.row.spread.no-print",
        h("a", { href: "#/notes" }, "← Ink Pages"),
        h("div.row", status, count,
          h("a.btn.ghost.small", { href: `#/notes/${id}`, title: "Open the full page with the handwriting canvas, tags and links" }, "✍️ Handwriting & details"),
          h("a.btn.small", { href: "#/notes" }, "Done"))),
      promptCard,
      h("div.write-sheet", title, body),
      h("p.tiny.muted.no-print", "Saved automatically on this device. With Apple Pencil in Safari, write anywhere in the box and Scribble turns it into text."));
  };
})(window.WOW);
