#import "plot-util.typ": *
#import "plot-mark.typ": *
#import "plot-line.typ"

/* Plot color array */
#let plot-colors = (
  black, red, blue, green, yellow,
)

/* Returns the stroke color if set, or the nth default color */
#let get-plot-color(data, n) = {
  if "stroke" in data and data.stroke != auto {
    return data.stroke
  }

  return plot-colors.at(calc.mod(n, plot-colors.len()))
}

/* Default settings */
#let plot-defaults = (
  tic-length: .4em,
  tic-stroke: .5pt + black,
  tic-mirror: true,
)

/* Data settings */
#let plot-data(data, x-axis: "x", y-axis: "y", label: "data", stroke: auto, mark: none, mark-stroke: auto, mark-fill: auto) = (
  data: data, stroke: stroke, x-axis: x-axis, y-axis: y-axis,
  mark: mark, // string or function
  mark-fill: mark-fill,
  mark-stroke: mark-stroke,
)

/* Plot a line chart */
#let plot(/* Tics Dictionary
	         * - every: number   Draw tic every n values
	         * - tics: array     Place tic at values
	         * - mirror: bool    Mirror tics to opposite side
	         * - side: string    Side (left, right, top, bottom)
	         * - length: length  Line length
	         * - offset: length  Offset (outset) 
	         * - angle: length   Label rotation
	         * - stroke: stroke  Tic stroke
	         */
          x-tics: (every: 1),
          y-tics: (every: 1),
          x2-tics: none,
          y2-tics: none,
          
          /* Axis Dictionary
	         * - range: array|auto  Range to plot `(min, max)`
	         */
          x-axis: (:),
          y-axis: (:),
          x2-axis: (:),
          y2-axis: (:),

          /* Labels */
          x-label:  [$x$],
          x2-label: [],
          y-label:  [$y$],
          y2-label: [],
          
          width: 10cm,
          height: 10cm,
          border-stroke: black + .5pt,

          /* Padding */
          padding: (left: 2.4em, right: 2.4em, top: 1.4em, bottom: 1.6em),

          ..data,
  ) = {
  let plots = data.pos().map(v => {
    if type(v) == "array" {
      return plot-data(v)
    }
    return v
  })

  style(st => {
    /* Plot viewport size */
    let data-width = width - padding.left - padding.right
    let data-height = height - padding.top - padding.bottom
    let data-x = padding.left
    let data-y = padding.top

    let frame = (x: 0cm, y: 0cm, width: width, height: height)
    let axis-frame = rect-inset(frame, padding)  // Padding between frame and axis
    let data-frame = rect-inset(axis-frame, 0cm) // Padding between axis and data

    /* All axes */
    let axes = (
      x: x-axis, x2: x2-axis,
      y: y-axis, y2: y2-axis,
    )

    /* All tics */
    let tics = (
      x: x-tics, x2: x2-tics,
      y: y-tics, y2: y2-tics,
    )

    /* Default axis side */
    let tic-side = (
      x: "bottom", x2: "top",
      y: "left", y2: "right",
    )

    /* Map side to opposite side */
    let other-side = (
      left: "right", right: "left",
      top: "bottom", bottom: "top",
    )

    /* Calculate unset axis ranges.
     * Returns new range as tuple (x-range, y-range)
     */
    let autorange-axes(d) = {
      let x-axis = axes.at(d.x-axis)
      let y-axis = axes.at(d.y-axis)

      let x-range = p-dict-get(x-axis, "range", auto)
      let y-range = p-dict-get(y-axis, "range", auto)
      if x-range == auto or y-range == auto {
        let min-x = none; let max-x = none
        let min-y = none; let max-y = none

        for pt in d.data {
          pt = pt.map(parse-data)
          if min-x == none or min-x > pt.at(0) { min-x = pt.at(0) }
          if max-x == none or max-x < pt.at(0) { max-x = pt.at(0) }
          if min-y == none or min-y > pt.at(1) { min-y = pt.at(1) }
          if max-y == none or max-y < pt.at(1) { max-y = pt.at(1) }
        }

        if x-range == auto { x-range = (min-x, max-x) }
        if y-range == auto { y-range = (min-y, max-y) }

        return (x: x-range, y: y-range)
      }

      return (x: x-axis.range, y: y-axis.range)
    }
    
    for sub-data in plots {
      let ranges = autorange-axes(sub-data)
      axes.at(sub-data.x-axis).range = ranges.x
      axes.at(sub-data.y-axis).range = ranges.y
    }

    // Returns a length on `range` scaled to `size`
    let length-on-range(range, size, value) = {
      let scale = 100% / (range.at(1) - range.at(0))
      return (value - range.at(0)) * scale
    }

    let tic-position(axis, tics, value, side) = {
      let pt = none
      let angle = 0deg
      let range = axis.range
      if range.at(0) > value or value > range.at(1) {
        return none
      }

      let offset = p-dict-get(tics, "offset", 0cm)    
      if side == "left" {
        pt = (0% - offset, 100% - length-on-range(range, data-frame.height, value))
        angle = 0deg
      } else if side == "right" {
        pt = (100% + offset, 100% - length-on-range(range, data-frame.height, value))
        angle = 180deg
      } else if side == "bottom" {
        pt = (length-on-range(range, data-frame.width, value), 100% + offset)
        angle = 270deg
      } else if side == "top" {
        pt = (length-on-range(range, data-frame.width, value), 0% - offset)
        angle = 90deg
      }

      return (position: pt, angle: angle)
    }

    let render-tic-mark(axis, tics, pt, angle) = {
      place(dx: 0cm, dy: 0cm, {
    	    line(start: pt, angle: angle,
    	         length: p-dict-get(tics, "lengts", plot-defaults.tic-length),
    		 stroke: p-dict-get(tics, "stroke", plot-defaults.tic-stroke))
    	  })
    }

    let render-tic-label(tics, pt, value, side) = {
      if type(value) == "array" {
        value = value.at(1)
      } else {
        value = p-tic-get-label(tics, value)
      }

      let label = rotate(origin: center + horizon, p-dict-get(tics, "angle", 0deg), [#value])
      let bounds = measure(label, st)

      let offset = (0cm, 0cm)
      if side == "left" { offset = (-.5em - bounds.width, -bounds.height / 2) }
      if side == "right" { offset = (.5em, -bounds.height / 2) }
      if side == "top" { offset = (-bounds.width / 2, -bounds.height - .5em) }
      if side == "bottom" { offset = (-bounds.width / 2, .5em) }

      place(dx: pt.at(0) + offset.at(0),
            dy: pt.at(1) + offset.at(1), label)
    }

    let render-tics(axis, tics, side, mirror: false) = {
      /* Render calculated ticks */
      let every = p-dict-get(tics, "every", 1)
      if every != 0 {
        let scale = 1 / every
        for t in range(int(axis.range.at(0) * scale), int(axis.range.at(1) * scale + 1.5)) {
          let v = t / scale
          let pos = tic-position(axis, tics, v, side)
          if pos == none { continue }
          
          render-tic-mark(axis, tics, pos.position, pos.angle)

          if not mirror {
            render-tic-label(tics, pos.position, v, side)
          }
        }
      }

      /* Render fixed tics */
      for v in p-dict-get(tics, "tics", ()) {
        let value = v
        let label = v
        if type(value) == "array" {
          value = v.at(0)
          label = v.at(1)
        }
        
        let pos = tic-position(axis, tics, value, side)
        render-tic-mark(axis, tics, pos.position, pos.angle)

        if not mirror {
          render-tic-label(tics, pos.position, label, side)
        }
      }
    }

    let content = box(width: width, height: height, {
      /* Plot point array */
      let stroke-data(data, stroke, n) = {
        let x-range = axes.at(data.x-axis).range
        let y-range = axes.at(data.y-axis).range
        let x-delta = x-range.at(1) - x-range.at(0)
        let y-delta = y-range.at(1) - y-range.at(0)
        let x-off = x-range.at(0)
        let y-off = y-range.at(0)

        plot-line.render(data.data.map(pt => {
          return ((pt.at(0) - x-off) / x-delta,
                  (pt.at(1) - y-off) / y-delta)
        }), stroke)
      }

      let mark-data(data, mark, n) = {
        let mark-size = p-dict-get(data, "mark-size", .5em)
        let mark-stroke = p-dict-get(data, "mark-stroke", auto)
        if mark-stroke == auto {
          mark-stroke = get-plot-color(data, n) + .5pt
        }

        let mark-fill = p-dict-get(data, "mark-fill", auto)
        if mark-fill == auto {
          mark-fill = get-plot-color(data, n)
        }

        let x-range = axes.at(data.x-axis).range
        let y-range = axes.at(data.y-axis).range
        let x-off = x-range.at(0)
        let y-off = y-range.at(0)

        for p in data.data {
          let delta-x = x-range.at(1) - x-range.at(0)
          let delta-y = y-range.at(1) - y-range.at(0)

          let x = (p.at(0) - x-off) / delta-x * 100%
          let y = 100% - (p.at(1) - y-off) / delta-y * 100%

          /* Skip out of range points */
          if x < 0% or x > 100% or y < 0% or y > 100% { continue }

          place(dx: x - mark-size/2,
                dy: y - mark-size/2,
                box(width: mark-size, height: mark-size, {
                  plot-mark(mark, stroke: mark-stroke, fill: mark-fill)
                }))
        }
      }

      /* Render axes */
      place(dx: axis-frame.x, dy: axis-frame.y, {
        box(width: axis-frame.width, height: axis-frame.height, {
          /* Render tics */
          for name, tic in tics {
            if tic != none {
              let side = p-dict-get(tic, "side", none)
              if side == none {
                side = tic-side.at(name)
              }

              let tics-frame = none
              if side == "left" or side == "right" {
                tics-frame = (
                  x: 0%,
                  y: data-frame.y - axis-frame.y,
                  width: 100%,
                  height: data-frame.height
                )
              } else {
                tics-frame = (
                  x: data-frame.x - axis-frame.x,
                  y: 0%,
                  width: data-frame.width,
                  height: 100%
                )
              }

              place(dx: tics-frame.x, dy: tics-frame.y,
                box(width: tics-frame.width, height: tics-frame.height, {
                  let axis = axes.at(name)
                  render-tics(axis, tic, side, mirror: false)

                  if p-dict-get(tic, "mirror", plot-defaults.tic-mirror) {
                    side = other-side.at(side)
                    render-tics(axis, tic, side, mirror: true)
                  }
                })
              )
            }
          }

          /* Render border */
          place(dx: 0cm, dy: 0cm, {
            rect(width: axis-frame.width, height: axis-frame.height,
                 stroke: border-stroke)
          })
        })
      })

      /* Plot graph(s) */
      place(dx: data-frame.x, dy: data-frame.y, {
        box(width: data-frame.width, height: data-frame.height, clip: false, {
          let n = 0
          for sub-plot in plots {
            let stroke = p-dict-get(sub-plot, "stroke", auto)
            if stroke == auto {
              stroke = get-plot-color(sub-plot, n) + .5pt
            }

            if stroke != none {
              stroke-data(sub-plot, stroke, n)
            }

            let mark = p-dict-get(sub-plot, "mark", none)
            if mark != none {
              mark-data(sub-plot, mark, n)
            }

            n += 1
          }
        })
      })
    })

    grid(columns: (auto, auto, auto), rows: (auto, auto, auto), gutter: 1pt,
      /* Row 1 */
      [], align(center, x2-label), [],
      /* Row 2 */
      align(center + horizon, rotate-bbox(y-label, -90deg)),
      content,
      align(center + horizon, rotate-bbox(y2-label, -90deg)),
      /* Row 3 */
      [], align(center, x-label), [])
  })
}
