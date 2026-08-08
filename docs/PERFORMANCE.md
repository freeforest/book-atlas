# Prompt 10 performance evidence

This file records local regression evidence, not a cross-device performance
promise or a release acceptance result.

## Environment and method

- Date: 2026-07-30
- Hardware: Apple M2 MacBook Air, 8 CPU cores, 24 GB memory
- macOS: 26.5.2 (25F84)
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- Configuration: Debug XCTest/XCUIAutomation plus Debug and Release production
  builds, arm64, macOS destination
- Data: fixed fictional records in fresh in-memory or temporary SQLite stores
- Repetitions: three per measured workload
- Reporting: median with observed minimum–maximum range

The run used production repository, migration, query, scrolling, duplicate,
graph, import/export, backup, and restore paths. It ran from an active
developer session, not a single-purpose benchmark host; filesystem cache,
window-server scheduling, thermal state, concurrent Xcode work, and allocator
reuse contribute noise. Ranges retain warm/cold and hitch outliers rather than
discarding them.

## Launch, open, first load, and tag counts

Cold launch uses Apple's
`XCTApplicationLaunchMetric(waitUntilResponsive: true)` in Debug. Before the
metric starts, a separate application process creates, closes, and verifies a
fixed-fictional current Schema 5 database with the requested exact count.
Every measured process receives only the session UUID, opens that existing
regular file without SQLite create fallback, runs normal interrupted-restore
and migration/version checks, and publishes the first 200 rows plus exact
total. The assertion after each launch confirms that the measured process saw
1,000/5,000/10,000 rows; it does not add preparation to the launch metric.

| Configuration | Books | Three raw runs (s) | Median | Range |
| --- | ---: | --- | ---: | ---: |
| Debug XCTest | 1,000 | 0.650830, 0.670892, 0.667705 | 0.667705 | 0.650830–0.670892 |
| Debug XCTest | 5,000 | 0.665359, 0.670500, 0.695031 | 0.670500 | 0.665359–0.695031 |
| Debug XCTest | 10,000 | 0.678458, 0.663082, 0.678608 | 0.678458 | 0.663082–0.678608 |

Each session is a UUID-named child of the process temporary root. The
test-only entry rejects uncontrolled paths, unknown or malformed performance
arguments, unsupported counts, symlinks, non-regular/missing database files,
and unexpected artifacts; it never falls back to Application Support.
Cleanup removes the validated database and WAL/SHM/journal sidecars and then
the empty session directory. Arguments and output contain no absolute path.

The same prepare → use-existing → cleanup protocol is implemented in the
Release product so Instruments can measure identical semantics. This closure
completed the unmeasured Release preparation process, but the measured
interactive Instruments App Launch request could not be authorized from the
task execution surface. No Release launch value is reported. Previous numbers
that generated the test library inside the timed launch are superseded because
they measured setup plus launch rather than opening an existing library.

Database open measures `SQLiteDatabase` construction plus the production
repository's migration/version check on an already-current Schema 5 file.
First load is the production default `LibraryQuery`: 200 rows plus an exact
filtered `COUNT(*)`, not a physical-frame rendering measurement. Tag usage is
the production grouped tag-summary query over 32 tags and one association per
book.

| Books | Database open, raw (s) | Open median (range) | First 200 + total, raw (s) | First-load median (range) | Tag usage, raw (s) | Tag median (range) |
| ---: | --- | ---: | --- | ---: | --- | ---: |
| 1,000 | 0.000167500, 0.000163416, 0.000164666 | 0.000164666 (0.000163416–0.000167500) | 0.055601750, 0.055447875, 0.056238958 | 0.055601750 (0.055447875–0.056238958) | 0.009333000, 0.009214333, 0.009164042 | 0.009214333 (0.009164042–0.009333000) |
| 5,000 | 0.000183125, 0.000154792, 0.000213959 | 0.000183125 (0.000154792–0.000213959) | 0.055298083, 0.055863625, 0.060349750 | 0.055863625 (0.055298083–0.060349750) | 0.010229625, 0.010720708, 0.013271458 | 0.010720708 (0.010229625–0.013271458) |
| 10,000 | 0.000223208, 0.000151750, 0.000231625 | 0.000223208 (0.000151750–0.000231625) | 0.055433958, 0.056390625, 0.056329208 | 0.056329208 (0.055433958–0.056390625) | 0.012143417, 0.012892708, 0.012686708 | 0.012686708 (0.012143417–0.012892708) |

These repository microbenchmarks ran in the Debug XCTest host. A Release
XCTest attempt was actually executed, but Xcode 26.6 hung the Release unit
test runner before it established a connection; a Release UI attempt
initialized its runner but discovered zero cases. Neither attempt is reported
as a performance result.

## Pagination correctness and workload

The production first page is 200 rows and the repository rejects page sizes
above 1,000. Fixed-fictional 501-, 1,001-, and 10,000-row tests walk the first,
next, and final pages and compare every UUID with a single deterministic
created-time/UUID order: no duplicate, missing, or reordered boundary was
observed. Separate state tests cover search/filter/sort reset, selection after
create/update/delete/merge, and next-page failure followed by retry while
retaining the already displayed rows. The interactive UI regression loads
501 rows as 200 → 400 → 501 through Shift-Command-L and checks both the
accessible “已显示 N 本，共 T 本” status and the final no-more-results state.

Exact UUID focus does not change the paging workload. It queries the normal
200-row page and exact count, then performs at most one indexed UUID lookup
under the same search/filter predicates if the target is not already loaded.
The focused record is presented separately until ordinary pagination reaches
it; intervening pages are not fetched. Fixed-fictional 501-book repository,
state, and graph-to-library UI regressions verify third-page focus, while
missing or excluded targets clear selection rather than selecting row one.
The existing 1k/5k/10k launch, next-page, and sustained-scroll measurements
therefore retain their documented workload and do not include library-wide
target scanning or data generation.

The XCUI next-page workload starts its clock before invoking the production
Shift-Command-L load-more command and stops after the accessible count status
changes atomically from “已显示 200 本，共 T 本，可以继续加载” to
“已显示 400 本，共 T 本，可以继续加载”. Publishing the count together
with the page-readiness state prevents a following keyboard command from
observing a new count while the load-more control is still disabled. The
separate 501-row UI regression verifies the visible load-more button's label,
value, keyboard command, and terminal state. The performance workload is
intentionally an end-to-end automation observation, not a SQLite-only query
duration; accessibility-tree traversal and WindowServer scheduling dominate
it.

| Existing library | Three raw 200→400 runs (s) | Median | Range |
| ---: | --- | ---: | ---: |
| 1,000 | 6.732388709, 6.718926250, 6.696181875 | 6.718926250 | 6.696181875–6.732388709 |
| 5,000 | 6.685939834, 6.745147250, 6.664272333 | 6.685939834 | 6.664272333–6.745147250 |
| 10,000 | 6.667712708, 6.714792208, 6.740694292 | 6.714792208 | 6.667712708–6.740694292 |

## Sustained library scrolling

XCUIAutomation focuses the real production list, performs two 4,800-point
downward and two upward scroll-wheel deltas, and measures three round trips
with `XCTClockMetric`, `XCTMemoryMetric`, `XCTCPUMetric`, and, on macOS 26,
`XCTHitchMetric`. Before measurement it loads a deliberately different
bounded workload for each existing library: all 5 pages/1,000 rows for the 1k
store, 10 pages/2,000 rows for the 5k store, and 15 pages/3,000 rows for the
10k store. Page preparation is outside the scroll metric and every step checks
the exact visible/total count. No workload puts all 5k or 10k rows in SwiftUI
state.

| Existing library | Loaded pages / rows | Clock raw (s) | Hitch count raw | Hitch duration raw (s) | Peak physical memory raw (kB) |
| ---: | ---: | --- | --- | --- | --- |
| 1,000 | 5 / 1,000 | 18.572304, 19.635145, 18.409691 | 8, 5, 7 | 6.199788, 6.416447, 3.549881 | 330106.152, 345294.144, 354895.168 |
| 5,000 | 10 / 2,000 | 19.453783, 19.597245, 19.561401 | 4, 2, 2 | 8.516344, 0.516646, 0.516646 | 328664.360, 338806.056, 348063.016 |
| 10,000 | 15 / 3,000 | 18.466320, 19.543076, 19.703817 | 4, 6, 6 | 4.966468, 4.299867, 7.116442 | 345867.584, 355337.536, 365675.840 |

Clock medians were 18.572304 / 19.561401 / 19.543076 seconds. Hitch-count
medians were 7 / 2 / 6, hitch-duration medians were
6.199788 / 0.516646 / 4.966468 seconds, and peak-memory medians were
345294.144 / 338806.056 / 355337.536 kB. The corresponding process
`Memory Physical` samples were 17121.328/17612.824/10813.440 kB for 1k,
11337.752/12140.544/11272.192 kB for 5k, and
16924.720/11386.880/11763.712 kB for 10k; these are Apple metric samples,
not a claim that the application allocated exactly those amounts. Broad
hitch and memory ranges show substantial
WindowServer/XCUIAutomation/accessibility-tree noise. They are not a physical
frame-rate measurement, a product threshold, or evidence that dataset size
has no effect.

There is no Release scrolling number. Instruments App Launch does not
simulate a user scroll, and Release UI TestAction did not provide a reliable
case-execution surface on this Xcode/macOS combination. Release scrolling
remains an explicit unverified gate.

## Historical migration to Schema 5

Each source database is created through the formal migrator only to Schema
1, 2, 3, or 4, filled with fixed fictional books, copied for each repetition,
then migrated through the production path to Schema 5. Every run checks the
final version, book count, and `foreign_key_check`.

| Source → 5 | Books | Three raw runs (s) | Median | Range |
| --- | ---: | --- | ---: | ---: |
| 1 → 5 | 1,000 | 0.223299750, 0.233619209, 0.226658750 | 0.226658750 | 0.223299750–0.233619209 |
| 2 → 5 | 1,000 | 0.228160791, 0.236771667, 0.234224375 | 0.234224375 | 0.228160791–0.236771667 |
| 3 → 5 | 1,000 | 0.232759917, 0.235621583, 0.234288125 | 0.234288125 | 0.232759917–0.235621583 |
| 4 → 5 | 1,000 | 0.001441791, 0.001407708, 0.001449000 | 0.001441791 | 0.001407708–0.001449000 |
| 1 → 5 | 5,000 | 1.127231542, 1.153490959, 1.142468208 | 1.142468208 | 1.127231542–1.153490959 |
| 2 → 5 | 5,000 | 1.177228542, 1.165987125, 1.165597125 | 1.165987125 | 1.165597125–1.177228542 |
| 3 → 5 | 5,000 | 1.142767375, 1.151058583, 1.137588041 | 1.142767375 | 1.137588041–1.151058583 |
| 4 → 5 | 5,000 | 0.001600625, 0.001227083, 0.001239375 | 0.001239375 | 0.001227083–0.001600625 |
| 1 → 5 | 10,000 | 2.288446958, 2.275376208, 2.287382417 | 2.287382417 | 2.275376208–2.288446958 |
| 2 → 5 | 10,000 | 2.285026125, 2.293042209, 2.284350709 | 2.285026125 | 2.284350709–2.293042209 |
| 3 → 5 | 10,000 | 2.285627041, 2.289707875, 2.284058417 | 2.285627041 | 2.284058417–2.289707875 |
| 4 → 5 | 10,000 | 0.001771666, 0.001282084, 0.001580333 | 0.001580333 | 0.001282084–0.001771666 |

These migration numbers are Debug XCTest observations. The large difference
for 4 → 5 is expected because that step adds the local-file-reference objects
without the earlier duplicate-key/token backfill. It is not an assertion that
migration cost is independent of all Schema 4 data shapes.

## Library query and duplicate lookup

Times are seconds. Insert is a single transaction. Tag write attaches one tag
to every tenth book. Search, multi-filter, and stable sort return at most 100
rows.

| Books | Insert | Tag write | Search | Multi-filter | Sort |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 0.5465 (0.5408–0.5521) | 0.000435 (0.000411–0.000590) | 0.000745 (0.000738–0.000861) | 0.009862 (0.009502–0.009878) | 0.028662 (0.028294–0.029929) |
| 5,000 | 2.7558 (2.6225–2.7965) | 0.002080 (0.002036–0.002209) | 0.002526 (0.002398–0.002657) | 0.029368 (0.029110–0.030461) | 0.028769 (0.028720–0.029000) |
| 10,000 | 5.3122 (5.2852–5.5163) | 0.004105 (0.004039–0.004290) | 0.004205 (0.004036–0.004346) | 0.028960 (0.028645–0.029445) | 0.028043 (0.027394–0.029301) |

The indexed 10,000-book Exact duplicate lookup measured a 0.200569-second
median (0.184636–0.208072) and remained below its one-second local regression
ceiling in all three repetitions.

## Bounded graph

Each projection reaches the deliberate 80-node/79-edge limited result.
Interaction is 100 production state updates and re-entry is five rebuilds.

| Books | Query | Projection | Layout | Total | First render | Interaction | Five re-entries |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 0.050041 (0.046576–0.050715) | 0.001034 (0.001007–0.001538) | 0.078356 (0.073580–0.082070) | 0.130617 (0.121172–0.133161) | 0.049592 (0.049326–0.071256) | 0.000802 (0.000781–0.000893) | 0.656045 (0.632729–0.726901) |
| 5,000 | 0.050843 (0.048581–0.053420) | 0.001172 (0.001112–0.001184) | 0.079524 (0.078578–0.079673) | 0.130617 (0.129226–0.134280) | 0.053965 (0.051742–0.056045) | 0.000845 (0.000822–0.000867) | 0.653091 (0.647488–0.658894) |
| 10,000 | 0.048603 (0.047731–0.052679) | 0.001068 (0.001009–0.001119) | 0.077407 (0.076849–0.081289) | 0.126529 (0.126176–0.135097) | 0.050288 (0.050054–0.052203) | 0.000795 (0.000787–0.000832) | 0.645992 (0.638360–0.680246) |

Median resident-memory growth was 2,506,752 / 11,976,704 / 23,838,720
bytes for 1k / 5k / 10k (full observed ranges:
2,375,680–13,500,416; 11,862,016–22,036,480; and
23,822,336–23,937,024). The separate 10,000-book background projection kept
the main-actor expectation responsive in 3/3 repetitions.

## Portability

Times are seconds and include production validation. Preview includes
disk-backed staging and duplicate evaluation; import streams and revalidates
that staging.

| Books | Parse | Preview | Import | Markdown | CSV | Backup | Restore |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 0.001796 (0.001665–0.002046) | 0.760522 (0.747240–0.940879) | 0.723763 (0.712129–0.871586) | 0.041290 (0.039670–0.047973) | 0.011179 (0.010864–0.013075) | 0.749505 (0.745340–0.867218) | 1.389779 (1.372184–1.587923) |
| 5,000 | 0.008437 (0.008262–0.009424) | 3.819061 (3.716182–4.367234) | 3.777798 (3.753663–4.326467) | 0.200848 (0.199075–0.228361) | 0.055021 (0.054650–0.062781) | 3.735070 (3.711333–4.405039) | 6.889987 (6.784194–8.669275) |
| 10,000 | 0.018314 (0.016613–0.020888) | 7.751431 (7.531155–9.606240) | 7.867666 (7.600779–9.037096) | 0.409404 (0.397403–0.501039) | 0.112077 (0.110370–0.139995) | 7.545222 (7.516153–11.314691) | 14.843626 (14.808317–21.984995) |

Resident-memory growth is process-level and allocator reuse makes later
samples smaller: medians were 0 / 0 / 9,617,408 bytes, with ranges 0–0 /
0–9,732,096 / 131,072–57,671,680. A separate 84,354,813-byte, 7,000-row
near-limit preview retained only bounded presentation state and measured zero
additional resident/peak growth in all three warm-process repetitions; this
does not mean the operation allocates no memory. Disk staging was created and
cleaned in every repetition. A 10,000-row detached parse kept the main-actor
expectation responsive in 3/3 repetitions.

## What this run does not measure

No metric here represents Release existing-library launch or sustained
scrolling, a reliable display frame rate, energy use, a memory-pressure kill,
the then-declared macOS 14 minimum, or cross-device behavior. ADR-0009 later
superseded that historical target with the macOS 26-only V1.0.0 policy. Graph first render
remains an `NSHostingView` measurement, not a physical-display frame-rate
test. Those items remain manual/release gates and must not be inferred from
the tables above.
