# Chronicle Sidekick addon IPC — version 1

This is the **addon-side contract**, not a claim that Sidekick already implements it.
All files live in the selected WoW installation's `CustomData/` directory. Files
are UTF-8 TSV, with LF line endings. No file is evaluated as Lua. Field values
must not contain tabs, CRs, or newlines; Sidekick should replace these with spaces
in display strings. Timestamps are Unix seconds from the local machine.

## Upload boundary

**Archive and upload** creates `ChronicleUpload_<request-id>.txt`. The ID includes
character, realm, timestamp, and a persisted counter; existing archive filenames
are never overwritten. The addon snapshots the active file, remaining deferred
flush lines, and the current buffer in order. It verifies the archive by reading
it back **before** clearing the active file or resetting caches. This avoids the
normal save path's existing behavior of clearing buffers after write errors.
After success it uses the shared Delete/Archive session reset, including unit,
talent, transmog, instance-ID, raid-composition, and Ursol tracking caches. It
starts fresh zone metadata and schedules a fresh raid composition snapshot.

Only then is the request appended. Queue failure retains the immutable archive
and a locally retryable request; retrying never resets the new log. Archives are
not deleted after upload. If clearing the active file fails, the archive may
exist, but no request is queued and in-memory state is retained. Do not manually
upload both that archive and the still-active log without checking for overlap.
Local pending requests and the counter use SavedVariables, which WoW persists
on logout/reload, not immediately; the archive itself is the durable recovery
copy if the client crashes before a failed queue operation can be retried.

## `ChronicleSidekick.requests` — addon writes, Sidekick reads

Each record has five fields:

```text
1<TAB>upload<TAB>request-id<TAB>created-at<TAB>archive-basename<LF>
1<TAB>retry<TAB>request-id<TAB>requested-at<TAB>archive-basename<LF>
```

`upload` is idempotent by ID. `retry` explicitly retries a failed request using
that same ID and archive. Repeated retries while already queued/uploading must
not start concurrent uploads. Sidekick must durably accept requests before
acknowledging them in status and persist deduplication across restarts, including
beyond the 24-hour display history. A retry should first publish a non-failed
state (e.g. `queued`) and use an updated timestamp for subsequent failure states.

The addon prefixes each append with LF to isolate an interrupted prior append.
Ignore blank lines and reject/skip malformed complete records; leave an
unterminated trailing record until the next read. Validate IDs and restrict
filenames to generated `ChronicleUpload_*.txt` basenames within `CustomData/`:
no absolute paths, traversal, or symlinks escaping the directory.

**The addon never deletes or truncates this file.** Sidekick may delete it only
when no WoW process using this installation is running, and all requests are
durably handled. Failed requests must remain pending or be durably stored for
retry before cleanup. Sidekick must coordinate process/startup detection with
cleanup to avoid racing a client opening the file.

## `ChronicleSidekick.status` — Sidekick writes, addon reads

Publish an entire snapshot via a temporary file and atomic replacement. Keep it
at or below 256 KiB. Every line, including the last, ends with LF. The first line
has six fields:

```text
SIDEKICK<TAB>1<TAB>sidekick-version<TAB>heartbeat<TAB>readiness<TAB>message<LF>
```

`readiness` is `ready`, `sign_in_required`, `folder_not_configured`, or another
non-ready reason. Empty messages are allowed (retain the final tab). No auth
secrets belong in this file. Refresh about every 5 seconds while the configured
WoW client is running. The addon requires heartbeat age between -5 and 20 seconds
and `readiness=ready` to enable uploading. A stale heartbeat means offline, not
that an upload failed.

Follow the header with request records (seven fields), and each request's
instance records (five fields):

```text
REQUEST<TAB>request-id<TAB>archive-basename<TAB>state<TAB>created-at<TAB>updated-at<TAB>message<LF>
INSTANCE<TAB>request-id<TAB>instance-id<TAB>instance-name<TAB>https-url<LF>
INSTANCE<TAB>request-id<TAB>another-instance-id<TAB>another-name<TAB>https-url<LF>
```

Request states: `queued`, `uploading`, `processing`, `complete`, `failed`.
**Processing state belongs to the whole log/request, never to an instance.**
Instances only contain ID, display name, and URL. Include all discovered instance
links, including while processing. URLs must be HTTPS without whitespace.
Sidekick must use Chronicle's actual processing result/API to report completion;
a successful upload HTTP response alone does not imply processing completed.

Place each REQUEST before its INSTANCE records. Request IDs are unique within a
snapshot. Include recent request history from the last 24 hours, plus outstanding
requests even if older. Bound snapshot size, preserving outstanding records and
preferring newer completed history if pruning is needed. This display window does
not govern deduplication or archive retention.

The addon ignores malformed/incomplete/unsupported snapshots and retains its
last good state until the heartbeat expires. It polls every 2 seconds while the
Sidekick pane is visible, every 10 seconds otherwise, and immediately on opening
Sidekick or initiating an action. Local unacknowledged requests remain visible;
failed requests can be retried without creating another archive.

## UI and testing

`/clog` or `/chronicle config` opens the main panel. **Extra Events** and
**Sidekick** toggle one shared right tray; clicking the active toggle or the tray
minimize button collapses it. Selection is saved in SavedVariables. Sidekick
shows connection state, recent log requests, retry actions, and copyable instance
links. **Archive and upload...** asks for confirmation and opens Sidekick after
queueing. Upload availability depends on a compatible live Sidekick status.

Automated Lua 5.0.3 tests:

```sh
lua tests/sidekick_test.lua
lua tests/sidekick_ui_test.lua
```

In-game smoke checks still required: confirm the window fits the chosen UI scale,
collapse/switch panes, queue a small log against a compatible Sidekick, log more
data during upload, verify the archived bytes stay unchanged, simulate queue and
status errors, and copy links from a multi-instance log.
