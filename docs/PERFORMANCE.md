# Prompt 10 performance evidence

This file records local regression evidence, not a cross-device performance
promise or a release acceptance result.

## Environment and method

- Date: 2026-07-30
- Hardware: Apple M2 MacBook Air, 8 CPU cores, 24 GB memory
- macOS: 26.5.2 (25F84)
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- Configuration: Debug XCTest/XCUIAutomation plus a Release-optimized local
  Instruments trace build, arm64, macOS destination
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
`XCTApplicationLaunchMetric(waitUntilResponsive: true)` in Debug. The separate
Release-optimized measurements use Instruments' **App Launch** template and
report the trace timestamp at the end of **Initial Frame Rendering**. These
metrics are related but not identical and should not be compared as a compiler
speedup ratio.

| Configuration | Books | Three raw runs (s) | Median | Range |
| --- | ---: | --- | ---: | ---: |
| Debug XCTest | 1,000 | 1.268940, 1.293977, 1.350821 | 1.293977 | 1.268940–1.350821 |
| Debug XCTest | 5,000 | 3.816601, 3.677170, 3.812545 | 3.812545 | 3.677170–3.816601 |
| Debug XCTest | 10,000 | 8.457591, 8.374219, 8.866668 | 8.457591 | 8.374219–8.866668 |
| Release Instruments | 1,000 | 1.776590, 1.191468, 1.251082 | 1.251082 | 1.191468–1.776590 |
| Release Instruments | 5,000 | 3.315764, 3.199479, 3.219467 | 3.219467 | 3.199479–3.315764 |
| Release Instruments | 10,000 | 5.663961, 6.075030, 5.765581 | 5.765581 | 5.663961–6.075030 |

The Release traces launched the final normal Release build (without
`ENABLE_TESTABILITY`) with the fixed-fictional performance seed argument and
ended after the Instruments time limit. On this Xcode/macOS combination,
Instruments left the launched app stopped, so task-created instances were
explicitly terminated between runs. They did not read the user's application
container. The first 1,000-book trace is a visible cold-cache outlier and
remains in the range.

Database open measures `SQLiteDatabase` construction plus the production
repository's migration/version check on an already-current Schema 5 file.
First load is the production default `LibraryQuery` (the documented 500-row
page), not a physical-frame rendering measurement. Tag usage is the production
grouped tag-summary query over 32 tags and one association per book.

| Books | Database open, raw (s) | Open median (range) | First 500 rows, raw (s) | First-load median (range) | Tag usage, raw (s) | Tag median (range) |
| ---: | --- | ---: | --- | ---: | --- | ---: |
| 1,000 | 0.000181, 0.000156, 0.000225 | 0.000181 (0.000156–0.000225) | 0.138198, 0.138849, 0.139008 | 0.138849 (0.138198–0.139008) | 0.009207, 0.009247, 0.009178 | 0.009207 (0.009178–0.009247) |
| 5,000 | 0.000185, 0.000166, 0.000224 | 0.000185 (0.000166–0.000224) | 0.137316, 0.139740, 0.148077 | 0.139740 (0.137316–0.148077) | 0.010483, 0.010581, 0.010952 | 0.010581 (0.010483–0.010952) |
| 10,000 | 0.000213, 0.000183, 0.000219 | 0.000213 (0.000183–0.000219) | 0.137718, 0.148031, 0.140263 | 0.140263 (0.137718–0.148031) | 0.012212, 0.012204, 0.012107 | 0.012204 (0.012107–0.012212) |

These repository microbenchmarks ran in the Debug XCTest host. A Release
XCTest attempt was actually executed, but Xcode 26.6 hung the Release unit
test runner before it established a connection; a Release UI attempt
initialized its runner but discovered zero cases. Neither attempt is reported
as a performance result.

## Sustained library scrolling

XCUIAutomation focuses the real production list, performs two 4,800-point
downward and two upward scroll-wheel deltas, and measures three round trips
with `XCTClockMetric`, `XCTMemoryMetric`, `XCTCPUMetric`, and, on macOS 26,
`XCTHitchMetric`. The table retains the exact order emitted by the result
bundle.

| Books | Clock raw (s) | Hitch count raw | Hitch duration raw (s) | Peak physical memory raw (kB) |
| ---: | --- | --- | --- | --- |
| 1,000 | 13.163990, 13.261486, 12.389271 | 11, 12, 7 | 6.716423, 3.216579, 3.066580 | 198165.632, 206800.000, 223446.168 |
| 5,000 | 12.984002, 12.603667, 12.206184 | 7, 11, 8 | 1.416633, 5.366482, 1.233302 | 215254.168, 227034.240, 257688.752 |
| 10,000 | 12.896391, 12.430073, 13.502227 | 7, 9, 8 | 2.433246, 2.666575, 2.116585 | 228017.304, 249218.200, 270435.504 |

Clock medians were 13.163990 / 12.603667 / 12.896391 seconds. Hitch-count
medians were 11 / 8 / 8 and peak-memory medians were 206800.000 / 227034.240 /
249218.200 kB. Hitch time ratios were respectively
`502.049, 238.670, 243.559`, `107.360, 418.975, 99.423`, and
`185.658, 211.094, 154.250` ms/s. Their broad ranges show substantial
WindowServer/automation noise; no frame-rate promise or regression threshold
is inferred.

The same test code was invoked against a Release TestAction. Xcode 26.6
completed with zero discovered UI cases, so there is no Release scrolling
number. Instruments launch traces do not simulate a user scroll, and this
execution surface could not safely control the interactive desktop. Release
scrolling remains an explicit unverified gate.

## Historical migration to Schema 5

Each source database is created through the formal migrator only to Schema
1, 2, 3, or 4, filled with fixed fictional books, copied for each repetition,
then migrated through the production path to Schema 5. Every run checks the
final version, book count, and `foreign_key_check`.

| Source → 5 | Books | Three raw runs (s) | Median | Range |
| --- | ---: | --- | ---: | ---: |
| 1 → 5 | 1,000 | 0.220136, 0.227036, 0.221168 | 0.221168 | 0.220136–0.227036 |
| 2 → 5 | 1,000 | 0.218386, 0.220838, 0.220874 | 0.220838 | 0.218386–0.220874 |
| 3 → 5 | 1,000 | 0.223276, 0.223231, 0.223638 | 0.223276 | 0.223231–0.223638 |
| 4 → 5 | 1,000 | 0.002076, 0.001343, 0.001230 | 0.001343 | 0.001230–0.002076 |
| 1 → 5 | 5,000 | 1.110918, 1.110890, 1.119885 | 1.110918 | 1.110890–1.119885 |
| 2 → 5 | 5,000 | 1.108541, 1.114122, 1.110669 | 1.110669 | 1.108541–1.114122 |
| 3 → 5 | 5,000 | 1.121896, 1.112315, 1.113862 | 1.113862 | 1.112315–1.121896 |
| 4 → 5 | 5,000 | 0.001639, 0.001228, 0.001246 | 0.001246 | 0.001228–0.001639 |
| 1 → 5 | 10,000 | 2.256332, 2.248088, 2.240435 | 2.248088 | 2.240435–2.256332 |
| 2 → 5 | 10,000 | 2.239509, 2.259295, 2.244865 | 2.244865 | 2.239509–2.259295 |
| 3 → 5 | 10,000 | 2.239877, 2.246382, 2.240865 | 2.240865 | 2.239877–2.246382 |
| 4 → 5 | 10,000 | 0.001620, 0.001642, 0.001836 | 0.001642 | 0.001620–0.001836 |

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

No metric here represents Release sustained scrolling, a reliable display
frame rate, energy use, a memory-pressure kill, minimum-supported macOS 14, or
cross-device behavior. Graph first render remains an `NSHostingView`
measurement, not a physical-display frame-rate test. Release Instruments
measures the initial frame, not completion of the first 500-row query. Those
items remain manual/release gates and must not be inferred from the tables
above.
