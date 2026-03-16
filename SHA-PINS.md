# SHA Pins — GitHub Actions

All `uses:` references in sennacc CI/CD must use commit SHA, not tags.
This prevents supply chain attacks where a tag is moved to a malicious commit.

**Last verified: 2026-03-13**

---

## Pinned Actions

| Action | Tag | Commit SHA | Last Verified |
|---|---|---|---|
| `actions/checkout` | v4.2.2 | `11bd71901bbe5b1630ceea73d27597364c9af683` | 2026-03-13 |
| `actions/setup-node` | v4.1.0 | `39370e3970a6d050c480ffad4ff0ed4d3fdee5af` | 2026-03-13 |
| `actions/upload-artifact` | v4.6.0 | `65c4c4a1ddee5b72af3b9d33e4d5bea034563ba6` | 2026-03-13 |
| `actions/download-artifact` | v4.1.8 | `fa0a91b85d4f404e444e00e005971372dc801d16` | 2026-03-13 |
| `actions/github-script` | v7.0.1 | `60a0d83039c74a4aee543508d2ffcb1c3799cdea` | 2026-03-13 |

---

## Renewal Process

SHA pins become stale when new versions are released. Dependabot (configured in `sennacc/github`) will automatically open PRs to update these pins.

### Manual verification
```bash
# Verify a SHA still matches a tag
gh api repos/actions/checkout/git/refs/tags/v4.2.2 \
  --jq '.object.sha'
# Should match: 11bd71901bbe5b1630ceea73d27597364c9af683
```

### When adding a new action
1. Find the commit SHA for the desired tag:
   ```bash
   gh api repos/<owner>/<action>/git/refs/tags/<tag> --jq '.object.sha'
   ```
2. Add to this file with the date
3. Use the SHA in the `uses:` field, with a comment showing the tag:
   ```yaml
   uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
   ```

---

## Dependabot Configuration

SHA pins are kept up to date automatically by the `dependabot.yml` in `sennacc/github`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: monthly
```

When Dependabot opens a PR, verify the new SHA before merging.
