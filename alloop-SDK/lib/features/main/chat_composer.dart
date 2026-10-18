import 'package:flutter/material.dart';
import '../../foundations/ui/vvewell_theme.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.hintText,
    this.enabled = true,
    this.inputKey,
    this.actions = const [],
    this.header,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final bool enabled;
  final Key? inputKey;
  final List<Widget> actions;
  final Widget? header;

  @override
  Widget build(BuildContext context) => Material(
    color: VvewellColors.surface,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: VvewellColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 8)],
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: inputKey,
                  controller: controller,
                  maxLength: 4000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: enabled ? (_) => onSend() : null,
                  decoration: InputDecoration(
                    hintText: hintText,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(width: 8),
                action,
              ],
              const SizedBox(width: 9),
              SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed: enabled ? onSend : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: enabled
                      ? const Icon(Icons.send_rounded)
                      : const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
