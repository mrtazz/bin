#!/usr/bin/env ruby

#
# Script to fetch all issues assigned to you from GitHub (Enterprise) and add
# it to your OmniFocus inbox with the configured context
#
# Thanks to @ickymettle for inspiration and letting me base this on his code
#
# create an oauth token with:
# curl -k -s -u mrtazz -d '{ "scopes": [ "repo" ], "note": "ghfocus cli"}'\
# -X POST https://api.github.com/authorizations
#
# Then create a ~/.ghfocus file with the following content format:
# -
#   GHHOST: "https://api.github.com"
#   GHPATH: "/issues"
#   TOKEN: "token"
#   CONTEXT: "GitHub"
#   GHNAME: "GitHub"
#

$VERBOSE = nil

require "rubygems"
require "appscript"
require "yaml"
require "pp"
require "faraday"
require "json"

CONFIG = YAML.load_file(File.join(ENV["HOME"], ".ghfocus"))
CONFIG.each do |c|
  GHHOST  = c["GHHOST"]
  GHPATH  = c["GHPATH"]
  TOKEN   = c["TOKEN"]
  CONTEXT = c["CONTEXT"]
  GHNAME  = c["GHNAME"]

  # Public: get all issues for a user corresponding to a given OAuth token
  # across owned, member and organization repositories
  #
  # Params:
  #   token - OAuth token for a user
  #   host  - github host
  #   path  - path to issues API
  #
  # Returns an array of GitHub issues of the format [{:title, :repo, :url}]
  def get_github_issues(token, host="https://api.github.com", path="/issues")
    conn = Faraday.new(:url => host)
    res = conn.get do |req|
      req.url path
      req.headers['Authorization'] = "token #{token}"
    end
    res = JSON.parse(res.body)
    res.map! {|item| {:summary => item["title"],
                      :repo => item["repository"]["full_name"],
                      :url => item["html_url"],
                      :reporter => item["user"]["login"]
                      }}
  end


  # hash to hold all data from omnifocus
  omni_data = Hash.new()
  gh_data = Hash.new()

  issues = get_github_issues(TOKEN, GHHOST, GHPATH)
  issues.each do |issue|
    id = "#{issue[:repo]}/#{issue[:url].split("/")[-1]}"
    gh_data[id] = issue
  end

  # connect to OmniFocus
  omnifocus = Appscript.app('OmniFocus')
  omnifocus_doc = omnifocus.default_document
  github_context = omnifocus.default_document.flattened_contexts[CONTEXT]

  omnifocus_doc.flattened_tasks.get.each do |task|
      name = task.name.get
      created = task.creation_date.get

      if name =~ /^([[:alpha:]]+\/[[-_.a-zA-Z0-9]]+\/\d+) - (.*?) \(([^\)]+)\)$/
          key = $1
          summary = $2
          reporter = $3

          omni_data[key] = Hash.new()
          omni_data[key][:summary]  = summary
          omni_data[key][:reporter] = reporter
          omni_data[key][:created]  = created
      end
  end

  # sync to OF
  skipped = 0
  synced  = 0
  gh_data.each do |key,props|
      if omni_data.has_key?(key)
          skipped += 1
      else
          name = sprintf("%s - %s (%s)", key, props[:summary], props[:reporter])
          link = props[:url]
          desc = sprintf("REF: %s\n\n%s", link, props[:desc])

          puts "** Adding #{key}"
          omnifocus_doc.make(:new => :inbox_task, :with_properties => { :name => name, :creation_date => props[:created], :note => desc, :context => github_context })
          synced += 1
      end
  end

  puts "** Synced #{synced} issues from #{GHNAME} to OmniFocus, Skipped #{skipped}"

end
