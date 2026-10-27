# Extension proposals: synapse-board

The binary has no interim host code. Everything it does is in `src/*.om` on the pinned omega-mv
(`omega.pin`). The repo carries two POSIX shell files, `build.sh` and `tests/run.sh`. They are build and
test drivers, not part of the shipped tool. The Omega gaps that would let them, and parts of `src/`,
become simpler:

1. **Omega test driver.** `tests/run.sh` launches the binary, compares exit codes and files, runs `curl`
   once and checks the clock against `date -u`. A seeded Omega test runner would replace it: run a program
   with argv, capture stdout and stderr, compare files, and make one HTTP GET (http.om already has the client).
   Missing capability: a library for waiting on child processes and capturing their output.
2. **Globals as arguments.** Inputs live in 4 MiB globals, and each JSONL line is copied into a local
   64 KiB buffer before json.om can parse it, because a global cannot be passed to a function. A
   borrowed view of a global (`view gin0`) would remove the copy and the 64 KiB line limit.
3. **Interface address query.** `serve` takes `--bind` from the caller, and the tests find the tailnet
   address with `ip -4 addr`. A host word that lists interface addresses (`getifaddrs`) would let `serve`
   pick its 100.64.0.0/10 address itself.
