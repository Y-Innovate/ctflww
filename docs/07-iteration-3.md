# Iteration 3: provisioning and the scheduled batch

Iterations 1 and 2 ([05](05-iteration-1.md), [06](06-iteration-2.md)) cover the
player side, with CREATE as the only provisioning action. This iteration adds the
rest of the RACF work: changing a passphrase, joining another event, the admin
actions on players and jobs, closing an event, and the scheduled batch of S3 and
S4. It also gives a way to clean up test userids. Nothing here has been compiled or
run yet.

## What is built

| Method and path | Access | Wrapper | Module | Use case |
|---|---|---|---|---|
| PUT `/myPassphrase` | Player | `CTFC291` | none | P3 |
| POST `/participants` | Player | `CTFC306` | `CTFM306` | P2 |
| GET `/admin/players` | Admin | `CTFC403` | `CTFM403` | A5 |
| GET `/admin/provisioningJobs` | Admin | `CTFC404` | `CTFM404` | A6 |
| GET `/admin/players/{playerID}` | Admin | `CTFC503` | `CTFM503` | A5 |
| POST `/admin/playerResets/{playerID}` | Admin | `CTFC510` | `CTFM510` | A5 |
| POST `/admin/playerRevocations/{playerID}` | Admin | `CTFC510` | `CTFM510` | A5 |
| POST `/admin/playerResumptions/{playerID}` | Admin | `CTFC510` | `CTFM510` | A5 |
| DELETE `/admin/players/{playerID}` | Admin | `CTFC510` | `CTFM510` | A5, A9 |
| POST `/admin/jobRetries/{provJobID}` | Admin | `CTFC520` | `CTFM520` | A6 |
| POST `/admin/eventClosures/{eventID}` | Admin | `CTFC502` | `CTFM502` | A9 |

The four player actions share one module and wrapper: LWW maps a constant action
code into the IO area for each path.

Batch, in a new member `JCL/CTFBATCH.jcl`, run on a schedule under the batch userid:

| Step | Program | What it does |
|---|---|---|
| 1 | `CTFM930` | S4: expire unclaimed accounts. S3: fail stuck jobs. Pick the queued rows and write one line per RACF command |
| 2 | `CTFR931` (REXX) | Run each command, write one result line per row |
| 3 | `CTFM915` | Record the results, as at the end of every provisioning job |

Numbering: `4nn` admin lists, `5nn` admin operations, after the table where that
works.

Changed:

| Program | Change |
|---|---|
| `CTFC910` | JCL for every action, not just CREATE (see below) |
| `CTFM910` | Claim checks the claim token for CREATE and RESET, the job token for the rest |
| `CTFM915` | All actions, all result lines on SYSIN, JOBRC and JOBMESSAGE recorded |
| `CTFC303` | Starting the submit task moves to a copybook, shared with the new wrappers |
| `CTFM303` | Event check, taking a place and the team of one move to a copybook, shared with `CTFM306` |
| `CTFC290` | The `CTF.ADMIN` check moves to a copybook, shared with the admin wrappers |

New copybooks: `CTFADMW`/`CTFADMP` (admin check), `CTFSUBW`/`CTFSUBP` (starting
the submit task), `CTFREGW`/`CTFREGP` (taking a place, with `COPY ... REPLACING` as
`CTFCTXP`). `LCTFC910` gets `JOBTOKEN`: the module that makes a job puts the token
to submit with there, and `CTFSUBP` passes it on.

`CTFC303` and `CTFM303` change, so `testIteration1.py` runs again.

## Design decisions

1. **A job token for actions without a claim token.** The submit task only submits
   after checking a token against a stored hash, so nobody who can start `CTFS`
   can submit what they like. CREATE and RESET keep using the claim token, because
   the one-time passphrase comes from it. All other actions get a random job token
   of their own: its hash goes into a new nullable column PROVJOBS.JOBHASH
   (`AA000026`), and the claim clears it. Players and admins get surrogate access to
   start `CTFS` as the submit userid, as the CICS default userid has now.
2. **Statuses.** JOBSTATUS gets Q (queued for the batch) besides N, S, D and F; there
   are no CHECK constraints, so no DDL is needed for this. The effect of a job on the
   player or place is recorded only when the job reports success (`CTFM915`):

   | Action | Allowed from PLAYERSTATUS | RACF commands | On success |
   |---|---|---|---|
   | C create | (registration) | ADDUSER, then ALTUSER PHRASE, PASSWORD NOINTERVAL, CONNECT | Player R, place A |
   | N connect | A | CONNECT | Place A |
   | M remove | (closing, batch only) | REMOVE | None |
   | P reset | A, R, V | ALTUSER PHRASE RESUME | Player R, new claim token |
   | V revoke | A, R | ALTUSER REVOKE | Player V |
   | U resume | V | ALTUSER RESUME | Player A |
   | X delete | V | DELUSER | Player X; the row stays |

   A failed job leaves the player and the place as they were, except CREATE, which
   sets the player F as now. A player can have one open job (N, Q or S) at a time;
   a second request gets `08 53`. Resume puts a player back to ACTIVE, so it is for
   players who had activated their account; for one who never did, use reset.
3. **CREATE is safe to retry.** ADDUSER no longer sets the passphrase. A second step
   sets it with ALTUSER, together with NOINTERVAL and the event group, and success
   depends only on that step. So a retry works when an earlier run did create the
   userid. A userid outside the batch userid's group-special scope can't be
   altered, so this can't take over someone else's userid.
4. **Retry (A6).** Only a failed job. RETRYCOUNT goes up and the row goes back to N
   (Q for REMOVE). CREATE and RESET get a new claim token, returned to the admin;
   the other actions get a new job token. CREATE also puts the player back to P.
5. **Joining another event (P2).** The same code, window and cap checks as R1, with
   the same `08 51` for a wrong code or a closed registration. Already in the event
   is `08 11`. In an individual event the team of one is created. If the event has
   a RACF group, the place is P and a CONNECT job is submitted; CONNECT is
   harmless when the player is connected already. Without a group the place is A
   at once.
6. **Changing a passphrase (P3).** `EXEC CICS CHANGE PHRASE` with the current and the
   new passphrase, under the player's own userid. No DB2, so `CTFC291` has no
   module. A wrong current passphrase and a refused new one
   both give `08 56`, with a message that tells them apart where RACF does.
7. **Closing an event (A9).** Only a PUBLISHED event after its end. In one unit of
   work: the event becomes CLOSED, and queued rows are inserted with INSERT ...
   SELECT: REMOVE for every player with a place if the event has a RACF group, and
   REVOKE for every ACTIVE or READY player without a place in another open event.
   The batch carries them out.
8. **The batch.**
   - S4: READY players whose CLAIMEXPIRES has passed get a queued REVOKE, and their
     claim hash is cleared. Their places are deleted with their teams of one, and
     PLAYERCOUNT goes down, so they no longer count towards the cap. They never
     signed in, so there are no solves to lose. A reset (A5) brings them back.
   - S3: jobs that are S for longer than the new setting `JOBMINS` become F, with a
     message. Jobs that are still N after that time were never submitted: CREATE
     and RESET become F, because their one-time passphrase is gone; the other
     actions are carried out by the batch.
   - Q rows, and those old N rows, are written to a work file, one line per row:
     job ID, action, userid, group. They are set to S first, so a batch that stops
     halfway leaves them for the S3 check of the next run.
   - The REXX step issues each command with `ADDRESS TSO` and writes the job ID, O
     or F, and the return code. It is copied from the JCL into a temporary library,
     so the batch is one member.
   - `CTFM915` reads all result lines, so the provisioning jobs and the batch record
     results the same way.
9. **Admin check.** Each admin wrapper checks `CTF.ADMIN` with `EXEC CICS QUERY
   SECURITY` before it calls the module, and answers `08 50` (403) otherwise. The
   check moves from `CTFC290` into a copybook, used by both.

## Rules per operation

| Operation | Precondition, rule | Codes |
|---|---|---|
| PUT `/myPassphrase` | Both passphrases given; RACF decides the rest | `08 02`, `08 56`, `08 90` |
| POST `/participants` | Player ACTIVE; code, window and cap as R1; not in the event yet | `08 11`, `08 51`, `08 52` |
| GET `/admin/players` | Filters on name, userid, status and event; by PLAYERID | |
| GET `/admin/provisioningJobs` | Filters on status, event and player; by PROVJOBID, newest first | |
| GET `/admin/players/{id}` | | `04 01` |
| Reset, revoke, resume, delete | Status as in decision 2; no open job | `04 01`, `08 53` |
| POST `/admin/jobRetries/{id}` | Job is F | `04 01`, `08 53` |
| POST `/admin/eventClosures/{id}` | Event PUBLISHED and ended | `04 01`, `08 53` |

All admin operations also give `08 50` for a userid without `CTF.ADMIN`.

## Changes outside the programs

| File | Change |
|---|---|
| `DDL/AA000026.sql` | ALTER PROVJOBS ADD JOBHASH BINARY(32); the setting `JOBMINS` is in `SETTINGS.sql` since 2026-11-11 |
| `DDL/AA000027.sql` | Seed data: an event that has ended but is still open for registration, for testing A9, and an event with a RACF group, for testing CONNECT |
| `COPY/TBCTF004.cpy` | JOBHASH |
| `JCL/RACF.jcl` | Surrogate access to start `CTFS` for the player and admin groups |
| `JCL/CTFBATCH.jcl` | New: the scheduled batch |
| `envs/t01.yaml` | `EVENTGROUP` for the test event, `JOBMINUTES`, `ZWSUSER` |
| `openapi/` | Steps and IO areas for the 11 paths |
| `docs/02-use-cases.md`, `03-data-model.md` | S1-S4, JOBHASH, status Q, `JOBMINS` |
| `python/testIteration3.py` | See below |

## Setting it up on t01

1. Check `EVENTGROUP`, `JOBMINUTES` and especially `ZWSUSER` at the end of
   `envs/t01.yaml`. The batch userid needs CONNECT authority in `FLAGUSER`, or
   CONNECT and REMOVE fail with a violation; `RACF.jcl` gives it. Its group-special
   in `PLAYERGROUP` covers the player userids, but not other groups.
2. `python python/deploy.py DEPLOY_DDL`, then run `AA000026` with `RUNDDL`. The
   packages use JOBHASH, so this comes before the BIND.
3. `. ./setenv`, then `build`, and `python python/deploy.py`.
4. Run `AA000027` with `RUNDDL`.
5. Submit `RACF`: players and admins may now start the submit task, and ZWS may
   submit as the batch userid.
6. Copy both specs to LWW and register `ctf_1.0.0.yaml` again. Assign `CTFU` to
   `/myPassphrase` and `/participants`, and `CTFA` to the nine `/admin` paths.
7. Put `CTFBATCH` from the deployed JCL library in the ZWS job library, and plan it
   once a day.

## Testing

`python python/testIteration3.py [--target <name>] <userid>` takes a player of event 1,
such as the one `testIteration1.py` created. It prompts for that player's passphrase, a
new one for that player, and one for the new test players. The host and the admin
sign-in come from the target in `python/runtimeTargets.yaml` (see "Decided"). It walks
through:
- `/myPassphrase` with a wrong current passphrase, then a real change; the player keeps
  the new passphrase, because RACF may not allow going back to an old one;
- `/participants` with a wrong code, then the team event (active at once) and the
  event with a group (pending until the CONNECT job is done); a second run gets `08 11`;
- a player calling an admin path is refused; CICS does this already, because only
  `ADMINGROUP` may use transaction `CTFA`, so the `08 50` of the admin check isn't reached;
- the admin finds the player; a new test player in the group event is revoked (can't
  sign in), resumed, reset (activates again with the new claim token), revoked and
  deleted;
- while `Demo Ended CTF` is open: a test player registers there, the admin closes the
  event, and a REMOVE and a REVOKE are queued. The script then asks you to submit
  `CTFBATCH`, checks the results, and deletes that player;
- a retry of a failed job of a test player, if there is one.

Every run creates one RACF userid, and one more the first time, and deletes them
again. `Demo Ended CTF` can be closed once; run `AA000027` again for another.

`python python/testIteration3.py [--target <name>] --cleanup` revokes and deletes the userids of all
test players, the ones whose display name starts with `Tester`, from this and earlier
iterations. It lists them and asks before it does anything.

## Known limits

- REMOVE of a player who isn't connected, and DELUSER of a userid that is gone, end
  with RC 8, so a retry of a half-done job stays failed (decided: later).
- JESJOBID stays empty: neither CICS SPOOL nor the batch learns the JES job ID.
- `CTFR931` reads the whole work file into storage; fine for thousands of rows.
- The S4 expiry of a player in a team with other members only revokes the userid;
  the place stays and keeps counting towards the cap.

## Decided

- **Path:** `/me` is a path of its own already, and LWW can't have `/me` as both a
  resource and a folder, so changing a passphrase is PUT `/myPassphrase`, like
  `/myEvents`.
- **Admin sign-in for the test:** from the target in `python/runtimeTargets.yaml`
  (`python/testTarget.py`). With `auth: entra`, as on t01 and t02, the Entra client
  credentials of its `credsFile` (default `~/.creds`), which LWW maps to a RACF userid
  in `ADMINGROUP`. With `auth: password`, the target's `userid` and its password
  through `POST /token`; that userid must be in `ADMINGROUP`.
- **Event RACF group:** `FLAGUSER`, as `EVENTGROUP` in `envs/t01.yaml`. It is added to
  the `RACFGRP` allowlist by `AA000027`.
- **Scheduling:** ZWS, once a day. The ZWS controller's userid submits the job, so it
  gets surrogate access to the batch userid in `RACF.jcl`; it is `ZWSUSER` in
  `envs/t01.yaml`, a placeholder to fill in.
- **Idempotent REMOVE and DELETE:** later.
