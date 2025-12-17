# Private values

(def- nl "\n")

# Public values

(def sep (get {:windows "\\" :cygwin "\\" :mingw "\\"} (os/which) "/"))

# Private helpers

(defn- mkdirp [path]
  (var res false)
  (def pwd (os/cwd))
  (each part (string/split sep path)
    (set res (os/mkdir part))
    (os/cd part))
  (os/cd pwd)
  res)

(defn- rmrf [path]
  (case (os/lstat path :mode)
    :directory
    (do
      (each p (os/dir path)
        (rmrf (string path sep p)))
      (os/rmdir path))
    # do nothing if file does not exist
    nil
    nil
    # default
    (os/rm path)))

# Public helpers

(defn add-nl
  "Adds a new line to a string"
  [s &opt n]
  (default n 1)
  (string s (string/repeat "\n" n)))

(defn fix-seps
  "Normalises path separators in s to be platform-specific"
  [s]
  (if (= "\\" sep)
    (string/replace-all "/" "\\" s)
    s))

(defn shell-capture
  "Runs a command and captures all output"
  [cmd]
  (let [x (os/spawn cmd :p {:in :pipe :out :pipe :err :pipe})
        o (:read (x :out) :all)
        e (:read (x :err) :all)]
    (:wait x)
    (os/proc-close x)
    [(get x :return-code) o e]))

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
