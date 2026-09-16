import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/reliable_location.dart';
import '../../../../features/emergency/domain/models/emergency_state.dart';
import '../../../../features/emergency/presentation/controllers/sos_controller.dart';
import '../../../../features/guardians/data/guardian_repository.dart';

class SOSButton extends ConsumerStatefulWidget {
  final VoidCallback onNoContacts;

  const SOSButton({super.key, required this.onNoContacts});

  @override
  ConsumerState<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends ConsumerState<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _holdTimer;
  StreamSubscription? _guardianSubscription;
  double _holdProgress = 0.0;
  bool _hasGuardian = false;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _guardianSubscription = GuardianRepository().watchGuardians().listen(
      (guardians) {
        if (mounted) setState(() => _hasGuardian = guardians.isNotEmpty);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Guardian status unavailable: $error');
        if (mounted) setState(() => _hasGuardian = false);
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdTimer?.cancel();
    _guardianSubscription?.cancel();
    super.dispose();
  }

  void _startHold() async {
    if (ref.read(sosControllerProvider).phase != EmergencyPhase.idle) return;

    if (!_hasGuardian) {
      widget.onNoContacts();
      return;
    }

    HapticFeedback.lightImpact();
    ref.read(sosControllerProvider.notifier).beginPress();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        return;
      }
      setState(() {
        _holdProgress += (1 / 40);
      });
      if (_holdProgress >= 1.0) _triggerSOS();
    });
  }

  void _cancelHold() {
    if (ref.read(sosControllerProvider).phase != EmergencyPhase.pressing) {
      return;
    }
    _holdTimer?.cancel();
    setState(() {
      _holdProgress = 0.0;
    });
    ref.read(sosControllerProvider.notifier).cancelPress();
  }

  Future<void> _triggerSOS() async {
    _holdTimer?.cancel();
    setState(() {
      _holdProgress = 1.0;
    });
    HapticFeedback.heavyImpact();

    try {
      final position = await getReliableLocation();
      if (position == null) {
        throw StateError(
            'Location is unavailable. Move outdoors or enable GPS.');
      }
      await ref.read(sosControllerProvider.notifier).trigger(position);
    } catch (e) {
      debugPrint("SOS Error: $e");
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _holdProgress = 0.0;
      });
      ref.read(sosControllerProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(sosControllerProvider);
    final isActive = emergencyState.phase == EmergencyPhase.triggered ||
        emergencyState.phase == EmergencyPhase.broadcasting;
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: () => _cancelHold(),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (!isActive && _holdProgress == 0)
                Container(
                    width: 170 + (20 * _pulseController.value),
                    height: 170 + (20 * _pulseController.value),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF43F5E).withValues(
                            alpha: 0.1 * (1 - _pulseController.value)))),
              SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                      value: _holdProgress,
                      strokeWidth: 8,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFF43F5E)))),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: isActive
                            ? [const Color(0xFFBE123C), const Color(0xFF881337)]
                            : [
                                const Color(0xFFF43F5E),
                                const Color(0xFFBE123C)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 5))
                    ]),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isActive)
                        const Icon(Icons.wifi_tethering,
                            color: Colors.white, size: 40)
                      else ...[
                        const Icon(Icons.touch_app,
                            color: Colors.white, size: 32),
                        const Text("SOS",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900))
                      ]
                    ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
