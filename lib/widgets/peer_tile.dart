import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/peer.dart';

class PeerTile extends StatelessWidget {
  const PeerTile({super.key, required this.peer});

  final Peer peer;

  @override
  Widget build(BuildContext context) {
    final accent =
        peer.local ? const Color(0xFF0096DE) : const Color(0xFF00AFF0);
    final showVideo =
        peer.videoEnabled && peer.renderer != null && peer.hasVideoTrack;
    final subtitle = _subtitle();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCEFFC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1200AFF0),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (showVideo)
                    RTCVideoView(
                      peer.renderer!,
                      mirror: peer.local,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.22),
                            const Color(0xFFF1F9FF),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(
                                peer.videoEnabled
                                    ? Icons.videocam_rounded
                                    : Icons.videocam_off_rounded,
                                color: accent,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              peer.videoEnabled
                                  ? 'Подключаем видео...'
                                  : 'Камера выключена',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF31567E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        _StatusChip(
                          icon: peer.muted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          active: !peer.muted,
                          activeColor: accent,
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          icon: peer.videoEnabled
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          active: peer.videoEnabled,
                          activeColor: accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            peer.local ? '${peer.name} (вы)' : peer.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF173A63),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFF65829D)),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    if (peer.local) {
      if (peer.videoEnabled) {
        return peer.muted
            ? 'Камера включена, микрофон выключен.'
            : 'Камера и микрофон активны.';
      }
      return peer.muted
          ? 'Вы в голосовом чате без камеры. Микрофон выключен.'
          : 'Вы в голосовом чате без камеры.';
    }

    if (peer.videoEnabled) {
      return 'Участник подключён с видео.';
    }
    return 'Участник подключён только по голосу.';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.active,
    required this.activeColor,
  });

  final IconData icon;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        size: 18,
        color: active ? activeColor : const Color(0xFF7B93AA),
      ),
    );
  }
}
