# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, GitHub Copilot, and others) when
working with code in this repository.

## What this scraper does

A [morph.io](https://morph.io) scraper for NZ Members of Parliament data, fetched from
[data.govt.nz's official open-data catalogue](https://catalogue.data.govt.nz/dataset/members-of-parliament) -
a completely separate source from Hansard (see the sibling
[aotearoa_hansard](https://github.com/Br3nda/aotearoa_hansard) repo). It only stores *raw*
content, upserted by whichever key each CSV's own rows naturally provide - it does not parse or
normalise anything. That happens downstream, in the [hotair](https://github.com/Br3nda/hotair)
Rails app, which already has a working import for these same three CSVs
(`Members::Fetcher`/`Members::Importer`) reading from a local cache - the plan is for that (or an
adapted version of it) to eventually read from this scraper's morph.io output instead.

## Layout

- `scraper.rb` - the whole thing. Fetches the dataset's landing page to discover the three CSVs'
  current download URLs (their filenames include a publish date, so they can't be hardcoded),
  then saves each one's rows raw into its own table.
- `platform` - which morph.io build stack this scraper runs on (`heroku-24`). See
  `aotearoa_hansard`'s `PLAN.md` for the full history of why `heroku-24` over the older,
  unmaintained `heroku-18`/`cedar-14` stacks.

## Things that will catch you out

- **The three CSVs have real, confirmed-not-hypothetical quirks** - don't "simplify" these away
  without re-checking against the live data first:
  - `member_list.csv` and `member_terms.csv` are UTF-8 with a byte-order mark.
    `CSV.parse`'s `encoding: "bom|utf-8"` trick only works with `CSV.open`/`CSV.foreach` on a
    file - it silently fails (`unknown encoding name`) on an in-memory string like these
    already-downloaded bodies. See `strip_bom`.
  - `member_contact_details.csv` is Windows-1252 encoded, not UTF-8 - it has real accented names
    that aren't valid UTF-8 bytes.
  - `member_terms.csv` is one row per parliamentary term, not one row per member - `MemberID`
    repeats, and even `MemberID+Parliament` isn't unique on its own (a member can have more than
    one entry within the same Parliament, e.g. a list replacement or a mid-term change in
    affiliation). The upsert key is `MemberID+Parliament+Date_Elected+Electorate_List`.
  - `member_contact_details.csv` has no `MemberID` at all - just a name (`Contact`) to key on.
  - `member_contact_details.csv`'s headers have spaces/slashes (`Salutation/Title`,
    `Job Title`, `Parliament Email`). `scraperwiki-ruby`'s `save_sqlite` doesn't quote column
    names, so passing those straight through breaks the SQL it generates - see
    `sanitize_headers`.
- **Not a paginated/incremental source** - unlike `aotearoa_hansard`, this is three flat CSVs
  fetched in full every run. No rate-limiting/backfill logic here; there's nothing to page
  through, and data.govt.nz isn't the kind of source that needs the same care Hansard's own
  servers do.

## Commands

- Syntax check: `ruby -c scraper.rb`
- Lint: `bundle exec rubocop` (or `rubocop scraper.rb` if gems aren't installed locally)
- Run against morph.io directly (uploads and streams output back, doesn't run locally):
  `morph` (needs an API key in `~/.morph` - see morph.io/settings)
