(import ../deps/argy-bargy/argy-bargy :as argy)

(import ./cmd-clean :as cmd/clean)
(import ./cmd-janet :as cmd/janet)
(import ./cmd-quickbin :as cmd/quickbin)

(import ./util)

(def config
  ```
  The configuration for kris
  ```
  {:rules ["--cache"  {:kind  :single
                       :short "c"
                       :proxy "path"
                       :hide? true
                       :help  "The path to the cache directory."}]
   :subs ["clean" cmd/clean/config
          "janet" cmd/janet/config
          "quickbin" cmd/quickbin/config]
   :info {:about "A tool for cross-compiling Janet projects for multiple platforms using Zig."}})

(def file-env (curenv))

(defn run
  [args]
  (def err (args :err))
  (def help (args :help))
  (def opts (args :opts))
  (def sub (args :sub))
  (cond
    (not (empty? help))
    (do
      (prin help)
      (os/exit (if (opts "help") 0 1)))
    (not (empty? err))
    (do
      (eprin err)
      (os/exit 1))
    # default
    (do
      (unless (util/zig-installed?)
        (eprintf "kris: zig not found on PATH")
        (os/exit 1))
      (setdyn :kris-cache-dir (opts "cache"))
      (def name (symbol "cmd/" (sub :cmd) "/run"))
      (def sub/run (module/value file-env name true))
      (try
        (sub/run sub)
        ([e f]
         (eprint "error: " e)
         (debug/stacktrace f)
         (os/exit 1))))))

(defn main [& args] (run (argy/parse-args "kris" config)))
