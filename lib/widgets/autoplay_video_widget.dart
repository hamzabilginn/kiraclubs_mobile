import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AutoplayVideoWidget extends StatefulWidget {
  final String videoUrl;
  final String? placeholderUrl;
  
  const AutoplayVideoWidget({
    Key? key,
    required this.videoUrl,
    this.placeholderUrl,
  }) : super(key: key);

  @override
  State<AutoplayVideoWidget> createState() => _AutoplayVideoWidgetState();
}

class _AutoplayVideoWidgetState extends State<AutoplayVideoWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      // Add a 3-second timeout to prevent infinite hangs on unsupported codecs/networks
      await _controller.initialize().timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0.0); // Muted by default
        _controller.play();
      }
    } catch (e) {
      debugPrint('Video initialization error for ${widget.videoUrl}: $e');
      try {
        _controller.dispose();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _controller.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildPlaceholder();
    }
    
    if (!_isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildPlaceholder(),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            ),
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholderUrl != null && widget.placeholderUrl!.isNotEmpty) {
      final url = widget.placeholderUrl!.toLowerCase();
      final isVideo = url.endsWith('.mov') || url.endsWith('.mp4') || url.endsWith('.avi') || url.endsWith('.mkv') || url.endsWith('.webm');
      if (!isVideo) {
        return CachedNetworkImage(
          imageUrl: widget.placeholderUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorWidget: (_, __, ___) => _buildFallbackColorBlock(),
        );
      }
    }
    return _buildFallbackColorBlock();
  }

  Widget _buildFallbackColorBlock() {
    return Container(
      color: const Color(0xFF0F0D1A),
      child: const Center(
        child: Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 28),
      ),
    );
  }
}
