# UX Telemetry Event Schema (Stage C)

Collection: `telemetry_events`

## Core Fields
1. `event_name` (string)
2. `event_group` (string): `discovery | header | engagement | navigation | system`
3. `screen` (string): e.g. `feed`, `search`, `notifications`
4. `user_id` (string)
5. `role` (string)
6. `session_id` (string)
7. `metadata` (map)
8. `created_at` (Firestore server timestamp)
9. `client_created_at` (ISO UTC string fallback for diagnostics)

## Implemented Events
1. `header_action`
2. `discovery_rail_tap`
3. `engagement_action`
4. `navigation_action`
5. `search_performed`
6. `notifications_mark_all_read`
7. `otp_verify_success`

## Dashboard-Friendly Metrics
1. Discovery rail CTR:
- `event_name=discovery_rail_tap`, grouped by `metadata.rail_label`.

2. Header interaction rate:
- `event_name=header_action`, grouped by `metadata.action`.

3. Engagement action mix:
- `event_name=engagement_action`, grouped by `metadata.action`.

4. Post detail open funnel:
- `event_name=navigation_action` with `metadata.destination=post_detail`.

5. Search quality proxies:
- `event_name=search_performed` with `metadata.query_length`, `metadata.filter`.

## Privacy Notes
1. Raw search query text is not logged.
2. Event writes are best-effort and non-blocking.
