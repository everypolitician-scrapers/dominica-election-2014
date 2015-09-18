#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('#map area/@href').map(&:text).uniq.each do |href|
    link = URI.join url, href
    scrape_area(link)
  end
end

def scrape_area(url)
  noko = noko_for(url)

  box = noko.css('.map2')
  constituency = box.css('h2').text.sub('Constituency','').tidy
  candidates = box.css('.candidate').map do |c|
    info = c.css('.cand_name').text.tidy
    if found = info.match(/(.*) \((.*)\)/)
      name, party = found.captures
    else
      raise "No details: #{info}"
    end

    {
      id: File.basename(c.css('.cand_img img/@src').text, '.*'),
      name: name,
      party: party,
      constituency: constituency,
      image: URI.join(url, c.css('.cand_img img/@src').text).to_s,
      votes: c.css('.cand_votes strong').text.to_i,
      term: 2014,
      winner: 'no', # override later for winner
    }
  end
  winner = candidates.sort_by { |c| c[:votes] }.last
  winner[:winner] = 'yes'
  
  # puts candidates
  ScraperWiki.save_sqlite([:id, :term], candidates)
end

scrape_list('http://electoraloffice.gov.dm/past-general-elections/227-2014-general-elections-results')
