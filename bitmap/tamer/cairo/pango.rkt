#lang racket

(provide (all-defined-out))

(require "../../digitama/draw.rkt")
(require "../../constructor.rkt")
(require "../../font.rkt")

(require "../../digitama/unsafe/pangocairo.rkt")
(require (submod "../../digitama/unsafe/font.rkt" unsafe))

(define (cairo-text-polygon words radius font-face font-weight font-attrs)
  (define-values (bmp cr width height) (make-cairo-image (* 2.0 radius) (* 2.0 radius) density #true))
  (define (draw-text-circle cr context words)
    (define layout (pango_layout_new context))
    (when font-attrs (pango_layout_set_attributes layout font-attrs))

    (define n (length words))
    (for ([i (in-range n)])
      (define angle (/ (* 360.0 i) n))
      (cairo_save cr)

      ; Gradient from red at angle == 60 to blue at angle == 240
      (define red (/ (+ 1 (cos (degrees->radians (- angle 60)))) 2))
      (pango_layout_set_text layout (list-ref words i))
      (cairo_set_source_rgb cr red 0 (- 1.0 red))
      (cairo_rotate cr (degrees->radians angle))

      (define-values (width height) (pango_layout_get_size layout))
      (cairo_move_to cr (/ (~metric width) -2) (- radius))
      (pango_cairo_show_layout cr layout)

      (cairo_restore cr)))

  ; draw background squares
  (for* ([x (in-range (/ width 10.0))]
         [y (in-range (/ height 10.0))])
    (cairo_rectangle cr (* x 10.0) (* y 10) 5 5))
  
  (define brush (cairo_pattern_create_radial radius radius (/ radius 3.0) radius radius radius))
  (cairo_pattern_set_extend brush CAIRO_EXTEND_PAD)
  (cairo_pattern_add_color_stop_rgba brush 0.0 (random) (random) (random) 1.0)
  (cairo_pattern_add_color_stop_rgba brush 0.9 1.0 1.0 1.0 1.0)
  (cairo_set_source cr brush)
  (cairo_fill cr)

  (define desc (bitmap_create_font_desc font-face (* radius 0.16) font-weight 0 4))

  ; Center coordinates on the middle of the region we are drawing
  (cairo_translate cr radius radius)
  (pango_context_set_font_description context desc)
  ; (pango_cairo_update_context cr context) ; this is not neccessary?
  
  (draw-text-circle cr context (string-split words))
  
  (pango_font_description_free desc)
  (cairo_destroy cr)
  (cairo_pattern_destroy brush)
  
  (define temp.png (make-temporary-file))
  (displayln temp.png)
  (send bmp save-file temp.png 'png #:unscaled? #true)
  (read-bitmap temp.png #:backing-scale density))

(define (cairo-paragraph)
  (define-values (width height indent spacing) (values 256.0 128.0 32.0 4.0))
  (define pattern (cairo_pattern_create_linear 0.0 0.0 width height))
  (cairo_pattern_set_extend pattern CAIRO_EXTEND_PAD)
  (cairo_pattern_add_color_stop_rgba pattern 0.0 1.0 0.0 0.0 1.0)
  (cairo_pattern_add_color_stop_rgba pattern 0.5 0.0 1.0 0.0 1.0)
  (cairo_pattern_add_color_stop_rgba pattern 1.0 0.0 0.0 1.0 1.0)
  (bitmap-paragraph (list (format "Layout Box(~a, ~a):" width height)
                          "Here is some text that should wrap suitably to demonstrate PangoLayout's features."
                          "This paragraph should be ellipsized or truncated.")
                    (desc-font #:family "Trebuchet MS" #:size 16.0 #:weight 'medium #:style 'normal #:stretch 'normal)
                    #:max-width width #:max-height height #:indent indent #:spacing spacing
                    #:wrap-mode 'word-char #:ellipsize-mode 'end #:lines '(undercurl)
                    #:color pattern #:background (rgba (random) (random) (random) 0.2) #:density density))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (benchmark make-image . args)
  (define smart-fmt (if (terminal-port? (current-output-port)) "\033[38;5;32m~a\033[0m " "~a "))
  (printf smart-fmt (object-name make-image))
  (collect-garbage)
  (time (apply make-image args)))

(define density 2.0)
(define pango-font-map (benchmark pango_cairo_font_map_get_default))
(define context (pango_font_map_create_context pango-font-map))
(define font-options (benchmark cairo_font_options_create))
(cairo_font_options_set_antialias font-options CAIRO_ANTIALIAS_DEFAULT)
(pango_cairo_context_set_font_options context font-options)

(define double-attrs (pango_attr_list_new))
(pango_attr_list_insert double-attrs (pango_attr_underline_new PANGO_UNDERLINE_DOUBLE))

(define delete-attrs (pango_attr_list_new))
(pango_attr_list_insert delete-attrs (pango_attr_strikethrough_new #true))

(benchmark cairo-text-polygon "Using Pango with Cairo to Draw Regular Polygon" 150 "Courier" 700 double-attrs)
(benchmark cairo-text-polygon "Test Global Cairo Context and Pango Layout" 100 "Helvetica Neue" 100 delete-attrs)
(benchmark cairo-paragraph)