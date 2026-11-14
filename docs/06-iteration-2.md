# Iteration 2: the rest of the player side

Iteration 1 ([05-iteration-1.md](05-iteration-1.md)) proved registration, sign-in,
the board, submitting a flag and the leaderboard. This iteration adds what a player
needs for a complete game: hints, links, prerequisites, own progress,
announcements, own events, and teams (T1-T4). Nothing here needs RACF or a
provisioning job. Built, deployed and tested on t01 with `testIteration2.py`, after
`testIteration1.py` was run again for the refactored `CTFM311`-`CTFM313`.

Not in this iteration, because they need RACF or a job: `PUT /myPassphrase` (P3)
and `POST /participants` (P2). They go with the other provisioning work.

## What is built

All paths are player paths: transaction `CTFU`, plan `CTFT01`.

| Method and path | Wrapper | Module | Use case |
|---|---|---|---|
| GET `/myEvents` | `CTFC206` | `CTFM206` | P2, P8 |
| GET `/hints` | `CTFC209` | `CTFM209` | P5, P7 |
| GET `/challengeLinks` | `CTFC210` | `CTFM210` | P5 |
| GET `/prerequisites` | `CTFC212` | `CTFM212` | P5 |
| GET `/progressSolves` | `CTFC214` | `CTFM214` | P8 |
| GET `/progressAwards` | `CTFC216` | `CTFM216` | P8 |
| GET `/announcements` | `CTFC217` | `CTFM217` | P9 |
| GET `/teamMembers` | `CTFC205` | `CTFM205` | P8, T4 |
| POST `/hintUnlocks` | `CTFC315` | `CTFM315` | P7 |
| GET `/progress/{eventID}` | `CTFC320` | `CTFM320` | P8, T4 |
| POST `/teams` | `CTFC321` | `CTFM321` | T1 |
| POST `/teamMembers` | `CTFC322` | `CTFM322` | T2 |
| DELETE `/teamMembers/{playerID}` | `CTFC323` | `CTFM323` | T3, T4 |
| PUT `/teamCaptains/{eventID}` | `CTFC324` | `CTFM324` | T4 |

Numbering as before: `2nn` lists, numbered after the table they list where that
works, and `3nn` operations. `32n` is the team block.

## Design decisions

1. **Shared player context.** Every player module starts with the same SELECT:
   player from the CICS userid, the place, the team and the event phase. It lives
   in a procedure copybook, `CTFCTXP`, with `CTFCTXW` for the working storage, used
   as `COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFMnnn==`. The module sets
   `W-EVENTID` first. Besides `R100-GET-CONTEXT` it has small sections that each
   module performs as its rules need: `R101-NEED-TEAM`, `R102-NEED-STARTED`,
   `R103-NEED-RUNNING`, `R104-NEED-ACTIVE`, `R105-NEED-TEAMMODE`, and
   `R106-CHECK-CHALLENGE` (visible and not locked). Every section does nothing once
   there is an error, so they are performed one after the other. `CTFM311`,
   `CTFM312` and `CTFM313` from iteration 1 use it too now, so they need a new test.
2. **Score on `/progress` during a freeze.** P8 said the team sees its "true score".
   But values computed from every solve would show the team when others solve its
   challenges after the freeze, and P4 hides exactly that. So `/progress` and
   `/progressSolves` count all of the team's own solves, awards and hint costs,
   at the challenge values of the board (solve counts up to the freeze). When the
   freeze is lifted this becomes the leaderboard score. P8 in 02-use-cases.md says
   so now.
3. **Locked and hidden challenges.** `/hints`, `/challengeLinks` and `/hintUnlocks`
   follow `GET /challenges/{id}`: hidden or unknown is `04 01`, locked is `08 50`.
   `/prerequisites` works on a locked challenge (that is its purpose). It shows the
   title of a required challenge only if that one is visible; a hidden one is listed
   with an empty title.
4. **Hint text** is returned only for hints the team unlocked. The cost is always
   shown. Unlocking an unlocked hint returns `00 00` with the text and the cost paid
   at the time, and charges nothing (P7). A duplicate (`-803`) from a teammate at the
   same moment is handled the same way.
5. **Paging of `/hints`.** Hints are shown by `SORTORDER`, so `/hints` pages on
   `sortOrder_since` and `hintID_since`, as `/challenges` does.
6. **Team rules.** The team operations reject individual events with `08 53`.
   `MEMBERCOUNT` is changed with a guarded UPDATE, as the cap is (03-data-model.md),
   so a team can't grow past `MAXTEAMSIZE` with players joining at the same moment.
   Every write module's wrapper rolls back on an error, as `CTFC313` does.
7. **Join code.** It comes from `CTFA991`, through `CTFSECW`/`CTFSECP`, as in
   `CTFM303`: 12 hex characters. Input is upper-cased before comparing.

## Rules per operation

Return codes beyond `00 00`, `08 21`/`08 6x` (SQL) and `08 90` (CTFA990).
"Active place" means PARTICIPANTS.PARTSTATUS = A.

| Operation | Precondition, rule | Codes |
|---|---|---|
| `/myEvents` | All own places, also pending, and events PUBLISHED or CLOSED. Phase as in `/events`. Order by EVENTID | |
| `/hints`, `/challengeLinks` | Active place in a team; started; challenge visible and not locked | `04 01`, `08 50`, `08 53` |
| `/prerequisites` | As above, but a locked challenge is allowed | `04 01`, `08 50`, `08 53` |
| `/hintUnlocks` | As `/hints`, and the event is running or frozen. Copies COST into HINTUNLOCKS | `04 01`, `08 50`, `08 53` |
| `/progress/{eventID}` | Active place in a team, also before the start. Join code only for the captain. Score per decision 2 | `08 50` |
| `/progressSolves` | As `/progress`. Order by CHALLENGEID | `08 50` |
| `/progressAwards` | As `/progress`. All own awards, also after a freeze. Order by AWARDID | `08 50` |
| `/announcements` | Active place, a team isn't needed. Newest first, so `announceID_since` pages downwards | `08 50` |
| `/teamMembers` GET | Active place in a team. Order by PLAYERID | `08 50` |
| POST `/teams` | Team event; registration open; active place without a team. Name 1-30 characters, unique per event regardless of case | `08 02`, `08 11`, `08 50`, `08 53` |
| POST `/teamMembers` | Team event; registration open; active place without a team; join code of a team in this event, in any case; not full | `04 01`, `08 02`, `08 50`, `08 52`, `08 53` |
| DELETE `/teamMembers/{id}` | Team event; not started. Own ID: leave; a captain with other members must hand over first; the last member deletes the team. Other ID: only the captain, and only a member of the team | `04 01`, `08 50`, `08 53` |
| PUT `/teamCaptains/{eventID}` | Team event; at any time; only the captain; the new captain is a member of the team | `04 01`, `08 50`, `08 53` |

A player gets their own `playerID` from `GET /me`. Updates also give `08 32`
(UPDATE) and `08 42` (DELETE) on an SQL error. Deleting a team before the start
fails with `08 42` if an admin gave it an award already.

The wrappers of the five write operations roll back on any error, as `CTFC313`
does. Team names and join codes are compared in upper case: TEAMKEY holds the
upper-case name, and the join code is hex in upper case.

## Changes outside the new programs

| File | Change |
|---|---|
| `COPY/CTFCTXW.cpy`, `CTFCTXP.cpy` | New: player context (decision 1) |
| `COBOL/CTFM311.cbl`, `CTFM312.cbl`, `CTFM313.cbl` | Use `CTFCTXW`/`CTFCTXP`; same behaviour |
| `COPY/LCTFMnnn.cpy` | One per new module |
| `LKED/` | One per new load module, as `CTFM311` and `CTFC311` |
| `openapi/ctf_1.0.0.yaml` | `x-LWWProcessingSteps` refs on the 14 operations; `sortOrder_since` on `/hints` |
| `openapi/ctf_2_1.0.0.yaml` | Processing steps and `x-ioareas` for the 14 operations. |
| `DDL/AA000025.sql`, `$INFO.txt` | Seed data: a team event `Demo Team CTF` with code `DEMO-TEAM` and team size 3, hints and links on the two challenges, an announcement per event |
| `docs/02-use-cases.md` | P8 wording (decision 2) |
| `python/testIteration2.py` | See below |

No change to `DEPLOY.zmake` (no public modules), `BUILD.zmake`, `CICSCSD`, `RACF`
or `BINDPLAN`: the build and deploy pick up new members by directory, the CICS
programs are found in the load library, and the packages go into the existing
collection of plan `CTFT01`.

## Setting it up on t01

1. `. ./setenv`, then `build`.
2. `python python/deploy.py`. This copies the modules and binds the packages.
3. Run `AA000025` with `RUNDDL`.
4. Copy both specs in `openapi/` to LWW again and register `ctf_1.0.0.yaml`, as for
   iteration 1.
5. In LWW, assign `CTFU` to the 14 paths above.

## Testing

`python python/testIteration2.py [--target <name>] <userid>` uses an existing player
of event 1 who solved the first challenge, such as the one `testIteration1.py` created,
so it doesn't create one; the passphrase is prompted. The host comes from
`python/runtimeTargets.yaml`, as for `testIteration1.py`. It walks through:
`/myEvents`, `/hints` (no text), `/hintUnlocks` twice (charged once), `/hints` (text),
`/challengeLinks`, `/prerequisites` of the second challenge, `/progress/1` before and
after the unlock, `/progressSolves`, `/progressAwards`, `/announcements`, and the team
operations in event 1, which must give `08 53`.

The team part needs players in the team event. Until `POST /participants` exists, the
script registers two new players with `DEMO-TEAM`, as `testIteration1.py` does, so it
creates two RACF userids per run. Then: create a team, a taken name in other case,
a wrong join code, join in lower case, list members, the captain-only rules, hand
over captaincy, remove a member, join again and leave, and the last member deleting
the team. A full team isn't tested, because that would need a fourth new player.
Run `testIteration1.py` first: it also tests the refactored `CTFM311`-`CTFM313`.

## Decided

- Decision 2 changes the meaning of P8 slightly: agreed.
- Decision 5 changes the API contract for `/hints`: nothing depends on
  `ctf_1.0.0.yaml` yet.
- The iteration 1 modules use `CTFCTXP` too, so the context SELECT is in one place.
