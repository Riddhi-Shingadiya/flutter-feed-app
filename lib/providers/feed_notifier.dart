import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../models/post.dart';
import 'feed_state.dart';
import 'supabase_provider.dart';

class FeedNotifier extends Notifier<FeedState> {

  final Map<String, bool> _confirmedLikeState = {};

  final Map<String, Timer> _likeDebounceTimers = {};

  @override
  FeedState build() {
    ref.onDispose(() {
      for (final timer in _likeDebounceTimers.values) {
        timer.cancel();
      }
    });
    Future.microtask(fetchInitial);
    return FeedState(isLoading: true);
  }

  Future<void> fetchInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .range(0, kPageSize - 1);

      final posts = (response as List).map((e) => Post.fromMap(e)).toList();
      final merged = await _mergeLikeStatus(posts);
      _recordConfirmedState(merged);

      state = state.copyWith(
        posts: merged,
        isLoading: false,
        hasMore: posts.length == kPageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final start = state.posts.length;
      final response = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .range(start, start + kPageSize - 1);

      final newPosts = (response as List).map((e) => Post.fromMap(e)).toList();
      final merged = await _mergeLikeStatus(newPosts);
      _recordConfirmedState(merged);

      state = state.copyWith(
        posts: [...state.posts, ...merged],
        isLoadingMore: false,
        hasMore: newPosts.length == kPageSize,
      );
    } catch (e) {
      debugPrint('fetchNextPage ERROR: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
        hasMore: false,
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null, hasMore: true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .range(0, kPageSize - 1);

      final posts = (response as List).map((e) => Post.fromMap(e)).toList();
      final merged = await _mergeLikeStatus(posts);
      _recordConfirmedState(merged);

      state = state.copyWith(
        posts: merged,
        isLoading: false,
        hasMore: posts.length == kPageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }


  void toggleLike(String postId) {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = state.posts[index];
    final optimistic = post.copyWith(
      isLiked: !post.isLiked,
      likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
    );
    final updatedList = [...state.posts];
    updatedList[index] = optimistic;
    state = state.copyWith(posts: updatedList);


    _likeDebounceTimers[postId]?.cancel();
    _likeDebounceTimers[postId] = Timer(
      const Duration(milliseconds: 500),
      () => _syncLike(postId),
    );
  }

  Future<void> _syncLike(String postId) async {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final currentLiked = state.posts[index].isLiked;
    final confirmedLiked = _confirmedLikeState[postId] ?? false;


    if (currentLiked == confirmedLiked) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .rpc(
            'toggle_like',
            params: {'p_post_id': postId, 'p_user_id': kTestUserId},
          )
          .timeout(const Duration(seconds: 5));
      _confirmedLikeState[postId] = currentLiked;
    } catch (e) {
      debugPrint('toggleLike sync ERROR: $e');
      final rollbackIndex = state.posts.indexWhere((p) => p.id == postId);
      if (rollbackIndex != -1) {
        final original = state.posts[rollbackIndex];
        final reverted = original.copyWith(
          isLiked: confirmedLiked,
          likeCount: confirmedLiked
              ? (original.isLiked ? original.likeCount : original.likeCount + 1)
              : (original.isLiked
                    ? original.likeCount - 1
                    : original.likeCount),
        );
        final rollbackList = [...state.posts];
        rollbackList[rollbackIndex] = reverted;
        state = state.copyWith(
          posts: rollbackList,
          likeError: 'Couldn\'t sync like — check your connection',
        );
      }
    }
  }

  void clearLikeError() {
    state = state.copyWith(clearLikeError: true);
  }


  void _recordConfirmedState(List<Post> posts) {
    for (final p in posts) {
      _confirmedLikeState[p.id] = p.isLiked;
    }
  }

  Future<List<Post>> _mergeLikeStatus(List<Post> posts) async {
    if (posts.isEmpty) return posts;
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase
        .from('user_likes')
        .select('post_id')
        .eq('user_id', kTestUserId)
        .inFilter('post_id', posts.map((p) => p.id).toList());

    final likedIds = (response as List)
        .map((e) => e['post_id'] as String)
        .toSet();
    return posts
        .map((p) => p.copyWith(isLiked: likedIds.contains(p.id)))
        .toList();
  }
}

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
