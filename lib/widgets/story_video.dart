import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

/// Widget for displaying video stories.
///
/// This widget streams video directly from a network URL.
/// It does not use any caching mechanisms.
class StoryVideo extends StatefulWidget {
  /// The controller for managing story playback.
  final StoryController? controller;

  /// The URL of the video to be played.
  final String url;

  /// Optional HTTP headers for the video request.
  final Map<String, String>? requestHeaders;

  /// Widget to display while the video is loading.
  final Widget? loadingWidget;

  /// Widget to display if the video fails to load.
  final Widget? errorWidget;

  /// BoxFit for the video.
  final BoxFit? fit;

  /// Height of the video.
  final double? height;

  /// Whether the video should start playing automatically.
  final bool autoplay;

  /// Creates a StoryVideo widget that plays video from a network URL.
  ///
  /// [url] is the network URL of the video.
  /// [controller] is an optional controller for playback.
  /// [requestHeaders] are optional HTTP headers for the video request.
  /// [loadingWidget] is an optional widget to display during loading.
  /// [errorWidget] is an optional widget to display on error.
  /// [fit] is the BoxFit for the video.
  /// [height] is the height of the video.
  /// [autoplay] determines if the video should play automatically.
  StoryVideo.url(
    this.url, {
    Key? key,
    this.controller,
    this.requestHeaders,
    this.loadingWidget,
    this.errorWidget,
    this.fit,
    this.height,
    this.autoplay = true,
  }) : super(key: key ?? UniqueKey());

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  VideoPlayerController? _playerController;
  StreamSubscription? _streamSubscription;
  LoadState _loadState = LoadState.loading;

  @override
  void initState() {
    super.initState();
    // Pause the story controller while the video is initializing.
    // If autoplay is false, the controller should remain paused.
    widget.controller?.pause();
    _initializePlayer();
  }

  /// Initializes the video player with the provided URL.
  Future<void> _initializePlayer() async {
    try {
      _playerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: widget.requestHeaders ?? {},
      );
      await _playerController!.initialize();
      // Video has successfully initialized.
      setState(() {
        _loadState = LoadState.success;
      });

      if (widget.autoplay) {
        // Start playback automatically.
        _playerController!.play();
        // Resume story playback.
        widget.controller?.play();
      } else {
        // If not autoplaying, ensure the story controller remains paused.
        widget.controller?.pause();
      }

      // Listen to playback state changes from the story controller.
      if (widget.controller != null) {
        _streamSubscription = widget.controller!.playbackNotifier.listen((playbackState) {
          if (playbackState == PlaybackState.pause) {
            _playerController!.pause();
          } else {
            _playerController!.play();
          }
        });
      }
    } catch (e) {
      // Video failed to initialize.
      debugPrint("Video failed to initialize: $e"); // Added debug print
      setState(() {
        _loadState = LoadState.failure;
      });
    }
  }

  /// Builds the content widget based on the current load state.
  Widget _buildContent() {
    if (_loadState == LoadState.success && _playerController!.value.isInitialized) {
      // Display the video player if successfully loaded.
      final videoPlayer = AspectRatio(
        aspectRatio: _playerController!.value.aspectRatio,
        child: FittedBox(
          fit: widget.fit ?? BoxFit.fitWidth,
          child: SizedBox(
            width: _playerController!.value.size.width,
            height: _playerController!.value.size.height,
            child: VideoPlayer(_playerController!),
          ),
        ),
      );

      if (widget.height != null) {
        return Center(
          child: SizedBox(
            height: widget.height,
            child: videoPlayer,
          ),
        );
      }

      return Center(
        child: videoPlayer,
      );
    }

    if (_loadState == LoadState.failure) {
      // Display the error widget if loading failed.
      return Center(
        child: widget.errorWidget ??
            const Text(
              "Media failed to load.",
              style: TextStyle(
                color: Colors.white,
              ),
            ),
      );
    }
    // Display the loading widget by default (while loading).
    return Center(
      child: widget.loadingWidget ??
          Container(
            width: 70,
            height: 70,
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_playerController != null && _playerController!.value.isInitialized) {
          if (_playerController!.value.isPlaying) {
            _playerController!.pause();
            widget.controller?.pause();
          } else {
            _playerController!.play();
            widget.controller?.play();
          }
        }
      },
      child: _buildContent(),
    );
  }

  @override
  void dispose() {
    // Dispose of the video player controller and stream subscription.
    _playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
