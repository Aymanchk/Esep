import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable Liquid Glass material — glassmorphism style.
class LiquidGlass extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool interactive;
  final VoidCallback? onTap;
  final double blurSigma;
  final Color? fillColor;

  const LiquidGlass({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.interactive = false,
    this.onTap,
    this.blurSigma = 30,
    this.fillColor,
  });

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  bool _pressed = false;

  void _onDown(_) => setState(() => _pressed = true);
  void _onUp(_) => setState(() => _pressed = false);
  void _onCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(24);
    final fillAlpha = _pressed ? 0.10 : 0.06;
    final topHighlight = _pressed ? 0.20 : 0.18;
    final sideHighlight = _pressed ? 0.14 : 0.12;
    final bottomHighlight = _pressed ? 0.08 : 0.06;

    Widget glass = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: widget.blurSigma,
          sigmaY: widget.blurSigma,
        ),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color:
                widget.fillColor ?? Colors.white.withValues(alpha: fillAlpha),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: _pressed ? 0.12 : 0.08),
                Colors.transparent,
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: topHighlight),
                width: 1,
              ),
              left: BorderSide(
                color: Colors.white.withValues(alpha: sideHighlight),
                width: 1,
              ),
              right: BorderSide(
                color: Colors.white.withValues(alpha: sideHighlight),
                width: 1,
              ),
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: bottomHighlight),
                width: 1,
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );

    if (!widget.interactive) return glass;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onDown,
      onTapUp: _onUp,
      onTapCancel: _onCancel,
      child: AnimatedScale(
        scale: _pressed ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: glass,
      ),
    );
  }
}

/// A pill-shaped glass chip.
class GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isActive;

  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(50),
      interactive: onTap != null,
      onTap: onTap,
      fillColor: isActive
          ? const Color(0xFF22D3EE).withValues(alpha: 0.25)
          : null,
      padding: padding,
      child: child,
    );
  }
}

/// Ambient blobs — warm tones for the "appetizing" aesthetic.
class GlassAmbientBackground extends StatelessWidget {
  final Widget child;

  const GlassAmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Amber blob — top-left
        Positioned(
          top: -60,
          left: -40,
          child: _Blob(color: const Color(0xFF22D3EE), size: 220),
        ),
        // Peach blob — top-right
        Positioned(
          top: 40,
          right: -60,
          child: _Blob(color: const Color(0xFF67E8F9), size: 180),
        ),
        // Coral blob — bottom-center
        Positioned(
          bottom: -40,
          left: 60,
          child: _Blob(color: const Color(0xFFA78BFA), size: 160),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.35),
      ),
    );
  }
}
