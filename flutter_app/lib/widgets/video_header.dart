import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoHeader extends StatefulWidget {
  final String videoAsset;
  final double height;

  const VideoHeader({
    super.key,
    required this.videoAsset,
    this.height = 300,
  });

  @override
  State<VideoHeader> createState() => _VideoHeaderState();
}

class _VideoHeaderState extends State<VideoHeader> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoAsset)
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized
        setState(() {
          _isInitialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0); // Mute for background feel
        _controller.play();
      }).catchError((error) {
        debugPrint("Video initialization failed: $error");
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer
          if (_isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),

          // Gradient Overlay (for text readability)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // Text Overlay
          const Positioned(
            bottom: 32,
            left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                   "Crave Delivery",
                   style: TextStyle(
                     color: Colors.white,
                     fontSize: 36,
                     fontWeight: FontWeight.bold,
                     shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                   ),
                 ),
                 Text(
                   "Authentic Flavors Delivered",
                   style: TextStyle(
                     color: Colors.white, // Fully opaque for better visibility
                     fontSize: 18,
                     fontWeight: FontWeight.w500,
                     shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                   ),
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
