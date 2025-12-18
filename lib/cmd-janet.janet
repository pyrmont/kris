(import ./util)
(import ./compile :as c)

(def target-list
  (do
    (def targets (sort (keys c/target-map)))
    (def last-t (array/pop targets))
    (string (string/join targets ", ") " and " last-t)))

(def config
  ```
  The configuration for the janet subcommand
  ```
  {:rules ["--target"  {:kind    :single
                        :short   "t"
                        :default "native"
                        :help    (string "The target platform. Valid targets are "
                                         target-list ".")}
          "--version" {:kind    :single
                       :short   "v"
                       :default "latest"
                       :help    "The Janet version to build."}
          "--output"  {:kind    :single
                       :short   "o"
                       :default "janet"
                       :help    "The output path for the compiled binary."}
          "--small"   {:kind    :flag
                       :short   "s"
                       :help    "Optimise for smallest binary size."}
          "-------------------------------------------"]
   :short "j"
   :info {:about "Cross-compiles Janet for a target platform."}
   :help "Cross-compile Janet."})

(defn run
  [args]
  (def opts (args :opts))
  (def target (opts "target"))
  (def version (opts "version"))
  (def output (opts "output"))
  (def small? (opts "small"))
  (def zig-target (get c/target-map target))
  (unless zig-target
    (eprintf (string "kris: invalid target %s\n"
                     "Try 'kris --help' for more information.")
             target target-list)
    (os/exit 1))
  (print "creating executable '" output "' for " zig-target "...")
  (def source-dir (c/download-janet version))
  (def bootstrap (c/build-bootstrap source-dir))
  (def build-c-dir (c/generate-amalgamation source-dir bootstrap))
  (c/compile-janet-executable source-dir build-c-dir target output small?)
  (print "Compilation completed."))
