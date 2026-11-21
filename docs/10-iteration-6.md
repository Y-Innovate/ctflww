# Iteration 6: archiving past events

Iterations 1 to 5 ([05](05-iteration-1.md) to [09](09-iteration-5.md)) built the
whole API. This iteration adds use case A10: archiving a CLOSED event, so the
event lists stay short, while the event and its leaderboard stay viewable.

Built; to be tested on t01 with `testIteration6.py`.

## What is built

| Method and path | Wrapper | Module | Use case |
|---|---|---|---|
| POST `/admin/eventArchives/{eventID}` | `CTFC540` | `CTFM540` (new) | A10 |
| DELETE `/admin/eventArchives/{eventID}` | `CTFC540` | `CTFM540` (new) | A10 |
| GET `/events` | `CTFC202` | `CTFM202` (changed) | V1 |
| GET `/admin/events` | `CTFC402` | `CTFM402` (changed) | A1, A10 |

Changed to keep an archived event read-only: `CTFM002` (events), `CTFM011`
(event challenges), `CTFM012` (prerequisites), `CTFM016` (awards), `CTFM017`
(announcements) and `CTFM514` (solve reversals).

POST archives, DELETE restores. They share one wrapper and module, with `OPCODE`
A or R set by LWW, as `CTFC510` does for the player actions. The number follows
the other admin operations that aren't CRUD: 510, 520, 530, 540.

## Design decisions

1. **A status, not a table.** ARCHIVED is EVENTSTATUS `A`. EVENTSTATUS is
   GRAPHIC(1) without a CHECK constraint, so there is no DDL. Nothing moves to
   other tables, and restoring is a status change too.
2. **Only CLOSED to ARCHIVED, and back.** One `UPDATE ... WHERE EVENTSTATUS =`
   the old status. No row: `04 01` if the event doesn't exist, otherwise `08 53`.
   Archiving needs a closed event, so the offboarding (A9) has always been done.
3. **Read-only, as CLOSED.** Every check that refused changes to a CLOSED event
   now refuses ARCHIVED as well, with `08 53`. PUT `/admin/events` refuses
   `eventStatus` A, as it refuses C, with a message that points to
   `/admin/eventArchives`. Player modules already need status P to play, so
   nothing changes there.
4. **Still viewable.** The reads that leave out only DRAFT keep showing an
   archived event: GET `/events/{eventID}`, the public and admin leaderboard, and
   the player's own events and pages (`CTFCTXP`). The phase is empty, as for a
   closed event.
5. **Lists.**
   - GET `/events` gets `eventStatus_filter`, the name the admin list already
     uses: empty = PUBLISHED and CLOSED (as before), P, C or A = only that status.
     D gives nothing: drafts stay hidden. `LCTFM202` gets `EVENTSTATUS-FILTER
     PIC N` after INFOMESSAGE, so the IO area grows by 2 bytes (9680).
   - GET `/admin/events` without a filter leaves out archived events; filter A
     lists them.
   - GET `/myEvents` is unchanged: a player keeps seeing their past events.
6. **No deletion.** Deleting an event means deleting from eleven child tables,
   PROVJOBS included, the audit trail of the RACF changes. See decision 6 in
   [02-use-cases.md](02-use-cases.md).

## Rules per operation

| Operation | Checks | Codes |
|---|---|---|
| POST `/admin/eventArchives/{id}` | Event exists and is CLOSED | `04 01`, `08 53` |
| DELETE `/admin/eventArchives/{id}` | Event exists and is ARCHIVED | `04 01`, `08 53` |
| PUT `/admin/events/{id}` | Not CLOSED or ARCHIVED; `eventStatus` not A | `08 53` |
| Event challenges, prerequisites, awards, announcements, reversals | Event not CLOSED or ARCHIVED | `08 53` |

## Changes outside the programs

| File | Change |
|---|---|
| `COPY/LCTFM540` | IO area of the new module |
| `COPY/LCTFM202` | `EVENTSTATUS-FILTER` |
| `LKED/CTFC540`, `LKED/CTFM540` | New load modules |
| `openapi/ctf_1.0.0.yaml` | New path with POST and DELETE, `AdminArchiveEventResponse`, `eventStatus_filter` on `/events`, A in `eventStatus` |
| `openapi/ctf_2_1.0.0.yaml` | Steps for the new path, IO area `LCTFM540`, `LCTFM202` and its size, the filter mapping |
| `LWWAdmin/API/v1/admin` | Placeholder `eventArchives` with `.eventArchives` (transaction `CTFA`) |
| `docs/02`, `03`, `04` | Status ARCHIVED, use case A10, the new operations |
| `python/testIteration6.py` | See below |

No DDL. `CTFM540` goes into the `CTFT01` plan by itself, because it isn't in
`loadpubmems`; `CTFM202` is bound again into both plans.

The frontend (`ctflww-frontend`) gets an "Archive" toggle on the public event
list, an "Archived" filter on the admin event list, and Archive and Restore
buttons on the admin event page.

## Setting it up on t01

1. `. ./setenv`, then `build`, and `python python/deploy.py`.
2. Copy both specs to LWW and register `ctf_1.0.0.yaml` again. The public event
   list needs the new IO area size as well.
3. Upload `LWWAdmin` with `python/uploadLWW.py`, for the new placeholder and the
   new frontend build.

## Testing

`python python/testIteration6.py [--target <name>] [<eventID>]` takes a CLOSED
event, or finds the first one, and the target's admin sign-in. It walks through:
- archiving it; archiving it again, archiving a published event, archiving an
  unknown event and restoring a published event refused;
- read-only: PUT of the event (also with `eventStatus` A), deleting it, an
  announcement and closing it again refused with `08 53`;
- lists: the admin list without filter leaves it out, filter A shows only
  archived events; the public list leaves it out, filter A shows it, filter D
  shows nothing; the event and its leaderboard still answer publicly;
- restoring it to CLOSED; restoring again refused; back in the admin list.

The event ends CLOSED, as it started, also when a check fails.
