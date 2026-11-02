// Cyberdeck de RoninShell: pantalla de arranque en pixel art (320x180, se escala x4).
// Oro envejecido, negro, metal y teal. Se construye con pxl (ver art/README.md).

pal({
  k: "#05090b", b: "#0a1416", d: "#0d2a27", e: "#123d38",
  m: "#232b30", M: "#37434a", n: "#4d5c64", N: "#6c7f88",
  g: "#7a5a22", G: "#c9a24a", y: "#f0d27a", Y: "#fff0b8",
  t: "#1f6f63", T: "#2fbfa8", c: "#5ee6cf", w: "#e8fff8",
  r: "#d9583f", a: "#e8a33a",
})
ramps("kdtTcw", "kgGyY")

// --- Piezas pequeñas ---------------------------------------------------------

sprite("_screw", { w: 5, h: 5 },
  rect(0, 0, 5, 5, "."), rect(1, 0, 3, 5, "n"), rect(0, 1, 5, 3, "n"),
  rect(1, 1, 3, 3, "N"), px(2, 1, "M"), px(2, 2, "M"), px(2, 3, "M"), px(1, 2, "M"), px(3, 2, "M"))

sprite("_rivet", { w: 3, h: 3 }, rect(0, 0, 3, 3, "M"), px(0, 0, "N"), px(2, 2, "m"))

// Esquina dorada: soporte en L con tornillo.
sprite("_corner", { w: 30, h: 30 },
  rect(0, 0, 30, 9, "G"), rect(0, 0, 9, 30, "G"),
  hline(0, 0, 30, "y"), vline(0, 0, 30, "y"),
  hline(0, 8, 30, "g"), vline(8, 8, 22, "g"),
  rect(9, 9, 1, 1, "g"),
  stamp("_screw", 2, 2))

// Media cabeza de samurái (kabuto + menpo); se refleja con mx. Coordenadas base x1.45.
const F = 1.45
const P = (...n) => n.map((v) => Math.round(v * F))
const poly2 = (pts, c) => poly(P(...pts), c)
sprite("helmet", { w: 60, h: 50, mx: true, outline: "T" },
  // cuerno (maedate), curvado hacia fuera
  poly2([0, 1, 3, 0, 5, 3, 10, 8, 16, 12, 20.5, 14, 20.5, 18, 12, 15, 6, 11, 2, 6], "G"),
  poly2([1, 1, 3, 1, 6, 5, 11, 9, 16, 13, 12, 12, 6, 8, 2, 4], "y"),
  // cúpula y cresta
  poly2([20.5, 7, 14, 9, 10, 14, 8, 20, 20.5, 20], "G"),
  poly2([20.5, 8, 15, 10, 12, 14, 20.5, 14], "y"),
  circ(...P(19, 8), 3, "Y"),
  // cubrenucas (shikoro) con lamas
  poly2([2, 18, 9, 18, 8, 33, 0, 28], "g"),
  hline(...P(1, 22), 12, "G"), hline(...P(1, 26), 12, "G"), hline(...P(1, 30), 12, "G"),
  // frente y máscara
  poly2([9, 19, 20.5, 19, 20.5, 32, 14, 31, 10, 26], "g"),
  poly2([10, 20, 20.5, 20, 20.5, 22, 10, 22], "G"),
  poly2([11, 22, 17, 24, 20.5, 24, 20.5, 26, 12, 25], "k"),
  rect(...P(14.5, 23.5), 2, 2, "c"),
  hline(...P(12, 29), 11, "k"), rect(...P(14, 27.5), 2, 2, "k"), rect(...P(17, 27.5), 2, 2, "k"),
  rect(...P(13, 26.2), 2, 2, "y"), rect(...P(15.2, 26.2), 2, 2, "y"))

// --- Escena ------------------------------------------------------------------

function screenLines(c) {
  for (let y = 24; y < 142; y += 2) c.hline(48, y, 224, "b")
}


// Letras propias para el título (5x7, rotuladas a 2x): la fuente 3x5 de pxl confundía la N.
const GLYPHS = {
  R: ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
  O: [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
  N: ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
  I: ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
  S: [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
  H: ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
  E: ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
  L: ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
}
function title(word, x, y, color, shadow) {
  return (c) => {
    const step = 12
    const left = x - Math.floor((word.length * step - 2) / 2)
    for (let i = 0; i < word.length; i++) {
      GLYPHS[word[i]].forEach((row, gy) => {
        for (let gx = 0; gx < 5; gx++) {
          if (row[gx] === "#") {
            if (shadow) c.rect(left + i * step + gx * 2 + 1, y + gy * 2 + 1, 2, 2, shadow)
            c.rect(left + i * step + gx * 2, y + gy * 2, 2, 2, color)
          }
        }
      })
    }
  }
}

function bootScene(name, open, base = false) {
  const slide = Math.round(open * 114)
  return scene(name, { w: 320, h: 180, bg: "k" },
  layer("body",
    rect(0, 0, 320, 180, "m"),
    hline(0, 0, 320, "M"),
    // placas laterales con remaches
    rect(0, 40, 38, 100, "M"), rect(282, 40, 38, 100, "M"),
    rect(2, 42, 34, 96, "m"), rect(284, 42, 34, 96, "m"),
    ...[50, 66, 82, 98, 114, 130].flatMap((y) => [stamp("_rivet", 17, y), stamp("_rivet", 299, y)]),
    // franja inferior de mandos
    rect(0, 150, 320, 30, "k"), rect(0, 150, 320, 1, "M"),
    rect(0, 151, 320, 1, "n")),
  layer("bezel",
    rect(36, 12, 248, 134, "g"),
    rect(37, 13, 246, 132, "G"),
    hline(37, 13, 246, "y"),
    rect(41, 17, 238, 124, "g"),
    rect(43, 19, 234, 120, "k")),
  layer("screen",
    rect(46, 22, 228, 114, "d"),
    // viñeta suave en el borde de la pantalla
    rect(46, 22, 228, 3, "b"), rect(46, 133, 228, 3, "b"),
    screenLines),
  layer("content",
    title("RONINSHELL", 160, 26, "G", "g"),
    ...(base ? [] : [stamp("helmet", 130, 43)]),
    text(160, 99, "CYBERDECK OS 0.1", "T", { align: "c" }),
    ...(base ? [] : [
      ...Array.from({ length: 16 }, (_, i) => rect(86 + i * 9, 112, 7, 8, i < 9 ? "c" : "e")),
      text(160, 124, "CARGANDO MODULOS...", "t", { align: "c" })])),
  layer("shutters", { hidden: base },
    clip([46, 22, 228, 114],
      // dos compuertas que se abren hacia los lados
      rect(46 - slide, 22, 114, 114, "m"), rect(160 + slide, 22, 114, 114, "m"),
      rect(46 - slide, 22, 114, 3, "M"), rect(160 + slide, 22, 114, 3, "M"),
      rect(155 - slide, 22, 5, 114, "n"), rect(160 + slide, 22, 5, 114, "n"),
      ...[34, 62, 90, 118].flatMap((y) => [stamp("_rivet", 148 - slide, y), stamp("_rivet", 169 + slide, y)]),
      // luz de la rendija central mientras abre
      ...(open > 0 && open < 1 ? [rect(159 - slide + 5, 22, 1, 114, "c"), rect(160 + slide - 5, 22, 1, 114, "c")] : []))),
  layer("frame",
    stamp("_corner", 0, 0), stamp("_corner", 290, 0, { flip: "x" }),
    stamp("_corner", 0, 150, { flip: "y" }), stamp("_corner", 290, 150, { flip: "xy" })),
  layer("controls",
    // rejillas de ventilación con luz teal
    ...[0, 1, 2, 3, 4].map((i) => rect(40 + i * 7, 158, 4, 14, i % 2 ? "t" : "T")),
    ...[0, 1, 2, 3, 4].map((i) => rect(246 + i * 7, 158, 4, 14, i % 2 ? "t" : "T")),
    // interruptores
    ...[0, 1, 2].flatMap((i) => [rect(104 + i * 14, 160, 6, 10, "n"), rect(105 + i * 14, 161, 4, 4, "N")]),
    // LEDs (en la base se dibujan desde el juego, para que parpadeen)
    ...(base ? [] : [px(190, 164, "r"), px(191, 164, "r"), px(198, 164, "a"), px(199, 164, "a"), px(206, 164, "c"), px(207, 164, "c")]),
    // mandos
    circ(222, 165, 6, "M"), circ(222, 165, 4, "n"), vline(222, 160, 5, "Y"),
    circ(236, 165, 4, "G"), circ(236, 165, 2, "y")),
  glow("cTy", { r: 3, strength: 0.35 }))
}

bootScene("boot", 1)
bootScene("boot_closed", 0)
bootScene("boot_mid", 0.35)

bootScene("boot_base", 1, true)

// Compuerta izquierda (la derecha es su reflejo): 114x114, cubre media pantalla.
sprite("shutter", { w: 114, h: 114 },
  rect(0, 0, 114, 114, "m"), rect(0, 0, 114, 3, "M"), rect(0, 111, 114, 3, "k"),
  rect(109, 0, 5, 114, "n"), vline(109, 0, 114, "N"), vline(113, 0, 114, "M"),
  ...[12, 40, 68, 96].map((y) => stamp("_rivet", 98, y)),
  hline(8, 57, 90, "M"), hline(8, 58, 90, "k"))

// Cursores del juego (se amplian x2 al cargarlos).
sprite("cursor_arrow", { w: 12, h: 17, outline: "k" }, `
  G...........
  GG..........
  GyG.........
  GyyG........
  GyyyG.......
  GyyyyG......
  GyyyyyG.....
  GyyyyyyG....
  GyyyyyyyG...
  GyyyyyGGGG..
  GyyGyyG.....
  GyG.GyyG....
  GG..GyyG....
  G....GyyG...
  .....GyyG...
  ......GG....`)
sprite("cursor_link", { base: "cursor_arrow", swap: { G: "T", y: "c" } })
sprite("cursor_text", { w: 5, h: 15, outline: "k" },
  rect(0, 0, 5, 1, "c"), rect(2, 1, 1, 13, "c"), rect(0, 14, 5, 1, "c"))
