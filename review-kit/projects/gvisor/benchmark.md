# gVisor benchmark overlay

Used by the `benchmark` skill.

## When to benchmark

Benchmark when the change touches a path in the "Performance sensitivity"
section of `AGENTS.md`, or when it can affect performance in another way. Read
the list from the checkout each time; don't copy it here. Changes that only touch
tests don't need benchmarks.

## Method (source of truth)

Read "Benchmarking methodology" in `.agents/skills/gvisor-performance/SKILL.md`
in the checkout. Its rules apply. In short:
- Present results as the **raw output of `benchstat`**.
- Run until **n≥16 per side or p<0.01**, whichever comes first. Run more when
  the stddev is over 5% on microbenchmarks.
- Include `~` (no significant change) rows for metrics that should not move.
- Explain surprising results after the table.

## Stats tool

- `~/go/bin/benchstat base.txt change.txt` (not on `PATH`). Fallback:
  `go run golang.org/x/perf/cmd/benchstat@latest base.txt change.txt`.
- Run it from the results directory with the files named `base.txt` and
  `change.txt`. `benchstat` labels the columns with the file paths you give it.
- The input files must contain Go benchmark output lines (`BenchmarkX  N  v ns/op ...`),
  appended one run at a time.

## Picking benchmarks

- List the available targets:
  - `bazel query 'kind(go_test, //test/benchmarks/...)'` (macro benchmarks,
    run in containers);
  - `grep -rl 'func Benchmark' <changed package dirs>` (Go microbenchmarks).
- Upstream example: for startup, run `//test/benchmarks/base:startup_test` (and
  `//test/kubernetes/benchmarks:startup_test` if a cluster is available).
- Prefer a microbenchmark for the changed function **and** one macro benchmark
  for the user-visible path. A microbenchmark alone doesn't show an end-to-end
  effect.

## Go microbenchmarks (no containers)

1. Build the test binary on each side with the **same compilation mode**. The
   default is `fastbuild`; prefer `-c opt` on both sides, and state the mode in
   the report: `bazel build -c opt //pkg/foo:foo_test`.
2. Find the binary with `bazel cquery -c opt --output=files //pkg/foo:foo_test`
   (pass the same `-c` flag), and copy it to `<tmp>/base/` or `<tmp>/change/`.
3. Run each side directly, one count per call, in ABBA order:
   `<bin> -test.run='^$' -test.bench='<regex>' -test.benchmem -test.count=1 >> base.txt`.
   Running the binary directly avoids Bazel's test caching and overhead.

## Macro benchmarks (`//test/benchmarks`, Docker, root)

- **Build:** `bazel build //runsc` on each side. Copy the binaries to
  `<tmp>/base/runsc` and `<tmp>/change/runsc`.
- **Build the benchmark binary once**, from the base. Use it for both sides, so
  that only runsc differs. If the change modifies the benchmark or harness,
  say so in the report.
- **Runtimes:** both sides must be registered as Docker runtimes. **Don't do
  this yourself.** Print these steps for the user:
  1. Add `runsc-base` and `runsc-change` to `/etc/docker/daemon.json`, pointing
     at the copied binaries, with `"runtimeArgs": ["--platform=systrap"]`.
  2. `sudo systemctl restart docker`.
  3. Check: `docker run --rm --runtime=runsc-base hello-world`, and the same
     for `runsc-change`.

  Then wait for confirmation.
- **Run** in ABBA order, one count per call:
  `sudo <bench-binary> -runtime=runsc-base -test.bench='<regex>' -test.count=1 >> base.txt`
  (and `-runtime=runsc-change` for change). The default `make` option is
  `-test.benchtime=30s`; keep the same benchtime on both sides.
- **Clean up:** remind the user to remove the two runtimes from
  `daemon.json` afterward.

## Platform and environment

- **Default platform:** systrap. Only add KVM or runc as reference points when
  the user asks.
- This machine is a GCP VM. Note it in the report. Virtualization distorts
  results, and KVM-platform numbers from a VM don't reflect bare metal. Don't
  make KVM performance claims from VM runs.
- On this VM, run the A/A noise floor check. A quick A/A test of
  `//pkg/buffer` `BenchmarkReadAt` (n=3, same binary) showed 14.0 vs 18.1 ns/op.
  Small effects need many runs here.

## Report

- Location: `~/workspace/benchmarks/<branch>-<YYYYMMDD>.md`.
- The "For the PR description" section has the raw `benchstat` output, then a
  short explanation of anything surprising, as `gvisor-performance` requires.
