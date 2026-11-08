import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS renders Apple's own ASAuthorizationAppleIDButton, including its logo,
/// localized title and VoiceOver label. Flutter only forwards the native tap.
class OfficialAppleSignInButton extends StatefulWidget {
  const OfficialAppleSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<OfficialAppleSignInButton> createState() =>
      _OfficialAppleSignInButtonState();
}

class _OfficialAppleSignInButtonState extends State<OfficialAppleSignInButton> {
  MethodChannel? _channel;

  void _onCreated(int id) {
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('com.4athletes.auth/apple_button/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (mounted && identical(_channel, channel) && call.method == 'pressed') {
        widget.onPressed();
      }
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      height: 56,
      // Recreate the native control when the theme changes: its style is fixed
      // by Apple's initializer, rather than recoloring the logo ourselves.
      child: UiKitView(
        key: ValueKey(brightness),
        viewType: 'com.4athletes.auth/apple_button',
        creationParams: {
          'style': brightness == Brightness.dark ? 'white' : 'black'
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
      ),
    );
  }
}
