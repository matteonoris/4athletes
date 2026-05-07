import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double? height;
  final double? width;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: color ?? AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border:
                  borderColor != null ? Border.all(color: borderColor!) : null,
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
