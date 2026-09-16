import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:audio_session/audio_session.dart' as a_session;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// SIREN SCREEN
// -----------------------------------------------------------------------------
class SirenScreen extends StatefulWidget {
  const SirenScreen({super.key});
  @override
  State<SirenScreen> createState() => _SirenScreenState();
}

class _SirenScreenState extends State<SirenScreen> {
  bool _isRed = true;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startSiren();
  }

  Future<void> _startSiren() async {
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted) setState(() => _isRed = !_isRed);
      if (!kIsWeb) HapticFeedback.vibrate();
    });

    if (!kIsWeb) {
      try {
        final session = await a_session.AudioSession.instance;

        // FIX: More aggressive speaker routing
        await session.configure(const a_session.AudioSessionConfiguration(
          avAudioSessionCategory: a_session
              .AVAudioSessionCategory.playAndRecord, // Changed to playAndRecord
          avAudioSessionCategoryOptions:
              a_session.AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: a_session
              .AVAudioSessionMode.spokenAudio, // Better for forcing speaker
          avAudioSessionRouteSharingPolicy:
              a_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              a_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: a_session.AndroidAudioAttributes(
            contentType: a_session.AndroidAudioContentType.speech,
            flags: a_session.AndroidAudioFlags.audibilityEnforced,
            usage: a_session.AndroidAudioUsage.alarm, // High priority
          ),
          androidAudioFocusGainType:
              a_session.AndroidAudioFocusGainType.gainTransientExclusive,
          androidWillPauseWhenDucked: true,
        ));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_app_changing_volume', true);

        await PerfectVolumeControl.setVolume(1.0);

        Future.delayed(const Duration(seconds: 2), () async {
          await prefs.setBool('is_app_changing_volume', false);
        });
      } catch (e) {
        debugPrint("Hardware volume override skipped/failed: $e");
      }
    }

    try {
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/siren.mp3'));
    } catch (e) {
      debugPrint("Siren audio failed to play: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor:
            _isRed ? const Color(0xFFF43F5E) : const Color(0xFF3B82F6),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 120),
              const SizedBox(height: 20),
              Text("EMERGENCY ALARM",
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4)),
              const SizedBox(height: 40),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(30)),
                child: Text("TAP ANYWHERE TO STOP",
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REAL AUDIO RECORDING EVIDENCE VAULT
// -----------------------------------------------------------------------------
class AudioRecordingSheet extends StatefulWidget {
  const AudioRecordingSheet({super.key});
  @override
  State<AudioRecordingSheet> createState() => _AudioRecordingSheetState();
}

class _AudioRecordingSheetState extends State<AudioRecordingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pc;
  int _s = 0;
  Timer? _t;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _pc = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _initRecording();
  }

  Future<void> _initRecording() async {
    try {
      if (kIsWeb) {
        // Fallback for Web Testing (Skips actual recording)
        setState(() => _isInitializing = false);
        return;
      }

      // Request microphone permissions
      if (await _audioRecorder.hasPermission()) {
        // Find the secure internal App Directory
        final dir = await getApplicationDocumentsDirectory();
        final String filePath =
            '${dir.path}/safesight_evidence_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Start High-Quality background recording
        await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
            path: filePath);

        if (mounted) {
          setState(() {
            _isRecording = true;
            _isInitializing = false;
          });
          // Start the UI Timer
          _t = Timer.periodic(
              const Duration(seconds: 1), (t) => setState(() => _s++));
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  "Microphone permission denied. Cannot collect evidence.")));
        }
      }
    } catch (e) {
      debugPrint("Record error: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _stopAndSave() async {
    if (_isRecording) {
      // Stops the recorder and grabs the final saved path
      final path = await _audioRecorder.stop();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Secure Audio Evidence Saved:\n$path",
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          backgroundColor: const Color(0xFF34D399),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    _t?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing && !kIsWeb) {
      return Container(
        height: 200,
        decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFF43F5E))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)))),
        Text(kIsWeb ? "Mock Recording (Web Mode)" : "Recording Evidence...",
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        AnimatedBuilder(
            animation: _pc,
            builder: (c, w) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF43F5E)
                        .withValues(alpha: 0.2 + (0.8 * _pc.value)),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFF43F5E)
                              .withValues(alpha: 0.5 * _pc.value),
                          blurRadius: 20)
                    ]),
                child: const Icon(Icons.mic, color: Colors.white, size: 40))),
        const SizedBox(height: 24),
        Text(
            "${(_s ~/ 60).toString().padLeft(2, '0')}:${(_s % 60).toString().padLeft(2, '0')}",
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
                onPressed: _stopAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  side: BorderSide(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("STOP & SAVE",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1)))),
        const SizedBox(height: 16),
      ]),
    );
  }
}
