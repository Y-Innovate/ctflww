# Tests iteration 2 (docs/06-iteration-2.md): hints, links, prerequisites,
# progress, announcements, own events and teams.
#
# python testIteration2.py [--target <name>] <userid>
#   <userid> is a player of event 1 who solved the first challenge, for
#   example the one testIteration1.py printed. Its passphrase is prompted.
#
# The host comes from runtimeTargets.yaml (testTarget.py),
# without --target its default target.
#
# The team part registers two new players with DEMO-TEAM (DDL/AA000025.sql),
# so every run creates two RACF userids, which nothing cleans up yet.
import json
import sys
import time

from datetime import datetime
from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

# From DDL/SEEDDATA.sql and DDL/AA000025.sql
eventName = "Demo CTF"
teamEventName = "Demo Team CTF"
teamRegCode = "DEMO-TEAM"
firstTitle = "First steps"
secondTitle = "Second steps"

pollSeconds = 5
pollMax = 60

# Passphrase per userid, to sign in again after a 401
passphrases = {}

def step(text):
    print(f"\n=== {text}")

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

def signOut():
    Globals.s.headers.pop('Authorization', None)
    Globals.signedIn = None

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

def text(value):
    # LWW returns an empty text field as null
    return (value or '').strip()

def check(condition, description):
    if not condition:
        raise Exception(f'check failed: {description}')

    print(f"OK: {description}")

def findEvent(name):
    for event in call("get", "/events")['events']:
        if (text(event['eventName']) == name):
            return event['eventID']

    raise Exception(f'event {name} not found')

def findChallenge(challenges, title):
    for challenge in challenges['challenges']:
        if (text(challenge['challengeTitle']) == title):
            return challenge

    raise Exception(f'challenge {title} not found')

def findMyEvent(eventID):
    for event in call("get", "/myEvents")['events']:
        if (event['eventID'] == eventID):
            return event

    raise Exception(f'event {eventID} not in /myEvents')

def registerPlayer(eventID, displayName, passphrase):
    data = {}
    data['eventID'] = eventID
    data['regCode'] = teamRegCode
    data['displayName'] = displayName
    registration = call("post", "/registrations", data, (201,))
    registrationID = registration['registrationID']

    status = 'P'

    for i in range(0, pollMax):
        status = text(call("get", f"/registrations/{registrationID}")['registrationStatus'])

        if (status != 'P'):
            break

        time.sleep(pollSeconds)

    check(status == 'R', f"registration of {displayName} is R, it is {status}")

    data = {}
    data['claimToken'] = registration['claimToken']
    data['passphrase'] = passphrase
    userid = text(call("post", f"/activations/{registrationID}", data, (201,))['racfUserid'])
    passphrases[userid] = passphrase

    return userid

def soloPart(userid):
    step("A1. GET /events, without a token")
    signOut()
    eventID = findEvent(eventName)
    signIn(userid)

    step("A2. GET /myEvents")
    myEvent = findMyEvent(eventID)
    check(text(myEvent['partStatus']) == 'A', "place in event 1 is active")
    check(myEvent['teamID'] != 0, "player has a team of one")

    challenges = call("get", f"/challenges?eventID={eventID}")
    first = findChallenge(challenges, firstTitle)
    second = findChallenge(challenges, secondTitle)
    check(text(first['isSolved']) == 'Y',
          f"{userid} solved {firstTitle}; run testIteration1.py first")

    step("A3. GET /hints: no text for hints not unlocked")
    hints = call("get", f"/hints?eventID={eventID}&challengeID={first['challengeID']}")['hints']
    check(len(hints) >= 2, f"{firstTitle} has hints")

    for hint in hints:
        if (text(hint['isUnlocked']) == 'N'):
            check(text(hint['hintText']) == '', f"hint {hint['hintID']} has no text yet")

    hint = hints[0]
    wasUnlocked = text(hint['isUnlocked']) == 'Y'

    step("A4. GET /progress before the unlock")
    before = call("get", f"/progress/{eventID}")

    step("A5. POST /hintUnlocks twice: charged once")
    data = {}
    data['eventID'] = eventID
    data['hintID'] = hint['hintID']
    unlock = call("post", "/hintUnlocks", data, (201,))
    check(text(unlock['hintText']) != '', "the unlock returns the text")
    again = call("post", "/hintUnlocks", data, (201,))
    check(again['cost'] == unlock['cost'], "the second unlock returns the same cost")

    after = call("get", f"/progress/{eventID}")
    expected = before['score'] if wasUnlocked else before['score'] - unlock['cost']
    check(after['score'] == expected, f"score went from {before['score']} to {expected}")
    expected = before['hintCount'] if wasUnlocked else before['hintCount'] + 1
    check(after['hintCount'] == expected, f"hint count is {expected}")

    step("A6. GET /hints: the unlocked hint has its text")
    hints = call("get", f"/hints?eventID={eventID}&challengeID={first['challengeID']}")['hints']
    check(text(hints[0]['isUnlocked']) == 'Y' and text(hints[0]['hintText']) != '',
          "the unlocked hint is shown")

    step("A7. GET /challengeLinks")
    links = call("get", f"/challengeLinks?eventID={eventID}&challengeID={first['challengeID']}")['links']
    check(len(links) >= 1, f"{firstTitle} has a link")

    step("A8. GET /prerequisites of the second challenge")
    prereqs = call("get", f"/prerequisites?eventID={eventID}&challengeID={second['challengeID']}")['prerequisites']
    check(len(prereqs) == 1 and prereqs[0]['reqChallengeID'] == first['challengeID'],
          f"{secondTitle} requires {firstTitle}")
    check(text(prereqs[0]['isSolved']) == 'Y', "and that one is solved")

    step("A9. GET /progressSolves, /progressAwards")
    solves = call("get", f"/progressSolves?eventID={eventID}")['solves']
    check(any(s['challengeID'] == first['challengeID'] for s in solves),
          f"{firstTitle} is among the solves")
    call("get", f"/progressAwards?eventID={eventID}")

    step("A10. GET /announcements")
    announcements = call("get", f"/announcements?eventID={eventID}")['announcements']
    check(any(text(a['announceTitle']) == 'Welcome' for a in announcements),
          "the Welcome announcement is there")

    step("A11. GET /teamMembers: a team of one")
    members = call("get", f"/teamMembers?eventID={eventID}")['members']
    check(len(members) == 1 and text(members[0]['isCaptain']) == 'Y',
          "one member, the captain")

    step("A12. Team operations in an individual event are refused")
    data = {}
    data['eventID'] = eventID
    data['teamName'] = 'Not allowed'
    refused("post", "/teams", data, 409, '53')

def teamPart():
    passphrase = getpass("Passphrase for the two new players (14 to 100 characters): ")

    if (len(passphrase) < 14 or len(passphrase) > 100):
        raise Exception('passphrase must be 14 to 100 characters')

    stamp = f"{datetime.now():%y%m%d%H%M%S}"

    step("B1. Register two players for the team event")
    signOut()
    eventID = findEvent(teamEventName)
    userA = registerPlayer(eventID, f"Tester A {stamp}", passphrase)
    userB = registerPlayer(eventID, f"Tester B {stamp}", passphrase)

    signIn(userB)
    idB = call("get", "/me")['playerID']
    signIn(userA)
    idA = call("get", "/me")['playerID']

    step("B2. A has no team yet")
    check(findMyEvent(eventID)['teamID'] == 0, "no team in /myEvents")
    refused("get", f"/progress/{eventID}", None, 403, '50')

    step("B3. A creates a team")
    teamName = f"Team {stamp}"
    data = {}
    data['eventID'] = eventID
    data['teamName'] = teamName
    team = call("post", "/teams", data, (201,))
    joinCode = text(team['joinCode'])
    check(len(joinCode) == 12, f"join code {joinCode}")
    refused("post", "/teams", data, 409, '53')

    progress = call("get", f"/progress/{eventID}")
    check(text(progress['isCaptain']) == 'Y', "A is captain")
    check(text(progress['joinCode']) == joinCode, "the captain sees the join code")
    check(progress['memberCount'] == 1 and progress['score'] == 0, "one member, score 0")

    step("B4. B joins, with a wrong code first; a team name is taken regardless of case")
    signIn(userB)
    data = {}
    data['eventID'] = eventID
    data['teamName'] = teamName.lower()
    refused("post", "/teams", data, 409, '11')

    data = {}
    data['eventID'] = eventID
    data['joinCode'] = 'NOT-A-CODE'
    refused("post", "/teamMembers", data, 404, '01')
    data['joinCode'] = joinCode.lower()
    joined = call("post", "/teamMembers", data, (201,))
    check(joined['teamID'] == team['teamID'], "B is in A's team, lower-case code works")

    progress = call("get", f"/progress/{eventID}")
    check(text(progress['isCaptain']) == 'N', "B is not captain")
    check(text(progress['joinCode']) == '', "B does not see the join code")
    check(progress['memberCount'] == 2, "two members")
    members = call("get", f"/teamMembers?eventID={eventID}")['members']
    check(len(members) == 2, "two members listed")

    step("B5. Only the captain removes members; a captain with members can't leave")
    refused("delete", f"/teamMembers/{idA}?eventID={eventID}", None, 403, '50')
    signIn(userA)
    refused("delete", f"/teamMembers/{idA}?eventID={eventID}", None, 409, '53')

    step("B6. A hands over to B")
    data = {}
    data['playerID'] = idB
    call("put", f"/teamCaptains/{eventID}", data)
    refused("put", f"/teamCaptains/{eventID}", data, 403, '50')

    step("B7. B removes A")
    signIn(userB)
    check(text(call("get", f"/progress/{eventID}")['isCaptain']) == 'Y', "B is captain")
    call("delete", f"/teamMembers/{idA}?eventID={eventID}")
    check(len(call("get", f"/teamMembers?eventID={eventID}")['members']) == 1, "one member left")

    step("B8. A joins again and leaves")
    signIn(userA)
    check(findMyEvent(eventID)['teamID'] == 0, "A has no team")
    data = {}
    data['eventID'] = eventID
    data['joinCode'] = joinCode
    call("post", "/teamMembers", data, (201,))
    call("delete", f"/teamMembers/{idA}?eventID={eventID}")

    step("B9. B leaves as the last member: the team is gone")
    signIn(userB)
    call("delete", f"/teamMembers/{idB}?eventID={eventID}")
    refused("get", f"/progress/{eventID}", None, 403, '50')
    signIn(userA)
    data = {}
    data['eventID'] = eventID
    data['joinCode'] = joinCode
    refused("post", "/teamMembers", data, 404, '01')

    print(f"\nTeam part done. The new players are {userA} and {userB}.")

def doStuff():
    if (len(sys.argv) != 2):
        raise Exception('usage: python testIteration2.py <userid of an event 1 player>')

    userid = sys.argv[1].upper()
    passphrases[userid] = getpass(f"Passphrase of {userid}: ")
    Globals.signedIn = None

    soloPart(userid)
    teamPart()

    print("\nDone.")

doStuff()
