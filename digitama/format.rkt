#lang at-exp typed/racket

(provide (all-defined-out))
(provide (all-from-out racket/flonum racket/fixnum))

@require{sugar.rkt}

(require racket/flonum)
(require racket/fixnum)

(define ~n_w : (-> Natural String String)
  (lambda [count word]
    (format "~a ~a" count (plural count word))))

(define ~w=n : (-> Natural String String)
  (lambda [count word]
    (format "~a=~a" (plural count word) count)))

(define ~% : (-> Flonum [#:precision (U Integer (List '= Integer))] String)
  (lambda [% #:precision [prcs '(= 2)]]
    (string-append (~r (fl* 100.0 %) #:precision prcs) "%")))

(define ~uptime : (-> Nonnegative-Fixnum String)
  (let ([~t : (-> Natural String) (λ [n] (if (< n 10) (string-append "0" (number->string n)) (number->string n)))])
    (lambda [s]
      (let*-values ([(d s) (quotient/remainder s 86400)]
                    [(h s) (quotient/remainder s 3600)]
                    [(m s) (quotient/remainder s 60)])
        (format "~a+~a:~a:~a" d (~t h) (~t m) (~t s))))))

(define-type/enum units : Unit 'KB 'MB 'GB 'TB)
(define ~size : (case-> [Natural 'Bytes [#:precision (U Integer (List '= Integer))] -> String]
                        [Flonum Unit [#:precision (U Integer (List '= Integer))] -> String])
  (lambda [size unit #:precision [prcs '(= 3)]]
    (if (symbol=? unit 'Bytes)
        (cond [(< size 1024) (~n_w size "Byte")]
              [else (~size (fl/ (real->double-flonum size) 1024.0) 'KB #:precision prcs)])
        (let try-next-unit : String ([s : Flonum size] [us : (Option Unit*) (member unit units)])
          (cond [(false? us) "Typed Racket is buggy if you see this message"]
                [(or (fl< s 1024.0) (null? (cdr us))) (string-append (~r s #:precision prcs) (symbol->string (car us)))]
                [else (try-next-unit (fl/ s 1024.0) (cdr us))])))))

(module digitama typed/racket
  (provide (all-defined-out))

  (define plural : (-> Natural String String)
    (lambda [n word]
      (define dict : (HashTable String String) #hash(("story" . "stories") ("Story" . "Stories")))
      (cond [(= n 1) word]
            [else (hash-ref dict word (λ _ (string-append word "s")))]))))

(require (submod "." digitama))