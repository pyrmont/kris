# Kris

[![Test Status](https://github.com/pyrmont/kris/workflows/test/badge.svg)](https://github.com/pyrmont/kris/actions?query=workflow%3Atest)

Kris is a tool for cross-compiling Janet projects for multiple platforms using
Zig.

```
Usage: kris <subcommand> [<args>]

A tool for cross-compiling Janet projects for multiple platforms using Zig.

Options:

 -h, --help    Show this help message.

Subcommands:

 c, clean        Delete the kris cache directory.
 j, janet        Cross-compile Janet.
 q, quickbin     Cross-compile a standalone executable.

For more information on each subcommand, type 'kris help <subcommand>'.
```

## Requirements

Kris requires [GNU Make][] and [Zig][] to be installed and available on your
PATH. Zig is used to cross-compile for different target platforms.

[GNU Make]: https://www.gnu.org/software/make/
[Zig]: https://ziglang.org/

## Installing

### Jeep

If you use Janet, you can install `kris` using [Jeep][]:

[Jeep]: https://github.com/pyrmont/jeep

```
$ jeep install https://github.com/pyrmont/kris
```

### From Source

To install the `kris` binary from source, you need [Janet][] installed on your
system. Then run:

[Janet]: https://janet-lang.org

```shell
$ git clone https://github.com/pyrmont/kris
$ cd kris
$ git tag --sort=creatordate
$ git checkout <version> # check out the latest tagged version
$ janet --install .
```

## Using

Run `kris --help` for usage information. The command-line arguments are
explained in more detail in the [man page][].

[man page]: https://github.com/pyrmont/kris/blob/master/man/man1/kris.1.predoc

### Cross-Compiling Janet

Cross-compile Janet for a specific platform:

```shell
$ kris janet --target linux-x64 --version 1.40.1
```

Supported targets:
- `native` - Your current platform
- `linux-x64` - Linux x86-64
- `linux-arm64` - Linux ARM64
- `macos-x64` - macOS x86-64
- `macos-arm64` - macOS ARM64
- `windows-x64` - Windows x86-64
- `windows-arm64` - Windows ARM64

By default, kris uses the latest release from the Janet repository. You can
specify a specific version with `--version`.

To optimize for the smallest binary size, use the `--small` flag:

```shell
$ kris janet --small
```

### Creating Quickbins

Create a standalone executable from a Janet script:

```shell
$ kris quickbin script.janet output
```

This embeds your Janet script's bytecode into a standalone executable that
includes the Janet runtime.

You can target different platforms:

```shell
$ kris quickbin --target linux-x64 script.janet output
```

As with the `janet` subcommand, you can optimize for the smallest binary size,
use the `--small` flag:

```shell
$ kris quickbin --small script.janet output
```

### Cleaning the Cache

Kris caches Janet source code and build artifacts in `~/.cache/kris` (or
`$XDG_CACHE_HOME/kris`). To clean the cache:

```shell
$ kris clean
```

## Bugs

Found a bug? I'd love to know about it. The best way is to report your bug in the [Issues][] section on GitHub.

[Issues]: https://github.com/pyrmont/kris/issues

## Licence

Kris is licensed under the MIT Licence. See [LICENSE][] for more details.

[LICENSE]: https://github.com/pyrmont/kris/blob/master/LICENSE
