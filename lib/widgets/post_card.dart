import 'package:flutter/material.dart';
import '../models/post.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Hero(
                tag: post.id,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final targetWidth = (constraints.maxWidth * dpr).round();
                    return CachedNetworkImage(
                      imageUrl: post.thumbUrl,
                      memCacheWidth: targetWidth,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey[200],
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onLikeTap,
                    child: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : Colors.grey[600],
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${post.likeCount}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
