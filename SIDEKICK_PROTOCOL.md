# Chronicle local RPC v1: ChronicleCompanion upload contract

> Adopted from the Sidekick-provided `chronicle-companion-rpc-v1.md` contract.
> Roadmap: [chronicle-sidekick#32](https://github.com/Emyrk/chronicle-sidekick/issues/32).
> The wire format below is authoritative for this addon; future ideas are not v1 features.
> Contract compatibility is covered by addon tests. This is not evidence of a completed
> end-to-end test against a released Sidekick build.

This document is the addon-facing contract supplied by Chronicle Sidekick.
It is intended to be copied into, or referenced by, the ChronicleCompanion
repository while its upload integration is updated.

RPC v1 is deliberately small. The only supported method is:

```text
combat_log.upload
```

The transport is asynchronous file IPC. ChronicleCompanion writes an immutable
combat-log archive and appends a request. Sidekick moves the archive into its
managed archive directory, uploads it through the normal Sidekick pipeline,
polls Chronicle processing, and publishes response snapshots for the addon.

## Required changes from the pre-RPC addon protocol

The earlier addon draft used `ChronicleSidekick.requests`,
`ChronicleSidekick.status`, an `upload` request action, and `REQUEST` status
records. Those names and records are **not RPC v1**.

Update ChronicleCompanion as follows:

| Earlier draft | RPC v1 |
|---|---|
| `ChronicleSidekick.requests` | `ChronicleRPC.requests` |
| `ChronicleSidekick.status` | `ChronicleRPC.status` |
| `1 upload <id> <time> <archive>` | `1 request <id> <time> combat_log.upload <archive>` |
| `1 retry <id> <time> <archive>` | `1 retry <id> <time> combat_log.upload <archive>` |
| `SIDEKICK ...` header | `RPC ...` header |
| `REQUEST <id> <archive> <state> ...` | `RESPONSE <id> combat_log.upload <state> ...` |

Sidekick does not read or write the earlier filenames or record shapes.

Example record lines below show separators as `<TAB>` (including trailing empty
fields). Write actual tab bytes to the files, not the marker text.

## Files

All paths are relative to the selected WoW installation's `CustomData/`
directory:

```text
ChronicleRPC.requests
ChronicleRPC.status
ChronicleUpload_<request-id>.txt
```

All protocol files use UTF-8, tab-separated fields, and LF line endings. Every
complete record ends in LF. Fields must not contain tabs, carriage returns, or
newlines. Protocol files are data and must never be evaluated as Lua.

## Request IDs and archive names

A request ID:

- Is 1 through 200 characters.
- Contains only ASCII letters, digits, `_`, and `-`.
- Is unique within one WoW installation.
- Remains the same for every retry of that upload.

The archive basename must be exactly:

```text
ChronicleUpload_<request-id>.txt
```

Sidekick rejects other names, path separators, symlinks, non-regular files, and
empty archives.

A suitable request ID is:

```text
<character>_<realm>_<unix-seconds>_<persisted-sequence>
```

## Request journal

ChronicleCompanion appends records to `ChronicleRPC.requests`. It does not
truncate the file. Sidekick durably deduplicates accepted request IDs across
restarts.

Sidekick ignores blank lines and malformed records. An unterminated final line
is ignored until a later append completes it.

### Upload request

The request has six fields:

```text
1<TAB>request<TAB>request-id<TAB>created-at<TAB>combat_log.upload<TAB>archive-basename<LF>
```

Example:

```text
1<TAB>request<TAB>Thrall_Nordanaar_1730000000_1<TAB>1730000000<TAB>combat_log.upload<TAB>ChronicleUpload_Thrall_Nordanaar_1730000000_1.txt
```

### Retry request

The retry has the same six-field shape:

```text
1<TAB>retry<TAB>request-id<TAB>requested-at<TAB>combat_log.upload<TAB>archive-basename<LF>
```

Example:

```text
1<TAB>retry<TAB>Thrall_Nordanaar_1730000000_1<TAB>1730000300<TAB>combat_log.upload<TAB>ChronicleUpload_Thrall_Nordanaar_1730000000_1.txt
```

`requested-at` identifies the retry attempt. Sidekick consumes a given retry
timestamp once. If that attempt later fails, the addon must append a newer
retry record instead of relying on the old record to run again.

A retry never creates a new archive and never clears the current active log.

### Safe append example

Prefixing the record with LF isolates it from an interrupted previous append.
Sidekick ignores the resulting blank line.

```lua
local function AppendRPCRecord(record)
    local ok, err = pcall(
        WriteCustomFile,
        "ChronicleRPC.requests",
        "\n" .. record .. "\n",
        "a"
    )
    if not ok or err == false then
        return false, (not ok and err) or "WriteCustomFile returned false"
    end
    return true
end

local line = table.concat({
    "1",
    "request",
    requestID,
    tostring(time()),
    "combat_log.upload",
    archiveBasename,
}, "\t")

local queued, queueErr = AppendRPCRecord(line)
```

## Upload boundary

Before appending the initial request, ChronicleCompanion must:

1. Snapshot the active on-disk log.
2. Include remaining deferred flush lines in order.
3. Include the current in-memory buffer in order.
4. Write `ChronicleUpload_<request-id>.txt`.
5. Read the archive back and verify the exact bytes.
6. Clear and verify the active log.
7. Reset the logging session and tracking caches.
8. Append the RPC request.
9. Continue logging into a fresh active log.

If the request append fails, keep the verified archive and expose a retry action.
Do not recreate the archive during retry.

After durable acceptance, Sidekick moves the archive to:

```text
<WoW>/ChronicleSidekick/<archive-group-id>/<timestamp>_CombatLog.txt
```

The managed copy then uses Sidekick's normal upload ledger, duplicate checks,
retry behavior, restart recovery, and retention policy.

## Status snapshot

Sidekick publishes `ChronicleRPC.status` by writing a temporary file and
atomically replacing the previous snapshot. The file is at most 256 KiB and
always ends in LF.

The addon must parse the snapshot strictly. If a replacement is malformed,
incomplete, too large, or unsupported, retain the last valid snapshot until its
heartbeat becomes stale.

### Header

The first line has six fields:

```text
RPC<TAB>1<TAB>sidekick-version<TAB>heartbeat<TAB>readiness<TAB>message<LF>
```

Example:

```text
RPC<TAB>1<TAB>0.16.0<TAB>1730000010<TAB>ready<TAB>
```

`heartbeat` is Unix seconds from the local machine. Sidekick normally refreshes
the snapshot on its five-second engine poll.

Initial readiness values are:

- `ready`
- `sign_in_required`

Other non-ready values may be added. Treat any value other than `ready` as
non-ready and display the message when present. No credentials are written to
the status file.

The addon should consider a heartbeat stale when its age is greater than 20
seconds. A heartbeat up to 5 seconds in the future may be accepted for minor
clock/timing differences.

### Response record

Each response has seven fields:

```text
RESPONSE<TAB>request-id<TAB>method<TAB>state<TAB>created-at<TAB>updated-at<TAB>message<LF>
```

Example:

```text
RESPONSE<TAB>Thrall_Nordanaar_1730000000_1<TAB>combat_log.upload<TAB>processing<TAB>1730000000<TAB>1730000020<TAB>
```

The method is always `combat_log.upload` in RPC v1.

States are:

- `queued`: durably accepted but not currently uploading.
- `uploading`: Sidekick is sending the managed archive to Chronicle.
- `processing`: Chronicle accepted the upload and its parser is running.
- `complete`: Chronicle processing reached a successful terminal state.
- `failed`: upload or processing reached a terminal failure.

A missing response does not prove failure. The request may not have been read
yet, or completed history may have aged out of the bounded display snapshot.
The addon should keep a local unacknowledged request visible until Sidekick
publishes a matching response.

### Instance record

A response may be followed by zero or more instance records:

```text
INSTANCE<TAB>request-id<TAB>instance-id<TAB>instance-name<TAB>https-url<LF>
```

Example:

```text
INSTANCE<TAB>Thrall_Nordanaar_1730000000_1<TAB>550e8400-e29b-41d4-a716-446655440000<TAB>Molten Core<TAB>https://chronicleclassic.com/instances/molten-core-abc
```

Instance records belong to the nearest matching request ID, not to a separate
processing state. Sidekick may publish instances while the response is still
`processing`. The addon should display every valid instance URL it receives.

URLs are HTTPS and contain no whitespace. Stock Vanilla chat does not make web
URLs clickable, so copy-to-clipboard behavior or a URL-handling addon may still
be required.

## Example complete status file

```text
RPC<TAB>1<TAB>0.16.0<TAB>1730000040<TAB>ready<TAB>
RESPONSE<TAB>Thrall_Nordanaar_1730000000_1<TAB>combat_log.upload<TAB>complete<TAB>1730000000<TAB>1730000040<TAB>
INSTANCE<TAB>Thrall_Nordanaar_1730000000_1<TAB>11111111-1111-1111-1111-111111111111<TAB>Molten Core<TAB>https://chronicleclassic.com/instances/molten-core-abc
INSTANCE<TAB>Thrall_Nordanaar_1730000000_1<TAB>22222222-2222-2222-2222-222222222222<TAB>Blackwing Lair<TAB>https://chronicleclassic.com/instances/blackwing-lair-def
```

## Retry behavior

### Upload failure

If the response is `failed` and has no Chronicle processing result, appending a
new retry record requeues the retained managed archive. Sidekick does not create
or mutate an archive during retry.

### Sign-in required

If Chronicle authentication is missing or rejected:

- The header readiness is `sign_in_required`.
- A durably accepted upload remains `queued`.
- Sidekick retains the managed archive.
- Sidekick resumes the blocked job after sign-in changes.
- The addon does not need to create a new request.

### Processing failure

If upload succeeded but Chronicle parsing failed, Sidekick retains the Chronicle
log ID. A new retry record asks Chronicle to reparse that log through:

```text
POST /api/v1/raidlogs/logs/<log-id>/reparse
```

Sidekick does not upload the combat log again. The response returns to
`processing` and is polled to another terminal state.

## Deduplication rules

For a request ID already known to Sidekick:

- Repeated `request` records do nothing.
- `retry` while queued, uploading, or processing does nothing.
- `retry` after completion does nothing.
- A newer `retry` after upload failure requeues the managed archive.
- A newer `retry` after processing failure reparses the existing Chronicle log.

Sidekick persists request deduplication beyond the 24-hour completed-response
display window.

## Addon polling guidance

Recommended polling intervals:

- Every 2 seconds while the Sidekick/upload pane is visible.
- Every 10 seconds while hidden.
- Immediately after appending a request or retry.

Polling must never send chat messages or initiate another upload. Announcements
and retries require an explicit user action.

## Security boundary

The addon controls only:

- The request ID.
- The request timestamp.
- The allowlisted method name.
- The matching generated archive basename.

The addon cannot specify URLs, HTTP methods, headers, tokens, Chronicle API
routes, arbitrary file paths, SQL, or Lua code. Sidekick selects and authenticates
all Chronicle API operations.

## Out of scope for RPC v1

The following are future work and must not be added to the addon as undocumented
RPC v1 methods:

- `instance.prepare`
- Character, guild, ranking, roster, encounter, or loot queries
- SQLite cache creation or querying
- Arbitrary API proxying
- Subscriptions or streaming
- General cancellation

Future data APIs are expected to use file RPC for commands and status, with a
Sidekick-written SQLite cache for larger queryable results.

## Addon validation checklist

- [x] Writes only `ChronicleRPC.requests`.
- [x] Reads only `ChronicleRPC.status` for RPC state.
- [x] Uses six-field `request` and `retry` records.
- [x] Includes the exact method `combat_log.upload`.
- [x] Generates the exact matching archive basename.
- [x] Verifies archive bytes before clearing the active log.
- [x] Retains failed/unacknowledged requests locally.
- [x] Does not recreate archives during retry.
- [x] Strictly parses the six-field header and seven-field responses.
- [x] Supports multiple `INSTANCE` records per response.
- [x] Retains the last valid snapshot after malformed reads.
- [x] Treats stale heartbeat as offline, not upload failure.
- [x] Requires user action for retry and chat announcement.

## ChronicleCompanion implementation notes

- `sidekick.lua` implements the RPC transport; the existing Lua namespace remains
  `ChronicleSidekick`. It writes only `ChronicleRPC.requests` and reads only
  `ChronicleRPC.status`. The draft `ChronicleSidekick.requests/.status` files are
  neither read nor written. There is no legacy wire-format fallback.
- Responses contain the method, not a filename. The addon derives the display
  filename exactly as `ChronicleUpload_<request-id>.txt`.
- The addon never deletes or truncates either request journal. Issue #32 permits
  optional Sidekick journal cleanup only when no WoW process using the installation
  is running, every complete record is durably handled, failures remain recoverable,
  and cleanup cannot race a newly starting client. This is separate from Sidekick's
  managed archive retention, which may delete eligible managed files independently.
- Unacknowledged requests use SavedVariables, written by WoW on logout/reload.
  On upgrade, pre-RPC local pending entries become explicit retryable entries;
  migration never sends an upload automatically. Retry submits an initial RPC
  `request` for such entries, reusing their archive. Old journal-only entries
  cannot be reconstructed automatically; retain their archives for recovery.
- RPC retries use a persisted per-request timestamp watermark, greater than the
  previous attempt and observed failure timestamp, even for rapid repeated clicks.
  Processing-failure retries are still just `combat_log.upload` retry records:
  only Sidekick decides whether to reupload or reparse the existing Chronicle log.
- A valid response acknowledges durable Sidekick ownership. The addon does not
  require the original CustomData archive to exist for a server-side retry,
  because Sidekick may have moved it into its managed directory. Do not promise
  indefinite local retention: Sidekick owns managed archive retention/deletion.
- The safe boundary preserves active data on archive write/readback or active-log
  clear failures. Delete, Backup, and upload share session resets, including
  unit, talent, transmog, instance-ID, raid-composition, and Ursol tracking state.
- `/clog` has one collapsible right tray, switched between Extra Events and
  Sidekick. Sidekick shows recent responses and every instance link on displayed
  responses, grouped in bordered log cards with local date/time headings and
  instance counts instead of raw archive filenames. Completed logs with links do
  not show a redundant complete label; pending/error states stay visible. Instance
  rows have Copy and explicit Announce actions (Say/Yell/Guild/Party/Raid).
  Announcements include instance name and URL. No polling sends chat or retries.

### Verification and remaining integration checks

Run all `tests/*_test.lua` files with Lua 5.0.3. `tests/sidekick_test.lua` covers
exact six-field request/retry serialization, Sidekick's supplied complete-status
example, strict method/ID/record validation, retry timestamps across reloads,
archive failures, migration, and multi-instance log-level processing state.
`tests/sidekick_ui_test.lua` covers trays, copy links, and chat announcements.

These are contract tests, not an actual Sidekick/Chronicle upload. Before release,
verify against a Sidekick build implementing RPC v1: durable acceptance and archive
movement, blocked sign-in/resume, upload retry, processing-failure reparse, multiple
instance URLs, restart recovery, and stale/malformed status behavior. Also verify
in-game rendering and chat behavior with the target client.

### Future ideas, not implemented RPC methods

[Sidekick issue #32](https://github.com/Emyrk/chronicle-sidekick/issues/32) describes
file RPC as the command/status transport and a possible Sidekick-written,
addon-readable SQLite cache for larger Chronicle datasets. Instance preparation,
character/guild/ranking/roster/encounter/loot queries, subscriptions, arbitrary API
proxying, and cancellation remain outside v1. No addon SQLite dependency or
additional method is introduced here; future methods need an agreed contract.

### Diagnosing an upload stall

A manual Archive and Upload attempt writes a bounded local breadcrumb trail to
`CustomData/ChronicleRPC.debug`. This is diagnostic text, **not an RPC file**;
Sidekick must ignore it. The latest attempt replaces the previous trace. It
contains stages, timestamps, archive filenames, and byte counts, but no combat-log
contents or credentials. Polling and chat announcements do not write the trace.
After a client hang, retain the trace and both active/archive log files. The last
stage identifies the operation entered; it does not prove that operation finished.

Archive-name allocation uses `ReadCustomFile` (nil means missing; any string,
including empty, means occupied) rather than `CustomFileExists`. The reported
in-game runtime marked all generated names as existing through the latter API,
so the original collision loop never terminated. Read errors abort safely and
existing readable archives are never overwritten. Allocation is limited to 32
probes and rejects invalid/precision-
stalled saved counters. Native slider callbacks are suppressed while the options
panel programmatically refreshes values, avoiding recursive refresh callbacks.
These guards address identifiable hazards; they do not establish the cause of any
reported in-game hang without client diagnostics.
