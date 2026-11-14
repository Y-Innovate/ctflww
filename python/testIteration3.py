# Tests iteration 3 (docs/07-iteration-3.md): changing a passphrase, joining
# another event, the admin actions on players and jobs, closing an event and
# the scheduled batch.
#
# python testIteration3.py [--target <name>] <userid>
#   <userid> is a player of event 1, for example the one testIteration1.py
#   printed. Its passphrase is prompted, and is changed to a new one, which is
#   prompted too. The admin calls use the target's admin sign-in.
#   Creates one RACF userid per run, and one more while "Demo Ended CTF" is open.
#   Halfway it asks you to submit CTFBATCH.
#
# python testIteration3.py [--target <name>] --cleanup
#   Revokes and deletes the RACF userids of all test players: those whose
#   display name starts with "Tester". Asks before it does anything.
#
# The host and the admin sign-in come from runtimeTargets.yaml (testTarget.py),
# without --target its default target.
import json
import sys
import time

from datetime import datetime
from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import adminToken, useTarget

useTarget()

# From DDL/SEEDDATA.sql, AA000025.sql and AA000027.sql
eventName = "Demo CTF"
teamEventName = "Demo Team CTF"
teamRegCode = "DEMO-TEAM"
groupEventName = "Demo Group CTF"
groupRegCode = "DEMO-GROUP"
endedEventName = "Demo Ended CTF"
endedRegCode = "DEMO-ENDED"

pollSeconds = 5
pollMax = 60

# Passphrase per userid, to sign in again after a 401
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

def signInFails(userid):
    # True if /token refuses this userid and passphrase
    Globals.s.headers.pop('Authorization', None)
    Globals.myCreds = (userid, passphrases[userid])
    try:
        MyRequests.getBearerToken(f"{Globals.pathPrefix}/token")
        # A 200 without a token is a refusal too
        return not Globals.myBearer
    except Exception:
        return True
    finally:
        Globals.myCreds = None
        Globals.myBearer = ""
        Globals.signedIn = None

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

def findEvent(name):
    for event in call("get", "/events")['events']:
        if (text(event['eventName']) == name):
            return event

    raise Exception(f'event {name} not found')

def findMyEvent(eventID):
    for event in call("get", "/myEvents")['events']:
        if (event['eventID'] == eventID):
            return event

    raise Exception(f'event {eventID} not in /myEvents')

def registerPlayer(eventID, regCode, displayName, passphrase):
    data = {}
    data['eventID'] = eventID
    data['regCode'] = regCode
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

    return activate(registrationID, registration['claimToken'], passphrase)

def activate(registrationID, claimToken, passphrase):
    data = {}
    data['claimToken'] = claimToken
    data['passphrase'] = passphrase
    userid = text(call("post", f"/activations/{registrationID}", data, (201,))['racfUserid'])
    passphrases[userid] = passphrase

    return userid

def findPlayer(userid):
    players = call("get", f"/admin/players?racfUserid_filter={userid}")['players']
    players = [p for p in players if text(p['racfUserid']) == userid]
    check(len(players) == 1, f"admin finds {userid}")

    return players[0]

def waitJob(playerID, provJobID):
    # Poll as admin until the job is done or failed
    job = None

    for i in range(0, pollMax):
        jobs = call("get", f"/admin/provisioningJobs?playerID_filter={playerID}")['provisioningJobs']
        job = next((j for j in jobs if j['provJobID'] == provJobID), None)

        if (job is not None and text(job['jobStatus']) in ('D', 'F')):
            return job

        time.sleep(pollSeconds)

    raise Exception(f'job {provJobID} did not finish: {job}')

def playerAction(path, playerID, method="post"):
    # Reset, revoke, resume or delete, and wait for the job
    answer = call(method, f"/admin/{path}/{playerID}")
    job = waitJob(playerID, answer['provJobID'])
    check(text(job['jobStatus']) == 'D', f"{path} job {answer['provJobID']} is done")

    return answer

def playerStatus(playerID):
    return text(call("get", f"/admin/players/{playerID}")['playerStatus'])

def playerPart(userid):
    newPassphrase = getpass(f"New passphrase for {userid} (14 to 100 characters): ")

    if (len(newPassphrase) < 14 or len(newPassphrase) > 100):
        raise Exception('passphrase must be 14 to 100 characters')

    step("A1. PUT /myPassphrase: a wrong current passphrase first")
    signIn(userid)
    data = {}
    data['currentPassphrase'] = 'NOT-THE-PASSPHRASE-0'
    data['newPassphrase'] = newPassphrase
    refused("put", "/myPassphrase", data, 400, '56')

    data['currentPassphrase'] = passphrases[userid]
    call("put", "/myPassphrase", data)
    passphrases[userid] = newPassphrase
    signIn(userid)
    print(f"NOTE: the passphrase of {userid} is now the new one")

    step("A2. POST /participants: the team event, without a group")
    signOut()
    teamEvent = findEvent(teamEventName)
    groupEvent = findEvent(groupEventName)
    signIn(userid)

    data = {}
    data['eventID'] = teamEvent['eventID']
    data['regCode'] = 'NOT-THE-CODE'
    refused("post", "/participants", data, 403, '51')

    data['regCode'] = teamRegCode
    answer = call("post", "/participants", data, (201, 409))

    if (text(answer.get('reasonCode')) == '11'):
        print("NOTE: in the team event already, from an earlier run")
    else:
        check(text(answer['partStatus']) == 'A', "place in the team event is active at once")
        check(not answer['teamID'], "no team yet")

    step("A3. POST /participants: the event with a group, then wait for CONNECT")
    data = {}
    data['eventID'] = groupEvent['eventID']
    data['regCode'] = groupRegCode
    answer = call("post", "/participants", data, (201, 409))

    if (text(answer.get('reasonCode')) == '11'):
        print("NOTE: in the group event already, from an earlier run")
    else:
        check(text(answer['partStatus']) == 'P', "place is pending until CONNECT is done")
        check(answer['teamID'] != 0, "a team of one")

    status = 'P'

    for i in range(0, pollMax):
        status = text(findMyEvent(groupEvent['eventID'])['partStatus'])

        if (status != 'P'):
            break

        time.sleep(pollSeconds)

    check(status == 'A', f"place in {groupEventName} is active")

    step("A4. A player can't use the admin paths")
    # RACF gives only the admin group the admin transaction, so CICS refuses the
    # player before the admin check in COBOL: no 08 50 in a JSON body, just an error
    resp = MyRequests.get(f"{Globals.pathPrefix}/admin/players")
    print(f"GET /admin/players: {resp.status_code} {resp.text}")
    check(resp.status_code >= 400, f"a player is refused, with {resp.status_code}")

def adminPart(userid, passphrase, stamp):
    step("B1. GET /admin/players and /admin/players/{id}")
    asAdmin()
    player = findPlayer(userid)
    check(text(call("get", f"/admin/players/{player['playerID']}")['racfUserid']) == userid,
          "get the player by ID")
    refused("get", "/admin/players/999999999", None, 404, '01')

    step("B2. A new player in the event with a group")
    signOut()
    groupEvent = findEvent(groupEventName)
    testUser = registerPlayer(groupEvent['eventID'], groupRegCode, f"Tester C {stamp}", passphrase)
    signIn(testUser)
    asAdmin()
    testID = findPlayer(testUser)['playerID']

    step("B3. Resume an active player is refused; revoke, then resume")
    refused("post", f"/admin/playerResumptions/{testID}", None, 409, '53')
    playerAction("playerRevocations", testID)
    check(playerStatus(testID) == 'V', "player is revoked")
    check(signInFails(testUser), "a revoked player can't sign in")
    asAdmin()
    playerAction("playerResumptions", testID)
    check(playerStatus(testID) == 'A', "player is active again")
    signIn(testUser)

    step("B4. Reset: a new claim token, and activation again")
    asAdmin()
    reset = playerAction("playerResets", testID)
    check(len(text(reset['claimToken'])) == 64, "the reset returns a claim token")
    check(playerStatus(testID) == 'R', "player is ready again")
    signOut()
    newPassphrase = passphrase[::-1]
    activate(testID, text(reset['claimToken']), newPassphrase)
    signIn(testUser)

    step("B5. Revoke and delete the new player")
    asAdmin()
    refused("delete", f"/admin/players/{testID}", None, 409, '53')
    playerAction("playerRevocations", testID)
    playerAction("players", testID, "delete")
    check(playerStatus(testID) == 'X', "player is deleted")

def closurePart(passphrase, stamp):
    step("C1. Register in the ended event, then close it")
    signOut()
    endedEvent = findEvent(endedEventName)

    if (text(endedEvent.get('eventStatus')) == 'C'):
        print(f"NOTE: {endedEventName} is closed already; run AA000027 again for a new one")
        return None

    closeUser = registerPlayer(endedEvent['eventID'], endedRegCode, f"Tester E {stamp}", passphrase)
    asAdmin()
    closeID = findPlayer(closeUser)['playerID']

    answer = call("post", f"/admin/eventClosures/{endedEvent['eventID']}")
    check(text(answer['eventStatus']) == 'C', "the event is closed")
    refused("post", f"/admin/eventClosures/{endedEvent['eventID']}", None, 409, '53')

    jobs = call("get", f"/admin/provisioningJobs?playerID_filter={closeID}&jobStatus_filter=Q")['provisioningJobs']
    actions = sorted(text(j['provAction']) for j in jobs)
    check(actions == ['M', 'V'], f"REMOVE and REVOKE are queued, found {actions}")

    return (closeUser, closeID)

def batchPart(closed):
    step("D1. The scheduled batch")
    input("Submit CTFBATCH now, and press Enter when it has ended: ")
    asAdmin()

    if (closed is not None):
        closeUser, closeID = closed
        jobs = call("get", f"/admin/provisioningJobs?playerID_filter={closeID}")['provisioningJobs']

        for job in jobs:
            if (text(job['provAction']) in ('M', 'V')):
                check(text(job['jobStatus']) in ('D', 'F'),
                      f"job {job['provJobID']} ({text(job['provAction'])}) has a result: "
                      f"{text(job['jobStatus'])} {text(job['jobMessage'])}")

        check(playerStatus(closeID) == 'V', f"{closeUser} is revoked")
        playerAction("players", closeID, "delete")

    step("D2. Retry a failed job, if there is one")
    # Only jobs of test players: a retry of another CREATE makes a real userid
    failed = call("get", "/admin/provisioningJobs?jobStatus_filter=F")['provisioningJobs']
    job = None

    for candidate in failed:
        name = text(call("get", f"/admin/players/{candidate['playerID']}")['displayName'])
        if (name.startswith('Tester')):
            job = candidate
            break

    if (job is None):
        print("NOTE: no failed job of a test player to retry")
        return

    answer = call("post", f"/admin/jobRetries/{job['provJobID']}", None, (200, 409))

    if (text(answer.get('reasonCode')) == '53'):
        print(f"NOTE: job {job['provJobID']} can't be retried now: {text(answer.get('infoMessage'))}")
    else:
        check(text(answer['jobStatus']) in ('N', 'Q'), f"job {job['provJobID']} is {text(answer['jobStatus'])} again")
        if (text(job['provAction']) in ('C', 'P')):
            check(len(text(answer['claimToken'])) == 64, "a CREATE or RESET retry gives a new claim token")

def cleanup():
    asAdmin()
    players = []
    since = 0

    while True:
        page = call("get", f"/admin/players?displayName_filter=Tester&playerID_since={since}")['players']
        players += page

        if (len(page) < 20):
            break

        since = page[-1]['playerID']

    players = [p for p in players if text(p['playerStatus']) in ('A', 'R', 'V')]

    for p in players:
        print(f"{p['playerID']:6} {text(p['racfUserid']):8} {text(p['playerStatus'])} {text(p['displayName'])}")

    if (not players):
        print("No test players to clean up")
        return

    if (input(f"Revoke and delete these {len(players)} RACF userids? Type YES: ") != 'YES'):
        print("Nothing done")
        return

    for p in players:
        if (text(p['playerStatus']) != 'V'):
            playerAction("playerRevocations", p['playerID'])
        playerAction("players", p['playerID'], "delete")

def doStuff():
    Globals.signedIn = None

    if (len(sys.argv) == 2 and sys.argv[1] == '--cleanup'):
        cleanup()
        return

    if (len(sys.argv) != 2):
        raise Exception('usage: python testIteration3.py <userid of an event 1 player> | --cleanup')

    userid = sys.argv[1].upper()
    passphrases[userid] = getpass(f"Passphrase of {userid}: ")
    passphrase = getpass("Passphrase for the new test players (14 to 100 characters): ")

    if (len(passphrase) < 14 or len(passphrase) > 100):
        raise Exception('passphrase must be 14 to 100 characters')

    stamp = f"{datetime.now():%y%m%d%H%M%S}"

    playerPart(userid)
    adminPart(userid, passphrase, stamp)
    closed = closurePart(passphrase, stamp)
    batchPart(closed)

    print("\nDone.")

doStuff()
