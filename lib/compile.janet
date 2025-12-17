(import ./util)

(defdyn *kris-cache-dir*)

(def native-target
  (do
		(def os-type (os/which))
		(def arch (os/arch))
		(cond
			(and (= os-type :macos) (= arch :aarch64)) "macos-arm64"
			(and (= os-type :macos) (= arch :x64)) "macos-x64"
			(and (= os-type :linux) (= arch :aarch64)) "linux-arm64"
			(and (= os-type :linux) (= arch :x64)) "linux-x64"
			(errorf "unsupported native platform %s/%s" os-type arch))))

(def target-map
  ```
  Maps friendly target names to Zig target triples
  ```
  (do
    (def targets
      {"linux-x64"     "x86_64-linux-gnu"
       "linux-arm64"   "aarch64-linux-gnu"
       "macos-x64"     "x86_64-macos"
       "macos-arm64"   "aarch64-macos"
       "windows-x64"   "x86_64-windows-gnu"
       "windows-arm64" "aarch64-windows-gnu"})
		(merge targets {"native" (targets native-target)})))

(def linker-flags
  ```
  Platform-specific linker flags for linking executables
  ```
  {"linux-x64"     ["-lrt" "-ldl"]
   "linux-arm64"   ["-lrt" "-ldl"]
   "macos-x64"     ["-ldl"]
   "macos-arm64"   ["-ldl"]
   "windows-x64"   ["-lws2_32" "-lpsapi" "-lwsock32"]
   "windows-arm64" ["-lws2_32" "-lpsapi" "-lwsock32"]})

(defn get-cache-dir
  ```
  Returns the cache directory

  Uses XDG_CACHE_HOME if set, otherwise defaults to ~/.cache/kris
  ```
  []
  (when (dyn :kris-cache-dir)
    (break (dyn :kris-cache-dir)))
  (def xdg-cache (os/getenv "XDG_CACHE_HOME"))
  (def home (os/getenv "HOME"))
  (def base-dir (or xdg-cache (string/join [home ".cache"] util/sep)))
  (string/join [base-dir "kris"] util/sep))

(defn get-source-dir
  ```
  Returns the source directory for Janet
  ```
  []
  (string/join [(get-cache-dir) "sources" "janet"] util/sep))

(defn get-build-dir
  ```
  Returns the build directory for a specific target
  ```
  [target]
  (string/join [(get-cache-dir) "builds" "janet" target] util/sep))

(defn- parse-version
  ```
  Parses a version string into [major minor patch] tuple

  Returns nil if the version string is malformed.
  ```
  [version-str]
  (def parts (string/split "." version-str))
  (when (>= (length parts) 3)
    (def [ok? res] (protect (map scan-number parts)))
    (when ok?
      res)))

(defn- compare-versions
  ```
  Compares two version strings
  ```
  [a b]
  (cond
    (and (nil? a) (nil? b)) false
    (nil? a) false
    (nil? b) false
    (< (a 0) (b 0)) true
    (> (a 0) (b 0)) false
    (< (a 1) (b 1)) true
    (> (a 1) (b 1)) false
    (< (a 2) (b 2)) true
    (> (a 2) (b 2)) false
    false))

(defn- get-latest-version
  ```
  Gets the latest version tag from the Janet repository

  Fetches all tags and returns the highest version tag (starting with 'v').
  ```
  [source-dir]
  # Fetch all tags
  (def fetch-cmd ["git" "-C" source-dir "fetch" "--tags" "origin"])
  (def fetch-exit (os/execute fetch-cmd :p))
  (assert (zero? fetch-exit) "failed to fetch tags")
  (def proc (os/spawn ["git" "-C" source-dir "tag" "-l"] :p {:out :pipe}))
  (def [tag-exit tags] (ev/gather
                         (os/proc-wait proc)
                         (ev/read (proc :out) :all)))
  (os/proc-close proc)
  (assert (zero? tag-exit) "failed to list tags")
  (def version-tags
    (->> (filter (partial string/has-prefix? "v")
                 (string/split "\n" tags))
         (map (fn [t] (string/slice t 1)))))
  (assert (not (empty? version-tags)) "no version tags found in repository")
  (def sorted-tags
    (-> (map (fn [v] (map scan-number (string/split "." v))) version-tags)
        (sorted compare-versions)))
  # Return version without 'v' prefix
  (-> (map string (last sorted-tags)) (string/join ".")))

(defn download-janet
  ```
  Ensures Janet source is available and checked out to the specified version

  Uses git to clone the Janet repository (if needed) and checkout the version tag.
  If version is "latest", finds the highest version tag.
  ```
  [version]
  (def source-dir (get-source-dir))
  # Clone if directory doesn't exist
  (unless (= :directory (os/stat source-dir :mode))
    (print "cloning Janet repository...")
    (def parent-dir (string/join [(get-cache-dir) "sources"] util/sep))
    (util/mkdir parent-dir)
    (def clone-cmd ["git" "clone" "https://github.com/janet-lang/janet.git" source-dir])
    (def exit-code (os/execute clone-cmd :p))
    (assert (zero? exit-code) "failed to clone Janet repository"))
  # Resolve "latest" to the actual latest version
  (def actual-version
    (if (= version "latest")
      (do
        (print "resolving latest version...")
        (get-latest-version source-dir))
      version))
  (def tag (if (string/has-prefix? "v" actual-version) actual-version (string "v" actual-version)))
  # Fetch and checkout the requested version
  (print "checking out Janet v" actual-version "...")
  (def fetch-cmd ["git" "-C" source-dir "fetch" "origin" (string "refs/tags/" tag)])
  (def exit-code (os/execute fetch-cmd :p))
  (assert (zero? exit-code) "failed to fetch version tag")
  (def checkout-cmd ["git" "-C" source-dir "checkout" tag])
  (def exit-code (os/execute checkout-cmd :p))
  (assert (zero? exit-code) "failed to checkout version")
  source-dir)

(defn build-bootstrap
  ```
  Builds the native janet_boot binary

  This is used to generate the amalgamated janet.c file.
  ```
  [source-dir]
  (print "building native bootstrap compiler...")
  # Use the Makefile's bootstrap target
  (def make-cmd ["make" "-C" source-dir "build/janet_boot"])
  (def exit-code (os/execute make-cmd :p))
  (assert (zero? exit-code) "failed to build native bootstrap")
  (print "built native bootstrap")
  (string/join [source-dir "build" "janet_boot"] util/sep))

(defn generate-amalgamation
  ```
  Generates the amalgamated janet.c file

  Uses the native bootstrap to create a single C file containing all of Janet.
  ```
  [source-dir bootstrap-path]
  (print "generating amalgamation...")
  # Create build/c directory
  (def build-c-dir (string/join [source-dir "build" "c"] util/sep))
  (util/mkdir build-c-dir)
  # Generate janet.c
  # (def janet-path (os/getenv "JANET_PATH" "/usr/local/lib/janet"))
  (def janet-path (os/getenv "JANET_PATH"))
  (def janet-c-path (string/join [build-c-dir "janet.c"] util/sep))
  (def amalg-cmd (string bootstrap-path " " source-dir
                         (when janet-path (string " JANET_PATH '" janet-path "'"))
                         " > " janet-c-path))
  (def exit-code (os/execute ["sh" "-c" amalg-cmd] :p))
  (assert (zero? exit-code) "failed to generate amalgamation")
  # Copy shell.c
  (def shell-src (string/join [source-dir "src" "mainclient" "shell.c"] util/sep))
  (def shell-dst (string/join [build-c-dir "shell.c"] util/sep))
  (util/copy-file shell-src shell-dst)
  (print "generated amalgamation at " build-c-dir)
  build-c-dir)

(defn get-compiler-flags
  ```
  Returns common compiler flags for building Janet

  If small? is true, adds aggressive size optimization flags.
  ```
  [source-dir &opt small?]
  (def base-flags
    @["-Os" "-std=c99" "-Wall" "-Wextra"
      (string "-I" (string/join [source-dir "src" "include"] util/sep))
      (string "-I" (string/join [source-dir "src" "conf"] util/sep))
      "-fvisibility=hidden" "-fPIC"
      "-ffunction-sections" "-fdata-sections"])
  (array/concat base-flags
                (if small?
                  ["-fno-unwind-tables" "-fno-asynchronous-unwind-tables"
                   "-fomit-frame-pointer" "-fno-stack-protector"]
                  [])))

(defn compile-janet-executable
  ```
  Cross-compiles Janet executable using Zig

  Compiles janet.c and shell.c, then links them together for the target platform.
  If small? is true, strips symbols to minimize binary size.
  ```
  [source-dir build-c-dir target output-path &opt small?]
  (def zig-target (get target-map target))
  (print (unless (= "native" target) "cross-") "compiling for " zig-target "...")
  (def lflags (get linker-flags target))
  (def is-windows (string/has-prefix? "windows" target))
  (def exe-name (if is-windows "janet.exe" "janet"))
  (def output (or output-path exe-name))
  (def cflags (get-compiler-flags source-dir small?))
  (def build-dir (get-build-dir target))
  (util/mkdir build-dir)
  (print "compiling janet.c...")
  (def janet-o-path (string/join [build-dir "janet.o"] util/sep))
  (def janet-c-path (string/join [build-c-dir "janet.c"] util/sep))
  (def janet-compile-cmd
    ["zig" "cc" "-target" zig-target
     ;cflags
     "-c" janet-c-path
     "-o" janet-o-path])
  (def exit-code (os/execute janet-compile-cmd :p))
  (assert (zero? exit-code) "failed to compile janet.c")
  (print "compiling shell.c...")
  (def shell-o-path (string/join [build-dir "shell.o"] util/sep))
  (def shell-c-path (string/join [build-c-dir "shell.c"] util/sep))
  (def shell-compile-cmd
    ["zig" "cc" "-target" zig-target
     ;cflags
     "-c" shell-c-path
     "-o" shell-o-path])
  (def exit-code (os/execute shell-compile-cmd :p))
  (assert (zero? exit-code) "failed to compile shell.c")
  (print "linking for " zig-target "...")
  (def link-cmd
    ["zig" "cc" "-target" zig-target
     ;cflags
     "-Wl,--gc-sections"
     "-o" output
     janet-o-path
     shell-o-path
     ;(or lflags [])])
  (def exit-code (os/execute link-cmd :p))
  (assert (zero? exit-code) "failed to link")
  # Strip symbols to reduce size if requested
  (when small?
    (print "stripping symbols...")
    (def strip-cmd ["strip" output])
    (def strip-exit (os/execute strip-cmd :p))
    (when (not (zero? strip-exit))
      (print "warning: failed to strip symbols")))
  (print "successfully compiled to '" output "'")
  output)

(defn build-libjanet
  ```
  Builds the static Janet library (libjanet.a) for a target platform

  Compiles janet.c to janet.o and creates a static library from it.
  This library can be used to link quickbin executables.
  ```
  [source-dir build-c-dir target &opt small?]
  (def zig-target (get target-map target))
  (print "building libjanet.a for " zig-target "...")
  (def cflags (get-compiler-flags source-dir small?))
  (def build-dir (get-build-dir target))
  (util/mkdir build-dir)
  # Compile janet.c to janet.o (without shell.c - library doesn't need the REPL)
  (print "compiling janet.c for static library...")
  (def janet-o-path (string/join [build-dir "janet.o"] util/sep))
  (def janet-c-path (string/join [build-c-dir "janet.c"] util/sep))
  (def janet-compile-cmd
    ["zig" "cc" "-target" zig-target
     ;cflags
     "-c" janet-c-path
     "-o" janet-o-path])
  (def exit-code (os/execute janet-compile-cmd :p))
  (assert (zero? exit-code) "failed to compile janet.c for static library")
  # Create static library using ar
  (print "creating static library...")
  (def libjanet-path (string/join [build-dir "libjanet.a"] util/sep))
  (def ar-cmd ["zig" "ar" "rcs" libjanet-path janet-o-path])
  (def exit-code (os/execute ar-cmd :p))
  (assert (zero? exit-code) "failed to create static library")
  (print "successfully built libjanet.a at " libjanet-path)
  libjanet-path)

(defn marshal-script
  ```
  Marshals a Janet script to bytecode

  Loads the script, finds its main function, and marshals it to bytecode.
  Returns the marshalled bytecode as a buffer.
  ```
  [script-path]
  (print "marshalling " script-path "...")
  (def env (make-env))
  (dofile script-path :env env)
  (def main-fn (module/value env 'main))
  (assertf main-fn "no main function found in %s" script-path)
  (assert (function? main-fn) "main must be a function")
  (def bytecode (marshal main-fn (invert (env-lookup root-env))))
  (print "marshalled " (length bytecode) " bytes")
  bytecode)

(defn- create-bytecode-array
  ```
  Converts bytecode buffer to a C array string
  ```
  [bytecode]
  (def result @"")
  (eachp [i b] bytecode
    (when (> i 0)
      (buffer/push-string result (if (zero? (% i 16)) ",\n    " ", ")))
    (buffer/push-string result (string b)))
  (string result))

(defn create-embedding-c
  ```
  Creates C source code that embeds the marshalled bytecode
  ```
  [bytecode]
  (string
    ```
    #include <janet.h>

    static const unsigned char bytecode[] = {
    ```
    (create-bytecode-array bytecode)
    ```
    };

    static const size_t bytecode_size = sizeof(bytecode);

    int main(int argc, const char **argv) {
        janet_init();

        /* Get core env */
        JanetTable *env = janet_core_env(NULL);
        JanetTable *lookup = janet_env_lookup(env);
        int handle = janet_gclock();

        /* Unmarshal bytecode */
        Janet marsh_out = janet_unmarshal(bytecode, bytecode_size, 0, lookup, NULL);

        /* Verify it's a function */
        if (!janet_checktype(marsh_out, JANET_FUNCTION)) {
            fprintf(stderr, "error: invalid bytecode - expected function\n");
            janet_deinit();
            return 1;
        }
        JanetFunction *jfunc = janet_unwrap_function(marsh_out);

        /* Check arity */
        if (argc > jfunc->def->max_arity && jfunc->def->max_arity >= 0) {
            fprintf(stderr, "error: too many arguments\n");
            janet_deinit();
            return 1;
        }

        /* Collect command line arguments */
        JanetArray *args = janet_array(argc);
        for (int i = 0; i < argc; i++) {
            janet_array_push(args, janet_cstringv(argv[i]));
        }

        /* Set up environment */
        janet_table_put(env, janet_ckeywordv("args"), janet_wrap_array(args));
        janet_table_put(env, janet_ckeywordv("executable"), janet_cstringv(argv[0]));
        janet_gcroot(janet_wrap_table(env));

        /* Unlock GC */
        janet_gcunlock(handle);

        /* Run the function */
        JanetFiber *fiber = janet_fiber(jfunc, 64, argc, argc ? args->data : NULL);
        fiber->env = env;
    #ifdef JANET_EV
        janet_gcroot(janet_wrap_fiber(fiber));
        janet_schedule(fiber, janet_wrap_nil());
        janet_loop();
        int status = janet_fiber_status(fiber);
        janet_deinit();
        return status;
    #else
        Janet out;
        JanetSignal result = janet_continue(fiber, janet_wrap_nil(), &out);
        if (result != JANET_SIGNAL_OK && result != JANET_SIGNAL_EVENT) {
            janet_stacktrace(fiber, out);
            janet_deinit();
            return result;
        }
        janet_deinit();
        return 0;
    #endif
    }
    ```))

(defn compile-quickbin
  ```
  Compiles a quickbin executable

  Takes the embedding C code, compiles it, and links it with libjanet.a
  to create a standalone executable.
  If small? is true, strips symbols to minimize binary size.
  ```
  [source-dir libjanet-path embedding-c target output-path &opt small?]
  (def zig-target (get target-map target))
  (print "compiling quickbin for " zig-target "...")
  (def lflags (get linker-flags target))
  (def is-windows (string/has-prefix? "windows" target))
  (def build-dir (get-build-dir target))
  (util/mkdir build-dir)
  (def embed-c-path (string/join [build-dir "quickbin.c"] util/sep))
  (spit embed-c-path embedding-c)
  (print "compiling quickbin.c...")
  (def embed-o-path (string/join [build-dir "quickbin.o"] util/sep))
  (def cflags (get-compiler-flags source-dir small?))
  (def compile-cmd
    ["zig" "cc" "-target" zig-target
     ;cflags
     "-c" embed-c-path
     "-o" embed-o-path])
  (def exit-code (os/execute compile-cmd :p))
  (assert (zero? exit-code) "failed to compile quickbin.c")
  (print "linking for " zig-target "...")
  (def link-cmd
    ["zig" "cc" "-target" zig-target
     ;cflags
     "-Wl,--gc-sections"
     "-o" output-path
     embed-o-path
     libjanet-path
     "-lm" "-lpthread"
     ;(or lflags [])])
  (def exit-code (os/execute link-cmd :p))
  (assert (zero? exit-code) "failed to link quickbin")
  # Strip symbols to reduce size if requested
  (when small?
    (print "stripping symbols...")
    (def strip-cmd ["strip" output-path])
    (def strip-exit (os/execute strip-cmd :p))
    (when (not (zero? strip-exit))
      (print "warning: failed to strip symbols")))
  (print "successfully created quickbin at " output-path)
  output-path)
