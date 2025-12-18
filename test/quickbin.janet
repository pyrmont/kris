(use ../deps/testament)
(import ../res/helpers/util :as h)

(def cache-dir (string (os/cwd) h/sep (string "tmp-" (gensym) "-quickbin")))
(def cli-path (string (os/cwd) h/sep "lib" h/sep "cli.janet"))
(def confirmation "Compilation completed.")
(def input (string (os/cwd) h/sep "res" h/sep "fixtures" h/sep "hello_world.janet"))
(def output "hello-world")

(deftest compile-quickbin-linux-arm64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "quickbin" "--target" "linux-arm64" input output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-quickbin-linux-x64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "quickbin" "--target" "linux-x64" input output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-quickbin-macos-arm64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "quickbin" "--target" "macos-arm64" input output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-quickbin-macos-x64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "quickbin" "--target" "macos-x64" input output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-quickbin-windows-arm64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "quickbin" "--target" "windows-arm64" input output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(deftest compile-quickbin-windows-x64
  (h/in-dir d
    (def [exit-code out err]
      (h/shell-capture ["janet" cli-path "--cache" cache-dir "quickbin" "--target" "windows-x64" input output]))
    (is (zero? exit-code))
    (is (string/has-suffix? (h/add-eol confirmation) out))
    (is (= :file (os/stat output :mode)))))

(defer (h/rmrf cache-dir)
  (h/setup-cache cache-dir)
  (run-tests!))
