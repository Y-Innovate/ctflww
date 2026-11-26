# The target of the testIteration*.py scripts: host and admin sign-in from
# runtimeTargets.yaml next to this script, as uploadLWW.py has them (see
# runtimeTargets.example.yaml), loaded and signed in by runtimeTarget.py.
#
# python testIterationN.py [--target <name>] ...
#   Without --target, the config's "default" is used. --list shows the
#   targets.
import requests
import runtimeTarget
import sys

from Globals import Globals

CONFIG = str(runtimeTarget.scriptDir / "runtimeTargets.yaml")

def _takeOption(names, hasValue=True):
    # Takes an option out of sys.argv, so the scripts see only their own
    # arguments. Returns its value (True for a flag), or None.
    for i, arg in enumerate(sys.argv[1:], start=1):
        for name in names:
            if hasValue and arg.startswith(f"{name}="):
                del sys.argv[i]
                return arg.split("=", 1)[1]
            if arg == name:
                if not hasValue:
                    del sys.argv[i]
                    return True
                if i + 1 >= len(sys.argv):
                    sys.exit(f"{name} needs a value")
                value = sys.argv[i + 1]
                del sys.argv[i:i + 2]
                return value
    return None

def useTarget(pathPrefix="/ctf/API/v1"):
    """Sets Globals for the target chosen with --target, or the default one."""
    target = runtimeTarget.loadTarget(CONFIG,
                                      _takeOption(("-t", "--target")),
                                      _takeOption(("-l", "--list"), hasValue=False))

    print(f"Testing against {target['name']} ({target['host']})")

    Globals.target = target
    Globals.myHost = target["host"].rstrip("/")
    Globals.pathPrefix = pathPrefix
    Globals.myCreds = None
    Globals.myBearer = ""
    Globals.myDebug = 0
    Globals.s = requests.sessions.Session()
    # Extra headers sent with every request, e.g. a Cloudflare Access cookie
    Globals.s.headers.update(target.get("headers") or {})

    return target

def adminToken():
    """Signs in as admin on the target and returns the bearer token.

    auth: entra    - the Entra client credentials of credsFile (default
                     ~/.creds) at tokenUrl; LWW maps them to a RACF admin.
    auth: password - the target's userid (or one asked for) and its
                     password, through the app's own POST /token.
    """
    try:
        runtimeTarget.signIn(Globals.target, f"{Globals.pathPrefix}/token")
        return Globals.myBearer
    finally:
        Globals.myCreds = None
        Globals.myBearer = ""
