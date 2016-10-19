#!/usr/bin/env ruby

# this is all @ickymettle's magic
# you need to create a JIRA filter with your issues and configure the filter
# ID in the config file:
#
# username: dschauenberg
# passworditem: Etsy LDAP
#
# jql: "assignee = mrtazz"
#
# jira_base_url: http://jira.example.com

$VERBOSE = nil

require "rubygems"
require "faraday"
require "appscript"
require "yaml"
require "pp"
require "uri"
require 'json'

# Public: get all issues for a given JQL search
#
# Params:
#   user     - username for basic auth
#   password - password for basic auth
#   jql      - jql to use for searching for issues
#   host     - jira base URL
#   path     - path to issues API
#
# Returns an array of Jira issues of the format [{:summary, :reporter, :url,
# :created, :description, :key}]
def get_jira_issues(user, password, jql, host="https://jira.example.com", path="/rest/api/2/search")
  conn = Faraday.new(:url => host)
  conn.basic_auth(user, password)
  res = conn.get do |req|
    req.url path
    req.params['jql'] = jql
  end
  res = JSON.parse(res.body)
  res["issues"].map! {|item| {:summary => item["fields"]["summary"],
                    :reporter => item["fields"]["reporter"]["name"],
                    :created => DateTime.strptime(item["fields"]["created"],'%Y-%m-%dT%H:%M:%S.%L%z').strftime("%Y-%m-%dT%H:%M:%SZ"),
                    :description => item["fields"]["description"],
                    :key => item["key"]
                    }}
end


jira_data = Hash.new()
omni_data = Hash.new()

CONFIG = YAML.load_file(File.join(ENV["HOME"], ".jirafocus"))

# connect to JIRA
cmd = "findpassword.sh \"#{CONFIG["passworditem"]}\""
password = `#{cmd}`
if password.empty?
  $stderr.puts "Couldn't get password, aborting..."
  exit 1
end

issues = get_jira_issues(CONFIG["username"], password.strip!, CONFIG["jql"], CONFIG["jira_base_url"])

issues.each do |issue|
    jira_data[issue[:key]] = Hash.new()
    jira_data[issue[:key]][:summary]     = issue[:summary]
    jira_data[issue[:key]][:reporter]    = issue[:reporter]
    jira_data[issue[:key]][:created]     = issue[:created]
    jira_data[issue[:key]][:description] = issue[:description]
end

# connect to OmniFocus
omnifocus = Appscript.app('OmniFocus')
omnifocus_jira = omnifocus.default_document
jira_context = omnifocus.default_document.flattened_contexts['Jira']

omnifocus_jira.flattened_tasks.get.each do |task|
    name = task.name.get
    created = task.creation_date.get

    if name =~ /^([[:alpha:]]+-\d+) - (.*?) \(([^\)]+)\)$/
        key = $1
        summary = $2
        reporter = $3

        omni_data[key] = Hash.new()
        omni_data[key][:summary]  = summary
        omni_data[key][:reporter] = reporter
        omni_data[key][:created]  = created
        omni_data[key][:completed]  = task.completed.get
    end
end

mine_not_assigned = omni_data.select { |key, value| value[:completed] == false }

# sync jira to OF
skipped = 0
synced  = 0
jira_data.each do |key,props|
  if omni_data.has_key?(key)
    skipped += 1
    mine_not_assigned.delete(key)
    ## TODO: update name and reporter if it has changed
  else
    # TODO: fix timezones (inserting as UTC)
    name = sprintf("%s - %s (%s)", key, props[:summary], props[:reporter])
    link = sprintf("#{CONFIG["jira_base_url"]}/browse/%s", key)
    desc = sprintf("REF: %s\n\n%s", link, props[:description])

    puts "** Adding #{key}"
    omnifocus_jira.make(:new => :inbox_task,
                        :with_properties => { :name => name,
                                              :note => desc,
                                              :context => jira_context })
    synced += 1
  end

end

puts "** Synced #{synced} issues from JIRA to OmniFocus, Skipped #{skipped}"

puts "** #{mine_not_assigned.keys.length} tasks in OmniFocus but not assigned to me:"
mine_not_assigned.each do |key, props|
  puts "#{key}: #{props[:summary]} => #{sprintf("#{CONFIG["jira_base_url"]}/browse/%s", key)}"
end
