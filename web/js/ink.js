// Handwriting pad for Apple Pencil, stylus, finger or mouse (Pointer Events with pressure).
// "Convert to text" uses the browser's on-device Handwriting Recognition API where it exists.
// On iPad, Safari's Scribble also lets you write straight into any text box in this app.
(function (WOW) {
  const { h } = WOW;
  const COLORS = ["#22142F", "#4B1F7A", "#9C7A00", "#B42318", "#1E6F5C"];

  function pad({ png, onSave, onText }) {
    const canvas = h("canvas");
    const ctx = canvas.getContext("2d");
    let strokes = [];          // strokes drawn this session: {color, width, erase, points:[{x,y,p,t}]}
    let base = null;           // previously saved image
    let color = COLORS[0], width = 3, erase = false, penOnly = false;
    let current = null;

    function resize() {
      const rect = canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.max(1, Math.round(rect.width * dpr));
      canvas.height = Math.max(1, Math.round(rect.height * dpr));
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      redraw();
    }

    function drawStroke(s) {
      ctx.save();
      ctx.globalCompositeOperation = s.erase ? "destination-out" : "source-over";
      ctx.strokeStyle = s.color;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      for (let i = 1; i < s.points.length; i++) {
        const a = s.points[i - 1], b = s.points[i];
        ctx.lineWidth = s.width * (s.erase ? 6 : 0.4 + (b.p || 0.5) * 1.6);
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.stroke();
      }
      ctx.restore();
    }

    function redraw() {
      const rect = canvas.getBoundingClientRect();
      ctx.clearRect(0, 0, rect.width, rect.height);
      if (base) ctx.drawImage(base, 0, 0, base.width, base.height, 0, 0, base.width / (base.dpr || 1), base.height / (base.dpr || 1));
      strokes.forEach(drawStroke);
    }

    function pos(ev) {
      const r = canvas.getBoundingClientRect();
      return { x: ev.clientX - r.left, y: ev.clientY - r.top, p: ev.pressure || 0.5, t: Date.now() };
    }

    canvas.addEventListener("pointerdown", (ev) => {
      if (penOnly && ev.pointerType === "touch") return; // palm rejection: ignore fingers
      canvas.setPointerCapture(ev.pointerId);
      current = { color, width, erase, points: [pos(ev)] };
      strokes.push(current);
      ev.preventDefault();
    });
    canvas.addEventListener("pointermove", (ev) => {
      if (!current) return;
      const events = ev.getCoalescedEvents ? ev.getCoalescedEvents() : [ev];
      for (const e of events) current.points.push(pos(e));
      redraw();
      ev.preventDefault();
    });
    const end = () => { if (current) { current = null; save(); } };
    canvas.addEventListener("pointerup", end);
    canvas.addEventListener("pointercancel", end);

    const save = WOW.debounce(() => {
      const img = canvas.toDataURL("image/png");
      onSave && onSave(img);
    }, 600);

    if (png) {
      const img = new Image();
      img.onload = () => {
        // Saved images are stored at device-pixel resolution.
        img.dpr = window.devicePixelRatio || 1;
        base = img;
        redraw();
      };
      img.src = png;
    }

    async function recognise() {
      if (!("createHandwritingRecognizer" in navigator)) {
        WOW.toast("This browser has no handwriting recognition. On iPad, use Scribble in any text box, or the iPad app.");
        return;
      }
      const inkStrokes = strokes.filter((s) => !s.erase && s.points.length > 1);
      if (!inkStrokes.length) { WOW.toast("Write something new on the page first."); return; }
      try {
        const recognizer = await navigator.createHandwritingRecognizer({ languages: ["en"] });
        const drawing = recognizer.startDrawing({ recognitionType: "text", inputType: "stylus" });
        const t0 = inkStrokes[0].points[0].t;
        for (const s of inkStrokes) {
          const stroke = new window.HandwritingStroke();
          for (const p of s.points) stroke.addPoint({ x: p.x, y: p.y, t: p.t - t0 });
          drawing.addStroke(stroke);
        }
        const predictions = await drawing.getPrediction();
        drawing.clear();
        recognizer.finish();
        if (predictions && predictions[0]) onText && onText(predictions[0].text);
        else WOW.toast("Couldn't read that — try writing a little larger.");
      } catch (e) {
        console.warn(e);
        WOW.toast("Handwriting recognition isn't available for this language/device.");
      }
    }

    const colorBtns = COLORS.map((c) => h("button.swatch", { type: "button", style: { background: c }, "aria-label": "Ink colour", onclick: (ev) => {
      color = c; erase = false;
      colorBtns.forEach((b) => b.classList.remove("on"));
      ev.currentTarget.classList.add("on");
      eraserBtn.classList.remove("gold");
    } }));
    colorBtns[0].classList.add("on");
    const eraserBtn = h("button.ghost.small", { type: "button", onclick: () => { erase = !erase; eraserBtn.classList.toggle("gold", erase); } }, "Eraser");
    const penOnlyBtn = h("button.ghost.small", { type: "button", title: "Ignore finger touches so your palm can rest on the screen", onclick: () => { penOnly = !penOnly; penOnlyBtn.classList.toggle("gold", penOnly); } }, "Pencil only");
    const widthSel = h("select", { style: { width: "auto" }, onchange: (e) => { width = Number(e.target.value); } },
      [["1.5", "Fine"], ["3", "Medium"], ["6", "Bold"]].map(([v, l]) => h("option", { value: v, selected: v === "3" || null }, l)));

    const tools = h("div.ink-tools",
      ...colorBtns, widthSel, eraserBtn, penOnlyBtn,
      h("button.ghost.small", { type: "button", onclick: () => { strokes.pop(); redraw(); save(); } }, "Undo"),
      h("button.ghost.small", { type: "button", onclick: () => { if (confirm("Clear this page?")) { strokes = []; base = null; redraw(); save(); } } }, "Clear"),
      h("span", { style: { flex: 1 } }),
      h("button.gold.small", { type: "button", onclick: recognise }, "Convert to text"));

    const wrap = h("div.ink-wrap", tools, canvas);
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    return wrap;
  }

  WOW.ink = { pad };
})(window.WOW);
