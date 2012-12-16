#!/usr/bin/env python
import sys
import gntp
import json
import redis
import gntp.notifier
import netrc

hosts = netrc.netrc().hosts

auth = filter(lambda x: (x[1][1] == "etsyircredis"), hosts.items())[0]

host, port = auth[0].split(":")
password = auth[1][2]

r = redis.StrictRedis(host=host,
                      port=int(port), db=0,
                      password=password )
app = "irc-growl"

while 1:
    key, logline = r.blpop("notifications")
    try:
        log = json.loads(logline)
    except Exception as e:
        title = "Failure loading logline: " + str(logline)
        message = "error({0})".format(e)
        gntp.notifier.mini(message, applicationName=app, title=title)
        continue

    try:
        channel = "-".join(log["@source"].split("/")[-1].split("_")[1:-1])
    except Exception as e:
        title = "Failure parsing channel name in: " + str(log["@source"])
        message = "error({0})".format(e)
        gntp.notifier.mini(message, applicationName=app, title=title)
        continue

    try:
        title = ("%s in %s" % (log["@fields"]["ircsender"][0], channel.encode("utf-8")))
    except Exception as e:
        title = "Failure parsing ircsender in: " + str(log)
        message = "error({0})".format(e)
        print title
        print message
        gntp.notifier.mini(message, applicationName=app, title=title)
        continue

    message = (log["@fields"]["ircmessage"][0]).encode("utf-8")
    gntp.notifier.mini(message, applicationName=app, title=title)
