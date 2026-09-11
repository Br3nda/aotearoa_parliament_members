# aotearoa_parliament_members

A [morph.io](https://morph.io) scraper for NZ Members of Parliament data, fetched straight from
[data.govt.nz's official open-data catalogue](https://catalogue.data.govt.nz/dataset/members-of-parliament) -
not from Hansard at all, a completely separate source from the
[aotearoa_hansard](https://github.com/Br3nda/aotearoa_hansard)/
[aotearoa_hansard_transcripts](https://github.com/Br3nda/aotearoa_hansard_transcripts) scrapers.

**Data lives on morph.io, not in this repo**: <https://morph.io/Br3nda/aotearoa_parliament_members>

That page has the scraper's run history and a `data.sqlite` you can query directly (via the page
itself, or morph.io's [API](https://morph.io/documentation/api)) - this repo is just the code
that produces it.

Three raw tables, matching the three CSVs the dataset publishes:

- `member_list` - everyone who's ever been an MP, one row per person
- `member_terms` - one row per parliamentary term served (most members have several)
- `member_contact_details` - current MPs only, no shared ID with the other two tables, just a
  name to match on

Downstream, [hotair](https://github.com/Br3nda/hotair) is what actually turns this data into
linked `Member`/`MemberTerm` records - it already has a working import for these same three CSVs
(`Members::Fetcher`/`Members::Importer`), just reading from a local file cache rather than
morph.io. This scraper only stores raw content, it doesn't parse or normalise anything.
