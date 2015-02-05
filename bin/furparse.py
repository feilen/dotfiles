#!/usr/bin/python

## Outdated furaffinity parser script. Needs some work.

from html.parser import HTMLParser
from gi.repository import Notify, GdkPixbuf, Gio
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import Header
import urllib.request
import os
import smtplib

# Handles collection of images from online
class AvatarGet:
    avatars = {}
    
    def collect_avie(self, username):
        try:
            urlresponse = urllib.request.urlopen("http://a.facdn.net/" + username + ".gif")
            memstream = Gio.MemoryInputStream.new_from_data(urlresponse.read())
            image = GdkPixbuf.Pixbuf.new_from_stream(memstream)
            self.avatars[username] = image
        except urllib.error.HTTPError:
            self.avatars[username] = GdkPixbuf.Pixbuf.new_from_file("${HOME}/.local/share/pawprint.png")    

    def get_avie(self, username):
        if username in self.avatars:
            return self.avatars[username]
        else:
            self.collect_avie(username)

# Handy journal structure
class Journal:
    def __init__(self, newname, newvalue, newuser):
        self.name = newname
        self.value = newvalue
        self.user = newuser

# Build our Journal Page parser
class JournalParser(HTMLParser):
    list = []

    inMessages = False
    inAJournal = False
    inAUserName = False
    inAMessage = False

    curName = ""
    curJournal = ""
    curUser = ""
    def handle_starttag(self, tag, attrs):
        # First check if we're in the body where the journals are
        if tag == "fieldset" and len(attrs) > 0:
            if attrs[0][1] == "messages-journals":
                self.inMessages = True
        # If we're in the messages chunk, start making a journals out of it
        if self.inMessages:
            if tag == "li" and len(attrs) == 0:
                self.inAMessage = True
            if self.inAMessage:
                if tag == "a":
                    if "/journal/" in attrs[0][1]:
                        self.inAJournal = True
                        self.curJournal = attrs[0][1].split('/')[2]
                    if "/user/" in attrs[0][1]:
                        self.inAUserName = True
                        self.curUserName = attrs[0][1].split('/')[2]
    def handle_data(self,data):
        if self.inAJournal:
            self.curName = data
    def handle_endtag(self,tag):
        if tag == "ul":
            self.inMessages = False
        if tag == "a":
            self.inAJournal = False
            self.inAUsername = False
        if tag == "li":
            if self.inAMessage:
                self.list.append(Journal(self.curName,self.curJournal,self.curUserName))
            self.inAMessage = False

# Get the page using our cookies and parse it to get our list
opener = urllib.request.build_opener()
for header in (("Host", "www.furaffinity.net"),
               ("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:28.0) Gecko/20100101 Firefox/28.0"),
               ("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"),
               ("Accept-Language", "en-US,en;q=0.5"),
               ("DNT", "1"),
               ("Content-Type", "application/x-www-form-urlencoded"),
               ("Cookie", "b=COOKIE1; a=COOKIE2")):
    opener.addheaders.append(header)
parser = JournalParser()
infile = opener.open('http://www.furaffinity.net/msg/others/')
parser.feed(infile.read().decode('utf-8'))

# Filter out the newest journals, notify if new, email if containing 'free'
print("New journals:")
oldjournals = []
mailjournals = []
newjournals = []

try:
    journalfile = open("${HOME}/.cache/furaffinityJournals", "r")
    oldjournals = journalfile.read().split("\n")
except FileNotFoundError:
    print("No cache found, assuming no journals")
newjournals = [journal for journal in parser.list if not journal.value in oldjournals]



icons = AvatarGet()
Notify.init("FurAffinity Notifier")
# First iterate to collect the icons
for journal in newjournals:
    icons.collect_avie(journal.user)

# Then display notifications and send emails
for journal in newjournals:
    message = Notify.Notification.new(journal.user + " <FurAffinity Notifier>", journal.name)
    message.set_image_from_pixbuf(icons.get_avie(journal.user))
    message.show()
    if any( key in journal.name.upper() for key in ['PUT', 'TAGS', 'HERE'] if not 'CLOSED' in journal.name.upper()):
        mailjournals.append(journal)
    
# Anything to write about? Set up SMTP        
if len(mailjournals) > 0:
    SendRcv = "user@example.com"
    SMTP_SERVER = 'server.example.com'
    SMTP_PORT = 587

    session = smtplib.SMTP(SMTP_SERVER,SMTP_PORT)
    session.ehlo()
    session.starttls()
    session.ehlo()
    session.login(SendRcv, "PasswordHere")
    
    for journal in mailjournals:
        message = MIMEMultipart('alternative')
        message.set_charset('utf8')
        message['FROM'] = "\"FurAffinity Notifier\""
        message['TO'] = SendRcv
        message['Subject'] = Header( journal.user + u": " + journal.name, "utf-8" )
        body = u'<a href="http://www.furaffinity.net/journal/' + journal.value + u'">' + journal.name + u'</a>'
        message.attach(
            MIMEText(
                body.encode('utf-8'),
                'html', 
                'UTF-8'
            )
        )
        
        session.sendmail(SendRcv, SendRcv, message.as_string())

    session.quit()

# At the end, write out currently listed journals.
journalfile = open("${HOME}/.cache/furaffinityJournals", "w+")
for journal in parser.list:
    journalfile.write(journal.value + "\n")
