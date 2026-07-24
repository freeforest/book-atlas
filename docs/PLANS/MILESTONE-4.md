# Milestone 4 — portability and exploration

## Goal

Give the user control of data portability, add bounded relationship exploration, and adopt only verified external-link behavior.

## Stages

- Prompt 7: staged import, explicit export, versioned backup, validated restore, and failure recovery.
- Prompt 8: local relationship graph projection, native rendering, bounded interaction, and accessible alternatives.
- Prompt 9: Apple Books and external-link behavior supported by Prompt 1 evidence.

## Gates

- Untrusted files are validated before transactions touch the live store.
- Restore cannot silently overwrite the live library and failures preserve the prior state.
- The graph is not a second source of truth and has practical size limits.
- External links validate schemes, require user action, and degrade visibly when unsupported.

