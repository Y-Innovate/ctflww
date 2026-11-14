# Iteration 5: running a live event

Iterations 1 to 4 ([05](05-iteration-1.md), [06](06-iteration-2.md),
[07](07-iteration-3.md), [08](08-iteration-4.md)) cover the player side,
provisioning, the batch and content management. This iteration adds the admin API
for a running event (use cases A4, A7 and A8): following submissions and solves,
the live leaderboard, reversing a solve, the teams, awards and penalties, and
announcements. After it, every operation in `ctf_1.0.0.yaml` has its processing
steps.

Built; to be tested on t01 with `testIteration5.py`.

## What is built

| Method and path | Wrapper | Module | Use case |
|---|---|---|---|
| GET `/admin/submissions` | `CTFC413` | `CTFM413` | A4 |
| GET `/admin/solves` | `CTFC414` | `CTFM414` | A4 |
| POST `/admin/solveReversals` | `CTFC514` | `CTFM514` | A4 |
| GET `/admin/leaderboard/{eventID}` | `CTFC530` | `CTFM314` (changed) | A4 |
| GET `/admin/teams` | `CTFC405` | `CTFM405` | A4, A7 |
| GET `/admin/awards` | `CTFC416` | `CTFM416` | A7 |
| POST, DELETE `/admin/awards[/{awardID}]` | `CTFC016` | `CTFM016` | A7 |
| GET `/admin/announcements` | `CTFC417` | `CTFM417` | A8 |
| POST, PUT, DELETE `/admin/announcements[/{announceID}]` | `CTFC017` | `CTFM017` | A8 |

That is 12 operations, in 8 new modules and 9 wrappers. The numbering follows
iteration 4: `CTFM0nn` for create, read, update and delete of table `nnn`, with
`OPCODE`; `CTFM4nn` for lists; `5nn` for admin operations that aren't CRUD.
`CTFM514` reverses a solve (table 014). The admin leaderboard has no module of its
own: `CTFC530` calls the public `CTFM314` with a new admin flag (decision 4).

All are admin paths, with transaction `CTFA` and the admin check (`CTFADMP`). The
placeholder files in `LWWAdmin/API/v1/admin` exist already. The API itself doesn't
change, so the frontend needs no change.

As in iteration 4, the create, update and delete wrappers roll back when the module
fails, and a create answers 201. POST `/admin/solveReversals` answers 200, as the
spec says: it doesn't create a resource.

## Design decisions

1. **A reversal deletes the solve and marks the attempt.** In one unit of work:
   - `SELECT SUBMISSIONID FROM OLD TABLE (DELETE FROM SOLVES WHERE <key>)`, with
     the key (event, challenge, team) from the request. No row: `08 41` "no solve to
     reverse". Two admins reversing at once can't both succeed.
   - `UPDATE SUBMISSIONS SET REVERSEDBY, REVERSEDDATE, REVERSEREASON` for that
     submission, with the userid from `CTFA990`. ISCORRECT stays `Y`: the attempt
     was correct, and it stays on record (A4).
   - The reason is required (`08 0x`), although the schema allows an empty string.
2. **What a reversal changes.** Scores are calculated, never stored, so the next
   read shows the effect at once:
   - The dynamic value of the challenge goes back up, for every team that solved
     it, as A4 says.
   - The team may solve it again: the primary key of SOLVES is free again. The
     reversed attempt doesn't count as a wrong attempt, because `MAXATTEMPTS`
     counts only ISCORRECT `N`.
   - Hint unlocks stay: the team keeps paying for a hint it saw.
   - There is no "first blood" in the model, so nothing else to correct.
   - During a freeze, reversing a solve from before the freeze changes the public
     board at once, because the row is gone. Hiding that would mean keeping the
     solve row and filtering on REVERSEDDATE in the leaderboard query; not worth
     it for a correction.
3. **Awards and penalties.**
   - The team must be in the event: `SELECT FROM TEAMS WHERE TEAMID AND EVENTID`,
     otherwise `08 13`. Points not zero, reason not empty: `08 0x`.
   - A penalty may take the score below zero, as the data model already says.
   - There is no update, as in A7: delete and give a new one. OPCODE C, R and D;
     R reads the row back for the create response.
   - CREATEDDATE decides the freeze: an award given during a freeze shows on the
     public board once the freeze ends or is lifted, also if it is about something
     earlier.
4. **The admin leaderboard reuses `CTFM314`.** `LCTFM314` gets a field
   `ADMINVIEW PIC N` before `BOARD-COUNT`. With `Y` the cutoff is always
   `9999-12-31-23.59.59.999999`, and a DRAFT is not "not found" but an empty
   board. The public wrapper `CTFC314` sets `ADMINVIEW` to `N` after the GET
   CONTAINER, so no request can set it, and `CTFC530` sets `Y` after its admin
   check. The x-ioarea `LCTFM314` and the `AllocateIOArea` size of the public path
   change with it (+2 bytes). `CTFM314` is already bound in both plans.
5. **Lists.** `eventID` is required in all of them (the spec says so); an event
   that doesn't exist gives an empty list, as `CTFM411`.
   - Submissions: newest first, so `SUBMISSIONID-SINCE` pages downwards (0 =
     start), as `CTFM404`. Filters team, player, challenge and ISCORRECT (`Y`, `N`
     or empty; anything else `08 0x`). Reversed attempts show REVERSEDBY,
     REVERSEDDATE and REVERSEREASON.
   - Solves: by CHALLENGEID and TEAMID, with both `*_since` keys. Filters team and
     challenge. Reversed solves aren't there; they are in the submissions.
   - Teams: by TEAMID, also the teams of one in individual events. No join code.
   - Awards: by AWARDID, oldest first, as `CTFM216`. Filter team.
   - Announcements: newest first, as `CTFM217`.
6. **Announcements.**
   - The event must exist (`08 13`). Title and body not empty (`08 0x`).
   - Allowed on a DRAFT, to have a welcome message ready. CREATEDDATE is the
     publish time, so it shows with the date it was written.
   - PUT changes title and body only; the event can't change. CREATEDDATE stays,
     so a correction keeps its place in the list, and UPDATEDDATE shows it was
     changed.
   - DELETE removes the row; there is no history.
7. **Nothing changes once an event is CLOSED.** Reversals,
   awards (create and delete) and announcements (create, update and delete) on a
   CLOSED event give `08 53`, as the content changes of iteration 4. Corrections are
   made between the end and the closing; the closing is the admin's own act.

## Rules per operation

| Operation | Checks | Codes |
|---|---|---|
| GET `/admin/submissions` | ISCORRECT filter Y, N or empty | `08 0x` |
| POST `/admin/solveReversals` | Reason; solve exists; event not closed | `08 0x`, `08 41`, `08 53` |
| GET `/admin/leaderboard/{id}` | Event exists, any status | `04 01` |
| POST `/admin/awards` | Points not 0, reason; team in event; event not closed | `08 0x`, `08 13`, `08 53` |
| DELETE `/admin/awards/{id}` | Event not closed | `08 41`, `08 53` |
| POST `/admin/announcements` | Title, body; event exists, not closed | `08 0x`, `08 13`, `08 53` |
| PUT `/admin/announcements/{id}` | Title, body; event not closed | `08 0x`, `08 31`, `08 53` |
| DELETE `/admin/announcements/{id}` | Event not closed | `08 41`, `08 53` |

The other lists only have the SQL error codes.

## Changes outside the programs

| File | Change |
|---|---|
| `COPY/LCTFM0nn`, `LCTFM4nn`, `LCTFM514` | IO areas of the new modules |
| `COPY/LCTFM314` | `ADMINVIEW` (decision 4) |
| `COBOL/CTFM314`, `CTFC314` | Admin flag; public wrapper forces `N` |
| `LKED/` | One member per new load module |
| `openapi/ctf_2_1.0.0.yaml` | Steps and IO areas for the 12 operations; `LCTFM314` and its size |
| `openapi/ctf_1.0.0.yaml` | `x-LWWProcessingSteps` references |
| `docs/04-api.md` | `reverseReason` required |
| `python/testIteration5.py` | See below |

No DDL: the tables and indexes are there already, including (EVENTID,
CREATEDDATE) on SUBMISSIONS for the newest-first list. The new modules go in the
`CTFT01` plan by themselves, because they aren't in `loadpubmems`.

## Setting it up on t01

1. `. ./setenv`, then `build`, and `python python/deploy.py`. The 8 new `CTFM`
   packages are bound into `CTFT01`; `CTFM314` is bound again into both plans.
2. Copy both specs to LWW and register `ctf_1.0.0.yaml` again. The public
   leaderboard needs the new IO area size as well.
3. The `admin` placeholders are on LWW already.

## Testing

`python python/testIteration5.py [--target <name>] <userid>` takes an active player of
event 1, and the target's admin sign-in, as `testIteration4.py`. It walks through:
- setup: a test event that started an hour ago, ends in an hour and froze a minute
  ago, with one dynamic challenge and one static challenge, each with a flag;
  published, and the player joins;
- the player solves both, after the freeze, and makes one wrong attempt;
- monitoring: submissions with and without filters (ISCORRECT `X` refused), solves,
  teams; the public leaderboard shows 0 (frozen), the admin one the real score;
- awards: +50 and a penalty that takes the score below zero; 0 points, an empty
  reason and a team of another event refused; the list; one deleted;
- reversal: an empty reason and a solve that doesn't exist refused; reversing the
  dynamic solve; the submission shows who and why; the solve and its points are
  gone from the admin board; the player solves it again;
- announcements: created, seen by the player with GET `/announcements`, corrected,
  an empty title refused, deleted;
- closing, as `testIteration4.py`: the end moved into the past and the event
  closed, only if the player has a place in another open event. Then a reversal,
  an award and an announcement are refused with `08 53`.

## Decided

1. **Changes after closing:** refused (`08 53`) for reversals, awards and
   announcements; corrections are made before closing.
2. **Announcements on a DRAFT:** allowed.
3. **Admin leaderboard:** the `ADMINVIEW` flag in `CTFM314`; the public wrapper
   forces `N`.
