# Tests iteration 6 (docs/10-iteration-6.md): archiving a closed event and
# restoring it, and how an archived event shows in the lists.
#
# python testIteration6.py [--target <name>] [<eventID>]
#   <eventID> is a CLOSED event to archive and restore. Without it, the
#   first closed event of GET /admin/events?eventStatus_filter=C is used.
#   Everything runs as admin, with the target's admin sign-in, or without
#   a sign-in for the public paths. No RACF userids are made.
#
# The host and the admin sign-in come from runtimeTargets.yaml (testTarget.py),
# without --target its default target.
#
# The event ends as it started: CLOSED. Nothing else is left behind.
import json
import sys

from Globals import Globals
from MyRequests import MyRequests
from testTarget import adminToken, useTarget

useTarget()

# From DDL/SEEDDATA.sql: a published event
seedEventID = 1

adminBearer = None

# The fields PUT /admin/events takes
EVENT_FIELDS = ['eventName', 'eventDescription', 'eventStatus', 'playMode', 'maxTeamSize', 'startTS',
                'endTS', 'freezeTS', 'regCode', 'regFromTS', 'regToTS', 'maxPlayers', 'racfGroup']

def step(text):
    print(f"\n=== {text}")

def text(value):
    # LWW returns an empty text field as null
    return (value or '').strip()

def check(condition, description):
    if not condition:
        raise Exception(f'check failed: {description}')

    print(f"OK: {description}")

def asAdmin():
    # The target's admin sign-in (testTarget.adminToken)
    global adminBearer
    Globals.s.headers.pop('Authorization', None)

    if adminBearer is None:
        adminBearer = adminToken()

    Globals.s.headers['Authorization'] = f"Bearer {adminBearer}"
    Globals.signedIn = None
    print("Signed in as admin")

def signOut():
    Globals.s.headers.pop('Authorization', None)
    Globals.signedIn = None

def call(method, uri, data=None, okCodes=(200,)):
    resp = getattr(MyRequests, method)(f"{Globals.pathPrefix}{uri}", data)

    print(f"{method.upper()} {uri}: {resp.status_code} {resp.text}")

    if (resp.status_code not in okCodes):
        raise Exception(f'status code {str(resp.status_code)} {resp.text}')

    return json.loads(resp.text) if resp.text else {}

def refused(method, uri, data, status, reason):
    # A call that must be refused with this HTTP status and reason code
    answer = call(method, uri, data, (status,))
    check(text(answer.get('reasonCode')) == reason,
          f"{method.upper()} {uri} refused with {status}, reason {reason}")

def allEvents(uri):
    # Every page of an event list. /events goes newest first, so its paging
    # continues below the last ID; /admin/events goes up from it.
    ids = []
    since = None
    while True:
        sep = '&' if '?' in uri else '?'
        page = call("get", f"{uri}{sep}eventID_since={since}" if since else uri).get('events') or []
        ids += [e['eventID'] for e in page]
        statuses = {text(e['eventStatus']) for e in page}
        if len(page) < 20:
            return ids, statuses
        since = page[-1]['eventID']

def findClosed():
    if len(sys.argv) == 2:
        return int(sys.argv[1])

    ids, _ = allEvents("/admin/events?eventStatus_filter=C")
    if not ids:
        raise Exception('no CLOSED event: close one first (testIteration3.py), or pass an eventID')
    return ids[0]

def archivePart(eventID):
    step("A1. Archive the closed event")
    event = call("get", f"/admin/events/{eventID}")
    check(text(event['eventStatus']) == 'C', f"event {eventID} is closed")
    answer = call("post", f"/admin/eventArchives/{eventID}")
    check(answer['eventID'] == eventID and text(answer['eventStatus']) == 'A', "archived")
    refused("post", f"/admin/eventArchives/{eventID}", None, 409, '53')
    refused("post", f"/admin/eventArchives/{seedEventID}", None, 409, '53')
    refused("post", "/admin/eventArchives/999999999", None, 404, '01')
    refused("delete", f"/admin/eventArchives/{seedEventID}", None, 409, '53')
    return event

def readOnlyPart(eventID, event):
    step("A2. An archived event can't change")
    data = {f: event.get(f) or '' for f in EVENT_FIELDS}
    refused("put", f"/admin/events/{eventID}", dict(data, eventStatus='P'), 409, '53')
    refused("put", f"/admin/events/{eventID}", dict(data, eventStatus='A'), 409, '53')
    refused("delete", f"/admin/events/{eventID}", None, 409, '53')
    data = {'eventID': eventID, 'announceTitle': "Too late", 'announceBody': "Archived"}
    refused("post", "/admin/announcements", data, 409, '53')
    refused("post", f"/admin/eventClosures/{eventID}", None, 409, '53')

def listPart(eventID):
    step("A3. Lists: archived only when asked for; still readable")
    ids, statuses = allEvents("/admin/events")
    check(eventID not in ids and 'A' not in statuses, "admin list without filter: no archived events")
    ids, statuses = allEvents("/admin/events?eventStatus_filter=A")
    check(eventID in ids and statuses == {'A'}, "admin list, filter A: archived events only")

    signOut()
    ids, statuses = allEvents("/events")
    check(eventID not in ids and statuses <= {'P', 'C'}, "public list: published and closed only")
    ids, statuses = allEvents("/events?eventStatus_filter=A")
    check(eventID in ids and statuses == {'A'}, "public list, filter A: archived events only")
    ids, _ = allEvents("/events?eventStatus_filter=D")
    check(ids == [], "public list, filter D: never drafts")
    answer = call("get", f"/events/{eventID}")
    check(text(answer['eventStatus']) == 'A', "public: the event itself")
    call("get", f"/leaderboard/{eventID}")
    print("OK: public: its leaderboard")
    asAdmin()

def restorePart(eventID):
    step("A4. Restore it to closed")
    answer = call("delete", f"/admin/eventArchives/{eventID}")
    check(answer['eventID'] == eventID and text(answer['eventStatus']) == 'C', "closed again")
    refused("delete", f"/admin/eventArchives/{eventID}", None, 409, '53')
    ids, _ = allEvents("/admin/events")
    check(eventID in ids, "back in the admin list without filter")

def doStuff():
    Globals.signedIn = None

    if (len(sys.argv) > 2):
        raise Exception('usage: python testIteration6.py [<eventID of a CLOSED event>]')

    asAdmin()
    eventID = findClosed()
    event = archivePart(eventID)
    try:
        readOnlyPart(eventID, event)
        listPart(eventID)
    finally:
        # Leave the event closed, also when a check failed
        asAdmin()
        if text(call("get", f"/admin/events/{eventID}")['eventStatus']) == 'A':
            restorePart(eventID)

    print("\nDone.")

doStuff()
