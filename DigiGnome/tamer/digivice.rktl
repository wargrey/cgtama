#lang scribble/lp2

@(require "tamer.rkt")

@(require (for-syntax "tamer.rkt"))

@handbook-story{Hello, Brave End-Hero!}

@margin-note{This is an additional part of @secref{infrastructure.rktl}}

Every end user needs a @deftech{digivice} which usually exists as a commandline or graphical interface to operate the system.
The point is making a more user-friendly system is an endless work, that@literal{'}s why I call you the brave end-hero.
Perhaps in the future I would glad to provide a better interface, but meanwhile I only focus on the commandline interface
which is friendly to @italic{test harness} so that I could finish the core parts of system more quickly.

@tamer-smart-summary[]

@chunk[|<digivice taming start>|
       (require "tamer.rkt")

       (tamer-taming-start)
       (define partner (tamer-partner->modpath "makefile.rkt"))
       (define make-digivice (dynamic-require/expose partner 'make-digivice))

       |<digivice:*>|]

@handbook-scenario{Create a digivice demo from scratch!}

Different @itech{digivice}s relate different sophistication to different components, but they should share the same specification.
We do have a @hyperlink[@(build-path (digimon-stone) "digivice.rkt")]{@italic{template}} for making @itech{digivice}s
which are set in @filepath{info.rkt} and match the hierarchy in @racket[digimon-digivice] directory.

@chunk[|<define digivice hierarchy>|
       (define dgvc-name (symbol->string (gensym "dgvc")))
       (define dgvc.dir (build-path (digimon-digivice) dgvc-name))
       (define dgvc.rkt (path-add-suffix dgvc.dir ".rkt"))
       (define action.rkt (build-path dgvc.dir (file-name-from-path action.scrbl)))

       (define {setup-demo}
         (make-directory* dgvc.dir)
         |<instantiating from the template>|
         (make-digivice dgvc.scrbl dgvc.rkt))]

which means user @deftech{action}s (also unknown as @deftech{subcommand}s) are stored in the subdirectory
whose name double the basename of @racketvarfont{dgvc.rkt}.

@chunk[|<instantiating from the template>|
       (putenv "digivice-name" dgvc-name)
       (putenv "digivice-desc" "Digivice Demonstration")
       (with-output-to-file action.rkt #:exists 'replace
         {λ _ (dynamic-require action.scrbl #false)})]

@tamer-racketbox['action.scrbl]

The most interesting things are just a description @envvar{desc}
and a @racket[module] named after the @itech{digivice}.
Quite simple, is it?

@tamer-note['make-demo]

@chunk[|<testcase: make digivice>|
       (let ([msecs file-or-directory-modify-seconds])
         (test-spec "digivice should be updated!"
                    (check-pred file-exists? dgvc.rkt)
                    (check <= (msecs dgvc.scrbl) (msecs dgvc.rkt)))
         (test-spec "action should be updated!"
                    (check-pred file-exists? action.rkt)
                    (check <= (msecs action.scrbl) (msecs action.rkt)))
         (test-spec "exec racket digivice"
                    #:before {λ _ (parameterize ([current-command-line-arguments (vector)])
                                    (call-with-fresh-$ dynamic-require dgvc.rkt #false))}
                    (check-pred zero? ($?) (get-output-string $err))))]

The made @itech{digivice} is not the final launcher which would be generated by the @itech{makefile.rkt}
or @exec{raco setup}. But the launcher is just a shell script that starts the @itech{digivice}, so forget it for a moment.

@handbook-scenario{That@literal{'}s it! Help!}

Okay, the @itech{digivice} demo is ready! Now what?

@tamer-action[(parameterize ([exit-handler void]) ((force digivice)))
              (code:comment @#,t{So we have got the entrance.})
              (code:comment @#,t{Please do not ask me why it talks without being invoked, bleme @racketcommentfont{@exec{raco setup}}.})]

@tamer-note['dgvc-option]

@chunk[|<testcase: dgvc action>|
       (test-spec "digivice help ['help' can be omitted if you want]"
                  #:before {λ _ (call-with-fresh-$ dgvc "help")}
                  (check-pred zero? ($?) (get-output-string $err))
                  (check-regexp-match #px"Usage:.+?where <action>(\\s+\\S+){3,}"
                                      (get-output-string $out)))
       (test-spec "digivice --help [a kind of mistyped action]"
                  #:before {λ _ (call-with-fresh-$ dgvc "--help")}
                  (check-pred (procedure-rename (negate zero?) 'nonzero?) ($?))
                  (check-regexp-match #px".+?<action>.+?Unrecognized" (get-output-string $err)))
       (test-spec "digivice action [mission start]"
                  #:before {λ _ (call-with-fresh-$ dgvc "action")}
                  (check-pred zero? ($?) (get-output-string $err)))]

So far it all works well. However the following tests are just based on this demo,
nothing can be done to guarantee that real implementation @bold{is} taking care
the commandline arguments even though it is suggested to.

@chunk[|<testcase: dgvc action option>|
       (test-spec "digivice action --help [pass option to action]"
                  #:before {λ _ (call-with-fresh-$ dgvc "action" "--help")}
                  (check-pred zero? ($?) (get-output-string $err))
                  (check-regexp-match #px"where <option>(\\s+\\S+){3,}" (get-output-string $out)))
       (test-spec "digivice action --version [show version information]"
                  #:before {λ _ (call-with-fresh-$ dgvc "action" "--version")}
                  (check-pred zero? ($?) (get-output-string $err))
                  (check-regexp-match #px"version:" (get-output-string $out)))
       (test-spec "digivice action --unknown [a kind of mistyped option]"
                  #:before {λ _ (call-with-fresh-$ dgvc "action" "--unknown")}
                  (check-pred (procedure-rename (negate zero?) 'nonzero?) ($?))
                  (check-regexp-match #px"unknown switch" (get-output-string $err)))
       (test-spec "digivice action job done"
                  #:before {λ _ (call-with-fresh-$ dgvc "action" "job" "done")}
                  (check-pred zero? ($?) (get-output-string $err))
                  (check-regexp-match #px"(job done)" (get-output-string $out)))]

@handbook-scenario{Don@literal{'}t forget to restore the filesystem!}

So far we are done with playing the toy demo, and it is time to hunt for some real world problems.
But wait! we might have forgotten something. This demo does affect the filesystem which is a kind of resource
that @exec{racket} process could not manager automatically.

@chunk[|<destroy the demo zone>|
       (define {teardown-demo}
         (define px.dgvc (pregexp (string-replace dgvc-name #px"\\d+" "\\d+")))
         (for ([dgvc (in-list (directory-list (path-only dgvc.rkt)))]
               #:when (or (member dgvc (use-compiled-file-paths))
                          (regexp-match px.dgvc dgvc)))
             (delete-directory/files (build-path (path-only dgvc.rkt) dgvc)))
         (with-handlers ([exn:fail:filesystem? void])
           (delete-directory (digimon-digivice))))]

The @italic{@secref["plumbers" #:doc '(lib "scribblings/reference/reference.scrbl")]} is designed for this kind of work,
but I@literal{'}d like to watch the @italic{teardown} routine in order to ensure that it does work as it should do.

@tamer-note['clean-demo]

@chunk[|<testcase: destroy digivice>|
       (let ([exn:dnf? exn:fail:filesystem:errno?]
             [errno (compose1 car exn:fail:filesystem:errno-errno)])
         (test-spec "digivice should be deleted!"
                    (check-pred (negate file-exists?) dgvc.rkt))
         (test-spec "actions directory should be deleted recursively!"
                    (check-pred (negate directory-exists?) action.rkt))
         (test-spec (format "~a should be deleted if empty!" (digimon-digivice))
                    (with-handlers ([exn:dnf? {λ [e] (check-equal? 2 (errno e))}])
                      (check-pred (negate null?) (directory-list (digimon-digivice))))))]

@handbook-appendix[]

@chunk[|<digivice:*>|
       {module+ main (call-as-normal-termination tamer-prove)}
       {module+ story
         (define dgvc.scrbl (build-path (digimon-stone) "digivice.rkt"))
         (define action.scrbl (build-path (digimon-stone) "action.rkt"))

         |<define digivice hierarchy>|
         (define-tamer-suite make-demo "Make the demo from scratch"
           #:before setup-demo
           |<testcase: make digivice>|)

         (define digivice (lazy (dynamic-require/expose dgvc.rkt 'main)))
         (define-tamer-suite dgvc-option "That's it, Help!"
           (let ([dgvc (force digivice)])
             (list (test-suite "digivice [action]" |<testcase: dgvc action>|)
                   (test-suite "digivice action [option]" |<testcase: dgvc action option>|))))
         
         |<destroy the demo zone>|
         (define-tamer-suite clean-demo "Restore the filesystem"
           #:before teardown-demo
           |<testcase: destroy digivice>|)}]
