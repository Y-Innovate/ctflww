# Walks through "Trying it" in docs/05-iteration-1.md, from registration to the
# leaderboard. Every run creates a real RACF userid and takes a seat in the event.
#
# python testIteration1.py [--target <name>]
#   The host comes from runtimeTargets.yaml (testTarget.py), without --target
#   its default target.
import json
import time

from datetime import datetime
from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

# From DDL/SEEDDATA.sql
eventName = "Demo CTF"
regCode = "DEMO-CODE"
firstTitle = "First steps"
secondTitle = "Second steps"
firstFlag = "FIRST-FLAG"
wrongFlag = "NOT-THE-FLAG"

pollSeconds = 5
pollMax = 60

def step(text):
    print(f"\n=== {text}")

def getToken():
    # A rejected token must not go along on the request for a new one
    Globals.s.headers.pop('Authorization', None)
    #resp = MyRequests.post(f"{Globals.pathPrefix}/token", Globals.tokenData)

    # The token is printed by call(), with the result of the call that used it
    #print(f"POST /token: {resp.status_code}")

    #if (resp.status_code not in (200, 201)):
    #    raise Exception(f'status code {str(resp.status_code)} {resp.text}')

    Globals.myCreds = (Globals.tokenData['username'], Globals.tokenData['password'])

    MyRequests.getBearerToken(f"{Globals.pathPrefix}/token")

    Globals.myCreds = None

    # On the session and not in myBearer: MyRequests would send a request again after a 4xx
    Globals.s.headers['Authorization'] = f"Bearer {Globals.myBearer}"

def call(method, uri, data=None, okCodes=(200,)):
    for attempt in range(0, 2):
        resp = getattr(MyRequests, method)(f"{Globals.pathPrefix}{uri}", data)

        print(f"{method.upper()} {uri}: {resp.status_code} {resp.text}")

        authorization = Globals.s.headers.get('Authorization')

        # Calls without a token have nothing to print or refresh
        if (authorization is None):
            break

        # Printed for analyzing the JWT validation problems in CICS
        token = authorization.removeprefix('Bearer ')

        if (resp.status_code in okCodes):
            print(f"Token that succeeded: {token}")

        if (resp.status_code != 401):
            break

        print(f"Token that got the 401: {token}")

        if (attempt == 0):
            print("Retrying with a new token")
            getToken()

    if (resp.status_code not in okCodes):
        raise Exception(f'status code {str(resp.status_code)} {resp.text}')

    return json.loads(resp.text)

def check(condition, text):
    if not condition:
        raise Exception(f'check failed: {text}')

    print(f"OK: {text}")

def findChallenge(challenges, title):
    for challenge in challenges['challenges']:
        if (challenge['challengeTitle'].strip() == title):
            return challenge

    raise Exception(f'challenge {title} not found')

def doStuff():
    passphrase = getpass("Passphrase for the new player (14 to 100 characters): ")

    if (len(passphrase) < 14 or len(passphrase) > 100):
        raise Exception('passphrase must be 14 to 100 characters')

    displayName = f"Tester {datetime.now():%y%m%d%H%M%S}"

    step("1. GET /events, without a token")
    events = call("get", "/events")
    eventID = None

    for event in events['events']:
        if (event['eventName'].strip() == eventName):
            eventID = event['eventID']

    check(eventID is not None, f"{eventName} is event {eventID}")
    call("get", f"/events/{eventID}")

    step(f"2. POST /registrations as {displayName}")
    data = {}
    data['eventID'] = eventID
    data['regCode'] = regCode
    data['displayName'] = displayName
    registration = call("post", "/registrations", data, (201,))
    registrationID = registration['registrationID']

    step("3. Poll GET /registrations until the provisioning job is done")
    status = 'P'

    for i in range(0, pollMax):
        status = call("get", f"/registrations/{registrationID}")['registrationStatus'].strip()

        if (status != 'P'):
            break

        time.sleep(pollSeconds)

    check(status == 'R', f"registration status is R, it is {status}")

    step("4. POST /activations")
    data = {}
    data['claimToken'] = registration['claimToken']
    data['passphrase'] = passphrase
    userid = call("post", f"/activations/{registrationID}", data, (201,))['racfUserid'].strip()

    step(f"5. POST /token as {userid}")
    data = {}
    data['username'] = userid
    data['password'] = passphrase
    Globals.tokenData = data
    getToken()
    
    me = call("get", "/me")
    check(me['racfUserid'].strip() == userid, "GET /me returns the new userid")
    
    step("6. GET /challenges: the second challenge is locked")
    challenges = call("get", f"/challenges?eventID={eventID}")
    first = findChallenge(challenges, firstTitle)
    check(findChallenge(challenges, secondTitle)['isLocked'].strip() == 'Y', f"{secondTitle} is locked")
    
    #res = input("Press enter to continue")

    call("get", f"/challenges/{first['challengeID']}?eventID={eventID}")

    step("7. POST /submissions with a wrong flag, then the right one")
    data = {}
    data['eventID'] = eventID
    data['challengeID'] = first['challengeID']
    data['flag'] = wrongFlag
    check(call("post", "/submissions", data, (201,))['isCorrect'].strip() == 'N', "wrong flag is not correct")
    data['flag'] = firstFlag
    check(call("post", "/submissions", data, (201,))['isCorrect'].strip() == 'Y', "right flag is correct")

    step("8. GET /challenges: the second challenge is open")
    challenges = call("get", f"/challenges?eventID={eventID}")
    check(findChallenge(challenges, firstTitle)['isSolved'].strip() == 'Y', f"{firstTitle} is solved")
    check(findChallenge(challenges, secondTitle)['isLocked'].strip() == 'N', f"{secondTitle} is open")

    step("9. GET /leaderboard, without a token")
    del Globals.s.headers['Authorization']
    leaderboard = call("get", f"/leaderboard/{eventID}")

    for row in leaderboard['leaderboard']:
        if (row['teamName'].strip() == displayName):
            print(f"OK: {displayName} has rank {row['rank']} with score {row['score']}")
            break
    else:
        # Equal scores go to who got there first, so older test players can fill the page
        print(f"NOTE: {displayName} is not in the first {len(leaderboard['leaderboard'])} rows")

    print(f"\nDone. The new player is {userid}.")

doStuff()
