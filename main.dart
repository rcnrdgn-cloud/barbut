import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feel.dart';
import 'palette.dart';
import 'table_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Feel.I.init();
  runApp(const BarbutApp());
}

class BarbutApp extends StatelessWidget {
  const BarbutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barbut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.bg,
        colorScheme: const ColorScheme.dark(
          primary: Palette.gold,
          surface: Palette.surface,
          onSurface: Palette.ink,
        ),
      ),
      home: const TableScreen(),
    );
  }
}
