(def psep "/")
(def wsep "\\")
(def sep (get {:windows wsep :cygwin wsep :mingw wsep} (os/which) psep))

(def pathg ~{:main    (* (+ :abspath :relpath) (? :sep) -1)
             :abspath (* :root (any :relpath))
             :relpath (* :part (any (* :sep :part)))
             :root    (+ (* ,sep (constant ""))
                         (* '(* :a ":") ,wsep))
             :sep     (some ,sep)
             :part    '(some (* (! :sep) 1))})

(def- posix-pathg ~{:main     (* (+ :abspath :relpath) (? :sep) -1)
                    :abspath  (* :root (any :relpath))
                    :relpath  (* :part (any (* :sep :part)))
                    :root     (* ,psep (constant ""))
                    :sep      (some ,psep)
                    :part     '(some (* (! :sep) 1))})

(defn abspath?
  ```
  Checks if a path is absolute
  ```
  [path]
  (if (= wsep sep)
    (not (nil? (peg/match ~(* (? (* :a ":")) ,wsep) path)))
    (string/has-prefix? psep path)))

(defn apart
  ```
  Splits a path into parts
  ```
  [path &opt posix?]
  (if (empty? path)
    []
    (or (peg/match (if posix? posix-pathg pathg) path)
        (error "invalid path"))))

(defn copy-file
  ```
  Copies a file from src to dest
  ```
  [src dest]
  (def content (slurp src))
  (spit dest content))

(defn devnull
  ```
  Open the equivalent of /dev/null
  ```
  []
  (os/open (if (= :windows (os/which)) "NUL" "/dev/null") :rw))

(defn mkdir
  ```
  Creates a directory recursively
  ```
  [path &opt posix?]
  (def parts (apart path posix?))
  (cond
    # absolute path
    (= "" (first parts))
    (put parts 0 (if posix? psep sep))
    # Windows path beginning with drive letter
    (string/has-suffix? ":" (first parts))
    (put parts 0 (string (first parts) wsep)))
  (var res false)
  (def cwd (os/cwd))
  (each part parts
    (unless (string/has-suffix? sep part)
      (set res (os/mkdir part)))
    (os/cd part))
  (os/cd cwd)
  res)

(defn rmrf
  ```
  Recursively removes a directory or file
  ```
  [path &opt ignore-check?]
  (case (os/lstat path :mode)
    # recursive delete directories
    :directory
    (do
      (def msg "cannot delete directory while current working directory is inside it")
      (assert (or ignore-check? (not (string/has-prefix? path (os/cwd)))) msg)
      (each subpath (os/dir path)
        (rmrf (string path sep subpath) true))
      (os/rmdir path))
     # do nothing if file does not exist
    nil
    nil
    # default
    (os/rm path)))

(defn zig-installed?
  ```
  Checks if Zig is installed
  ```
  []
  (with [dn (devnull)]
    (zero? (os/execute ["which" "zig"] :p {:err dn :out dn}))))
