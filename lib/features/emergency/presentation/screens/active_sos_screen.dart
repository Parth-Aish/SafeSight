import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/sos_controller.dart';
import '../../domain/models/emergency_state.dart';

class ActiveSosScreen extends ConsumerStatefulWidget {
  const ActiveSosScreen({super.key});

  @override
  ConsumerState<ActiveSosScreen> createState() => _ActiveSosScreenState();
}

class _ActiveSosScreenState extends ConsumerState<ActiveSosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showDeactivationKeypad(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _PinKeypadSheet(
        onPinEntered: (pin) async {
          // We pass pin to cancelWithPin which now takes a String pin.
          // Wait, the existing `cancelWithPin` takes (String pin, PinType pinType).
          // Oh, I will refactor `cancelWithPin` to just take (String pin) and handle the logic inside it!
          final success = await ref
              .read(sosControllerProvider.notifier)
              .cancelWithPin(pin, PinType.safety); // We will update signature in sos_controller
          
          if (success) {
            if (context.mounted) Navigator.pop(context); // Close keypad
          } else {
            HapticFeedback.heavyImpact();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9F1239),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 150 + (30 * _pulseController.value),
                    height: 150 + (30 * _pulseController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF43F5E).withOpacity(0.2),
                      border: Border.all(
                        color: const Color(0xFFF43F5E)
                            .withOpacity(0.5 + (0.5 * _pulseController.value)),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withOpacity(0.6),
                          blurRadius: 40 * _pulseController.value,
                          spreadRadius: 10 * _pulseController.value,
                        )
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 80),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              Text(
                "EMERGENCY ACTIVE",
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your location and distress signals\nare being broadcasted securely.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF9F1239),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  onPressed: () => _showDeactivationKeypad(context, ref),
                  child: Text(
                    "DEACTIVATE EMERGENCY",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinKeypadSheet extends StatefulWidget {
  final Function(String pin) onPinEntered;
  const _PinKeypadSheet({required this.onPinEntered});

  @override
  State<_PinKeypadSheet> createState() => _PinKeypadSheetState();
}

class _PinKeypadSheetState extends State<_PinKeypadSheet> {
  String _pin = "";

  void _onKeyPress(String key) {
    if (_pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += key;
      });
      if (_pin.length == 4) {
        widget.onPinEntered(_pin);
        // Clear after a brief delay if it failed
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _pin = "");
        });
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Widget _buildKey(String label) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1.2,
        child: InkWell(
          onTap: () => _onKeyPress(label),
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(top: 32, bottom: 40, left: 24, right: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Enter PIN to resolve alert",
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? const Color(0xFF38BDF8) : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? const Color(0xFF38BDF8) : Colors.white24,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 48),
          Column(
            children: [
              Row(children: [_buildKey('1'), _buildKey('2'), _buildKey('3')]),
              const SizedBox(height: 16),
              Row(children: [_buildKey('4'), _buildKey('5'), _buildKey('6')]),
              const SizedBox(height: 16),
              Row(children: [_buildKey('7'), _buildKey('8'), _buildKey('9')]),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Container()),
                  _buildKey('0'),
                  Expanded(
                    child: InkWell(
                      onTap: _onDelete,
                      borderRadius: BorderRadius.circular(20),
                      child: const Center(
                        child: Icon(Icons.backspace_outlined,
                            color: Colors.white54, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
