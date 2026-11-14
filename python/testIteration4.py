# Tests iteration 4 (docs/08-iteration-4.md): the admin API for content:
# reference tables, the challenge library with flags, hints and links,
# events, challenges in an event and prerequisites.
#
# python testIteration4.py [--target <name>] <userid>
#   <userid> is an active player of event 1. Its passphrase is prompted.
#   Everything else runs as admin, with the target's admin sign-in. No RACF
#   userids are made.
#
# The host and the admin sign-in come from runtimeTargets.yaml (testTarget.py),
# without --target its default target.
#
# Each run leaves one closed test event behind, "Test Event <stamp>", with
# one library challenge in it, because it has a place and a solve. The
# rest is deleted again. The event is only closed if the player has a
# place in another event that hasn't ended, so closing doesn't revoke them.
import json
import sys

from datetime import datetime, timedelta
from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import adminToken, useTarget

useTarget()

# From DDL/SEEDDATA.sql
existingCategory = "ZOS"

passphrases = {}
adminBearer = None

def step(text):
    print(f"\n=== {text}")

def text(value):
    # LWW returns an empty text field as null
    return (value or '').strip()

def check(condition, description):
    if not condition:
        raise Exception(f'check failed: {description}')

    print(f"OK: {description}")

def signIn(userid):
    # The token goes on the session only. With Globals.myBearer set, MyRequests
    # would ask for a new token after every 4xx, and this test expects some.
    Globals.s.headers.pop('Authorization', None)
    Globals.myCreds = (userid, passphrases[userid])
    MyRequests.getBearerToken(f"{Globals.pathPrefix}/token")
    Globals.myCreds = None
    Globals.s.headers['Authorization'] = f"Bearer {Globals.myBearer}"
    Globals.myBearer = ""
    Globals.signedIn = userid
    print(f"Signed in as {userid}")

def asAdmin():
    # The target's admin sign-in (testTarget.adminToken)
    global adminBearer
    Globals.s.headers.pop('Authorization', None)

    if adminBearer is None:
        adminBearer = adminToken()

    Globals.s.headers['Authorization'] = f"Bearer {adminBearer}"
    Globals.signedIn = None
    print("Signed in as admin")

def call(method, uri, data=None, okCodes=(200,)):
    for attempt in range(0, 2):
        resp = getattr(MyRequests, method)(f"{Globals.pathPrefix}{uri}", data)

        print(f"{method.upper()} {uri}: {resp.status_code} {resp.text}")

        if (resp.status_code != 401 or Globals.signedIn is None or attempt > 0):
            break

        print("Signing in again")
        signIn(Globals.signedIn)

    if (resp.status_code not in okCodes):
        raise Exception(f'status code {str(resp.status_code)} {resp.text}')

    return json.loads(resp.text) if resp.text else {}

def refused(method, uri, data, status, reason):
    # A call that must be refused with this HTTP status and reason code
    answer = call(method, uri, data, (status,))
    check(text(answer.get('reasonCode')) == reason,
          f"{method.upper()} {uri} refused with {status}, reason {reason}")

def ts(delta):
    # A DB2 timestamp, now plus delta. The hours of margin around "now" in
    # this test cover a difference between this clock and the mainframe's.
    return f"{datetime.now() + delta:%Y-%m-%d-%H.%M.%S}.000000"

def eventBody(name, regCode):
    data = {}
    data['eventName'] = name
    data['eventDescription'] = "Made by testIteration4.py"
    data['eventStatus'] = "D"
    data['playMode'] = "I"
    data['maxTeamSize'] = 1
    data['startTS'] = ts(timedelta(days=-1))
    data['endTS'] = ts(timedelta(days=1))
    data['freezeTS'] = ""
    data['regCode'] = regCode
    data['regFromTS'] = ts(timedelta(days=-1))
    data['regToTS'] = ts(timedelta(days=1))
    data['maxPlayers'] = 10
    data['racfGroup'] = ""
    return data

# LWW refuses a request without a field its mapping needs, unless the mapping
# marks it required: false. The bodies below send all fields, "" or 0 for empty;
# B1 leaves out optional ones once.
def challengeBody(title, category, description="Find the flag. Made by testIteration4.py"):
    data = {}
    data['challengeTitle'] = title
    data['category'] = category
    data['challengeDescription'] = description
    data['challengeType'] = "S"
    data['verifierPgm'] = ""
    return data

def newChallenge(title, category):
    data = challengeBody(title, category)
    return call("post", "/admin/challenges", data, (201,))['challengeID']

def eventChallenge(eventID, challengeID, visible):
    data = {}
    data['eventID'] = eventID
    data['challengeID'] = challengeID
    data['scoreType'] = "S"
    data['initPoints'] = 100
    data['isVisible'] = visible
    data['sortOrder'] = 1
    data['minPoints'] = 0
    data['decaySolves'] = 0
    data['maxAttempts'] = 0
    return data

def refTablePart(category):
    step("A1. Reference tables: a test category, a duplicate, the settings")
    asAdmin()
    data = {}
    data['tableID'] = "category"
    data['tabKey'] = category.lower()
    data['tabValue'] = "Test category"
    answer = call("post", "/admin/refTables", data, (201,))
    check(text(answer['tableID']) == "CATEGORY" and text(answer['tabKey']) == category,
          "table ID and key are upper case")
    refused("post", "/admin/refTables", data, 409, '11')

    refused("delete", "/admin/refTables/SETTINGS?tabKey=JOBMINS", None, 409, '53')
    refused("put", "/admin/refTables/SETTINGS?tabKey=JOBMINS", {'tabValue': 'sixty'}, 400, '03')
    # Text settings can be changed too, within the length CTFM910 reads
    # (2026-11-11); saved unchanged here, so the jobs keep working
    settings = call("get", "/admin/refTables?tableID_filter=SETTINGS")['refTables']
    jobClass = next(text(e['tabValue']) for e in settings if text(e['tabKey']) == "JOBCLASS")
    answer = call("put", "/admin/refTables/SETTINGS?tabKey=JOBCLASS", {'tabValue': jobClass})
    check(text(answer['tabValue']) == jobClass, "a text setting saved unchanged")
    refused("put", "/admin/refTables/SETTINGS?tabKey=JOBCLASS", {'tabValue': "AB"}, 400, '02')
    refused("put", "/admin/refTables/SETTINGS?tabKey=JOBCLASS", {'tabValue': ""}, 400, '02')

    entries = call("get", "/admin/refTables?tableID_filter=CATEGORY")['refTables']
    check(any(text(e['tabKey']) == category for e in entries), "the list has the test category")

def libraryPart(stamp, category):
    step("B1. The library: a challenge with two flags, two hints and a link")
    # Without the optional challengeType and verifierPgm
    bad = {'challengeTitle': "Bad", 'category': "NOSUCH", 'challengeDescription': "x"}
    refused("post", "/admin/challenges", bad, 400, '06')

    challengeID = newChallenge(f"Test challenge {stamp}", existingCategory)
    flags = []

    for value, case in ((f"flag{{test-{stamp}}}", "N"), (f"Second-{stamp}", "Y")):
        data = {'challengeID': challengeID, 'flagValue': value, 'caseSensitive': case}
        flags.append(call("post", "/admin/flags", data, (201,))['flagID'])

    for order, cost in ((1, 10), (2, 25)):
        data = {'challengeID': challengeID, 'sortOrder': order,
                'hintText': f"Hint {order}", 'cost': cost}
        call("post", "/admin/hints", data, (201,))

    data = {'challengeID': challengeID, 'linkName': "Example",
            'linkUrl': "https://example.com/file.txt"}
    linkID = call("post", "/admin/links", data, (201,))['linkID']
    refused("post", "/admin/flags", {'challengeID': 999999999, 'flagValue': "x",
                                     'caseSensitive': "N"}, 404, '13')

    step("B2. Read, list and update")
    challenge = call("get", f"/admin/challenges/{challengeID}")
    check(text(challenge['category']) == existingCategory, "get the challenge")
    data = challengeBody(f"Test challenge {stamp} updated", existingCategory,
                         text(challenge['challengeDescription']))
    check(text(call("put", f"/admin/challenges/{challengeID}", data)['challengeTitle']).endswith("updated"),
          "the title is updated")
    check(len(call("get", f"/admin/flags?challengeID={challengeID}")['flags']) == 2, "two flags")
    check(len(call("get", f"/admin/hints?challengeID={challengeID}")['hints']) == 2, "two hints")
    check(len(call("get", f"/admin/links?challengeID={challengeID}")['links']) == 1, "one link")
    data = {'linkName': "Example, renamed", 'linkUrl': "https://example.com/file.txt"}
    check(text(call("put", f"/admin/links/{linkID}", data)['linkName']) == "Example, renamed",
          "the link is updated")
    refused("get", "/admin/challenges/999999999", None, 404, '01')

    step("B3. A second challenge, without flags, in the test category")
    secondID = newChallenge(f"Test challenge {stamp} second", category)
    found = call("get", f"/admin/challenges?category_filter={category}")['challenges']
    check([c['challengeID'] for c in found] == [secondID], "listed by category")
    refused("delete", f"/admin/refTables/CATEGORY?tabKey={category}", None, 409, '53')

    return challengeID, secondID, flags

def eventPart(stamp, challengeID, secondID):
    step("C1. An event: invalid dates refused, then a DRAFT")
    data = eventBody(f"Test Event {stamp}", f"TEST-{stamp}")
    data['endTS'] = ts(timedelta(days=-2))
    refused("post", "/admin/events", data, 400, '05')
    data['endTS'] = ts(timedelta(days=1))
    data['eventStatus'] = "P"
    refused("post", "/admin/events", data, 400, '03')
    data['eventStatus'] = "D"
    event = call("post", "/admin/events", data, (201,))
    eventID = event['eventID']
    check(text(event['eventStatus']) == "D" and event['playerCount'] == 0, "a new DRAFT")

    data['eventStatus'] = "P"
    refused("put", f"/admin/events/{eventID}", data, 409, '53')

    step("C2. Composing: visible needs a flag, scoring, prerequisites")
    call("post", "/admin/eventChallenges", eventChallenge(eventID, challengeID, "Y"), (201,))
    refused("post", "/admin/eventChallenges", eventChallenge(eventID, challengeID, "Y"), 409, '11')
    refused("post", "/admin/eventChallenges", eventChallenge(eventID, secondID, "Y"), 409, '53')
    call("post", "/admin/eventChallenges", eventChallenge(eventID, secondID, "N"), (201,))

    bad = eventChallenge(eventID, secondID, "N")
    bad.update({'scoreType': "D", 'minPoints': 200, 'decaySolves': 5})
    refused("put", f"/admin/eventChallenges/{secondID}?eventID={eventID}", bad, 400, '04')
    good = eventChallenge(eventID, secondID, "N")
    good.update({'scoreType': "D", 'minPoints': 50, 'decaySolves': 5})
    answer = call("put", f"/admin/eventChallenges/{secondID}?eventID={eventID}", good)
    check(answer['minPoints'] == 50 and text(answer['scoreType']) == "D", "dynamic scoring")

    prereq = {'eventID': eventID, 'challengeID': secondID, 'reqChallengeID': challengeID}
    call("post", "/admin/prerequisites", prereq, (201,))
    refused("post", "/admin/prerequisites",
            {'eventID': eventID, 'challengeID': challengeID, 'reqChallengeID': challengeID}, 400, '03')
    refused("post", "/admin/prerequisites",
            {'eventID': eventID, 'challengeID': challengeID, 'reqChallengeID': secondID}, 409, '53')
    check(len(call("get", f"/admin/prerequisites?eventID={eventID}")['prerequisites']) == 1,
          "one prerequisite")
    check(len(call("get", f"/admin/eventChallenges?eventID={eventID}")['eventChallenges']) == 2,
          "two challenges in the event")

    step("C3. Publish")
    event = call("put", f"/admin/events/{eventID}", data)
    check(text(event['eventStatus']) == "P" and text(event['phase']) == "R", "published and running")

    return eventID, data

def playPart(userid, eventID, regCode, challengeID, stamp):
    step("D1. The player joins and solves, with the flag in upper case")
    signIn(userid)
    answer = call("post", "/participants", {'eventID': eventID, 'regCode': regCode}, (201,))
    check(text(answer['partStatus']) == "A", "no RACF group, so the place is active at once")
    board = call("get", f"/challenges?eventID={eventID}")['challenges']
    check([c['challengeID'] for c in board] == [challengeID], "the board shows the visible challenge only")
    data = {'eventID': eventID, 'challengeID': challengeID, 'flag': f"FLAG{{TEST-{stamp}}}"}
    check(text(call("post", "/submissions", data, (201,))['isCorrect']) == "Y",
          "a flag that isn't case sensitive is correct in upper case")

    # Is there another event the player stays in? Then closing can't revoke them.
    others = [e for e in call("get", "/myEvents")['events']
              if e['eventID'] != eventID and text(e.get('phase')) in ('U', 'R', 'F')]
    return len(others) > 0

def lockPart(eventID, eventData, challengeID, secondID, flags):
    step("E1. Locks once a player has joined and solved")
    asAdmin()
    data = dict(eventData, playMode="T", maxTeamSize=2)
    refused("put", f"/admin/events/{eventID}", data, 409, '53')
    data = dict(eventData, eventStatus="D")
    refused("put", f"/admin/events/{eventID}", data, 409, '53')
    refused("delete", f"/admin/eventChallenges/{challengeID}?eventID={eventID}", None, 409, '53')
    refused("delete", f"/admin/events/{eventID}", None, 409, '53')
    refused("delete", f"/admin/challenges/{challengeID}", None, 409, '53')

    call("delete", f"/admin/flags/{flags[1]}")
    refused("delete", f"/admin/flags/{flags[0]}", None, 409, '53')

    hints = call("get", f"/admin/hints?challengeID={challengeID}")['hints']
    call("delete", f"/admin/hints/{hints[-1]['hintID']}")

def cleanupPart(stamp, category, eventID, eventData, secondID, canClose):
    step("F1. A DRAFT is deleted with its challenges")
    data = eventBody(f"Test Draft {stamp}", f"DRAFT-{stamp}")
    draftID = call("post", "/admin/events", data, (201,))['eventID']
    call("post", "/admin/eventChallenges", eventChallenge(draftID, secondID, "N"), (201,))
    call("delete", f"/admin/events/{draftID}")
    refused("get", f"/admin/events/{draftID}", None, 404, '01')

    step("F2. The second challenge: out of the event, its prerequisite too, then deleted")
    call("delete", f"/admin/eventChallenges/{secondID}?eventID={eventID}")
    check(len(call("get", f"/admin/prerequisites?eventID={eventID}")['prerequisites']) == 0,
          "the prerequisite went with it")
    call("delete", f"/admin/challenges/{secondID}")
    refused("get", f"/admin/challenges/{secondID}", None, 404, '01')
    call("delete", f"/admin/refTables/CATEGORY?tabKey={category}")

    step("F3. Close the test event")
    if not canClose:
        print(f"SKIPPED: the player has no place in another event that hasn't ended, so closing "
              f"would revoke them. Test Event {stamp} stays published.")
        return

    data = dict(eventData, endTS=ts(timedelta(hours=-3)))
    call("put", f"/admin/events/{eventID}", data)
    call("post", f"/admin/eventClosures/{eventID}")
    check(text(call("get", f"/admin/events/{eventID}")['eventStatus']) == "C", "the event is closed")
    refused("put", f"/admin/events/{eventID}", data, 409, '53')

def doStuff():
    Globals.signedIn = None

    if (len(sys.argv) != 2):
        raise Exception('usage: python testIteration4.py <userid of an event 1 player>')

    userid = sys.argv[1].upper()
    passphrases[userid] = getpass(f"Passphrase of {userid}: ")
    stamp = f"{datetime.now():%y%m%d%H%M%S}"
    category = f"T{stamp[-7:]}"

    refTablePart(category)
    challengeID, secondID, flags = libraryPart(stamp, category)
    eventID, eventData = eventPart(stamp, challengeID, secondID)
    canClose = playPart(userid, eventID, eventData['regCode'], challengeID, stamp)
    lockPart(eventID, eventData, challengeID, secondID, flags)
    cleanupPart(stamp, category, eventID, eventData, secondID, canClose)

    print("\nDone.")

doStuff()
