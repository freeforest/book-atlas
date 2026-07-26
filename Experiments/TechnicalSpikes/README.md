# Book Atlas technical spikes

This directory contains disposable, non-production experiments for Prompt 1.

- All records and identifiers are fictional.
- The package and Xcode project are not application architecture.
- Production targets must not depend on this directory.
- Network access is not used by the experiment code.
- Commands and measured results are recorded in `docs/PLANS/MILESTONE-0.md`.

## Swift package

The Swift package compares a small SwiftData probe with a direct system-SQLite
probe and exercises graph math, URL policy, and bookmark lifecycle behavior.

```sh
swift build --package-path Experiments/TechnicalSpikes
swift test --package-path Experiments/TechnicalSpikes
swift run --package-path Experiments/TechnicalSpikes SpikeBenchmark
```

The persistence prototype uses the system SQLite C API. GRDB is compared in the
decision record but is deliberately not downloaded or linked by this experiment.
