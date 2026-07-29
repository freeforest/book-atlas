# ADR-0005: External links and Apple Books

- Status: Accepted
- Date: 2026-07-26
- Owners: Project maintainers

## Context

Book Atlas may offer user-approved external destinations, but it must not promise access to a specific item in a user's Apple Books library without supported evidence. The app is offline by default and does not receive a network-client entitlement.

Prompt 1 verified that the installed Books application can be located through bundle identifier `com.apple.iBooksX`. It background-launched that application and asked macOS to dispatch a public Apple Books search URL containing only a fictional term; both system commands exited successfully. The code-level policy accepts only well-formed HTTPS URLs, labels the `books.apple.com` host as a store destination, rejects `file:` and `ibooks:` input, and refuses any open operation that was not user initiated.

## Decision

Open only user-initiated, allowlisted HTTPS URLs through `NSWorkspace`. Treat Apple Books store URLs as ordinary external HTTPS destinations with an Apple Books label. Do not implement or promise custom `ibooks:` URLs, automatic opening, scraping, or direct navigation to an item in a user's local Apple Books library.

When a destination is unsupported or unavailable, present a visible fallback such as opening an approved public store/search page or allowing the user to copy a link. Do not silently fail or attempt a private-library lookup.

## Alternatives considered

- **Custom `ibooks:` deep links:** rejected because this stage did not establish supported behavior.
- **Apple Books local-library identification:** rejected because no supported, reproducible API was established.
- **Automatic URL opening:** rejected because it would violate user control and could disclose private terms to another application.

## Consequences

### Positive

- The integration has a narrow, testable allowlist and explicit user action.
- Unsupported Apple Books behavior degrades safely rather than creating a false product promise.

### Negative or tradeoffs

- Apple Books behavior is limited to operating-system URL dispatch and app presence.
- The target application or browser may use the network after the user approves an external URL; Book Atlas itself remains offline by default.

## Privacy and security

External URLs and search terms can be private. Book Atlas must not log them and must require a user action before dispatching them. It does not hold a network-client entitlement for this behavior; macOS delivers the approved URL to the user's chosen external application.

## Validation

The isolated package test suite passed tests for app detection, HTTPS allowlisting, rejected schemes, and denied non-user-initiated opens. The following system-dispatch check used only a fictional term:

```sh
open -gj -b com.apple.iBooksX
open -gj 'https://books.apple.com/us/search?term=BookAtlas%20Technical%20Spike'
```

These commands verify dispatch only. They do not prove custom schemes, a particular store result, or local-library item support.

Prompt 9 implements this accepted boundary behind replaceable validators, workspace/Apple Books adapters, and a state-layer fallback coordinator. Production applies the same HTTPS validator before persistence, before ordinary dispatch, and after Apple Books search URL generation. It rejects raw and percent-decoded C0/DEL controls and requires an explicit port, when present, to be unsigned ASCII decimal in `1...65535`; `URLComponents` cannot normalize an empty or malformed port into acceptance. It labels only the exact `books.apple.com` host, requires confirmation before public search, and uses the documented order: saved store URL, public search, app launch, ISBN copy, title copy, then another saved HTTPS entry. Automated tests use spies and never invoke a real external application. Prompt 9 remains awaiting another independent review after its first-review closure; these implementation facts do not expand the experimental dispatch evidence or claim private-library item support.
