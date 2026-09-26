import 'package:flutter/material.dart';

/// Widget emoji tangan melambai (👋) yang memiliki animasi lambaian
/// secara otomatis dan halus (say hello wave animation).
class WavingHandEmoji extends StatefulWidget {
  final double fontSize;

  const WavingHandEmoji({
    super.key,
    this.fontSize = 22,
  });

  @override
  State<WavingHandEmoji> createState() => _WavingHandEmojiState();
}

class _WavingHandEmojiState extends State<WavingHandEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -0.32, end: 0.32).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: Text(
        '👋',
        style: TextStyle(
          fontSize: widget.fontSize,
          height: 1.0,
        ),
      ),
    );
  }
}
