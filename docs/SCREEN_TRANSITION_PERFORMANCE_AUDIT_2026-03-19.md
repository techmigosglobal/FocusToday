# Screen Transition & Loading Performance Audit (2026-03-19)

## Objective
Validate screen transition smoothness and loading responsiveness across primary workflows (public, reporter, admin, super-admin), and enforce expected UX-performance level.

## Expected UX-Performance Baseline
1. Transition animation should feel intentional and complete quickly (target <= 300ms).
2. Navigation action should show visible feedback instantly (same-frame tap response + transition start).
3. Heavy data fetch should not block first route frame.
4. Empty/loading/error states must prevent blank screens.

## What Was Analyzed
1. Route transition usage patterns (`MaterialPageRoute` vs custom smooth routes).
2. Initial loading behavior in key screens (`initState`, `addPostFrameCallback`, async fetch timing).
3. Loading/empty-state consistency for high-traffic workflows.

## Code-Level Findings
1. Transition inconsistency existed due to mixed route usage.
2. Several high-traffic screens started data loading immediately in `initState`, risking transition frame contention.
3. Core flows already had loading states, but transitions were not uniformly premium.

## Implemented Optimizations
1. Transition timing refinement in shared route system:
- `SmoothPageRoute`: 280ms forward / 220ms reverse
- `SlidePageRoute`: 280ms forward / 220ms reverse
- `ScalePageRoute`: 320ms forward / 240ms reverse

2. Transition standardization in high-traffic flows:
- Notifications module navigations switched to `SmoothPageRoute`
- Search result navigations switched to `SmoothPageRoute`
- Moderation module navigations switched to `SmoothPageRoute`
- All Posts module navigations switched to `SmoothPageRoute`
- Workspace and Settings role-module navigations switched to `SmoothPageRoute`

3. First-frame loading deferral (to protect transition smoothness):
- Notifications screen load deferred via `addPostFrameCallback`
- Moderation screen initial load deferred via `addPostFrameCallback`
- All Posts screen initial load deferred via `addPostFrameCallback`
- Settings screen load deferred via `addPostFrameCallback`
- Profile screen initial data/language load deferred via `addPostFrameCallback`

## Current Snapshot
1. `SmoothPageRoute` usages: 83
2. `MaterialPageRoute` usages (remaining): 0
3. `addPostFrameCallback` usages in features: 8

## Residual Risk / Next Perf Pass
1. True frame-time validation (jank %, raster/UI frame budget) still needs on-device profile mode run.
2. Some screens still do large in-memory list transforms in build-sensitive paths; optimize further if timeline shows spikes.

## Recommended Runtime Validation (Device)
1. Run in profile mode and record DevTools timeline for:
- Feed -> Post Detail
- Feed -> Workspace -> Moderation
- Settings -> Role module navigation chain
- Search -> Post/Profile detail

2. Validate targets:
- No perceptible transition hitching.
- Initial route frame paints before heavy data load spinner updates.
- No frame spikes >16ms sustained during push/pop.

## Verification
- `flutter analyze` on all modified transition/loading screens: pass
- `flutter test test/widget_test.dart`: pass
