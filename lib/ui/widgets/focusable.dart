import 'package:flutter/material.dart';

/// Enveloppe un widget cliquable avec un anneau/agrandissement au focus,
/// pour une navigation fluide à la télécommande (Android TV) tout en restant
/// parfaitement tactile sur téléphone.
class Focusable extends StatefulWidget {
  const Focusable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.06,
    this.borderRadius = 8,
    this.autofocus = false,
    this.focusColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final double borderRadius;
  final bool autofocus;
  final Color? focusColor;

  @override
  State<Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<Focusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ring = widget.focusColor ?? Colors.white;
    return InkWell(
      autofocus: widget.autofocus,
      onTap: widget.onTap,
      onFocusChange: (f) => setState(() => _focused = f),
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedScale(
        scale: _focused ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _focused ? ring : Colors.transparent,
              width: 3,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
