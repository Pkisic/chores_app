import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chores/app/theme.dart';

/// Hours / minutes / seconds stepper. The value is in **seconds**, like
/// every duration in the app. Holding a button repeats the step.
class DurationPicker extends StatelessWidget {
  final int seconds;
  final ValueChanged<int> onChanged;

  /// Upper bound in seconds (default 23h 59m 59s).
  final int max;

  const DurationPicker({
    super.key,
    required this.seconds,
    required this.onChanged,
    this.max = 24 * 3600 - 1,
  });

  @override
  Widget build(BuildContext context) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    void step(int delta) => onChanged((seconds + delta).clamp(0, max));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Unit(label: 'h', value: h, onStep: (d) => step(d * 3600)),
        const _Colon(),
        _Unit(label: 'm', value: m, onStep: (d) => step(d * 60)),
        const _Colon(),
        _Unit(label: 's', value: s, onStep: step),
      ],
    );
  }
}

class _Colon extends StatelessWidget {
  const _Colon();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(fontSize: 24, color: AppColors.textHint),
      ),
    );
  }
}

class _Unit extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onStep;

  const _Unit({required this.label, required this.value, required this.onStep});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: Icons.keyboard_arrow_up, onStep: () => onStep(1)),
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                value.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ),
        _StepButton(icon: Icons.keyboard_arrow_down, onStep: () => onStep(-1)),
      ],
    );
  }
}

/// Tap for one step; hold to repeat.
class _StepButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onStep;

  const _StepButton({required this.icon, required this.onStep});

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _repeat;

  void _start() {
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 90),
      (_) => widget.onStep(),
    );
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onStep();
      },
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: SizedBox(
        width: 56,
        height: 36,
        child: Icon(widget.icon, color: AppColors.textSecondary),
      ),
    );
  }
}
