# Sample data policy

Only deterministic fictional data may be committed here. Every book, contributor, publisher, identifier, list, source, URL, note, and relationship must be invented for Book Atlas testing or demonstration.

Do not copy, transform, anonymize, or “sanitize” a real personal library for this directory. Realistic structure is useful; real content is not.

Review new fixtures for private paths, live URLs, credentials, and accidental real metadata before committing them.

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
