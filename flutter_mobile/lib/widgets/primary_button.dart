import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isSecondary;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isSecondary
        ? Theme.of(context).outlinedButtonTheme.style
        : Theme.of(context).elevatedButtonTheme.style;

    Widget child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.background),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    return isSecondary
        ? OutlinedButton(
            onPressed: isLoading
                ? () {}
                : () {
                    HapticFeedback.lightImpact();
                    onPressed();
                  },
            style: style,
            child: child)
        : ElevatedButton(
            onPressed: isLoading
                ? () {}
                : () {
                    HapticFeedback.lightImpact();
                    onPressed();
                  },
            style: style,
            child: child);
  }
}
