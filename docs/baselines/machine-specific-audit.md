# Machine-specific documentation audit (ARCH-00)

Scope: `docs/adr/**` was scanned for absolute user paths, UDID-shaped identifiers, derived-data locations, signing/team settings, and host-specific commands. The wider `docs/**` tree was also sampled to identify historical references that should not be treated as current evidence.

## Current ADRs

No personal filesystem path, UDID, `DEVELOPMENT_TEAM`, signing setting, or machine hostname was found in `docs/adr/**`. ADR 0015 mentions `.xcode-version` as a repository contract and ADR 0017 records platform floors; both are machine-neutral.

## Historical documentation findings (report only)

The broader documentation tree contains legacy machine-bound references, including:

- `/Users/sunweizhou/...` paths in archived handoffs/plans and `docs/vela-handoff-20260824.md`;
- `/tmp/...` result bundles in validation reports;
- simulator/device UDIDs in archived plans and parity validation;
- `DerivedData` paths and direct `devicectl` install examples tied to a prior host/device.

These files are historical records and were deliberately not rewritten in PR0. They must not be copied into new engineering instructions or used as current device evidence. New baselines use repository-relative links and explicitly label external result bundles as local evidence.

## Re-run commands

```text
rg -n --glob 'docs/adr/**' '/Users/|/Volumes/|/private/var|/tmp/' docs/adr
rg -n --glob 'docs/adr/**' -i '\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b|DEVELOPMENT_TEAM|DerivedData|xcode-select|/Applications/Xcode' docs/adr
```

Both current-ADR scans returned no matches other than the intentional `.xcode-version` contract wording in ADR 0015.
