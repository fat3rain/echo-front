import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vois/screens/profile_screen.dart';

import '../models/room_summary.dart';
import '../models/user_profile.dart';
import '../services/room_service.dart';
import 'join_screen.dart';
import 'room_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    super.key,
    required this.baseUri,
    required this.token,
    required this.profile,
  });

  final Uri baseUri;
  final String token;
  final UserProfile profile;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _rooms = <RoomSummary>[];
  final _roomService = RoomService();
  bool _busy = false;
  String _status = 'Загружаем комнаты...';

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _busy = true;
      _status = 'Загружаем список комнат...';
    });

    try {
      final rooms = await _roomService.listRooms(
        baseUri: widget.baseUri,
        token: widget.token,
      );
      setState(() {
        _rooms
          ..clear()
          ..addAll(rooms);
        _status =
            rooms.isEmpty
                ? 'У вас пока нет комнат. Можно создать новую или найти по ID.'
                : 'Выберите комнату и подключайтесь.';
      });
    } catch (error) {
      setState(() {
        _status = 'Не удалось загрузить комнаты: $error';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _createRoom() async {
    final controller = TextEditingController();
    final roomName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новая комната'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Название комнаты',
              hintText: 'Например: Команда, Друзья, Работа',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );

    if (roomName == null) {
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Создаём комнату...';
    });

    try {
      final room = await _roomService.createRoom(
        baseUri: widget.baseUri,
        token: widget.token,
        name: roomName.isEmpty ? 'Новая комната' : roomName,
      );
      _rooms.insert(0, room);
      setState(() {
        _status = 'Комната ${room.name} создана. ID: ${room.id}';
      });
    } catch (error) {
      setState(() {
        _status = 'Не удалось создать комнату: $error';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _findAndJoinRoom() async {
    final controller = TextEditingController();
    final roomId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Войти по ID комнаты'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'ID комнаты',
              hintText: 'Введите ID комнаты',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.pop(
                    context,
                    controller.text.trim().toUpperCase(),
                  ),
              child: const Text('Найти'),
            ),
          ],
        );
      },
    );

    if (roomId == null || roomId.isEmpty) {
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Ищем комнату $roomId...';
    });

    try {
      final room = await _roomService.findRoom(
        baseUri: widget.baseUri,
        token: widget.token,
        roomId: roomId,
      );
      final joined = await _roomService.joinRoom(
        baseUri: widget.baseUri,
        token: widget.token,
        roomId: room.id,
      );

      _rooms.removeWhere((item) => item.id == joined.id);
      _rooms.insert(0, joined);

      setState(() {
        _status = 'Комната ${joined.name} добавлена в ваш список.';
      });
    } catch (error) {
      setState(() {
        _status = 'Не удалось найти комнату: $error';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _deleteRoom(RoomSummary room) async {
    setState(() {
      _busy = true;
      _status = 'Удаляем комнату ${room.name}...';
    });

    try {
      await _roomService.deleteRoom(
        baseUri: widget.baseUri,
        token: widget.token,
        roomId: room.id,
      );
      _rooms.removeWhere((item) => item.id == room.id);
      setState(() {
        _status = 'Комната удалена из вашего списка.';
      });
    } catch (error) {
      setState(() {
        _status = 'Не удалось удалить комнату: $error';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _openRoom(RoomSummary room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => RoomScreen(
              baseUri: widget.baseUri,
              roomId: room.id,
              roomName: room.name,
              token: widget.token,
              userId: widget.profile.id,
              displayName: widget.profile.displayName,
            ),
      ),
    );
    await _loadRooms();
  }

  Future<void> _logout() async {
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const JoinScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.profile.displayName.isEmpty
            ? '?'
            : String.fromCharCode(
              widget.profile.displayName.runes.first,
            ).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('echo'),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Выйти'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFDCEFFC)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProfileScreen(
                                  displayName: widget.profile.displayName,
                                ),
                          ),
                        ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF00AFF0),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.displayName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ваши комнаты',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _createRoom,
                  icon: const Icon(Icons.add),
                  label: const Text('Создать комнату'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _findAndJoinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBEEBFF),
                    foregroundColor: const Color(0xFF17608E),
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text('Найти по ID'),
                ),
                // OutlinedButton.icon(
                //   onPressed: _busy ? null : _loadRooms,
                //   icon: const Icon(Icons.refresh),
                //   label: const Text('Обновить'),
                // ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FCFF),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDCEFFC)),
              ),
              child: Text(_status),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _rooms.isEmpty
                      ? Center(
                        child: Text(
                          'Комнат пока нет.\nСоздайте новую или войдите по ID.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                      : ListView.separated(
                        itemCount: _rooms.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFDCEFFC),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Container(
                                //   width: 52,
                                //   height: 52,
                                //   decoration: BoxDecoration(
                                //     color: const Color(0xFFE8F8FF),
                                //     borderRadius: BorderRadius.circular(16),
                                //   ),
                                //   child: const Icon(
                                //     Icons.forum_outlined,
                                //     color: Color(0xFF00AFF0),
                                //   ),
                                // ),
                                // const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        room.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontSize: 20),
                                      ),
                                      const SizedBox(height: 6),
                                      // Text('ID: ${room.id}'),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Скопировать ID комнаты',
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: room.id),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'ID ${room.id} скопирован',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy_rounded),
                                ),
                                IconButton(
                                  onPressed:
                                      _busy ? null : () => _deleteRoom(room),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed:
                                      _busy ? null : () => _openRoom(room),
                                  child: const Text('Подключиться'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
