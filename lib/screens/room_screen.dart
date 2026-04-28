import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/room_controller.dart';
import '../widgets/peer_tile.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.baseUri,
    required this.roomId,
    required this.roomName,
    required this.token,
    required this.userId,
    required this.displayName,
  });

  final Uri baseUri;
  final String roomId;
  final String roomName;
  final String token;
  final String userId;
  final String displayName;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final RoomController controller;
  bool _leavingInProgress = false;

  @override
  void initState() {
    super.initState();

    controller = RoomController(
      baseUri: widget.baseUri,
      roomId: widget.roomId,
      token: widget.token,
      userId: widget.userId,
      displayName: widget.displayName,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.connect();
    });
  }

  Future<void> _leaveRoom() async {
    if (_leavingInProgress) {
      return;
    }
    _leavingInProgress = true;
    await controller.disposeAll();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    if (!_leavingInProgress) {
      unawaited(controller.disposeAll());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: _RoomView(roomName: widget.roomName, onLeave: _leaveRoom),
    );
  }
}

class _RoomView extends StatelessWidget {
  const _RoomView({required this.roomName, required this.onLeave});

  final String roomName;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RoomController>();

    return WillPopScope(
      onWillPop: () async {
        await onLeave();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(roomName),
          leading: IconButton(
            onPressed: () async => await onLeave(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00AFF0), Color(0xFF57CCFF)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Комната: $roomName',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ID: ${controller.roomId}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Скопировать ID комнаты',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: controller.roomId),
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ID комнаты скопирован'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.status,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth > 860
                            ? 3
                            : constraints.maxWidth > 560
                            ? 2
                            : 1;

                    final hasVideo = controller.peers.values.any(
                      (peer) => peer.videoEnabled,
                    );

                    return GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio:
                          hasVideo ? (columns == 1 ? 0.94 : 0.9) : 1.25,
                      children:
                          controller.peers.values
                              .map((peer) => PeerTile(peer: peer))
                              .toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 720;
                  final width =
                      isWide
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: ElevatedButton.icon(
                          onPressed: controller.toggleMute,
                          icon: Icon(
                            controller.muted ? Icons.mic_off : Icons.mic,
                          ),
                          label: Text(
                            controller.muted
                                ? 'Включить микрофон'
                                : 'Выключить микрофон',
                          ),
                        ),
                      ),

                      SizedBox(
                        width: width,
                        child: ElevatedButton.icon(
                          onPressed:
                              controller.connecting
                                  ? null
                                  : () async => await controller.toggleVideo(),
                          icon: Icon(
                            controller.cameraEnabled
                                ? Icons.videocam_off_rounded
                                : Icons.videocam_rounded,
                          ),
                          label: Text(
                            controller.cameraEnabled
                                ? 'Выключить камеру'
                                : 'Включить камеру',
                          ),
                        ),
                      ),

                      SizedBox(
                        width: width,
                        child: ElevatedButton.icon(
                          onPressed: onLeave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBEEBFF),
                            foregroundColor: const Color(0xFF17608E),
                          ),
                          icon: const Icon(Icons.call_end),
                          label: const Text('Вернуться к комнатам'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
