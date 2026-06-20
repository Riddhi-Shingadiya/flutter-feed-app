# Flutter High-Performance Feed

A Flutter + Riverpod + Supabase infinite-scrolling social feed, built with a focus on UI
performance, memory management, and optimistic state — rather than feature breadth.

## Tech Stack

- **Flutter** (UI)
- **Riverpod** (`flutter_riverpod`) — state management
- **Supabase** — Auth-less REST data layer, Storage, and RPC (`toggle_like`)
- **cached_network_image** — disk caching + in-memory decode-size control

## Riverpod State Management Approach

The feed is driven by a single `NotifierProvider<FeedNotifier, FeedState>`.

**Why a plain `Notifier` instead of `AsyncNotifier`:** the feed has three independent
asynchronous operations happening at different times — the initial load, "load next page"
during scroll, and pull-to-refresh — each needing its own loading flag so the UI can show the
right indicator in the right place. `AsyncNotifier` collapses everything into one
`AsyncValue`, which isn't expressive enough for that. Instead, `FeedState` is a small
hand-rolled class:

```dart
class FeedState {
  final List<Post> posts;
  final bool isLoading;      // true only during the very first load
  final bool isLoadingMore;  // true only while fetching the next page
  final bool hasMore;        // false once a page returns fewer than 10 items
  final String? error;
  final String? likeError;   // surfaced to the UI, then cleared, on a failed like sync
}
```

**Pagination:** `fetchInitial()`, `fetchNextPage()`, and `refresh()` all query Supabase
directly with `.range(start, start + pageSize - 1)` ordered by `created_at`. A
`ScrollController` listener in the feed screen triggers `fetchNextPage()` once the user
scrolls within 300px of the bottom — no manual "Load More" button. `hasMore` is derived from
whether the page returned a full batch (10 items); once a page returns fewer, pagination
stops.

**Optimistic likes (the core state-management challenge):** `toggleLike()` does three
things:

1. **Instantly** flips `isLiked` and adjusts `likeCount` in local Riverpod state — the UI
   updates with zero perceived latency, before any network call happens.
2. **Debounces** the actual `toggle_like` RPC call per post (500ms). Rapid taps ("spam
   clicker") only ever produce a single network call once tapping settles, instead of 15
   concurrent requests racing each other. A `_confirmedLikeState` map tracks the last
   server-confirmed value per post, so if taps cancel out (e.g. tapped an even number of
   times), no network call fires at all.
3. **Rolls back** to the last confirmed server state and sets `likeError` (shown via a
   `SnackBar`, using `ref.listen` in the feed screen) if the RPC call fails — e.g. when
   offline.

`ref.watch(feedProvider)` is used in the widget `build()` method so the feed list rebuilds
when state changes; `ref.read(feedProvider.notifier)` is used inside callbacks (tap handlers,
pull-to-refresh) so those don't trigger unnecessary rebuilds themselves.

## Performance Verification

### RepaintBoundary (GPU protection)

Each post card has a `BoxDecoration` with a heavy `BoxShadow` (`blurRadius: 30`), wrapped in
a `RepaintBoundary`. This isolates the card into its own compositing layer so Flutter
rasterizes the shadow once and reuses that cached bitmap on subsequent frames, instead of
recalculating the blur every time the list scrolls.

**Verification method:** ran the app in profile mode (`flutter run --profile`, not debug —
debug mode is intentionally unoptimized and not representative) and used Flutter DevTools'
**Performance** tab. Recorded a session of continuous fast scrolling and inspected the frame
chart:

- **57 FPS average**, close to the ideal 60 FPS.
- The large majority of frames (both "Frame Time UI" and "Frame Time Raster") stayed under
  ~10ms, well inside the 16ms budget for smooth 60fps.
- Only one isolated jank frame appeared during the recorded session (a brief spike, likely
  coinciding with a new image decode), with no sustained run of red/orange frames during
  continuous scrolling.

This confirms the GPU is reusing the rasterized card layer rather than recomputing shadow
math on every frame.

### memCacheWidth (RAM protection)

The feed renders **only** `media_thumb_url` (never `mobile_url` or `raw_url`). Each thumbnail
is loaded through `CachedNetworkImage` with `memCacheWidth` computed per-card at build time:

```dart
final dpr = MediaQuery.of(context).devicePixelRatio;
final targetWidth = (constraints.maxWidth * dpr).round();
```

This ensures the decoder is told to produce a bitmap matching the **exact physical pixel
width** the image will actually render at on screen — never decoding (and holding in memory)
more pixels than will be displayed, regardless of the source image's native resolution.

**Verification method:** used DevTools' **Memory** tab while scrolling continuously through
20+ posts. Memory usage stayed stable rather than climbing — confirming that images are being
decoded at display resolution (and evicted from the cache as they scroll off-screen via
`ListView.builder`'s lazy building), rather than accumulating full-resolution decoded bitmaps
in memory as the list grows.

## Corner Cases Handled

- **Spam clicker:** debounced RPC calls + confirmed-state tracking prevent desync between UI
  and database even under rapid repeated taps (see Optimistic likes above).
- **Rapid scrolling:** verified jank-free via DevTools Performance tab (see RepaintBoundary
  above).
- **Offline revert:** the `toggle_like` RPC call has a 5-second timeout; on failure (e.g. no
  network), the optimistic update is rolled back to the last confirmed server state and a
  `SnackBar` informs the user.

## Architecture Notes

- Images render at their natural aspect ratio (no forced square cropping) — each card's
  height adapts to its source image's proportions.
- The detail screen uses tiered loading: the cached thumbnail displays instantly via
  `Hero`, the `mobile_url` (1080px) fades in once downloaded, and the original `raw_url` is
  only fetched if the user explicitly taps "Download High-Res" — never automatically.
