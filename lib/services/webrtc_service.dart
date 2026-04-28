import 'dart:developer' as developer;

import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localAudioStream;
  MediaStream? localVideoStream;
  RTCRtpTransceiver? _videoTransceiver;

  MediaStream? get localStream => localAudioStream;
  MediaStream? get localPreviewStream => localVideoStream;

  final config = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
      {
        'urls': [
          'turn:103.76.55.70:3478?transport=udp',
          'turn:103.76.55.70:3478?transport=tcp',
        ],
        'username': 'turnuser',
        'credential': 'turnpassword123',
      },
    ],
  };

  Future<void> init() async {
    developer.log("🎤 LOCAL STREAM ID: ${localAudioStream?.id}");
    
    
    print("🎤 INIT CALLED");
    localAudioStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,

      
    });
    print("🎤 AUDIO TRACKS: ${localAudioStream?.getAudioTracks().length}");
  }

  Future<RTCPeerConnection> createPeerConnectionForServer(
    void Function(RTCIceCandidate) onIce,
    void Function(MediaStream, MediaStreamTrack) onAddTrack,
    void Function(MediaStream, MediaStreamTrack) onRemoveTrack,
    void Function(RTCPeerConnectionState)? onConnectionState,
    void Function(RTCIceConnectionState)? onIceConnectionState,
  ) async {
    final pc = await createPeerConnection(config);
    pc.onConnectionState = (state) {
      print("🔥 PC STATE: $state");
      onConnectionState?.call(state);
    };

    pc.onIceConnectionState = (state) {
      print("🧊 ICE STATE: $state");
      onIceConnectionState?.call(state);
    };
    final audioStream = localAudioStream;
    if (audioStream == null) {
      throw StateError('Local audio stream is not initialized.');
    }

    for (final track in audioStream.getAudioTracks()) {
      await pc.addTrack(track, audioStream);
    }

    _videoTransceiver = await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
    );

    pc.onIceCandidate = onIce;
    pc.onAddTrack = onAddTrack;
    pc.onRemoveTrack = onRemoveTrack;

    peerConnection = pc;
    return pc;
  }

  Future<MediaStream> enableVideo() async {
    final transceiver = _videoTransceiver;
    if (peerConnection == null || transceiver == null) {
      throw StateError('Peer connection is not ready.');
    }

    final existingStream = localVideoStream;
    if (existingStream != null && existingStream.getVideoTracks().isNotEmpty) {
      return existingStream;
    }

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': true,
    });

    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) {
      await stream.dispose();
      throw StateError('Video track is not available.');
    }

    await transceiver.sender.replaceTrack(tracks.first);
    localVideoStream = stream;
    return stream;
  }

  Future<void> disableVideo() async {
    final transceiver = _videoTransceiver;
    if (transceiver != null && peerConnection != null) {
      try {
        await transceiver.sender.replaceTrack(null);
      } catch (_) {}
    }

    for (final track
        in localVideoStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    await localVideoStream?.dispose();
    localVideoStream = null;
  }

  Future<void> disposeAll() async {
    await disableVideo();
    await peerConnection?.close();
    peerConnection = null;
    _videoTransceiver = null;

    for (final track
        in localAudioStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    await localAudioStream?.dispose();
    localAudioStream = null;
  }
}
