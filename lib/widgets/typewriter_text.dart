import 'package:flutter/material.dart';

class TypewriterText extends StatelessWidget {
  final String text; // Text to display
  final TextStyle? style; // Custom text style

  const TypewriterText({
    Key? key,
    required this.text,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
    );
  }
}
