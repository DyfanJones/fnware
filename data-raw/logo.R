# Regenerates man/figures/logo.png: "functional wear" - a close crop of a white
# dinner jacket (the hex itself is the jacket) with black lapels, a bow tie,
# `f()` on the shirt, pockets and a button, package name below.
library(grid)
library(hexSticker)

ink <- "#111111"
paper <- "#FFFFFF"

# Evaluate a path of M/L/C commands (SVG-style, y pointing down on a 600 x 600
# canvas) into polygon points.
bezier <- function(p0, p1, p2, p3, n = 40) {
  t <- seq(0, 1, length.out = n)
  cbind(
    (1 - t)^3 *
      p0[1] +
      3 * (1 - t)^2 * t * p1[1] +
      3 * (1 - t) * t^2 * p2[1] +
      t^3 * p3[1],
    (1 - t)^3 *
      p0[2] +
      3 * (1 - t)^2 * t * p1[2] +
      3 * (1 - t) * t^2 * p2[2] +
      t^3 * p3[2]
  )
}

path <- function(...) {
  pts <- NULL
  cur <- NULL
  for (cmd in list(...)) {
    v <- unlist(cmd[-1])
    if (cmd[[1]] == "M") {
      cur <- v
      pts <- rbind(pts, cur)
    } else if (cmd[[1]] == "L") {
      cur <- v
      pts <- rbind(pts, cur)
    } else {
      pts <- rbind(pts, bezier(cur, v[1:2], v[3:4], v[5:6]))
      cur <- v[5:6]
    }
  }
  pts
}

shape <- function(pts, fill = NA, col = NA, lwd = 1) {
  polygonGrob(
    x = unit(pts[, 1] / 600, "npc"),
    y = unit(1 - pts[, 2] / 600, "npc"),
    gp = gpar(fill = fill, col = col, lwd = lwd)
  )
}

mirror <- function(pts) cbind(600 - pts[, 1], pts[, 2])
both <- function(pts, ...) gList(shape(pts, ...), shape(mirror(pts), ...))

# Scale points about the adorn bow's knot (300, 340) and move the knot to `to`.
place <- function(pts, scale, to) {
  cbind(
    (pts[, 1] - 300) * scale + to[1],
    (pts[, 2] - 340) * scale + to[2]
  )
}

# Left lapel (mirrored for the right): collar, notch, peak, then down to the
# button where the jacket closes.
lapel_left <- path(
  list("M", 152, 44),
  list("C", 124, 58, 104, 84, 92, 114),
  list("L", 138, 150),
  list("L", 78, 192),
  list("L", 300, 446)
)
# Seam between collar and lapel, drawn in the shirt colour.
seam_left <- rbind(c(138, 150), c(184, 120))

# Flap pocket (mirrored), breast pocket with a pocket square.
pocket_left <- rbind(c(96, 428), c(184, 428), c(184, 440), c(96, 440))
breast_pocket <- rbind(c(452, 318), c(528, 318), c(528, 328), c(452, 328))
pocket_square <- rbind(
  c(462, 318),
  c(474, 294),
  c(490, 310),
  c(506, 292),
  c(518, 318)
)

# The adorn bow without its tails, worn as a bow tie.
knot <- c(300, 98)
bow_scale <- 0.5
petal_left <- path(
  list("M", 300, 340),
  list("C", 240, 235, 105, 245, 115, 340),
  list("C", 125, 425, 240, 435, 300, 340)
)
# Creases either side of the knot, drawn in the shirt colour.
crease_left <- path(
  list("M", 268, 340),
  list("C", 240, 318, 205, 312, 175, 322)
)
crease_left2 <- cbind(crease_left[, 1], 680 - crease_left[, 2])

stroke <- function(pts, lwd, col = paper) {
  polylineGrob(
    x = unit(pts[, 1] / 600, "npc"),
    y = unit(1 - pts[, 2] / 600, "npc"),
    gp = gpar(col = col, lwd = lwd, lineend = "round", linejoin = "round")
  )
}
both_strokes <- function(pts, lwd, ...) {
  gList(stroke(pts, lwd, ...), stroke(mirror(pts), lwd, ...))
}

dot <- function(y, r) {
  circleGrob(
    x = 0.5,
    y = 1 - y / 600,
    r = r / 600,
    gp = gpar(fill = ink, col = NA)
  )
}

art <- gTree(
  children = gList(
    both(pocket_left, ink),
    shape(pocket_square, paper, ink, 8),
    shape(breast_pocket, ink),
    dot(462, 12),
    both(lapel_left, ink),
    both_strokes(seam_left, 7),
    textGrob(
      "f()",
      x = 0.5,
      y = 1 - 222 / 600,
      gp = gpar(
        fontfamily = "mono",
        fontface = "bold",
        fontsize = 175,
        col = ink
      )
    ),
    dot(306, 10),
    dot(352, 10),
    both(place(petal_left, bow_scale, knot), ink),
    both_strokes(place(crease_left, bow_scale, knot), 5),
    both_strokes(place(crease_left2, bow_scale, knot), 5),
    roundrectGrob(
      x = knot[1] / 600,
      y = 1 - knot[2] / 600,
      width = 0.085 * bow_scale,
      height = 0.1 * bow_scale,
      r = unit(0.25, "snpc"),
      gp = gpar(fill = ink, col = paper, lwd = 5)
    )
  )
)

artwork <- tempfile(fileext = ".png")
png(artwork, width = 1200, height = 1200, bg = "transparent", type = "cairo")
grid.draw(art)
dev.off()

sticker(
  subplot = artwork,
  package = "fnware",
  p_size = 28,
  p_color = ink,
  p_y = 0.36,
  s_x = 1,
  s_y = 1,
  s_width = 0.8,
  h_fill = paper,
  h_color = ink,
  filename = "man/figures/logo.png",
  dpi = 600
)
