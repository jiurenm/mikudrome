import 'package:flutter/material.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/theme/app_theme.dart';

void main() {
  runApp(const MikudromeApp());
}

class MikudromeApp extends StatelessWidget {
  const MikudromeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mikudrome',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const LibraryHomeScreen(),
    );
  }
}
