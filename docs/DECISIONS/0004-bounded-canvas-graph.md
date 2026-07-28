# ADR-0004: Bounded Canvas graph

- Status: Accepted
- Date: 2026-07-26
- Owners: Project maintainers

## Context

Book Atlas needs an optional relationship view without placing graph coordinates or presentation state in the bibliography model. The first renderer must remain native, offline, bounded, and accessible.

Prompt 1 created a fictional SwiftUI `Canvas` spike with a separate graph fixture and viewport model. It supports hit testing, node movement, panning, magnification from 0.5× through 3×, selection, a no-edge state, and an accessibility list alternative. The canvas was hosted and laid out in an AppKit host view during the test run.

The debug benchmark generated and hit-tested deterministic fixtures as follows: 50 nodes in 0.000024583 seconds, 100 nodes in 0.000027166 seconds, and 250 nodes in 0.000064541 seconds. Each fixture reported a zero resident-memory delta at the process sampling granularity. These measurements are model-generation results, not frame-rate measurements.

## Decision

Use SwiftUI `Canvas` for the bounded graph renderer, with graph interaction and accessibility represented outside the core bibliography model. Production defaults to 80 nodes and 200 edges, with hard configurable caps of 250 nodes and 500 edges. Truncation is explicit. The Canvas renders asynchronously, while a visible semantic list provides selection, concrete relationship reasons, weights, opening details, and re-centering.

Use a deterministic, cancellable local projection and layout. The default traversal is one layer with an optional second layer. Canonical edges merge evidence from same author, shared tags, shared collections, shared sources, and directed manual relationships. Ranking contributions are manual 100–120, same author 80, collections 40–60, sources 35–50, and tags 20 each up to 60; combined weight is capped at 250. A fixed radial seed followed by at most 80 bounded force iterations provides stable positions without perpetual animation. View-local dragging, zoom, pan, selection, and filters are not persisted.

## Alternatives considered

- **AppKit custom view:** offers lower-level drawing control, but the current native SwiftUI canvas spike meets the bounded first-release need.
- **Third-party graph renderer:** adds dependency and maintenance surface before a need has been demonstrated.
- **Unbounded canvas:** rejected because it would make responsiveness and accessibility claims unverifiable.

## Consequences

### Positive

- No graph dependency or network access is required.
- The domain remains independent of renderer coordinates and gesture state.
- A semantic list alternative avoids relying on non-semantic canvas elements alone.

### Negative or tradeoffs

- Canvas primitives are not individually accessible; the list representation is required.
- The 80-node default intentionally favors legibility; users cannot request an unbounded whole-library graph.
- Weighting is a deterministic display/ranking rule, not a claim about literary importance.
- Canvas primitives remain non-semantic, so the list representation is required for every production graph.

## Privacy and security

Graph data is derived locally from the user's private library. It must not be sent over the network or logged with book titles, relationship labels, coordinates, or identifiers.

## Validation

Completed with fictional data:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift test --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift run --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache SpikeBenchmark
```

The final isolated package run passed 13 tests, including an AppKit-hosted Canvas layout test.

Prompt 8 production validation uses fixed fictional Schema-4 stores. Domain/state regression tests cover all five relationship families, merged evidence, filtering, one/two layers, limits, merge/delete/kept-version behavior, deterministic layout, cancellation, stale centers, node movement, and error/empty states. The measured production 1,000/5,000/10,000-book baselines on the verified arm64 host are recorded in `docs/DEVELOPMENT.md`; at 10,000 books the bounded projection queried in approximately 46.7 ms, built in 1.0 ms, laid out in 75.1 ms, first-rendered in 38.5 ms, and grew resident memory by approximately 17.8 MB. These observations are not cross-device performance promises. Prompt 8 remains subject to independent acceptance.
