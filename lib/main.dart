import 'package:flutter/material.dart';
import 'package:mikudrome/screens/home_screen.dart';

void main() {
  runApp(const MikudromeApp());
}

class MikudromeApp extends StatelessWidget {
  const MikudromeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mikudrome',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
