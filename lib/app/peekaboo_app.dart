
import 'package:flutter/material.dart';

import '../theme/eink_theme.dart';
import '../screens/home_screen.dart';

class PeekabooApp extends StatelessWidget {
  const PeekabooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peekaboo Reader',
      debugShowCheckedModeBanner: false,
      theme: EinkTheme.light(),
      home: const HomeScreen(),
    );
  }
}
