# Flutter Client Test Fixtures

Fixture catalog for the Flutter rewrite. Fixtures should be small, deterministic, and safe to commit. Do not include real provider credentials, paid streams, or private playlist URLs.

## Categories

### Xtream auth

- Successful m3u-editor auth response with `user_info.auth = 1` and `m3u_editor.version`.
- Failed auth response with `auth = 0`.
- Error-shaped response such as `{ "error": "Unauthorized" }`.
- Non-m3u-editor Xtream-compatible response to verify current parity rejection or explicit rewrite decision.

### Direct M3U valid

- Minimal `#EXTM3U` playlist with one `#EXTINF` and stream URL.
- Multiple channels with logos, groups, and EPG ids.
- Streams with relative oddities such as whitespace around attributes.

### Direct M3U malformed

- Missing `#EXTM3U` header.
- `#EXTINF` without a following URL.
- URL without preceding `#EXTINF`.
- Badly quoted attributes.
- Empty lines, comments, duplicate ids, duplicate names.

### Direct M3U grouping

- Channels with `group-title` values.
- Channels without `group-title` for default/ungrouped behavior.
- Duplicate group names with different casing/spacing.

### Direct M3U EPG mapping

- `tvg-id` exact match to EPG channel id.
- `tvg-name` fallback match.
- Display-name fallback match.
- Missing EPG id/name with no programme match.

### Live

- Xtream live categories response.
- Live streams with `stream_id`, `stream_icon`, `category_id`, and `epg_channel_id`.
- Empty category and empty streams responses.
- Favorite live channel identity fixture.

### VOD

- VOD categories and streams.
- VOD info with poster, backdrop, rating, duration, genre, plot, director, and actors.
- Unsupported container extension fixture for playback fallback decisions.

### Series

- Series categories/list response.
- Series info with seasons.
- Series info missing seasons but containing episode keys, to verify season synthesis.
- Episode progress fixture with incomplete and completed episodes.

### EPG

- `get_short_epg` current/next response.
- `get_epg_batch` response for multiple streams.
- `get_simple_data_table` full-day response.
- Base64 encoded Xtream titles/descriptions and plain m3u-editor titles/descriptions.
- Expired/no-current-programme schedule.

### Subtitles

- Track list with no subtitles.
- Track list with multiple subtitle languages and titles.
- Disabled/off subtitle selection state.

### Audio tracks

- Track list with one default audio track.
- Track list with multiple language/title variants.
- Disabled/auto audio selection state where the backend supports it.

### Direct playback

- HLS `.m3u8` URL.
- MP4/WebM direct URL.
- Unsupported container URL that should trigger native/mpv or fallback behavior.
- Stream metadata requiring custom user-agent/header handling.

### Transcoding success

- Playback failure input followed by server transcode session creation success.
- Transcoded stream URL response.
- Progress/buffering events for transcoded playback.

### Transcoding failure

- Server transcode unavailable response.
- Transcode start failure.
- Transcoded stream stalls/errors after start.
- User-facing error state fixture.


## Production Playback Vertical Slice

`production_stream_catalog.dart` is the deterministic playback fixture catalog for release-gate tests. It uses only loopback/fake paths resolved against `FakeM3uEditorServer`; it contains no provider hosts, private tokens, or credentials.

Covered fixtures:

- HLS live stream with user-agent/header metadata and broadcast cleanup metadata.
- MP4 VOD stream with resume-friendly metadata.
- Unsupported codec stream (`vp9`/`opus`) that must fall back through `PlaybackOrchestrator`.
- Dead stream URL served by the fake server as deterministic `404`.
- Expired token URL served by the fake server as deterministic `403`.
- Stalled transcode metadata (`scenario: stalled`) for recoverable server fallback errors.
- Subtitle and audio track metadata with deterministic English/Spanish variants.
