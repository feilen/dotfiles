#!/usr/bin/env python3
import requests
import time
from bs4 import BeautifulSoup

day = "02-01-2020"
last_day_string = "03-01-2020"
page = requests.get("https://www.sfstation.com/calendar/{}".format(day))
soup = BeautifulSoup(page.content)

events_seen = set()

last_day = False
# loop through every day until the next month
while not last_day:
    print(day)
    last_page = False
    while not last_page:
        events = soup.find_all('div', {'class': 'ev_in ev_mobile_c'})
        todays_events = set()
        for event in events:
            title = event.find('span', {'itemprop': 'name'}).get_text()
            location = event.find('span', {'itemprop': 'location'}).find('span', {'itemprop': 'name'}).get_text()
            address = event.find('span', {'itemprop': 'streetAddress'}).get_text()
            url = event.find('span', {'itemprop': 'url'}).get_text()

            todays_events.add("{} {} @ {} ({}) {}".format(('-' if title not in events_seen else '+'), title, location, address, url))

            events_seen.add(title)

        for event in sorted(todays_events):
            print(event)

        if soup.find('a', {'rel': 'next'}) is not None:
            time.sleep(5)
            next_page = 'https://www.sfstation.com/' + soup.find('a', {'rel': 'next'})['href']
            page = requests.get(next_page)
            soup = BeautifulSoup(page.content)
        else:
            last_page = True

    next_day = soup.find('a', text='next day >')
    if next_day['href'][-10:] != last_day_string:
        time.sleep(5)
        day = next_day['href'][-10:]
        next_page = 'https://www.sfstation.com' + next_day['href']
        page = requests.get(next_page)
        soup = BeautifulSoup(page.content)
    else:
        last_day = True

