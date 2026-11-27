// Injected into Raycast's launcher page by patch.sh. Washes the window in colour on Hue Menubar pages:
// - scene grid: the selected scene tile (saved under scene-glow/), plus a glow around the tile;
// - light/room lists: the selected row's room colours (room-glow/), toned down;
// - colour and brightness grids: the selected swatch's colour, toned down, and dimmer with lower brightness.
// Root search and other extensions are left alone. Two layers crossfade (images are decoded first) so changes animate without flicker.
(() => {
  const OURS = "hue-menubar";
  // svg/<room or "all">~<glowHash>~<iconHash>.svg, with the slash possibly URL-encoded
  const ROOM_ICON = /svg(\/|%2F)([^/%]+~[0-9a-f]{16})~[0-9a-f]{16}\.svg/i;
  const layers = [0, 1].map(() => {
    const d = document.createElement("div");
    d.className = "hue-glow-layer";
    return d;
  });
  let front = 0;
  let last;
  let lastTile;

  const visible = (e) => e.getClientRects().length > 0;
  // Image addresses may be URL-encoded, so match on the decoded form
  const decoded = (src) => {
    try {
      return decodeURIComponent(src);
    } catch {
      return src;
    }
  };
  const ours = (img, folder) => {
    const p = decoded(img.src);
    return p.includes(OURS) && p.includes(`/${folder}/`);
  };

  // What the current page should glow with, or null
  function pick() {
    // Pushed views keep the root list in the page, hidden, so only visible selections count
    const selected = [...document.querySelectorAll('[data-state="selected"]')].filter(visible);
    const tile = selected.find((e) => e.style.getPropertyValue("--grid-item-content-aspect-ratio"));
    if (tile) {
      const img = tile.querySelector("img");
      if (img && ours(img, "scene-glow")) return { mode: "full", image: img.src, tile };
      const swatch = tile.querySelector('[style*="background-color"]');
      const ourPage = [...document.querySelectorAll(`img[src*="${OURS}"]`)].some(visible);
      if (!swatch || !ourPage) return null;
      // Brightness tiles are titled "50%" or "Off"; colour swatches have no title
      const text = tile.textContent.trim();
      const level = text === "Off" ? 0 : /^(\d+)%$/.test(text) ? Number(RegExp.$1) : 100;
      return level ? { mode: "soft", color: swatch.style.backgroundColor, strength: level / 100 } : null;
    }
    const row = selected.at(-1);
    const img = [...(row?.querySelectorAll("img") ?? [])].find((i) => ours(i, "svg"));
    const roomGlow = img?.src.replace(ROOM_ICON, "room-glow$1$2.svg");
    return roomGlow && roomGlow !== img.src ? { mode: "soft", image: roomGlow } : null;
  }

  let token = 0;

  async function update() {
    const g = pick();
    const key = g && `${g.mode} ${g.image ?? g.color} ${g.strength ?? 1}`;
    if (key === last && g?.tile === lastTile) return;
    last = key;
    lastTile = g?.tile;
    const mine = ++token;

    document.querySelectorAll(".hue-glow-tile").forEach((e) => e.classList.remove("hue-glow-tile"));
    if (g?.tile) {
      g.tile.classList.add("hue-glow-tile");
      g.tile.style.setProperty("--hue-glow-image", `url("${g.image}")`);
    }
    if (!g) return layers.forEach((l) => l.classList.remove("on"));

    // Have the next image decoded before fading it in; a newer selection makes this one stale
    if (g.image) {
      try {
        const img = new Image();
        img.src = g.image;
        await img.decode();
      } catch {}
      if (mine !== token) return;
    }

    // Crossfade: the old layer fades out while the new one fades in
    const previous = layers[front];
    front = 1 - front;
    const next = layers[front];
    next.className = `hue-glow-layer hue-glow-${g.mode}`;
    next.style.setProperty("--hue-glow-image", g.image ? `url("${g.image}")` : "none");
    next.style.setProperty("--hue-glow-color", g.color ?? "transparent");
    next.style.setProperty("--hue-glow-strength", g.strength ?? 1);
    layers.forEach((l) => l.isConnected || document.body.appendChild(l));
    requestAnimationFrame(() => {
      if (mine !== token) return;
      next.classList.add("on");
      previous.classList.remove("on");
    });
  }

  new MutationObserver(update).observe(document.documentElement, {
    subtree: true,
    childList: true,
    attributes: true,
    attributeFilter: ["data-state", "src", "class", "hidden"],
  });
  update();
})();
