# Tests iteration 5 (docs/09-iteration-5.md): the admin API for a running
# event: submissions, solves, reversals, the admin leaderboard, teams,
# awards and announcements.
#
# python testIteration5.py [--target <name>] <userid>
#   <userid> is an active player of event 1. Its passphrase is prompted.
#   Everything else runs as admin, with the target's admin sign-in. No RACF
#   userids are made.
#
# The host and the admin sign-in come from runtimeTargets.yaml (testTarget.py),
# without --target its default target.
#
# Each run leaves one test event behind, "Test Event <stamp>", with two
# library challenges, because it has a place, solves and awards. The event
# is frozen from the start of the test, so the public leaderboard hides
# what happens during it. It is closed at the end only if the player has a
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
seedEventID = 1

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

def ts(delta):
    # A DB2 timestamp, now plus delta. The hours of margin around "now" in
    # this test cover a difference between this clock and the mainframe's.
    return f"{datetime.now() + delta:%Y-%m-%d-%H.%M.%S}.000000"

def eventBody(name, regCode):
    # Started a day ago, frozen since a few hours, ends tomorrow. The hours
    # of margin cover a difference between this clock and the mainframe's.
    data = {}
    data['eventName'] = name
    data['eventDescription'] = "Made by testIteration5.py"
    data['eventStatus'] = "D"
    data['playMode'] = "I"
    data['maxTeamSize'] = 1
    data['startTS'] = ts(timedelta(days=-1))
    data['endTS'] = ts(timedelta(days=1))
    data['freezeTS'] = ts(timedelta(hours=-5))
    data['regCode'] = regCode
    data['regFromTS'] = ts(timedelta(days=-1))
    data['regToTS'] = ts(timedelta(days=1))
    data['maxPlayers'] = 10
    data['racfGroup'] = ""
    return data

def eventChallenge(eventID, challengeID, dynamic):
    data = {}
    data['eventID'] = eventID
    data['challengeID'] = challengeID
    data['scoreType'] = "D" if dynamic else "S"
    data['initPoints'] = 500 if dynamic else 100
    data['isVisible'] = "Y"
    data['sortOrder'] = 1
    data['minPoints'] = 100 if dynamic else 0
    data['decaySolves'] = 5 if dynamic else 0
    data['maxAttempts'] = 0
    return data

def newChallenge(title, flag):
    data = {}
    data['challengeTitle'] = title
    data['category'] = existingCategory
    data['challengeDescription'] = "Find the flag. Made by testIteration5.py"
    data['challengeType'] = "S"
    data['verifierPgm'] = ""
    challengeID = call("post", "/admin/challenges", data, (201,))['challengeID']
    data = {'challengeID': challengeID, 'flagValue': flag, 'caseSensitive': "Y"}
    call("post", "/admin/flags", data, (201,))
    return challengeID

def adminScore(eventID, teamID):
    board = call("get", f"/admin/leaderboard/{eventID}")['leaderboard']
    return next(r['score'] for r in board if r['teamID'] == teamID)

def submit(eventID, challengeID, flag):
    data = {'eventID': eventID, 'challengeID': challengeID, 'flag': flag}
    return text(call("post", "/submissions", data, (201,))['isCorrect'])

def setupPart(stamp):
    step("A1. A frozen test event with a dynamic and a static challenge")
    asAdmin()
    dynamicID = newChallenge(f"Test dynamic {stamp}", f"dyn-{stamp}")
    staticID = newChallenge(f"Test static {stamp}", f"stat-{stamp}")
    data = eventBody(f"Test Event {stamp}", f"TEST-{stamp}")
    eventID = call("post", "/admin/events", data, (201,))['eventID']
    call("post", "/admin/eventChallenges", eventChallenge(eventID, dynamicID, True), (201,))
    call("post", "/admin/eventChallenges", eventChallenge(eventID, staticID, False), (201,))
    data['eventStatus'] = "P"
    event = call("put", f"/admin/events/{eventID}", data)
    check(text(event['phase']) == "F", "published and frozen")
    return eventID, data, dynamicID, staticID

def playPart(userid, stamp, eventID, regCode, dynamicID, staticID):
    step("B1. The player joins and solves both, after the freeze, with one wrong attempt")
    signIn(userid)
    call("post", "/participants", {'eventID': eventID, 'regCode': regCode}, (201,))
    check(submit(eventID, dynamicID, "wrong") == "N", "a wrong flag")
    check(submit(eventID, dynamicID, f"dyn-{stamp}") == "Y", "the dynamic challenge solved")
    check(submit(eventID, staticID, f"stat-{stamp}") == "Y", "the static challenge solved")

    others = [e for e in call("get", "/myEvents")['events']
              if e['eventID'] != eventID and text(e.get('phase')) in ('U', 'R', 'F')]
    return len(others) > 0

def monitorPart(eventID, dynamicID, staticID):
    step("C1. Teams, submissions and solves")
    asAdmin()
    teams = call("get", f"/admin/teams?eventID={eventID}")['teams']
    check(len(teams) == 1 and teams[0]['memberCount'] == 1, "one team of one")
    check('joinCode' not in teams[0], "no join code in the list")
    teamID = teams[0]['teamID']

    subs = call("get", f"/admin/submissions?eventID={eventID}")['submissions']
    check(len(subs) == 3, "three attempts")
    check(subs[0]['submissionID'] > subs[-1]['submissionID'], "newest first")
    wrong = call("get", f"/admin/submissions?eventID={eventID}&isCorrect_filter=N")['submissions']
    check(len(wrong) == 1 and text(wrong[0]['submittedText']) == "wrong", "the wrong attempt, with its text")
    page = call("get", f"/admin/submissions?eventID={eventID}&submissionID_since={subs[0]['submissionID']}")
    check(len(page['submissions']) == 2, "paging downwards")
    refused("get", f"/admin/submissions?eventID={eventID}&isCorrect_filter=X", None, 400, '01')

    solves = call("get", f"/admin/solves?eventID={eventID}")['solves']
    check(sorted(s['challengeID'] for s in solves) == sorted([dynamicID, staticID]), "two solves")
    one = call("get", f"/admin/solves?eventID={eventID}&challengeID_filter={staticID}")['solves']
    check(len(one) == 1 and one[0]['teamID'] == teamID, "filtered by challenge")

    step("C2. The leaderboard: frozen for visitors, live for the admin")
    check(adminScore(eventID, teamID) == 600, "admin: 500 + 100")
    signOut()
    public = call("get", f"/leaderboard/{eventID}")
    check(text(public['isFrozen']) == "Y", "public: frozen")
    check(all(r['score'] == 0 for r in public['leaderboard']), "public: the solves after the freeze don't show")
    asAdmin()
    return teamID

def awardPart(eventID, teamID):
    step("D1. Awards and penalties")
    data = {'eventID': eventID, 'teamID': teamID, 'points': 50, 'reason': "Nice write-up"}
    award = call("post", "/admin/awards", data, (201,))
    check(award['points'] == 50 and text(award['reason']) == "Nice write-up", "an award")
    data = {'eventID': eventID, 'teamID': teamID, 'points': -1000, 'reason': "Flag sharing"}
    penalty = call("post", "/admin/awards", data, (201,))
    check(penalty['points'] == -1000, "a negative penalty")
    check(adminScore(eventID, teamID) == -350, "the score goes below zero")

    refused("post", "/admin/awards", dict(data, points=0), 400, '02')
    refused("post", "/admin/awards", dict(data, reason=""), 400, '03')
    seedTeams = call("get", f"/admin/teams?eventID={seedEventID}")['teams']
    if seedTeams:
        refused("post", "/admin/awards", dict(data, teamID=seedTeams[0]['teamID']), 404, '13')

    awards = call("get", f"/admin/awards?eventID={eventID}")['awards']
    check([a['awardID'] for a in awards] == [award['awardID'], penalty['awardID']], "the list, oldest first")
    call("delete", f"/admin/awards/{award['awardID']}")
    refused("delete", f"/admin/awards/{award['awardID']}", None, 404, '41')
    check(adminScore(eventID, teamID) == -400, "the award is gone: 600 - 1000")
    return penalty['awardID']

def reversalPart(userid, stamp, eventID, teamID, dynamicID):
    step("E1. Reversing the dynamic solve")
    data = {'eventID': eventID, 'challengeID': dynamicID, 'teamID': teamID, 'reverseReason': ""}
    refused("post", "/admin/solveReversals", data, 400, '02')
    data['reverseReason'] = "Test reversal"
    refused("post", "/admin/solveReversals", dict(data, challengeID=999999999), 404, '41')
    call("post", "/admin/solveReversals", data)
    refused("post", "/admin/solveReversals", data, 404, '41')

    subs = call("get", f"/admin/submissions?eventID={eventID}&challengeID_filter={dynamicID}"
                       f"&isCorrect_filter=Y")['submissions']
    check(len(subs) == 1 and text(subs[0]['reverseReason']) == "Test reversal"
          and text(subs[0]['reversedBy']) != "", "the attempt is kept, with who and why")
    solves = call("get", f"/admin/solves?eventID={eventID}")['solves']
    check(dynamicID not in [s['challengeID'] for s in solves], "the solve is gone")
    check(adminScore(eventID, teamID) == -900, "its points too: 100 - 1000")

    step("E2. The player solves it again")
    signIn(userid)
    check(submit(eventID, dynamicID, f"dyn-{stamp}") == "Y", "solved again")
    asAdmin()
    check(adminScore(eventID, teamID) == -400, "500 + 100 - 1000")

def announcementPart(userid, stamp, eventID):
    step("F1. Announcements")
    data = {'eventID': eventID, 'announceTitle': f"Welcome {stamp}", 'announceBody': "Have fun"}
    announceID = call("post", "/admin/announcements", data, (201,))['announceID']
    refused("post", "/admin/announcements", dict(data, announceTitle=""), 400, '02')
    refused("post", "/admin/announcements", dict(data, eventID=999999999), 404, '13')
    data = {'announceTitle': f"Welcome {stamp}, corrected", 'announceBody': "Have fun!"}
    answer = call("put", f"/admin/announcements/{announceID}", data)
    check(text(answer['announceTitle']).endswith("corrected"), "corrected")
    check(text(answer['createdDate']) != text(answer['updatedDate']), "the publish time stays")
    found = call("get", f"/admin/announcements?eventID={eventID}")['announcements']
    check([a['announceID'] for a in found] == [announceID], "the admin list")

    signIn(userid)
    found = call("get", f"/announcements?eventID={eventID}")['announcements']
    check(any(a['announceID'] == announceID for a in found), "the player sees it")
    asAdmin()
    call("delete", f"/admin/announcements/{announceID}")
    refused("delete", f"/admin/announcements/{announceID}", None, 404, '41')
    refused("put", f"/admin/announcements/{announceID}", data, 404, '31')

    step("F2. A DRAFT: an announcement allowed, an empty admin board, deleted together")
    draft = eventBody(f"Test Draft {stamp}", f"DRAFT-{stamp}")
    draftID = call("post", "/admin/events", draft, (201,))['eventID']
    data = {'eventID': draftID, 'announceTitle': "Coming soon", 'announceBody': "Get ready"}
    call("post", "/admin/announcements", data, (201,))
    check(call("get", f"/admin/leaderboard/{draftID}").get('leaderboard') in (None, []),
          "admin: an empty board, not 404")
    signOut()
    refused("get", f"/leaderboard/{draftID}", None, 404, '01')
    asAdmin()
    call("delete", f"/admin/events/{draftID}")

def closePart(stamp, eventID, eventData, teamID, staticID, penaltyID, canClose):
    step("G1. Close the test event; then nothing changes")
    if not canClose:
        print(f"SKIPPED: the player has no place in another event that hasn't ended, so closing "
              f"would revoke them. Test Event {stamp} stays published.")
        return

    data = dict(eventData, endTS=ts(timedelta(hours=-3)))
    call("put", f"/admin/events/{eventID}", data)
    call("post", f"/admin/eventClosures/{eventID}")
    data = {'eventID': eventID, 'challengeID': staticID, 'teamID': teamID, 'reverseReason': "Too late"}
    refused("post", "/admin/solveReversals", data, 409, '53')
    data = {'eventID': eventID, 'teamID': teamID, 'points': 10, 'reason': "Too late"}
    refused("post", "/admin/awards", data, 409, '53')
    refused("delete", f"/admin/awards/{penaltyID}", None, 409, '53')
    data = {'eventID': eventID, 'announceTitle': "Too late", 'announceBody': "Closed"}
    refused("post", "/admin/announcements", data, 409, '53')
    check(adminScore(eventID, teamID) == -400, "the admin board still answers")

def doStuff():
    Globals.signedIn = None

    if (len(sys.argv) != 2):
        raise Exception('usage: python testIteration5.py <userid of an event 1 player>')

    userid = sys.argv[1].upper()
    passphrases[userid] = getpass(f"Passphrase of {userid}: ")
    stamp = f"{datetime.now():%y%m%d%H%M%S}"

    eventID, eventData, dynamicID, staticID = setupPart(stamp)
    canClose = playPart(userid, stamp, eventID, eventData['regCode'], dynamicID, staticID)
    teamID = monitorPart(eventID, dynamicID, staticID)
    penaltyID = awardPart(eventID, teamID)
    reversalPart(userid, stamp, eventID, teamID, dynamicID)
    announcementPart(userid, stamp, eventID)
    closePart(stamp, eventID, eventData, teamID, staticID, penaltyID, canClose)

    print("\nDone.")

doStuff()
