#lang typed/racket/base

(provide (all-defined-out))
(provide (all-from-out "../paint.rkt"))
(provide (all-from-out "../color.rkt"))

(require "draw.rkt")
(require "unsafe/draw.rkt")
(require "../paint.rkt")
(require "../color.rkt")

(define stroke-paint->source : (-> Stroke-Paint Paint)
  (lambda [paint]
    (cond [(Paint? paint) paint]
          ;[(bitmap%? paint) (default-stroke)]
          [else (desc-stroke (default-stroke) #:color paint)])))

(define stroke-paint->source* : (-> (Option Stroke-Paint) (Option Paint))
  (lambda [paint]
    (and paint (stroke-paint->source paint))))

(define fill-paint->source : (-> Fill-Paint Bitmap-Source)
  (lambda [paint]
    (cond [(bitmap%? paint) (bitmap-surface paint)]
          [else (rgb* paint)])))

(define fill-paint->source* : (-> (Option Fill-Paint) (Option Bitmap-Source))
  (lambda [paint]
    (and paint (fill-paint->source paint))))