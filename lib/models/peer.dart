import 'package:flutter_webrtc/flutter_webrtc.dart';

class Peer {
  final String id;
  String name;
  final bool local;
  bool muted;
  bool videoEnabled;
  MediaStream? stream;
  RTCVideoRenderer? renderer;

  Peer({
    required this.id,
    required this.name,
    this.local = false,
    this.muted = false,
    this.videoEnabled = false,
    this.stream,
    this.renderer,
  });

  bool get hasVideoTrack => stream?.getVideoTracks().isNotEmpty ?? false;
}
