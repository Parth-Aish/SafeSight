import 'dart:async';
// FIX: Replaced 'dart:io' with Flutter's cross-platform foundation
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:audio_session/audio_session.dart' as a_session;
import 'package:shared_preferences/shared_preferences.dart';

class FakeCallScreen extends StatefulWidget {
  final String name;
  final String number;
  const FakeCallScreen({super.key, required this.name, required this.number});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool _isAccepted = false;
  int _seconds = 0;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  Future<void> _startRinging() async {
    if (!kIsWeb) HapticFeedback.vibrate();

    // 1. HARDWARE OVERRIDES: Force Audio to Main Speaker
    if (!kIsWeb) {
      try {
        final session = await a_session.AudioSession.instance;
        await session.configure(const a_session.AudioSessionConfiguration(
          avAudioSessionCategory: a_session.AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              a_session.AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: a_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              a_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              a_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: a_session.AndroidAudioAttributes(
            contentType: a_session.AndroidAudioContentType.music,
            flags: a_session.AndroidAudioFlags.audibilityEnforced,
            usage: a_session.AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              a_session.AndroidAudioFocusGainType.gainTransientExclusive,
          androidWillPauseWhenDucked: true,
        ));

        // Alert Background Engine to ignore this volume spike
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_app_changing_volume', true);

        await PerfectVolumeControl.setVolume(1.0);

        Future.delayed(const Duration(seconds: 2), () async {
          await prefs.setBool('is_app_changing_volume', false);
        });
      } catch (e) {
        debugPrint("Hardware override skipped: $e");
      }
    }

    // 2. PLAY AUDIO (Works on both Web and Mobile)
    try {
      _audioPlayer.setReleaseMode(ReleaseMode.loop);

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _audioPlayer.play(AssetSource('audio/iphone.mp3'));
      } else {
        await _audioPlayer.play(AssetSource('audio/samsung.mp3'));
      }
    } catch (e) {
      debugPrint("Audio play failed: $e");
    }
  }

  void _acceptCall() {
    setState(() => _isAccepted = true);
    _audioPlayer.stop();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds++);
    });
  }

  void _endCall() {
    _timer?.cancel();
    _audioPlayer.stop();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime() {
    int m = _seconds ~/ 60;
    int s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // FIX: Web-safe platform checking
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return _buildIosUI();
    }
    return _buildAndroidUI();
  }

  Widget _buildIosUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter))),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 50),
                Text(widget.name,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 8),
                Text(_isAccepted ? _formatTime() : "mobile",
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 18)),
                const Spacer(),
                if (!_isAccepted)
                  _buildIosIncomingActions()
                else
                  _buildIosActiveActions(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIosIncomingActions() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _iosIconBtn(Icons.alarm, "Remind Me"),
                _iosIconBtn(Icons.message, "Message")
              ]),
        ),
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _iosCircleBtn(
                Icons.call_end, "Decline", const Color(0xFFFF3B30), _endCall),
            _iosCircleBtn(
                Icons.call, "Accept", const Color(0xFF34C759), _acceptCall)
          ]),
        ),
      ],
    );
  }

  Widget _buildIosActiveActions() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Wrap(
              spacing: 30,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _iosIconBtn(Icons.mic_off, "mute", isActive: true),
                _iosIconBtn(Icons.dialpad, "keypad"),
                _iosIconBtn(Icons.volume_up, "speaker"),
                _iosIconBtn(Icons.add, "add call"),
                _iosIconBtn(Icons.videocam, "FaceTime"),
                _iosIconBtn(Icons.account_circle, "contacts")
              ]),
        ),
        const SizedBox(height: 60),
        _iosCircleBtn(Icons.call_end, "", const Color(0xFFFF3B30), _endCall,
            size: 75),
      ],
    );
  }

  Widget _iosCircleBtn(
      IconData icon, String label, Color color, VoidCallback onTap,
      {double size = 75}) {
    return Column(children: [
      GestureDetector(
          onTap: onTap,
          child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: size * 0.5))),
      if (label.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 16))
      ]
    ]);
  }

  Widget _iosIconBtn(IconData icon, String label, {bool isActive = false}) {
    return Column(children: [
      Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle),
          child: Icon(icon,
              color: isActive ? Colors.black : Colors.white, size: 30)),
      const SizedBox(height: 8),
      Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 13))
    ]);
  }

  Widget _buildAndroidUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const CircleAvatar(
                radius: 45,
                backgroundColor: Color(0xFF424242),
                child: Icon(Icons.person, size: 55, color: Colors.white70)),
            const SizedBox(height: 24),
            Text(widget.name,
                style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Text(_isAccepted ? _formatTime() : "Mobile • ${widget.number}",
                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 16)),
            const Spacer(),
            if (!_isAccepted)
              _buildAndroidIncomingActions()
            else
              _buildAndroidActiveActions(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidIncomingActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _androidActionBtn(Icons.call_end, Colors.red, _endCall),
            _androidActionBtn(Icons.call, Colors.green, _acceptCall)
          ]),
          const SizedBox(height: 30),
          Text("Tap to answer/decline",
              style: GoogleFonts.roboto(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAndroidActiveActions() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _androidSmallActionBtn(Icons.mic_off, "Mute"),
            _androidSmallActionBtn(Icons.dialpad, "Keypad"),
            _androidSmallActionBtn(Icons.volume_up, "Speaker")
          ]),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _androidSmallActionBtn(Icons.add_call, "Add call"),
            _androidSmallActionBtn(Icons.pause, "Hold"),
            _androidSmallActionBtn(Icons.more_vert, "More")
          ]),
        ),
        const SizedBox(height: 50),
        FloatingActionButton(
            onPressed: _endCall,
            backgroundColor: Colors.red,
            elevation: 0,
            child: const Icon(Icons.call_end, color: Colors.white, size: 30)),
      ],
    );
  }

  Widget _androidActionBtn(IconData icon, Color bgColor, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 35)));
  }

  Widget _androidSmallActionBtn(IconData icon, String label) {
    return Column(children: [
      Icon(icon, color: Colors.white, size: 28),
      const SizedBox(height: 8),
      Text(label, style: GoogleFonts.roboto(color: Colors.white, fontSize: 12))
    ]);
  }
}
