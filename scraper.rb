#!/usr/bin/env ruby
# frozen_string_literal: true

# Fetches NZ Members of Parliament data straight from data.govt.nz's official, open-data
# catalogue - not from Hansard at all, a completely separate source from the aotearoa_hansard(_
# transcripts) scrapers. Matches the same three CSVs hotair's own Members::Fetcher already
# imports locally: everyone who's ever been an MP, one row per parliamentary term served, and
# current MPs' contact details.
#
# Like the other scrapers, this only stores raw content (upserted by whichever key each CSV's
# own rows naturally provide) - it does not parse or normalise anything. That happens
# downstream, in the hotair Rails app.

Bundler.require

require "scraperwiki"
require "net/http"
require "csv"

USER_AGENT = "aotearoa_parliament_members/1.0 (+https://github.com/Br3nda/aotearoa_parliament_members)"
DATASET_PAGE_URL = "https://catalogue.data.govt.nz/dataset/members-of-parliament"

# Each CSV's filename includes the date it was published (e.g.
# "member-contact-details-as-at-22-july-2025.csv"), so URLs can't be hardcoded - find whichever
# files the dataset page is currently linking to, same approach as hotair's own Members::Fetcher.
def discover_csv_urls
  html = http_get(DATASET_PAGE_URL)
  hrefs = html.scan(%r{href="([^"]*/download/[^"]+)"}).flatten

  {
    "member_list" => hrefs.find { |h| h.include?("member-list") },
    "member_terms" => hrefs.find { |h| h.include?("member-terms") },
    "member_contact_details" => hrefs.find { |h| h.include?("member-contact-details") },
  }.tap do |urls|
    urls.each { |key, url| raise "Could not find a #{key} CSV link on #{DATASET_PAGE_URL}" if url.nil? }
  end
end

def http_get(url)
  uri = URI(url)
  request = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT)
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }

  case response
  when Net::HTTPRedirection
    http_get(response["location"])
  when Net::HTTPSuccess
    response.body
  else
    raise "GET #{url} failed: #{response.code} #{response.message}"
  end
end

# Strips a UTF-8 byte-order mark, if present - Encoding's own "bom|utf-8" trick only works for
# CSV.open on a file, not CSV.parse on an in-memory string like these already-downloaded bodies.
def strip_bom(str)
  str.dup.force_encoding("UTF-8").delete_prefix("﻿")
end

# One row per person - MemberID is unique on its own (confirmed directly against the real data:
# 1555 rows, 1555 unique MemberID). UTF-8 with a BOM.
def save_member_list(body)
  rows = CSV.parse(strip_bom(body), headers: true)
  rows.each { |row| ScraperWiki.save_sqlite(["MemberID"], row.to_h, "member_list") }
  rows.size
end

# One row per parliamentary term served - MemberID repeats (most members serve more than one
# term), and even MemberID+Parliament isn't quite unique on its own: a member can have more than
# one entry within the same Parliament (e.g. a list replacement, or a mid-term change in
# affiliation) - confirmed directly against the real data. UTF-8 with a BOM.
def save_member_terms(body)
  key = %w[MemberID Parliament Date_Elected Electorate_List]
  rows = CSV.parse(strip_bom(body), headers: true)
  rows.each { |row| ScraperWiki.save_sqlite(key, row.to_h, "member_terms") }
  rows.size
end

# scraperwiki-ruby's save_sqlite doesn't quote column names, so a header with a space or slash
# in it (this CSV has "Salutation/Title", "Job Title", "Parliament Email") breaks the SQL it
# generates - confirmed directly. Replace anything that's not a letter/digit/underscore with an
# underscore; still the CSV's own raw values, just column names safe to use unquoted.
def sanitize_headers(row_hash)
  row_hash.transform_keys { |key| key.to_s.gsub(/[^a-zA-Z0-9_]/, "_") }
end

# Current MPs only, no MemberID at all - just a name ("Contact") to key on. Windows-1252
# encoded, not UTF-8 (confirmed directly - real accented names in there aren't valid UTF-8
# bytes).
def save_member_contact_details(body)
  rows = CSV.parse(body.dup.force_encoding("Windows-1252").encode("UTF-8"), headers: true)
  rows.each { |row| ScraperWiki.save_sqlite(["Contact"], sanitize_headers(row.to_h), "member_contact_details") }
  rows.size
end

if __FILE__ == $PROGRAM_NAME
  urls = discover_csv_urls

  count = save_member_list(http_get(urls.fetch("member_list")))
  puts "member_list: saved/updated #{count} row(s)"

  count = save_member_terms(http_get(urls.fetch("member_terms")))
  puts "member_terms: saved/updated #{count} row(s)"

  count = save_member_contact_details(http_get(urls.fetch("member_contact_details")))
  puts "member_contact_details: saved/updated #{count} row(s)"
end
