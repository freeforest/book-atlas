# Fictional sample data

Only deterministic fictional data may be committed here. Every book, contributor, publisher, identifier, list, source, URL, note, and relationship must be invented for Book Atlas testing or demonstration.

Do not copy, transform, anonymize, or “sanitize” a real personal library for this directory. Realistic structure is useful; real content is not.

Review new fixtures for private paths, live URLs, credentials, and accidental real metadata before committing them.

## Product demo

[`bookatlas-demo.csv`](bookatlas-demo.csv) contains 12 invented records in the
16-column `bookatlas-csv/1` format. It covers all four book kinds and seven
reading states, with fixed publication dates and UTC reading timestamps.
ISBN fields are intentionally empty. Authors, publishers, organizations and
notes are fictional; none were sampled or anonymized from a personal library.

### Reproduce the isolated scene

Use an existing, known Book Atlas 1.2.0 / build 2 app. Substitute its absolute
path below; do not launch the default library or add other seed/test switches:

```sh
BOOKATLAS_DEMO_APP="/absolute/path/to/BookAtlas.app"
open -n "$BOOKATLAS_DEMO_APP" --args -BookAtlasUseInMemoryStore -ApplePersistenceIgnoreState YES -BookAtlasUseSystemFilePanel
```

Bind automation to the new process and verify its executable and arguments
before interacting. If the new process has no window, send that specific app
a standard reopen event. Keep any existing normal instance untouched.
Choose **数据 → 导入 CSV…**, select this CSV, inspect the preview, then confirm.
The preview should show 12 importable rows and no warnings, errors or duplicates;
the completed import should show **已导入 12 本；跳过 0 行，其中重复 0 行。**
The in-memory library disappears when this isolated instance exits.

For the library scene, keep filters clear and select **《雾港档案》**. The
screenshots use a 1280×800-point window in the existing Light appearance, saved
as 1600×1000 PNGs. Import-generated UUIDs, audit times and tied sort order may
differ across runs; locate books by their fictional titles, not fixed row numbers.

For the graph scene, choose **查看局部书图**, retain one layer and all relation
families, and select **《北岸来信》** in the node list. 《雾港档案》 has six
neighbors: shared author (北岸来信), tag 城市记忆 (潮汐街道、旧城的回声), tag 地图
(星图索引), reading list 雾港漫游 (灯塔以西), and source 虚构灯塔书讯 (纸月航线).
The other records form separate, smaller groups. No manual relations were
created for these screenshots; CSV does not carry manual relations.

On 2026-09-10, the existing Release app's importer completed the 12/0/0 result
above in an explicitly verified in-memory process. Both [library](../docs/media/bookatlas-library.png)
and [graph](../docs/media/bookatlas-graph.png) images are captures of that real
window, not mockups. Images were proportionally resized and ancillary metadata
removed, with no UI compositing. No desktop,
file-picker, personal library or unrelated window appears in the images.

## Small parser fixture and benchmarks

`bookatlas-small.csv` is a small, reviewable `bookatlas-csv/1` import fixture.
It is not loaded automatically and contains only invented records. Generate
larger benchmark fixtures outside the repository with:

```sh
swift Scripts/generate_fictional_library.swift \
  --count 10000 \
  --seed 20260730 \
  --output /tmp/bookatlas-fictional-10000.json
```

The JSON generator includes books, organizations, `example.invalid` links,
manual relationships, and deliberate strong-candidate pairs. Its output is a
benchmark fixture, not an application import format.
