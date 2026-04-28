import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/join_screen.dart';

class VoiceChatApp extends StatelessWidget {
  const VoiceChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'echo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.montserratAlternates().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00AFF0),
          brightness: Brightness.light,
          primary: const Color(0xFF00AFF0),
          secondary: const Color(0xFF89DAFF),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5FBFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5FBFF),
          foregroundColor: Color(0xFF173A63),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: GoogleFonts.montserratAlternatesTextTheme(
          const TextTheme(
            headlineMedium: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF173A63),
            ),
            titleLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF173A63),
            ),
            bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF355C7D)),
            bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF65829D)),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFFD9EEFB)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF00AFF0),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      home: const JoinScreen(),
    );
  }
}
