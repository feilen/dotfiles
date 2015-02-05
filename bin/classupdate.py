#!/usr/bin/python

from html.parser import HTMLParser
import urllib.request
import os
import smtplib
import time

# Handy section structure
class Section:
    justOpened = False
    def __init__(self, newClassName, newClassReason, newClassStatus):
        self.className = newClassName
        self.classReason = newClassReason
        self.classStatus = newClassStatus

# List of sections we want to take, and reasons why
desiredSections = {"ex1234.567.89s": "Example Section"}

# Formulate an array of Sections, assuming the status to be UNKNOWN
classSections = [ Section(name, reason, "UNKNOWN") for name, reason in desiredSections.items() ]

# Update them as to the status of the classes from our journal file
# File sturcture:
# course.section.semester status
# course2.section.semester status

try:
    sectionfile = open("/home/feilen/.courses", "r")
    sectionrecord = sectionfile.read().split("\n")
    for section in classSections:
        for record in sectionrecord:
            if section.className == record.split(" ")[0]:
                section.classStatus = record.split(" ")[1]
    sectionfile.close()
except:
    print("Couldn't find old course file")

# Build our Class Page parser
class ClassParser(HTMLParser):
    inStatus = False
    oldClassStatus = ""
    classStatus = ""
    justOpened = False
    foundStatus = False

    #If we've just encountered "Section Status:", we can check the status.
    def handle_data(self,data):
        if self.inStatus:
            print(data)
            if "Closed" in data:
                print(data)
                self.classStatus = "CLOSED"
                self.foundStatus = True
            if "Open" in data:
                print(data)
                if self.oldClassStatus != "OPEN":
                    self.justOpened = True
                self.classStatus = "OPEN"
                self.foundStatus = True
            self.inStatus = False
        if data == "15S":
            self.inStatus = True

# Get the page using our cookies and parse it to get our list
newClass = []

for section in classSections:
    parser = ClassParser()
    parser.oldClassStatus = section.classStatus
    opener = urllib.request.build_opener()
    infile = opener.open('http://go.utdallas.edu/' + section.className )
    parser.feed(infile.read().decode('utf-8'))
    if parser.classStatus != "":
        section.classStatus = parser.classStatus
        section.justOpened = parser.justOpened
    print(section.className + " " + section.classStatus)
    if section.justOpened:
        newClass.append(section)
    if not parser.foundStatus:
        newClass.append(section)
    time.sleep(5)

# Anything to write about? Set up SMTP        
if len(newClass) > 0:
    SendRcv = "email@example.com"
    SMTP_SERVER = 'server.example.com'
    SMTP_PORT = 587

    session = smtplib.SMTP(SMTP_SERVER,SMTP_PORT)
    session.ehlo()
    session.starttls()
    session.ehlo()
    session.login(SendRcv, "PasswordHere")

    for section in newClass:
        headers = ["From: " + SendRcv,
                   "To: " + SendRcv,
                   "Subject: " + "Class " + section.className + " has opened!",
                   "MIME-Version: 1.0",
                   "Content-Type: text/html"]
        headers = "\r\n".join(headers)
        body = '<a href="http://coursebook.utdallas.edu/' + section.className + '">' + section.className + ' on CourseBook</a>'
        body += "\n You need this class because: " + section.classReason
        session.sendmail(SendRcv, SendRcv, headers + "\r\n\r\n" + body)

    session.quit()    

# At the end, write out current class statuses.
sectionfile = open("${HOME}/.courses", "w+")
for section in classSections:
    sectionfile.write(section.className + " " + section.classStatus + "\n")
sectionfile.close()
