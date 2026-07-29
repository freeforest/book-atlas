# Prompt 10 performance evidence

This file records local regression evidence, not a cross-device performance
promise or a release acceptance result.

## Environment and method

- Date: 2026-07-30
- Hardware: Apple M2 MacBook Air, 8 CPU cores, 24 GB memory
- macOS: 26.5.2 (25F84)
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- Configuration: Debug, arm64, macOS destination
- Data: fixed fictional records in fresh in-memory or temporary SQLite stores
- Repetitions: three per measured workload
- Reporting: median with observed minimum–maximum range

The run used production repository, duplicate, graph, import/export, backup,
and restore paths. It ran from an active developer session, not a
single-purpose benchmark host; filesystem cache, thermal state, concurrent
Xcode work, and allocator reuse contribute noise. The third portability
iteration was visibly slower, so the range is retained rather than discarded.

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

No automated metric here represents cold application launch, sustained
library-list scrolling/frame pacing, energy use, a memory-pressure kill,
minimum-supported macOS 14, or release-optimized performance. Graph first
render is an `NSHostingView` measurement, not a physical-display frame-rate
test. Those items remain manual/release gates and must not be inferred from
the tables above.
