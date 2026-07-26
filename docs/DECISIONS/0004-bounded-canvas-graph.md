# ADR-0004: Bounded Canvas graph

- Status: Accepted
- Date: 2026-07-26
- Owners: Project maintainers

## Context

Book Atlas needs an optional relationship view without placing graph coordinates or presentation state in the bibliography model. The first renderer must remain native, offline, bounded, and accessible.

Prompt 1 created a fictional SwiftUI `Canvas` spike with a separate graph fixture and viewport model. It supports hit testing, node movement, panning, magnification from 0.5× through 3×, selection, a no-edge state, and an accessibility list alternative. The canvas was hosted and laid out in an AppKit host view during the test run.

The debug benchmark generated and hit-tested deterministic fixtures as follows: 50 nodes in 0.000024583 seconds, 100 nodes in 0.000027166 seconds, and 250 nodes in 0.000064541 seconds. Each fixture reported a zero resident-memory delta at the process sampling granularity. These measurements are model-generation results, not frame-rate measurements.

## Decision

Use SwiftUI `Canvas` for the initial bounded graph renderer, with graph interaction and accessibility represented outside the core bibliography model. Set an initial visible-node limit of 250. Prompt 8 must measure real rendering and interaction before increasing that limit or adding layout complexity.

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
- The 250-node cap is conservative and must be enforced by the future graph feature.
- Layout algorithms, clustering, and production frame timing are deferred to Prompt 8.

## Privacy and security

Graph data is derived locally from the user's private library. It must not be sent over the network or logged with book titles, relationship labels, coordinates, or identifiers.

## Validation

Completed with fictional data:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift test --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift run --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache SpikeBenchmark
```

The final isolated package run passed 13 tests, including an AppKit-hosted Canvas layout test. Prompt 8 must add production interaction, accessibility, and frame-time tests.
