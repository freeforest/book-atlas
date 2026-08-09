# Security policy

Book Atlas is preparing its first formal source-only version, 1.0.0. The
repository became Public on 2026-08-10, but tag `v1.0.0` and the corresponding
GitHub Release do not yet exist; public source availability is not a claim that
V1.0.0 has been formally released.

The project security model, threat boundaries, import/URL/backup controls,
dependency policy, and logging rules are documented in
[`docs/SECURITY.md`](docs/SECURITY.md). The privacy policy is in
[`docs/PRIVACY.md`](docs/PRIVACY.md).

## Reporting

GitHub Private Vulnerability Reporting is enabled. On 2026-08-10 an independent
public non-administrator view confirmed that the repository Security page
shows **Report a vulnerability** and routes reporters into GitHub's private
vulnerability-reporting flow. The administrator view shows **New draft
security advisory** instead; this is a role difference, not an alternate
public reporting channel. No test vulnerability report was created.

Report sensitive security issues through the repository's Security page using
**Report a vulnerability**. Do not publish exploit details,
private library content, local paths, bookmarks, credentials, keys,
certificates, recovery data, or signing material in a public Issue. No personal
email address is designated as an alternate security channel.

Ordinary non-sensitive defects can use the bug-report template. Remove private
data and use only fixed fictional examples.
