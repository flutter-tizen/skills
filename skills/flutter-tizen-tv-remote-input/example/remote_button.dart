// remote_button.dart
// Focusable TV button driven by D-pad + OK + Back + red color key.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RemoteButton extends StatelessWidget {
  const RemoteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onRedKey,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onRedKey;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: autofocus,
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.goBack): const DismissIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const DismissIntent(),
        const SingleActivator(LogicalKeyboardKey.colorF0Red): RedKeyIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => onPressed(),
        ),
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) => Navigator.maybePop(context),
        ),
        RedKeyIntent: CallbackAction<RedKeyIntent>(
          onInvoke: (_) => onRedKey?.call(),
        ),
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            transform: Matrix4.identity()
              ..scaleByDouble(
                focused ? 1.04 : 1.0,
                focused ? 1.04 : 1.0,
                1.0,
                1.0,
              ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF1E1E1E),
              border: Border.all(
                color: focused ? Colors.white : Colors.transparent,
                width: 4,
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          );
        },
      ),
    );
  }
}

class RedKeyIntent extends Intent {
  const RedKeyIntent();
}
