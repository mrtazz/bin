#!/usr/bin/env python
"""
    small script to check for unread count on imap inbox, the printed output
    format is especially useful for the tmux status bar
"""
import imaplib
import sys
import netrc

accounts = ("mail", "etsymail")
results = []
hosts = netrc.netrc().hosts

for account in accounts:

    # I'm using the netrc account property as aliases, so this
    # gives me the auth info for a specific alias. Return format is
    # [('host', ('login', 'account', 'password'))]
    auth = filter(lambda x: (x[1][1] == account), hosts.items())[0]
    try:
        mail = imaplib.IMAP4_SSL(auth[0])
        mail.login(auth[1][0], auth[1][2])
        code, mails = mail.select("inbox", True) # connect to inbox.
        count = str(mails[0])
        # to read count
        code, mails = mail.select("gtd-to-read", True) # connect to inbox.
        count += "|{0}".format(str(mails[0]))
        # needs reply count
        code, mails = mail.select("gtd-needs-reply", True) # connect to inbox.
        count += "|{0}".format(str(mails[0]))
    except:
        count = "0|0|0"

    results.append(count)

# make it nice
print "M:({0})|E:({1})".format(*results)
