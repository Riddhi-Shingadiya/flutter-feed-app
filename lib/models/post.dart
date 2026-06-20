class Post {
  final String id;
  final DateTime createdAt;
  final String thumbUrl;
  final String mobileUrl;
  final String rawUrl;
  final int likeCount;
  final bool isLiked;

  Post({
    required this.id,
    required this.createdAt,
    required this.thumbUrl,
    required this.mobileUrl,
    required this.rawUrl,
    required this.likeCount,
    this.isLiked = false,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      thumbUrl: map['media_thumb_url'] as String,
      mobileUrl: map['media_mobile_url'] as String,
      rawUrl: map['media_raw_url'] as String,
      likeCount: map['like_count'] as int,
    );
  }


  Post copyWith({
    int? likeCount,
    bool? isLiked,
  }) {
    return Post(
      id: id,
      createdAt: createdAt,
      thumbUrl: thumbUrl,
      mobileUrl: mobileUrl,
      rawUrl: rawUrl,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}