# Item audit — 2026-10-27 source snapshot

Read-only catalog and behavior analysis of `erikjpet/BeatTheHouse` at commit
`9adf460d1ad0d716e91049bda0d9477483e7aebe`. Saved in the BTH repository on
2026-10-28 at the owner's request. Findings describe that pinned source snapshot;
later game changes may require a new audit. No gameplay or authored descriptions
were changed by this report.

## Read on a phone

- **Spreadsheet:** download [the categorized CSV](beat_the_house_item_audit_categorized.csv)
  into your spreadsheet app. Turn on text wrapping and filter by `Item category`,
  `Default shop eligibility` or `Canonical item ID`. It has 153 unique item rows
  and 15 columns, including plain-language behavior and review notes.
- **One item at a time:** download [the offline HTML reader](beat_the_house_item_audit_mobile.html)
  and open the saved file in a browser that permits JavaScript in local HTML.
  Search, select an item, use Previous/Next, or expand Filters. Descriptions,
  full numerical analysis and sources expand underneath each item. If a file
  preview shows source text or disables controls, open the downloaded file in a
  browser instead. The report has no network dependencies; source links require
  a connection when tapped.

The HTML was checked in an isolated Chromium process at 375×812 and 320px width;
all 153 cards were expanded without horizontal overflow. Phone file-preview
support varies and was not verified on a physical phone. This directory is an
offline repository artifact; it does not publish a website or deploy the game.

## Files

| File | Purpose |
| --- | --- |
| [beat_the_house_item_audit.csv](beat_the_house_item_audit.csv) | Original requested four-column, duplicate-free baseline; preserved byte-for-byte |
| [beat_the_house_item_audit_categorized.csv](beat_the_house_item_audit_categorized.csv) | Complete expanded analysis; original four columns unchanged |
| [beat_the_house_item_audit_mobile.html](beat_the_house_item_audit_mobile.html) | Self-contained searchable one-item reader of the same data |
| [categorized_coverage_guide.md](categorized_coverage_guide.md) | Catalog scope, acquisition/count reconciliation, distinctions and evidence limits |
| [categorized_acquisition_evidence.json](categorized_acquisition_evidence.json) | Canonical IDs, categories, acquisition channels, source references and review notes |
| [categorized_validation.json](categorized_validation.json) | CSV row/column, duplicate and preservation checks |
| [mobile_validation.json](mobile_validation.json) | Local mobile-width HTML verification |
| [artifact_manifest.json](artifact_manifest.json) | Source commit, file sizes and SHA-256 checksums |

The six expanded-report artifacts retain their previously validated bytes. This
repository directory is the durable copy. At the owner's subsequent request,
the categorized CSV, offline HTML and coverage guide were also attached in
ChatGPT for phone access without LAN. Raw evidence and validation remain in this
directory. No separate website was published. Internal screenshots and transfer
tooling are not included.

## Scope and review state

There are **60 default ordinary merchant-stock IDs**, not 153 ordinary shop
items. Tickets, persistent collection gear/bags, souvenirs and mission contexts
are separate roles. Contraband is an overlapping risk flag. The coverage guide
reconciles all 153 rows and shows optional-group and other acquisition paths.

The current short/full text remains factual source material. Practical/value
notes distinguish connected effects, missing readers, state requirements and
untested player value; they do not select replacement balance values. Recorded
owner decisions: flag ordinary Lucky Penny for full rework (replacement
undecided); preserve ordinary X-Ray Glasses functionality pending description
discussion.

This docs-only handoff was prepared in an isolated BTH worktree to avoid the
primary worker's active gameplay fixes. Integrate only `docs/item-audit/` through
the primary repository workflow. Saving these local files does not itself push,
merge, publish, upload to Library or deploy anything.
