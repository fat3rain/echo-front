import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/peer.dart';
import '../services/websocket_service.dart';
import '../services/webrtc_service.dart';

class RoomController extends ChangeNotifier {
  RoomController({
    required this.baseUri,
    required this.roomId,
    required this.token,
    required this.userId,
    required this.displayName,
  });

  final Uri baseUri;
  final String roomId;
  final String token;
  final String userId;
  final String displayName;

  final WebSocketService ws = WebSocketService();
  final WebRTCService rtc = WebRTCService();
  final Map<String, Peer> peers = {};
  final List<String> logs = [];

  StreamSubscription? _subscription;
  final List<Map<String, dynamic>> _pendingCandidates = [];
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  Future<void>? _disposeOperation;
  int _sessionId = 0;
  Timer? _answerTimeoutTimer;
  bool _answerReceived = false;
  int _offerRetryCount = 0;
  int _iceRestartAttempts = 0;
  bool _iceRestartInProgress = false;
  bool _remoteDescriptionSet = false;
  bool muted = false;
  bool cameraEnabled = false;
  bool connected = false;
  bool connecting = false;
  bool _joinSent = false;
  String status = 'Подключаемся...';

  Future<void> connect() async {
    if (_disposeOperation != null) {
      await _disposeOperation;
    }

    await rtc.disposeAll();
    await Future.delayed(const Duration(milliseconds: 300));

    developer.log("🚀 CONNECT CALLED");
    developer.log("🚀 PC STATE: ${rtc.peerConnection}");
    if (connecting || connected) {
      _log('⚠️ CONNECT BLOCKED (already connecting/connected)');
      return;
    }

    final currentSessionId = ++_sessionId;

    try {
      connecting = true;
      _setStatus('Запрашиваем доступ к микрофону...');

      await rtc.init();
      if (currentSessionId != _sessionId) {
        return;
      }
      final tracks = rtc.localStream?.getAudioTracks();
      developer.log("AUDIO TRACKS COUNT: ${tracks?.length}");
      for (final t in tracks ?? []) {
        developer.log(
          "TRACK: id=${t.id}, enabled=${t.enabled}, muted=${t.muted}",
        );
      }
      _log('Доступ к микрофону получен.');

      peers['local'] = Peer(
        id: 'local',
        name: displayName,
        local: true,
        muted: muted,
        videoEnabled: cameraEnabled,
      );
      notifyListeners();

      final pc = await rtc.createPeerConnectionForServer(
        (candidate) {
          if (currentSessionId != _sessionId) {
            return;
          }

          final candidateValue = candidate.candidate;
          if (candidateValue == null || candidateValue.isEmpty) {
            return;
          }

          final payload = <String, dynamic>{
            'type': 'candidate',
            'candidate': candidate.toMap(),
          };

          if (_joinSent) {
            try {
              ws.send(payload);
              _log('ICE-кандидат отправлен.');
            } catch (error, stackTrace) {
              _handleFailure(
                'Не удалось отправить ICE-кандидат',
                error,
                stackTrace,
              );
            }
          } else {
            _pendingCandidates.add(payload);
            _log('ICE-кандидат отложен до отправки join.');
          }
        },
        (stream, track) {
          if (currentSessionId != _sessionId) {
            return;
          }
          unawaited(_handleRemoteTrackAdded(stream, track, currentSessionId));
        },
        (stream, track) {
          if (currentSessionId != _sessionId) {
            return;
          }
          unawaited(_handleRemoteTrackRemoved(stream, track, currentSessionId));
        },
        (state) {
          if (currentSessionId != _sessionId) {
            return;
          }
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _iceRestartAttempts = 0;
            _iceRestartInProgress = false;
          }
        },
        (state) {
          if (currentSessionId != _sessionId) {
            return;
          }
          unawaited(_handleIceStateChanged(state, currentSessionId));
        },
      );

      final wsUri = _buildWebSocketUri(baseUri);
      _setStatus('Подключаемся к сигнальному серверу...');
      await ws.connect(wsUri);
      if (currentSessionId != _sessionId) {
        return;
      }
      _log('WebSocket подключён: $wsUri');

      _subscription = ws.stream.listen(
        (event) async => _handleSignal(event.toString(), currentSessionId),
        onDone: () {
          if (currentSessionId != _sessionId) {
            return;
          }
          _log('WS CLOSED (ignored if RTC connected)');

          if (rtc.peerConnection?.connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _log('WS closed but RTC already connected → ignoring');
            return;
          }

          connected = false;
          connecting = false;
          _setStatus('Соединение с сигнальным сервером закрыто.');
        },
        onError: (error, stackTrace) {
          if (currentSessionId != _sessionId) {
            return;
          }
          _handleFailure('Ошибка сокета', error, stackTrace);
        },
      );

      _setStatus('Создаём WebRTC offer...');
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      if (currentSessionId != _sessionId) {
        return;
      }
      _log('Локальный offer создан.');

      ws.send({
        'type': 'join',
        'room': roomId,
        'sdp': offer.sdp,
        'sdpType': offer.type,
        'token': token,
      });
      _joinSent = true;
      _answerReceived = false;
      _offerRetryCount = 0;
      _iceRestartAttempts = 0;
      _iceRestartInProgress = false;
      _remoteDescriptionSet = false;
      _pendingRemoteCandidates.clear();
      _log('Сообщение join отправлено для комнаты "$roomId".');
      _startAnswerTimeoutWatcher(currentSessionId);

      for (final candidate in _pendingCandidates) {
        ws.send(candidate);
      }
      if (_pendingCandidates.isNotEmpty) {
        _log(
          'Отправлены отложенные ICE-кандидаты: ${_pendingCandidates.length}.',
        );
      }
      _pendingCandidates.clear();

      if (currentSessionId != _sessionId) {
        return;
      }
      connected = true;
      connecting = false;
      _setStatus('Входим в комнату "$roomId"...');
    } catch (error, stackTrace) {
      await disposeAll();
      _handleFailure('Ошибка подключения', error, stackTrace);
    }
  }

  Future<void> _handleSignal(String rawEvent, int sessionId) async {
    if (sessionId != _sessionId) {
      return;
    }

    final normalizedEvent = rawEvent.trim();
    if (normalizedEvent.isEmpty) {
      _log('Пустое сообщение сигналинга проигнорировано.');
      return;
    }

    try {
      final decoded = jsonDecode(normalizedEvent);
      if (decoded is! Map<String, dynamic>) {
        _log('Некорректный формат сигнального сообщения проигнорирован.');
        return;
      }

      final data = decoded;
      final type = data['type'] as String?;
      final pc = rtc.peerConnection;

      _log('Получено событие сигналинга: ${type ?? 'unknown'}');

      switch (type) {
        case 'participants':
          final participants = data['participants'] as List<dynamic>? ?? [];
          final activeIds = <String>{};
          for (final participant in participants) {
            if (participant is! Map<String, dynamic>) {
              continue;
            }

            final id = participant['id'] as String?;
            final name = participant['displayName'] as String?;
            final participantMuted = participant['muted'] as bool? ?? false;
            final videoEnabled = participant['videoEnabled'] as bool? ?? false;
            if (id == null || name == null) {
              continue;
            }

            activeIds.add(id);

            if (id == userId) {
              peers['local']?.videoEnabled = cameraEnabled;
              peers['local']?.muted = muted;
              continue;
            }

            final existing = peers[id];
            if (existing != null) {
              existing.name = name;
              existing.muted = participantMuted;
              existing.videoEnabled = videoEnabled;
            } else {
              peers[id] = Peer(
                id: id,
                name: name,
                muted: participantMuted,
                videoEnabled: videoEnabled,
              );
            }
          }

          final removedPeers =
              peers.entries
                  .where(
                    (entry) =>
                        !entry.value.local && !activeIds.contains(entry.key),
                  )
                  .map((entry) => entry.key)
                  .toList();

          for (final id in removedPeers) {
            final peer = peers.remove(id);
            if (peer != null) {
              await _disposePeerRenderer(peer);
            }
          }
          break;

        case 'answer':
          if (pc == null) {
            return;
          }
          await pc.setRemoteDescription(
            RTCSessionDescription(
              data['sdp'] as String,
              data['sdpType'] as String,
            ),
          );
          _remoteDescriptionSet = true;
          await _flushPendingRemoteCandidates(pc);
          _answerReceived = true;
          _answerTimeoutTimer?.cancel();
          _setStatus('Подключение к комнате "$roomId" установлено.');
          break;

        case 'offer':
          if (pc == null) {
            return;
          }
          await pc.setRemoteDescription(
            RTCSessionDescription(
              data['sdp'] as String,
              data['sdpType'] as String,
            ),
          );
          _remoteDescriptionSet = true;
          await _flushPendingRemoteCandidates(pc);
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          ws.send({
            'type': 'answer',
            'sdp': answer.sdp,
            'sdpType': answer.type,
          });
          _setStatus('Медиасессия обновлена.');
          break;

        case 'candidate':
        case 'candidateFromServer':
          final rawCandidate = data['candidate'];
          if (pc == null || rawCandidate is! Map<String, dynamic>) {
            return;
          }
          final candidate = RTCIceCandidate(
            rawCandidate['candidate'] as String?,
            rawCandidate['sdpMid'] as String?,
            rawCandidate['sdpMLineIndex'] as int?,
          );
          if (!_remoteDescriptionSet) {
            _pendingRemoteCandidates.add(candidate);
            _log('Удалённый ICE-кандидат отложен до remoteDescription.');
            return;
          }
          await pc.addCandidate(candidate);
          break;

        default:
          _log('Неизвестное событие проигнорировано.');
          return;
      }

      notifyListeners();
    } on FormatException catch (error) {
      _log('Невалидный JSON в сигналинге проигнорирован: $error');
    } catch (error, stackTrace) {
      _handleFailure(
        'Ошибка обработки сигнального сообщения',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _handleRemoteTrackAdded(
    MediaStream stream,
    MediaStreamTrack track,
    int sessionId,
  ) async {
    if (sessionId != _sessionId) {
      return;
    }

    final peerId = stream.id;
    final peer = peers.putIfAbsent(
      peerId,
      () => Peer(id: peerId, name: 'Участник'),
    );

    peer.stream = stream;
    if (track.kind == 'video') {
      peer.videoEnabled = true;
      await _attachRenderer(peer, stream);
      _setStatus('Получаем видео от ${peer.name}.');
    } else {
      _setStatus('Получаем удалённое аудио.');
    }

    notifyListeners();
  }

  Future<void> _handleRemoteTrackRemoved(
    MediaStream stream,
    MediaStreamTrack track,
    int sessionId,
  ) async {
    if (sessionId != _sessionId) {
      return;
    }

    final peer = peers[stream.id];
    if (peer == null) {
      return;
    }

    peer.stream = stream;
    if (track.kind == 'video') {
      peer.videoEnabled = false;
    }

    notifyListeners();
  }

  Future<void> _attachRenderer(Peer peer, MediaStream stream) async {
    final renderer = peer.renderer ?? RTCVideoRenderer();
    if (peer.renderer == null) {
      await renderer.initialize();
      peer.renderer = renderer;
    }
    renderer.srcObject = stream;
  }

  Future<void> _disposePeerRenderer(Peer peer) async {
    final renderer = peer.renderer;
    if (renderer == null) {
      return;
    }

    renderer.srcObject = null;
    await renderer.dispose();
    peer.renderer = null;
    peer.stream = null;
  }

  void toggleMute() {
    developer.log(
      "🎤 MIC STATE BEFORE: muted=$muted tracks=${rtc.localStream?.getAudioTracks().map((t) => t.enabled).toList()}",
    );
    muted = !muted;

    for (final track
        in rtc.localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }

    peers['local']?.muted = muted;
    _sendMediaState();
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    if (connecting || rtc.peerConnection == null) {
      return;
    }

    try {
      final localPeer = peers['local'];
      if (cameraEnabled) {
        _setStatus('Отключаем камеру...');
        await rtc.disableVideo();
        cameraEnabled = false;

        if (localPeer != null) {
          localPeer.videoEnabled = false;
          localPeer.stream = null;
          localPeer.renderer?.srcObject = null;
        }

        _sendMediaState();
        _setStatus('Камера выключена. Голосовой чат продолжается.');
      } else {
        _setStatus('Подключаем камеру...');
        final stream = await rtc.enableVideo();
        cameraEnabled = true;

        if (localPeer != null) {
          localPeer.videoEnabled = true;
          localPeer.stream = stream;
          await _attachRenderer(localPeer, stream);
        }

        _sendMediaState();
        _setStatus('Камера включена.');
      }

      notifyListeners();
    } catch (error, stackTrace) {
      developer.log(
        'Не удалось переключить камеру',
        name: 'RoomController',
        error: error,
        stackTrace: stackTrace,
      );
      _setStatus('Не удалось переключить камеру: $error');
    }
  }

  Future<void> disposeAll() async {
    final ongoing = _disposeOperation;
    if (ongoing != null) {
      await ongoing;
      return;
    }

    final op = _disposeAllInternal();
    _disposeOperation = op;
    try {
      await op;
    } finally {
      _disposeOperation = null;
    }
  }

  Future<void> _disposeAllInternal() async {
    _sessionId++;
    _answerTimeoutTimer?.cancel();
    _answerTimeoutTimer = null;
    _answerReceived = false;
    _offerRetryCount = 0;
    _iceRestartAttempts = 0;
    _iceRestartInProgress = false;
    _remoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();

    if (rtc.peerConnection == null && _subscription == null) {
      return;
    }
    _log('🧹 DISPOSE START');

    try {
      connecting = false;
      connected = false;

      _joinSent = false;

      await _subscription?.cancel();
      _subscription = null;

      ws.dispose();

      // 🔥 ВАЖНО: сначала закрываем RTC connection
      try {
        final pc = rtc.peerConnection;
        rtc.peerConnection = null;
        await pc?.close();
      } catch (_) {}

      await rtc.disposeAll();

      // чистим peers
      for (final peer in peers.values.toList()) {
        await _disposePeerRenderer(peer);
      }

      peers.clear();
      _pendingCandidates.clear();

      cameraEnabled = false;
      muted = false;

      _log('🧹 DISPOSE DONE');
    } catch (e) {
      _log('🧹 DISPOSE ERROR: $e');
    }
  }

  Future<void> _flushPendingRemoteCandidates(RTCPeerConnection pc) async {
    if (_pendingRemoteCandidates.isEmpty) {
      return;
    }

    final pending = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in pending) {
      await pc.addCandidate(candidate);
    }
    _log('Применены отложенные удалённые ICE-кандидаты: ${pending.length}.');
  }

  void _startAnswerTimeoutWatcher(int sessionId) {
    _answerTimeoutTimer?.cancel();
    _answerTimeoutTimer = Timer(const Duration(seconds: 6), () {
      if (sessionId != _sessionId || _answerReceived || !_joinSent) {
        return;
      }
      unawaited(_retryOffer(sessionId));
    });
  }

  Future<void> _retryOffer(int sessionId) async {
    if (sessionId != _sessionId || _answerReceived) {
      return;
    }
    if (_offerRetryCount >= 2) {
      _setStatus('Не получили ответ от сервера. Попробуйте переподключиться.');
      return;
    }

    final pc = rtc.peerConnection;
    if (pc == null) {
      return;
    }

    _offerRetryCount++;
    _setStatus('Повторяем установку соединения (${_offerRetryCount}/2)...');
    try {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      if (sessionId != _sessionId || _answerReceived) {
        return;
      }

      ws.send({
        'type': 'offer',
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
      _log('Повторный offer отправлен.');
      _startAnswerTimeoutWatcher(sessionId);
    } catch (error, stackTrace) {
      _handleFailure('Не удалось повторить offer', error, stackTrace);
    }
  }

  Future<void> _handleIceStateChanged(
    RTCIceConnectionState state,
    int sessionId,
  ) async {
    if (sessionId != _sessionId) {
      return;
    }

    if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _iceRestartAttempts = 0;
      _iceRestartInProgress = false;
      return;
    }

    if (state != RTCIceConnectionState.RTCIceConnectionStateFailed &&
        state != RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
      return;
    }

    if (_iceRestartInProgress || !_joinSent || _offerRetryCount > 0) {
      return;
    }
    if (_iceRestartAttempts >= 2) {
      _setStatus('Проблема сети: ICE не восстановился. Переподключитесь.');
      return;
    }

    _iceRestartAttempts++;
    _iceRestartInProgress = true;
    _setStatus('Пробуем восстановить аудио (${_iceRestartAttempts}/2)...');

    final pc = rtc.peerConnection;
    if (pc == null) {
      _iceRestartInProgress = false;
      return;
    }

    try {
      final offer = await pc.createOffer({'iceRestart': true});
      await pc.setLocalDescription(offer);
      if (sessionId != _sessionId) {
        return;
      }

      ws.send({
        'type': 'offer',
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
      _log('Отправлен ICE-restart offer.');
    } catch (error, stackTrace) {
      _handleFailure('Не удалось выполнить ICE restart', error, stackTrace);
    } finally {
      _iceRestartInProgress = false;
    }
  }

  void _setStatus(String value) {
    status = value;
    _log(value);
    notifyListeners();
  }

  void _log(String message) {
    final line = '${DateTime.now().toIso8601String()}  $message';
    logs.insert(0, line);
    if (logs.length > 50) {
      logs.removeLast();
    }
    developer.log(message, name: 'RoomController');
  }

  void _handleFailure(String context, Object error, StackTrace stackTrace) {
    connected = false;
    connecting = false;
    status = '$context: $error';
    _log('$context: $error');
    developer.log(
      context,
      name: 'RoomController',
      error: error,
      stackTrace: stackTrace,
    );
    notifyListeners();
  }

  void _sendMediaState() {
    if (!_joinSent) {
      return;
    }

    try {
      ws.send({
        'type': 'mediaState',
        'videoEnabled': cameraEnabled,
        'muted': muted,
      });
      _log(cameraEnabled ? 'Статус камеры: включена.' : 'Статус камеры: выключена.');
    } catch (error, stackTrace) {
      developer.log(
        'Не удалось отправить статус камеры',
        name: 'RoomController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Uri _buildWebSocketUri(Uri uri) {
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(
      scheme: scheme,
      path: '/ws',
      queryParameters: null,
      fragment: null,
    );
  }
}
