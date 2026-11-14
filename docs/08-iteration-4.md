# Iteration 4: content management

Iterations 1 to 3 ([05](05-iteration-1.md), [06](06-iteration-2.md),
[07](07-iteration-3.md)) cover the player side, provisioning and the batch. Events
and challenges still come from `SEEDDATA.sql` and the `AA0000nn` seed members. This
iteration adds the admin API for content (use cases A1 to A3): events, the challenge
library with its flags, hints and links, putting challenges in an event, and
prerequisites, plus the reference tables. After it, an admin can prepare and publish
an event without SQL.

Running a live event (A4, A7, A8: submissions, solves, reversals, the admin
leaderboard, teams, awards and announcements) is iteration 5.

Built and tested on t01 with `testIteration4.py`.

## What is built

| Method and path | Wrapper | Module | Use case |
|---|---|---|---|
| GET `/admin/refTables` | `CTFC401` | `CTFM401` | A1, A2 |
| POST, PUT, DELETE `/admin/refTables[/{tableID}]` | `CTFC001` | `CTFM001` | A1, A2 |
| GET `/admin/events` | `CTFC402` | `CTFM402` | A1 |
| POST, GET, PUT, DELETE `/admin/events[/{eventID}]` | `CTFC002` | `CTFM002` | A1 |
| GET `/admin/challenges` | `CTFC407` | `CTFM407` | A2 |
| POST, GET, PUT, DELETE `/admin/challenges[/{challengeID}]` | `CTFC007` | `CTFM007` | A2 |
| GET `/admin/flags` | `CTFC408` | `CTFM408` | A2 |
| POST, PUT, DELETE `/admin/flags[/{flagID}]` | `CTFC008` | `CTFM008` | A2 |
| GET `/admin/hints` | `CTFC409` | `CTFM409` | A2 |
| POST, PUT, DELETE `/admin/hints[/{hintID}]` | `CTFC009` | `CTFM009` | A2 |
| GET `/admin/links` | `CTFC410` | `CTFM410` | A2 |
| POST, PUT, DELETE `/admin/links[/{linkID}]` | `CTFC010` | `CTFM010` | A2 |
| GET `/admin/eventChallenges` | `CTFC411` | `CTFM411` | A3 |
| POST, PUT, DELETE `/admin/eventChallenges[/{challengeID}]` | `CTFC011` | `CTFM011` | A3 |
| GET `/admin/prerequisites` | `CTFC412` | `CTFM412` | A3 |
| POST, DELETE `/admin/prerequisites[/{challengeID}]` | `CTFC012` | `CTFM012` | A3 |

That is 33 operations, in 16 modules and 16 wrappers. There is no GET by ID for
flags, hints and links in the API; their modules can still read one row, to answer
a create or update. All are admin paths, with
transaction `CTFA` and the admin check of iteration 3 (`CTFADMP`). The placeholder
files in `LWWAdmin/API/v1/admin` exist already.

The API itself doesn't change: these operations are all in `ctf_1.0.0.yaml` already.
They only get their `x-LWWProcessingSteps`, so the frontend needs no change.

Optional request fields are marked `required: false` in their `ParseRequestJSON`
mapping; the list is under "Conventions" in [04-api.md](04-api.md).

The create, update and delete wrappers roll back when the module fails, so a delete
that removes children first is all or nothing. A create answers 201.

## Design decisions

1. **One CRUD module per table.** `CTFM0nn` handles create, read,
   update and delete of table `nnn`, with `OPCODE` C, R, U or D in the IO area. LWW
   maps the opcode as a constant per operation, as for the player actions of
   iteration 3. Update and create answer with the row as it is after the change
   (a read at the end), with CREATEDBY and UPDATEDBY from `CTFA990`. Lists are
   `CTFM4nn`, with `*_since` paging and up to 20 rows, as the other lists. `5nn`
   stays for admin operations that aren't CRUD (`CTFM502` closing, `CTFM510`
   player actions).
2. **Event status.** POST creates a DRAFT (D); another status is `08 0x`.
   - D to P (publish): only with at least one visible challenge. A visible
     challenge always has a flag (decision 5), so this is enough. Once published,
     hiding all challenges doesn't block other changes, such as extending the end.
   - P to D: only while nobody has a place, so a DRAFT never has players.
   - C: only through POST `/admin/eventClosures` (A9), not through PUT: `08 53`.
   - A CLOSED event can't be changed or deleted: `08 53`.
3. **Event fields.**
   - Start < end; the freeze is empty, or start < freeze < end. Registration from <
     to. Registration may end after the event (`Demo Ended CTF` does that). An
     empty freeze lifts it, as in A1.
   - Individual events have a maximum team size of 1, team events at least 2.
   - Once anyone has a place, the play mode and RACF group are locked. The maximum
     team size can't go below the largest team, nor the cap below PLAYERCOUNT.
     These checks go in the WHERE clause of the UPDATE, so a registration that
     comes in at the same moment can't slip past them.
   - The RACF group is empty or in the `RACFGRP` list (`08 0x`).
   - The registration code can't be empty. It needn't be unique: registration
     looks events up by ID and code.
4. **Deleting an event.** Only a DRAFT (`08 53` otherwise). Its prerequisites,
   challenge links and announcements are deleted with it, in one unit of work. A
   DRAFT has no places, teams, solves or jobs (decision 2), so nothing else refers
   to it.
5. **Challenges in an event.**
   - Scoring: S static uses only the initial value, and stores minimum and decay
     as empty; D dynamic needs initial >= minimum >= 0 and decay > 0. Maximum
     attempts 0 means no limit.
   - LWW maps a missing number as 0, and JSON has no other way to leave a number
     empty here, so for these three fields 0 stands for "empty", in requests and
     responses. That is safe: decay
     and maximum attempts must be above 0 when set, and minimum is only stored for
     dynamic scoring, where it is required.
   - ISVISIBLE Y needs at least one flag on the challenge (`08 53`).
   - Scoring and visibility may change during the event. Scores are always
     calculated, never stored, so the leaderboard changes at once, also for solves
     made earlier. The UI should warn about this.
   - Taking a challenge out of an event is refused once there are submissions for
     it, or unlocks of its hints in that event: `08 53`, hide it instead. Its
     prerequisites, in either direction, are deleted with it.
   - No changes to the challenges of a CLOSED event: `08 53`.
6. **Prerequisites.** Both challenges must be in the event (the foreign keys to
   EVENTCHALL give `-530`, so `08 13`). Not on itself (`08 0x`). No cycles: before
   inserting "C requires R", a recursive common table expression follows the
   prerequisites from R; if it reaches C, `08 53`. There is no update: delete and
   add.
7. **The challenge library.**
   - The category must be in the `CATEGORY` list (`08 0x`). Challenge type is S;
     the verifier program must be empty in v1.
   - A challenge in any event can't be deleted (`08 53`). Otherwise its flags,
     hints and links are deleted with it, in one unit of work. Its hints can't have
     unlocks then, because unlinking (decision 5) refuses those.
   - Changes to a challenge apply to every event that uses it, as A2 says.
   - A flag can't be deleted if it is the last one of a challenge that is visible
     in some event (`08 53`). Changing a flag doesn't touch earlier solves.
   - A hint with unlocks can't be deleted (`08 53`), because the unlocks count in
     the score. Its cost may change: unlocks keep the cost they were charged.
   - Links have no rules beyond required fields.
8. **Reference tables.** Any table ID and key may be added, in upper case. Deleting is
   refused (`08 53`) for:
   - a `CATEGORY` key that a challenge uses;
   - a `RACFGRP` key that an event uses;
   - any `SETTINGS` key, because the programs need them. Their values can be
     updated; the value must be a number.

     Changed 2026-11-11, for the admin screens: every setting can be changed.
     A value is required and must fit the field CTFM910 reads it into
     (`LCTFC910`: `JOBCLASS` and `MSGCLASS` 1, `DB2SSID`, `SUBMTXN` and
     `CLAIMHRS` 4, `BATCHUSR`, `PLAYGRP`, `CTFPLAN` and `SUBMUSR` 8, `DB2HLQ`
     and `DB2SSHLQ` 20, `LOADLIB` 44, others 255), else `08 02`. Only
     `CLAIMHRS` and `JOBMINS` must be numbers (`08 03`).

   Adding a group to `RACFGRP` isn't enough by itself: the batch userid needs
   CONNECT authority in it too (see `RACF.jcl`).
9. **"In use" is `08 53`.** No new reason code: `08 53` already means "not possible
   in this state", and the info message says what is in the way, such as "challenge
   has submissions in this event; hide it instead". Duplicates stay `08 11`, a
   missing parent `08 13`, a missing key on update or delete `08 31` and `08 41`.

## Rules per operation

| Operation | Checks | Codes |
|---|---|---|
| POST `/admin/events` | Fields (decision 3), status D | `08 0x` |
| PUT `/admin/events/{id}` | Not closed; status change (decision 2); fields and locks (decision 3) | `04 01`, `08 0x`, `08 53` |
| DELETE `/admin/events/{id}` | DRAFT only | `08 41`, `08 53` |
| POST, PUT `/admin/challenges` | Category, type S, no verifier | `08 0x` |
| DELETE `/admin/challenges/{id}` | In no event | `08 41`, `08 53` |
| POST `/admin/flags` | Challenge exists; case sensitivity Y or N | `08 0x`, `08 13` |
| DELETE `/admin/flags/{id}` | Not the last flag of a visible challenge | `08 41`, `08 53` |
| POST, PUT `/admin/hints` | Cost >= 0 | `08 0x`, `08 13` |
| DELETE `/admin/hints/{id}` | No unlocks | `08 41`, `08 53` |
| POST `/admin/eventChallenges` | Event not closed; scoring; visible needs a flag; already in the event is `08 11` | `08 0x`, `08 11`, `08 13`, `08 53` |
| PUT `/admin/eventChallenges/{id}` | As POST | `08 0x`, `08 31`, `08 53` |
| DELETE `/admin/eventChallenges/{id}` | No submissions, no hint unlocks | `08 41`, `08 53` |
| POST `/admin/prerequisites` | Both in the event, not itself, no cycle | `08 0x`, `08 11`, `08 13`, `08 53` |
| DELETE `/admin/refTables/{id}` | Decision 8 | `08 41`, `08 53` |

## Changes outside the programs

| File | Change |
|---|---|
| `COPY/LCTFM0nn`, `LCTFM4nn` | IO areas of the new modules |
| `LKED/` | One member per new load module |
| `openapi/ctf_2_1.0.0.yaml` | Steps and IO areas for the 33 operations |
| `openapi/ctf_1.0.0.yaml` | `x-LWWProcessingSteps` references |
| `docs/04-api.md` | `08 53` also for "in use"; 0 for an empty number |
| `python/testIteration4.py` | See below |

No DDL: the tables and indexes are there already. All new modules go in the
`CTFT01` plan, through the admin transaction.

## Setting it up on t01

1. `. ./setenv`, then `build`, and `python python/deploy.py`. The 16 new `CTFM`
   packages are bound into the `CTFT01` plan; none is on a public path.
2. Copy both specs to LWW and register `ctf_1.0.0.yaml` again.
3. `python python/uploadLWW.py`, if the `admin` placeholders aren't on LWW yet.

## Testing

`python python/testIteration4.py [--target <name>] <userid>` takes an active player of
event 1, and uses the target's admin sign-in for everything else (host and sign-in
from `python/runtimeTargets.yaml`, as in iteration 3). It makes no RACF userids. It
walks through:
- reference tables: a test category, added in lower case and stored in upper case;
  a duplicate refused; deleting a `SETTINGS` key and a value that isn't a number
  refused;
- the library: a challenge in the existing category `ZOS` with two flags (one not
  case sensitive), two hints and a link; an unknown category refused; get, list and
  update; a second challenge in the test category, without flags; deleting the test
  category refused while it is in use;
- an event: invalid dates and a new event that isn't a DRAFT refused; publishing
  refused without a visible challenge;
- composing: the first challenge visible in the event, the second hidden (visible
  refused without a flag); invalid dynamic scoring refused, valid accepted;
  prerequisites, with one on itself and a cycle refused;
- publishing; the player joins with POST `/participants` (no RACF group, so the
  place is active at once), sees only the visible challenge, and solves it with the
  flag in upper case;
- the locks: play mode change, back to DRAFT, unlinking the solved challenge,
  deleting the event and deleting the challenge are refused; one flag can be deleted,
  the last one can't;
- cleaning up: a second DRAFT event is deleted with its challenge link; the second
  challenge is taken out of the event (its prerequisite goes with it) and deleted,
  and so is the test category.

Each run leaves "Test Event <stamp>" behind, with the first challenge, because it
has a place and a solve. The script closes it, after moving its end into the past:
closing (A9) needs an event that has ended. It only does so if the player has a
place in another event that hasn't ended, because closing revokes a player without
one. Otherwise it says so and leaves the event published.

## Decided

1. **Numbering:** `CTFM0nn` per table for create, read, update and delete, and
   `CTFM4nn` for lists.
2. **Back to DRAFT:** allowed while nobody has a place.
3. **Scoring changes during an event** count for earlier solves too; the UI warns.
4. **Reference tables:** deleting `SETTINGS` keys, and categories or groups in use,
   is refused; `SETTINGS` values can be changed, to numbers only (since
   2026-11-11: any value that fits; numbers for `CLAIMHRS` and `JOBMINS`).
