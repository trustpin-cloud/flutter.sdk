import 'package:flutter/material.dart';

import 'log_entry.dart';
import 'ui_state.dart';

const int _primaryValue = 0xFF429488;
const MaterialColor trustPinGreen = MaterialColor(_primaryValue, <int, Color>{
  50: Color(0xFFE2F2EF),
  100: Color(0xFFB6DED7),
  200: Color(0xFF86C9BC),
  300: Color(0xFF56B3A1),
  400: Color(0xFF359F8C),
  500: Color(_primaryValue),
  600: Color(0xFF3C867B),
  700: Color(0xFF35766B),
  800: Color(0xFF2E655B),
  900: Color(0xFF204739),
});

/// The pinning status shown at the top of both tabs.
class StatusHeader extends StatelessWidget {
  final Status status;

  const StatusHeader({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      Status.notConfigured => 'TrustPin not configured',
      Status.configured => 'TrustPin configured',
      Status.testing => 'Testing connection...',
      Status.fetching => 'Fetching certificate...',
    };
    final color = status == Status.notConfigured ? Colors.red : Colors.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          StatusDot(color: color),
          const SizedBox(width: 8),
          Text(
            'Status: $label',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  final Color color;

  const StatusDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A titled card, as the native samples group their controls.
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A full-width button in the samples' style.
class WideButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool busy;

  const WideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = trustPinGreen,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: busy ? const ButtonSpinner() : Text(label),
      ),
    );
  }
}

class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final int maxLines;

  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.enabled,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

/// A tab's log: monospaced lines coloured by level, newest at the bottom.
class LogPanel extends StatefulWidget {
  final String title;
  final List<LogEntry> entries;
  final VoidCallback onClear;

  const LogPanel({
    super.key,
    required this.title,
    required this.entries,
    required this.onClear,
  });

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(LogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length != oldWidget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.entries.isEmpty ? null : widget.onClear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.entries.length,
                itemBuilder: (context, index) =>
                    _LogLine(entry: widget.entries[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final LogEntry entry;

  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      LogLevel.error => Colors.red,
      LogLevel.warning => Colors.orange,
      LogLevel.success => Colors.green,
      LogLevel.debug => Colors.purple,
      LogLevel.info => Theme.of(context).colorScheme.onSurface,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        '[${entry.timestamp}] ${entry.level.icon} ${entry.message}',
        style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: color),
      ),
    );
  }
}
