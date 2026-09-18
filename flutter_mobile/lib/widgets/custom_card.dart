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
    final radius = BorderRadius.circular(AppTheme.panelRadius);
    final decoration = AppTheme.panelDecoration(
      context: context,
      color: color,
      border: borderColor != null ? Border.all(color: borderColor!) : null,
    );
    return Container(
      margin: margin,
      decoration:
          BoxDecoration(borderRadius: radius, boxShadow: decoration.boxShadow),
      // Paint the hairline without taking space from compact metric grids.
      foregroundDecoration:
          BoxDecoration(borderRadius: radius, border: decoration.border),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration:
              decoration.copyWith(border: const Border(), boxShadow: const []),
          child: InkWell(
            onTap: onTap != null
                ? () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  }
                : null,
            borderRadius: radius,
            child: Container(
              height: height,
              width: width,
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
