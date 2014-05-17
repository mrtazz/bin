#!/usr/bin/env python

import sys
import os
import getopt
import email.parser

def usage():
    print """
    Take an RFC-compliant e-mail message on STDIN and add a
    corresponding task to the OmniFocus inbox for it.

    Options:
        -h, --help
            Display this help text.

        -q, --quick-entry
            Use the quick entry panel instead of directly creating a task.

        -c, --context=context
            Use the provided context for the task
    """

def applescript_escape(string):
    """Applescript requires backslashes and double quotes to be escaped in
    string.  This returns the escaped string.
    """
    # Backslashes first (else you end up escaping your escapes)
    string = string.replace('\\', '\\\\')

    # Then double quotes
    string = string.replace('"', '\\"')

    return string

def parse_message(raw):
    """Parse a string containing an e-mail and produce a list containing the
    significant headers.  Each element is a tuple containing the name and
    content of the header (list of tuples rather than dictionary to preserve
    order).
    """

    # Create a Message object
    message = email.parser.Parser().parsestr(raw, headersonly=True)
    if message.is_multipart():
        body = message.get_payload(decode=True)[0]
    else:
        body = message.get_payload(decode=True)

    return {"From": message.get("From"),
            "Subject": message.get("Subject"),
            "Body": body}

def send_to_omnifocus(params, quickentry=False, context="Email"):
    """Take the list of significant headers and create an OmniFocus inbox item
    from these.
    """

    # name and note of the task (escaped as per applescript_escape())
    name = "%s" % applescript_escape(dict(params)["Subject"])
    f = applescript_escape(dict(params)["From"])
    b = applescript_escape(dict(params)["Body"])
    note = "%s\n%s" % (f, b)

    # Write the Applescript
    if quickentry:
        applescript = """
            tell application "OmniFocus"
                set theContext to context "%s" of default document
                tell default document
                    tell quick entry
                        open
                        make new inbox task with properties {name: "%s", note:"%s", context:theContext}
                        select tree 1
                        set note expanded of tree 1 to true
                    end tell
                end tell
            end tell
        """ % (context, name, note)
    else:
        applescript = """
            on FindContext(strContext)
                tell application "OmniFocus"
                    tell first document
                        set oContextList to complete strContext as context maximum matches 1
                        if (oContextList is {}) then
                        else
                            return context id (id of item 1 of oContextList)
                        end if
                    end tell
                end tell
            end FindContext

            tell application "OmniFocus"
                set theContext to my FindContext("%s")
                tell default document
                    make new inbox task with properties {name: "%s", note:"%s", context:theContext}
                end tell
            end tell
        """ % (context, name, note)

    # Use osascript and a heredoc to run this Applescript
    os.system("\n".join(["osascript << EOT", applescript, "EOT"]))

def main():
    # Check for options
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hqc",
                ["help", "quick-entry", "context="])
    except getopt.GetoptError, e:
        print e
        usage()
        sys.exit(-1)

    # If an option was specified, do the right thing
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit(0)
        elif opt in ("-q", "--quick-entry"):
            raw = sys.stdin.read()
            send_to_omnifocus(parse_message(raw), quickentry=True)
            sys.exit(0)
        elif opt in ("-c", "--context"):
            raw = sys.stdin.read()
            send_to_omnifocus(parse_message(raw), quickentry=False, context=arg)
            sys.exit(0)

    # Otherwise fall back to standard operation
    raw = sys.stdin.read()
    send_to_omnifocus(parse_message(raw), quickentry=False)
    sys.exit(0)

if __name__ == "__main__":
    main()
