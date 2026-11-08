const SITES = [
  {
    sub: "notafriendof",
    title: "Not a Friend Of",
    blurb: "Every opening-credits tagline from 12 Real Housewives franchises: 690 taglines from 188 housewives across 116 seasons.",
    channel: "TV & Pop Culture",
    opened: "10.28.2026",
    tags: "housewives reality tv taglines api data",
    button: "b-yellow",
  },
  {
    sub: "blinkie",
    title: "Sparkle GIF Maker",
    blurb: "Make glitter text and 150x20 blinkies, then save them as GIFs.",
    channel: "Arts & Crafts",
    opened: "11.01.2026",
    tags: "glitter gif blinkie sparkle y2k text maker",
    button: "b-glitter",
  },
  {
    sub: "quarterinch",
    title: "The Geometry of Cloth",
    blurb: "Quilt history and the math inside the blocks, plus a planner for cut sizes and yardage.",
    channel: "Arts & Crafts",
    opened: "10.30.2026",
    tags: "quilt quilting sewing math symmetry wallpaper groups yardage",
    button: "b-quilt",
  },
  {
    sub: "austral",
    title: "Four Southern Hemisphere climate charts",
    blurb: "Four climate charts from my 2017 Harvey Mudd CS35 team project, rebuilt in 2026.",
    channel: "Science",
    opened: "11.02.2026",
    tags: "climate charts antarctica ozone science 2017 harvey mudd",
    button: "b-ice",
  },
  {
    sub: "groover",
    title: "Groover",
    blurb: "A 2019 lyrics-based song recommender, brought back with its original model.",
    channel: "Music",
    opened: "11.05.2026",
    tags: "music lyrics recommender doc2vec machine learning 2019 songs",
    button: "b-groove",
  },
];

const $ = (sel) => document.querySelector(sel);
const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
let channel = "all";

function url(site) {
  return `https://${site.sub}.siena.codes`;
}

function renderSites() {
  const list = $("#sites");
  list.replaceChildren(
    ...SITES.map((site) => {
      const li = document.createElement("li");
      li.className = "site";
      li.dataset.channel = site.channel;
      li.dataset.text = `${site.sub} ${site.title} ${site.blurb} ${site.channel} ${site.tags} ${site.opened}`.toLowerCase();
      li.innerHTML = `
        <a class="b88 ${site.button}" href="${url(site)}" aria-hidden="true" tabindex="-1">${site.sub}<br><b>.siena.codes</b></a>
        <div class="site-body">
          <h3><a href="${url(site)}">${site.title}</a></h3>
          <p class="addr">${site.sub}.siena.codes</p>
          <p>${site.blurb}</p>
          <p class="meta"><span class="chip">${site.channel}</span> opened ${site.opened}</p>
        </div>
        <a class="btn visit" href="${url(site)}">Visit &raquo;</a>`;
      return li;
    })
  );
}

function renderChannels() {
  const ul = $("#channels");
  ul.querySelector(".count").textContent = `(${SITES.length})`;
  const names = [...new Set(SITES.map((s) => s.channel))];
  for (const name of names) {
    const n = SITES.filter((s) => s.channel === name).length;
    const li = document.createElement("li");
    li.innerHTML = `<button type="button" data-channel="${name}">${name} <span class="count">(${n})</span></button>`;
    ul.append(li);
  }
  ul.addEventListener("click", (e) => {
    const btn = e.target.closest("button");
    if (!btn) return;
    channel = btn.dataset.channel;
    ul.querySelectorAll("button").forEach((b) => b.classList.toggle("on", b === btn));
    filter();
  });
}

function filter() {
  const words = $("#q").value.toLowerCase().split(/\s+/).filter(Boolean);
  let shown = 0;
  document.querySelectorAll(".site").forEach((li) => {
    const ok =
      (channel === "all" || li.dataset.channel === channel) &&
      words.every((w) => li.dataset.text.includes(w));
    li.hidden = !ok;
    if (ok) shown++;
  });
  $("#empty").hidden = shown > 0;
  const filtered = shown !== SITES.length;
  $("#result-note").textContent = filtered ? `${shown} of ${SITES.length} sites` : `${SITES.length} sites`;
}

function wireSearch() {
  $("#search").addEventListener("submit", (e) => {
    e.preventDefault();
    filter();
    $("#directory").scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth" });
  });
  $("#q").addEventListener("input", filter);
  $("#clear").addEventListener("click", () => {
    $("#q").value = "";
    channel = "all";
    document.querySelectorAll("#channels button").forEach((b) => b.classList.toggle("on", b.dataset.channel === "all"));
    filter();
  });
}

function wireRing() {
  let i = 0;
  const show = () => {
    const prev = SITES[(i - 1 + SITES.length) % SITES.length];
    const next = SITES[(i + 1) % SITES.length];
    $("#ring-prev").href = url(prev);
    $("#ring-next").href = url(next);
    $("#ring-here").innerHTML = `next stop: <a href="${url(next)}">${next.sub}</a>`;
  };
  $("#ring-rand").addEventListener("click", (e) => {
    e.preventDefault();
    location.href = url(SITES[Math.floor(Math.random() * SITES.length)]);
  });
  $("#ring-rand").href = url(SITES[0]);
  show();
}

function tickClock() {
  const now = new Date();
  $("#clock").textContent = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  $("#date").textContent = now.toLocaleDateString([], { weekday: "long", month: "long", day: "numeric", year: "numeric" });
}

function countVisit() {
  let n = 1;
  try {
    n = Number(localStorage.getItem("visits") || 0) + 1;
    localStorage.setItem("visits", String(n));
  } catch {}
  $("#counter").textContent = String(n).padStart(6, "0");
  $("#counter").setAttribute("aria-label", `${n} visits from you`);
}

function cloneTicker() {
  if (reduceMotion) return;
  const items = $(".ticker-items");
  const copy = items.cloneNode(true);
  copy.setAttribute("aria-hidden", "true");
  items.after(copy);
}

const SPRITES = {
  sparkle: {
    hot: [4, 4],
    rows: [
      "....o...........",
      "....o...........",
      "...oyo..........",
      "..oyyyo.........",
      "ooyywyyoo.......",
      "..oyyyo.........",
      "...oyoco........",
      "....o.occo......",
      "......occco.....",
      ".......occco....",
      "........occco...",
      ".........occco..",
      "..........occco.",
      "...........occo.",
      "............oo..",
      "................",
    ],
    trail: "✦",
  },
  hearts: {
    hot: [0, 0],
    rows: [
      "o...............",
      "oo..............",
      "owo.............",
      "owwo............",
      "owwwo...........",
      "owwwwo..........",
      "owwwwwo.........",
      "owwwwwwooo.ooo..",
      "owwwwooyyyoyyyo.",
      "owwowooywyyyyyo.",
      "owo.owoyyyyyyyo.",
      "oo..owooyyyyyo..",
      "o....oo.oyyyo...",
      ".........oyo....",
      "..........o.....",
      "................",
    ],
    trail: "♥",
  },
};
const PIXEL = { o: "#05506e", y: "#fff0aa", w: "#ffffff", c: "#22bfd8" };
const TRAIL_COLORS = ["#22bfd8", "#fff0aa", "#0a86a8"];
let cursorMode = "plain";
let lastTrail = { t: 0, x: 0, y: 0 };

function spriteUrl(sprite) {
  const scale = 2;
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = 16 * scale;
  const ctx = canvas.getContext("2d");
  sprite.rows.forEach((row, y) =>
    [...row].forEach((ch, x) => {
      if (!PIXEL[ch]) return;
      ctx.fillStyle = PIXEL[ch];
      ctx.fillRect(x * scale, y * scale, scale, scale);
    })
  );
  return `url(${canvas.toDataURL()}) ${sprite.hot[0] * scale} ${sprite.hot[1] * scale}, auto`;
}

function setCursor(mode) {
  cursorMode = SPRITES[mode] ? mode : "plain";
  document.documentElement.style.cursor = SPRITES[mode] ? spriteUrl(SPRITES[mode]) : "";
  document.querySelectorAll("[data-cursor]").forEach((b) =>
    b.setAttribute("aria-pressed", String(b.dataset.cursor === cursorMode))
  );
  try { localStorage.setItem("cursor", cursorMode); } catch {}
}

function dropTrail(e) {
  if (cursorMode === "plain" || reduceMotion || e.pointerType !== "mouse") return;
  const now = performance.now();
  if (now - lastTrail.t < 45 || Math.hypot(e.clientX - lastTrail.x, e.clientY - lastTrail.y) < 10) return;
  lastTrail = { t: now, x: e.clientX, y: e.clientY };
  const bit = document.createElement("span");
  bit.className = "trail";
  bit.setAttribute("aria-hidden", "true");
  bit.textContent = SPRITES[cursorMode].trail;
  bit.style.color = TRAIL_COLORS[Math.floor(Math.random() * TRAIL_COLORS.length)];
  bit.style.setProperty("--x", `${e.clientX + 8}px`);
  bit.style.setProperty("--y", `${e.clientY + 8}px`);
  bit.addEventListener("animationend", () => bit.remove());
  document.body.append(bit);
}

function wireCursor() {
  document.querySelector(".cursor-picks").addEventListener("click", (e) => {
    const btn = e.target.closest("[data-cursor]");
    if (btn) setCursor(btn.dataset.cursor);
  });
  addEventListener("pointermove", dropTrail, { passive: true });
  let saved = "plain";
  try { saved = localStorage.getItem("cursor") || "plain"; } catch {}
  setCursor(saved);
}

function greetConsole() {
  console.log(
    "%c\u2726 siena.codes \u2726",
    "font: bold 16px Verdana, sans-serif; color: #fff0aa; background: #05506e; padding: 4px 10px; border-radius: 3px;"
  );
  console.log("Hi, DevTools friend. Lessons: https://siena.codes/html-for-newbies.html");
}

renderSites();
renderChannels();
wireSearch();
wireRing();
filter();
cloneTicker();
wireCursor();
countVisit();
greetConsole();
tickClock();
setInterval(tickClock, 1000);
