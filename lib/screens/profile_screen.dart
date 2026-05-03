import 'package:flutter/material.dart';


class ProfileScreen extends StatelessWidget {
  final String displayName;

  const ProfileScreen({super.key, required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ваш профиль в echo!')),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          spacing: 20,
          children: [
            Text('Изменить имя'),
            Row(
              spacing: 20,
              children: [
                Flexible(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: displayName,
                      filled: true,
                      fillColor: const Color(0xFFF7FCFF),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFD7ECFA)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFF00AFF0),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                ElevatedButton(onPressed: () {}, child: Text('Изменить')),
              ],
            ),
            Text('Изменить аватар'),
            GestureDetector(
              onTap: () {},
              child: CircleAvatar(
                backgroundColor: Color(0xFF00AFF0),
                radius: 28,
                child: Icon(Icons.add, color: Colors.white),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Разработчики: Студия DnA'),
            ),
          ],
        ),
      ),
      // bottomNavigationBar: SnackBar(content: Text('data')),
    );
  }
}
