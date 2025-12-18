(def sep (get {:windows "\\" :cygwin "\\" :mingw "\\"} (os/which) "/"))

(def eol (get {:windows "\r\n" :cygwin "\r\n" :mingw "\r\n"} (os/which) "\n"))

# Private helpers

(defn- mkdirp [path]
  (var res false)
  (def pwd (os/cwd))
  (each part (string/split sep path)
    (set res (os/mkdir part))
    (os/cd part))
  (os/cd pwd)
  res)

(defn- rm-with-retry [path &opt is-dir?]
  (var attempts 0)
  (var success false)
  (while (and (not success) (< attempts 5))
    (def [ok? err]
      (protect
        (if is-dir?
          (os/rmdir path)
          (os/rm path))))
    (if ok?
      (set success true)
      (do
        (++ attempts)
        (when (< attempts 5)
          (ev/sleep 0.1))))) # Wait 100ms before retry
  success)

# Public helpers

(defn add-eol
  "Adds the platform-specific line ending to a string."
  [s]
  (string s eol))

(defn rmrf
  "Removes all files recursively."
  [path]
  (case (os/lstat path :mode)
    :directory
    (do
      (each p (os/dir path)
        (rmrf (string path sep p)))
      (rm-with-retry path true))
    # do nothing if file does not exist
    nil
    nil
    # default
    (rm-with-retry path false)))

(defn shell-capture
  "Runs a command and captures all output"
  [cmd]
  (def [ok? result]
    (protect
      (do
        (def proc (os/spawn cmd :p {:out :pipe :err :pipe}))
        (def [exit-code out err]
          (ev/gather
            (os/proc-wait proc)
            (ev/read (proc :out) :all)
            (ev/read (proc :err) :all)))
        (os/proc-close proc)
        [exit-code out err])))
  (if ok?
    result
    [1 "" (string "failed to spawn process: " result)]))

(defn setup-cache
  "Sets up the cache for tests."
  [cache-dir]
  (def cli-path (string (os/cwd) sep "lib" sep "cli.janet"))
  (def [setup-exit-code _ setup-error]
    (shell-capture ["janet" cli-path "--cache" cache-dir "janet" "--target" "native" "--output" "setup"]))
  (when (not (zero? setup-exit-code))
    (eprint "cache setup failed: " setup-error)
    (os/exit 1))
  (when (os/stat "setup" :mode)
    (os/rm "setup")))

(defmacro in-dir
  ```
  Evaluates `body` in a temporary directory

  The path to the temporary directory is assigned to `binding`.
  ```
  [binding & body]
  (def p (string "tmp-" (gensym)))
  (def cwd (os/cwd))
  ~(do
     (,mkdirp ,p)
     (def ,binding (,os/realpath ,p))
     ,(apply defer ['do [os/cd cwd] [rmrf p]] [[os/cd p] ;body])))
