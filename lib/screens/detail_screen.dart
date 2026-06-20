import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';

class DetailScreen extends StatefulWidget {
  final Post post;
  const DetailScreen({super.key, required this.post});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      appBar: AppBar(title: const Text('Post Detail')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Hero(
              tag: post.id,
              child: _showRaw
                  ? CachedNetworkImage(
                imageUrl: post.rawUrl,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                fadeInDuration: const Duration(milliseconds: 300),
                placeholder: (context, url) => CachedNetworkImage(
                  imageUrl: post.mobileUrl,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
              )
                  : CachedNetworkImage(
                imageUrl: post.mobileUrl,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                fadeInDuration: const Duration(milliseconds: 300),
                placeholder: (context, url) => CachedNetworkImage(
                  imageUrl: post.thumbUrl,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showRaw ? null : () => setState(() => _showRaw = true),
              icon: const Icon(Icons.download),
              label: Text(_showRaw ? 'High-Res Loaded' : 'Download High-Res'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}