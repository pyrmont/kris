(use ../deps/testament)
(import ../res/helpers/util :as h)

(def cache-dir (string (os/cwd) h/sep (string "tmp-" (gensym) "-janet")))
(def cli-path (string (os/cwd) h/sep "lib" h/sep "cli.janet"))
(def confirmation "Compilation completed.")
(def output "janet")

(deftest compile-janet-linux-arm64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "janet" "--target" "linux-arm64" "--output" output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-janet-linux-x64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "janet" "--target" "linux-x64" "--output" output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-janet-macos-arm64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "janet" "--target" "macos-arm64" "--output" output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-janet-macos-x64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "janet" "--target" "macos-x64" "--output" output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-janet-windows-arm64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "janet" "--target" "windows-arm64" "--output" output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-janet-windows-x64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "janet" "--target" "windows-x64" "--output" output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(defer (h/rmrf cache-dir)
  (h/setup-cache cache-dir)
  (run-tests!))
