# vbmeta_patch

A small CLI tool to patch the `flags` byte of an Android `vbmeta.img` file
(AVB — Android Verified Boot) in order to disable dm-verity / verification
enforcement, or to write it back to a custom value.

## Features

- Validates the input file is a real `vbmeta` image (checks the `AVB0` magic).
- Patch the flags byte in-place, or write the result to a new file with `-o`.
- Choose the exact flags value to write with `-f` (0–3), defaulting to `3`.
- Built with [Zig](https://ziglang.org/), so it cross-compiles cleanly to
  Windows, Linux, macOS and Android with no extra toolchain.

## AVB Flags Reference

The vbmeta flags byte accepts 4 possible values:

| Value | Meaning                                                        |
|-------|-----------------------------------------------------------------|
| `0`   | Verification and verity fully enabled (stock behavior)          |
| `1`   | `VERIFICATION_DISABLED`                                         |
| `2`   | `VERIFICATION_ERROR_IGNORED`                                     |
| `3`   | `VERIFICATION_DISABLED \| VERIFICATION_ERROR_IGNORED` (default)  |

## Usage

```
vbmeta_patch [options] <filename>

Options:
  -o, --out <path>       Write output to a new file instead of patching in-place
  -f, --flags <0-3>      Value to set the vbmeta flags to (default: 3)
                           0 = verification + verity enabled
                           1 = VERIFICATION_DISABLED
                           2 = VERIFICATION_ERROR_IGNORED
                           3 = VERIFICATION_DISABLED | VERIFICATION_ERROR_IGNORED
  -v, --version          Show version information
  -h, --help             Show this help message
```

### Examples

Patch a vbmeta image in place with the default flags (`3`):

```sh
vbmeta_patch vbmeta.img
```

Write the patched result to a new file, keeping the original untouched:

```sh
vbmeta_patch vbmeta.img -o vbmeta_patched.img
```

Set a specific flags value (e.g. re-enable full verification, value `0`):

```sh
vbmeta_patch vbmeta.img -f 0
```

Combine both:

```sh
vbmeta_patch vbmeta.img -o vbmeta_patched.img --flags 2
```

## Building from source

Requires [Zig](https://ziglang.org/download/) `0.16.0` or newer.

```sh
zig build -Doptimize=ReleaseSafe
```

The resulting binary will be at `zig-out/bin/vbmeta_patch`.

### Embedding a version string

The binary embeds a version string that is shown with `-v` / `--version`.
You can set it at build time with `-Dversion`:

```sh
zig build -Dversion="v1.0.0-abc1234-local-build"
```

If not provided, it defaults to `v0.0.0-dev-local-build`.

## Disclaimer

This tool modifies Android verified boot metadata. Only use it on devices
and images you own or are explicitly authorized to modify. Disabling
verification lowers the security guarantees of your device. All damage is the responsibility of the user and the developer is not responsible for any damage caused by this tool.
