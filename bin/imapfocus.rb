#!/usr/bin/env ruby

#
# Script to fetch all mails from a mailbox and add them to your OmniFocus
# inbox with the configured context
#
# Thanks to @ickymettle for inspiration and letting me base this on his code
#
# Then create a ~/.imapfocus file with the following content format:
# -
#   HOST: "imap.gmail.com"
#   USER: "foo@bla.com"
#   PASSWORD: "skskskskfjewf"
#   MAILBOX: "needs-answering"
#   CONTEXT: "Email"
#

$VERBOSE = nil

require "rubygems"
require "appscript"
require "yaml"
require "pp"
require "net/imap"

def add_tasks_to_omnifocus(tasks, existing, the_context)
  ctxs = the_context.split(":")
  our_context = nil

  omnifocus = Appscript.app('OmniFocus')
  omnifocus_doc = omnifocus.default_document

  if ctxs.length > 1
    omnifocus_doc.flattened_contexts[ctxs[0]].context.get.each do |context|
      if context.name.get == ctxs[1]
        our_context = context
      end
    end
  else
    our_context = omnifocus.default_document.flattened_contexts[ctxs[0]]
  end

  skipped = 0
  synced  = 0
  tasks.each do |name|
      if existing.has_key?(name)
          skipped += 1
      else
          puts "** Adding #{name} with context #{the_context}"
          omnifocus_doc.make(:new => :inbox_task, :with_properties => { :name => name, :context => our_context })
          synced += 1
      end
  end

  return synced, skipped

end

def get_tasks_from_omnifocus
  omni_data = Hash.new
  omnifocus = Appscript.app('OmniFocus')
  omnifocus_doc = omnifocus.default_document

  omnifocus_doc.flattened_tasks.get.each do |task|
      name = task.name.get.strip
      created = task.creation_date.get
      next if task.completed.get

      omni_data[name] = Hash.new()
      omni_data[name][:created]  = created
  end
  return omni_data
end

CONFIG = YAML.load_file(File.join(ENV["HOME"], ".imapfocus"))
CONFIG.each do |c|
  HOST     = c["HOST"]
  USER     = c["USER"]
  PASSWORD = c["PASSWORD"]
  MAILBOX  = c["MAILBOX"]
  CONTEXT  = c["CONTEXT"]

  tasks = []
  imap = Net::IMAP.new(HOST, 993, true)
  imap.login(USER, PASSWORD)
  imap.select(MAILBOX)
  imap.fetch(1..(imap.responses["EXISTS"][0].to_i), "BODY[HEADER.FIELDS (SUBJECT)]").each do |msg|
    tasks << msg.attr["BODY[HEADER.FIELDS (SUBJECT)]"].sub(/Subject: /,"").strip!
  end

  imap.logout
  imap.disconnect

  omni_data = get_tasks_from_omnifocus

  synced, skipped = add_tasks_to_omnifocus(tasks, omni_data, CONTEXT)

  puts "** Synced #{synced} issues from #{HOST} to OmniFocus, Skipped #{skipped}"


end

