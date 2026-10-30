// Arte pixel de RoninShell. Se construye con pxl (ver art/README.md).
// Paleta "ronin neón": negro, teal para información, oro para recompensas.

pal({
  k: "#05090b", d: "#0d2a27", t: "#1f6f63", T: "#2fbfa8", c: "#5ee6cf", w: "#e8fff8",
  g: "#8a6a2c", G: "#d9a441", y: "#f0cf7a", p: "#d9c9a0", i: "#2a2418",
  r: "#e0674f", s: "#2e4744", S: "#6fb3a5",
})
ramps("kdtTcw", "kgGy")

// ---------------------------------------------------------------- Hosts (mapa de red)

sprite("host_pc", { w: 22, h: 20, outline: "k" },
  rect(1, 1, 20, 13, "T"),
  rect(2, 2, 18, 11, "d"),
  rect(4, 4, 8, 1, "c"), rect(4, 6, 12, 1, "t"), rect(4, 8, 6, 1, "c"), rect(11, 8, 2, 1, "G"),
  px(19, 12, "c"),
  rect(9, 14, 4, 2, "t"),
  rect(5, 16, 12, 3, "T"), hline(5, 18, 12, "t"))

// Tu propia máquina: la misma, en oro.
sprite("host_you", { base: "host_pc", swap: { T: "G", t: "g", c: "y" } })

sprite("host_server", { w: 20, h: 20, outline: "k" },
  rect(1, 0, 18, 20, "T"),
  rect(2, 1, 16, 18, "d"),
  (c) => {
    for (const y of [2, 8, 14]) {
      c.rect(3, y, 14, 5, "s")
      c.rect(4, y + 1, 8, 1, "S")
      c.rect(4, y + 3, 8, 1, "S")
      c.px(14, y + 1, "c")
      c.px(14, y + 3, "G")
      c.px(16, y + 1, "c")
    }
  })

sprite("host_router", { w: 24, h: 18, outline: "k" },
  line(4, 10, 2, 2, "T"), line(19, 10, 21, 2, "T"),
  px(2, 1, "c"), px(21, 1, "c"),
  rect(1, 10, 22, 7, "T"),
  rect(2, 11, 20, 5, "d"),
  px(5, 13, "c"), px(8, 13, "c"), px(11, 13, "G"), px(14, 13, "c"),
  rect(17, 12, 4, 3, "s"))

// Host aún sin descubrir: silueta con interrogación.
sprite("host_ghost", { w: 22, h: 20, outline: "k" },
  rect(1, 1, 20, 13, "s"),
  rect(2, 2, 18, 11, "d"),
  text(8, 3, "?", "S", { scale: 2 }),
  rect(9, 14, 4, 2, "s"),
  rect(5, 16, 12, 3, "s"))

// ---------------------------------------------------------------- Puertos como puertas

sprite("door_closed", { w: 14, h: 16, outline: "k" },
  rect(0, 0, 14, 16, "g"),
  rect(2, 2, 10, 13, "G"),
  hline(2, 8, 10, "g"),
  rect(9, 9, 2, 2, "y"))

sprite("door_open", { w: 14, h: 16, outline: "k" },
  rect(0, 0, 14, 16, "t"),
  grad(1, 1, 12, 15, "wcT", "v"),
  rect(1, 1, 3, 15, "t"),
  vline(2, 2, 13, "T"))

sprite("door_filtered", { w: 14, h: 16, outline: "k" },
  rect(0, 0, 14, 16, "s"),
  rect(1, 1, 12, 14, "d"),
  line(1, 9, 8, 1, "s"), line(1, 14, 13, 3, "s"), line(5, 14, 13, 7, "s"), line(9, 14, 13, 11, "s"))

// ---------------------------------------------------------------- Iconos de servicio

sprite("icon_ssh", { w: 14, h: 12, outline: "k" },
  rect(0, 0, 14, 12, "T"),
  rect(1, 1, 12, 10, "d"),
  px(3, 3, "c"), px(4, 4, "c"), px(5, 5, "c"), px(4, 6, "c"), px(3, 7, "c"),
  rect(7, 8, 4, 1, "G"))

sprite("icon_http", { w: 14, h: 14, outline: "k" },
  circ(7, 7, 6, "d"),
  ring(7, 7, 6, "T"),
  hline(1, 7, 13, "T"), vline(7, 1, 13, "T"),
  ellipse(7, 7, 3, 6, "T", true),
  px(4, 4, "c"))

sprite("icon_ftp", { w: 14, h: 12, outline: "k" },
  rect(0, 1, 6, 3, "g"),
  rect(0, 3, 14, 9, "g"),
  rect(0, 4, 14, 8, "G"),
  hline(1, 5, 12, "y"),
  px(6, 7, "d"), px(7, 8, "d"), px(8, 7, "d"), vline(7, 6, 5, "d"))

sprite("icon_lock", { w: 12, h: 14, outline: "k" },
  ring(6, 5, 4, "y"),
  rect(1, 6, 10, 8, "G"),
  rect(5, 9, 2, 3, "d"))

// ---------------------------------------------------------------- Sellos de objetivo

sprite("seal_done", { w: 22, h: 22 },
  circ(11, 11, 10, "g"), circ(11, 11, 9, "G"), ring(11, 11, 8, "y"),
  line(6, 11, 9, 15, "i", 2), line(9, 15, 16, 7, "i", 2))

sprite("seal_active", { w: 22, h: 22 },
  circ(11, 11, 10, "d"), ring(11, 11, 10, "T"), ring(11, 11, 7, "t"),
  circ(11, 11, 3, "c"))

sprite("seal_pending", { w: 22, h: 22 },
  circ(11, 11, 10, "d"), ring(11, 11, 10, "g"),
  circ(11, 11, 2, "g"))

sprite("seal_locked", { w: 22, h: 22 },
  circ(11, 11, 10, "d"), ring(11, 11, 10, "s"),
  rect(8, 11, 7, 6, "s"), ring(11, 10, 3, "s"), rect(8, 11, 7, 6, "s"))

// ---------------------------------------------------------------- Mascota: el ronin del sombrero kasa

// Mitad izquierda; mx la refleja. Los gestos cambian solo la cara.
sprite("_ronin_body", { w: 32, h: 32 },
  poly([16, 1, 16, 12, 1, 12], "G"),                // sombrero kasa
  poly([16, 1, 16, 6, 11, 6], "y"),
  hline(2, 12, 14, "g"),
  circ(16, 20, 6, "p"),                              // cabeza
  rect(10, 14, 12, 3, "i"),                          // sombra bajo el ala
  rect(9, 25, 14, 4, "T"), hline(9, 27, 14, "G"),    // bufanda teal con franja dorada
  rect(10, 29, 12, 3, "d"))                          // ropa

sprite("ronin_idle", { w: 32, h: 32, mx: true, outline: "k" },
  stamp("_ronin_body", 0, 0),
  vline(12, 19, 2, "i"),
  px(15, 23, "i"))

sprite("ronin_happy", { w: 32, h: 32, mx: true, outline: "k" },
  stamp("_ronin_body", 0, 0),
  px(11, 20, "i"), px(12, 19, "i"), px(13, 20, "i"),
  hline(13, 23, 3, "i"), px(12, 22, "i"))

sprite("ronin_think", { w: 32, h: 32, mx: true, outline: "k" },
  stamp("_ronin_body", 0, 0),
  px(12, 20, "i"), px(13, 20, "i"),
  line(10, 18, 13, 17, "i"),
  hline(14, 23, 2, "i"))

sprite("ronin_alert", { w: 32, h: 32, mx: true, outline: "k" },
  stamp("_ronin_body", 0, 0),
  vline(12, 18, 3, "i"), px(11, 17, "i"),
  rect(15, 22, 2, 2, "i"))

// ---------------------------------------------------------------- Decoración

sprite("torii", { w: 40, h: 34, mx: true, outline: "k" },
  poly([0, 3, 20, 3, 20, 8, 3, 8], "T"),
  rect(3, 5, 17, 1, "c"),
  rect(5, 11, 17, 3, "T"),
  rect(6, 8, 4, 26, "t"), rect(7, 8, 1, 26, "T"))

sheet("hosts", ["host_you", "host_pc", "host_server", "host_router", "host_ghost"], { pad: 2 })
sheet("ronin", ["ronin_*"], { pad: 2 })
