import '../pages/home_page.dart';
import 'package:flutter/material.dart';

class Ollama extends StatefulWidget {
  const Ollama({Key? key}) : super(key: key);

  @override
  _OllamaState createState() => _OllamaState();
}

class _OllamaState extends State<Ollama> {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 16.0;

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void _changeFontSize(double size) {
    setState(() {
      _fontSize = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archer Assistant',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: HomePage(
        themeMode: _themeMode,
        fontSize: _fontSize,
        onThemeChanged: _changeTheme,
        onFontSizeChanged: _changeFontSize,
      ),
    );
  }
}
