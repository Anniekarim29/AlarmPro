import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────
// Design Tokens — Zero gradients, flat + professional
// ─────────────────────────────────────────────
const Color kBg      = Color(0xFF0F0E17);
const Color kSurface = Color(0xFF1C1A2E);
const Color kBorder  = Color(0xFF2A2840);
const Color kText    = Color(0xFFF5F4FF);
const Color kMuted   = Color(0xFF5A5870);
const Color kSuccess = Color(0xFF4ADE80);
const Color kWhite   = Color(0xFFFFFFFF);

// ─────────────────────────────────────────────
// Audio
// ─────────────────────────────────────────────
class AlarmAudio {
  static final AlarmAudio _i = AlarmAudio._();
  factory AlarmAudio() => _i;
  AlarmAudio._();

  AudioPlayer? _p;
  bool _playing = false;
  bool get isPlaying => _playing;

  Future<void> start() async {
    if (_playing) return;
    _p = AudioPlayer();
    try {
      await _p!.setUrl('https://www.soundjay.com/buttons/sounds/beep-07.mp3', preload: true);
      await _p!.setLoopMode(LoopMode.one);
      await _p!.play();
      _playing = true;
    } catch (_) {
      _playing = true;
    }
  }

  Future<void> stop() async {
    if (!_playing) return;
    try {
      await _p?.stop();
      await _p?.dispose();
    } catch (_) {}
    _p = null;
    _playing = false;
  }
}

// ─────────────────────────────────────────────
// Entry
// ─────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const AlarmSaasApp());
}

class AlarmSaasApp extends StatelessWidget {
  const AlarmSaasApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kWhite, surface: kSurface),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AlarmHomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// Shake Widget
// ─────────────────────────────────────────────
class ShakeWidget extends AnimatedWidget {
  final Widget child;
  final bool isShaking;
  const ShakeWidget({
    super.key,
    required Animation<double> animation,
    required this.child,
    required this.isShaking,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    if (!isShaking) return child;
    final a = listenable as Animation<double>;
    return Transform.translate(
      offset: Offset(
        math.sin(a.value * math.pi * 12) * 6.0,
        math.cos(a.value * math.pi * 9) * 4.0,
      ),
      child: Transform.rotate(
        angle: math.sin(a.value * math.pi * 6) * 0.03,
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Home Screen
// ─────────────────────────────────────────────
class AlarmHomeScreen extends StatefulWidget {
  const AlarmHomeScreen({super.key});
  @override
  State<AlarmHomeScreen> createState() => _AlarmHomeScreenState();
}

class _AlarmHomeScreenState extends State<AlarmHomeScreen>
    with TickerProviderStateMixin {
  late Timer _clockTimer;
  Timer? _hapticTimer;
  DateTime _now = DateTime.now();
  bool _alarmFiring = true;
  bool _showSuccess = false;

  final AlarmAudio _audio = AlarmAudio();
  late AnimationController _shakeCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _clockTimer = Timer.periodic(
        const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280))
      ..repeat();
    _startAlarm();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) {
      await [Permission.notification].request();
    }
  }

  void _startAlarm() async {
    setState(() => _alarmFiring = true);
    await _audio.start();
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_alarmFiring) HapticFeedback.vibrate();
    });
  }

  void _stopAlarm() async {
    _hapticTimer?.cancel();
    await _audio.stop();
    if (mounted) setState(() => _alarmFiring = false);
  }

  void _showPay() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApplePaySheet(
        onSuccess: () => setState(() => _showSuccess = true),
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _hapticTimer?.cancel();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final days = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
    final months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final dayStr =
        '${days[_now.weekday - 1]} · ${_now.day} ${months[_now.month - 1]} ${_now.year}';

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── HEADER ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    children: [
                      Text(
                        'Alarm SaaS',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: kText,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── CLOCK + CONTROLS ──
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Date + digital time
                      Text(
                        dayStr,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: kMuted,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$h:$m',
                            style: GoogleFonts.outfit(
                              fontSize: 52,
                              fontWeight: FontWeight.w300,
                              color: kText,
                              letterSpacing: -2,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              ' :$s',
                              style: GoogleFonts.outfit(
                                fontSize: 19,
                                color: kMuted,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // ── BIG 3D ANALOG CLOCK ──
                      ShakeWidget(
                        animation: _shakeCtrl,
                        isShaking: _alarmFiring,
                        child: const SizedBox(
                          width: 290,
                          height: 290,
                          child: ClockWidget3D(),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── STOP BUTTON ──
                      if (_alarmFiring)
                        _StopButton(
                          onTap: _showPay,
                          pulseAnim: _pulseAnim,
                        ),

                      // ── SILENCED STATE ──
                      if (!_alarmFiring)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 11),
                              decoration: BoxDecoration(
                                color: kSuccess.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: kSuccess.withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: kSuccess, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Alarm silenced · Payment received',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: kSuccess,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            GestureDetector(
                              onTap: _startAlarm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 12),
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: kBorder),
                                ),
                                child: Text(
                                  'ARM AGAIN',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: kMuted,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Bottom hint
                if (_alarmFiring)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Text(
                      'Tap STOP ALARM to unlock · \$19.00',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: kMuted),
                    ),
                  ),
              ],
            ),
          ),

          // ── SUCCESS OVERLAY ──
          if (_showSuccess)
            Positioned.fill(
              child: SuccessScreen(
                onClose: () {
                  setState(() => _showSuccess = false);
                  _stopAlarm();
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Professional Stop Button — flat, sharp, white
// ─────────────────────────────────────────────
class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  final Animation<double> pulseAnim;
  const _StopButton({required this.onTap, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        height: 56,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3B30).withOpacity(0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'STOP ALARM',
              style: GoogleFonts.outfit(
                color: const Color(0xFF0F0E17),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 3D Analog Clock — NO gradients, flat layers
// ─────────────────────────────────────────────
class ClockWidget3D extends StatefulWidget {
  const ClockWidget3D({super.key});
  @override
  State<ClockWidget3D> createState() => _ClockWidget3DState();
}

class _ClockWidget3DState extends State<ClockWidget3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _t;
  @override
  void initState() {
    super.initState();
    _t = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }
  @override
  void dispose() { _t.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) => CustomPaint(
        painter: _Clock3DPainter(DateTime.now()),
      ),
    );
  }
}

class _Clock3DPainter extends CustomPainter {
  final DateTime t;
  _Clock3DPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    // ── LAYER 1: Hard outer drop shadow (flat black) ──
    canvas.drawCircle(
      c + const Offset(0, 10),
      r,
      Paint()..color = Colors.black.withOpacity(0.55),
    );

    // ── LAYER 2: Outermost ring — dark steel ──
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1A1826));

    // ── LAYER 3: Bezel highlight edge (top-left bright rim, simulates 3D) ──
    // Use a thin arc painted as solid stroke — NO gradient
    const double bezelW = 5;
    // Top-left light arc
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - bezelW / 2),
      math.pi * 1.0,   // start: bottom-right
      math.pi,         // sweep half circle (top side)
      false,
      Paint()
        ..color = const Color(0xFF3A3650)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bezelW,
    );
    // Bottom-right darker arc
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - bezelW / 2),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF0D0B14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bezelW,
    );

    // ── LAYER 4: Inner thin bezel ring ──
    canvas.drawCircle(
      c,
      r - 10,
      Paint()
        ..color = const Color(0xFF0D0B14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      c,
      r - 11.5,
      Paint()
        ..color = const Color(0xFF2E2B44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ── LAYER 5: Clock FACE — flat dark color ──
    canvas.drawCircle(c, r - 13, Paint()..color = const Color(0xFF12101E));

    // ── LAYER 6: Face inner depth ring (flat) ──
    canvas.drawCircle(
      c,
      r - 13,
      Paint()
        ..color = const Color(0xFF0A0914)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // ── LAYER 7: Tick marks ──
    for (int i = 0; i < 60; i++) {
      final angle = i * 6 * math.pi / 180;
      final isHour = i % 5 == 0;
      final is3   = i % 15 == 0;

      final outer = r - 16;
      final inner = isHour
          ? (is3 ? r - 34 : r - 30)
          : r - 22;

      final p1 = Offset(
        c.dx + inner * math.cos(angle - math.pi / 2),
        c.dy + inner * math.sin(angle - math.pi / 2),
      );
      final p2 = Offset(
        c.dx + outer * math.cos(angle - math.pi / 2),
        c.dy + outer * math.sin(angle - math.pi / 2),
      );

      canvas.drawLine(
        p1, p2,
        Paint()
          ..color = is3
              ? const Color(0xFFFFFFFF)
              : isHour
                  ? const Color(0xFFA0A0C0)
                  : const Color(0xFF3A3855)
          ..strokeWidth = is3 ? 2.5 : (isHour ? 1.8 : 1.0)
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── LAYER 8: Hour numbers (12, 3, 6, 9) ──
    final Map<int, String> labels = {0: '12', 15: '3', 30: '6', 45: '9'};
    labels.forEach((tick, label) {
      final angle = tick * 6 * math.pi / 180 - math.pi / 2;
      final pos = Offset(
        c.dx + (r * 0.55) * math.cos(angle),
        c.dy + (r * 0.55) * math.sin(angle),
      );
      final span = TextSpan(
        text: label,
        style: GoogleFonts.outfit(
          fontSize: r * 0.13,
          color: const Color(0xFFCCCCDD),
          fontWeight: FontWeight.w600,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });

    // ── Time values ──
    final ms  = t.millisecond.toDouble();
    final sec = t.second + ms / 1000.0;
    final min = t.minute + sec / 60.0;
    final hr  = (t.hour % 12) + min / 60.0;

    final hourAngle = hr  * 30 * math.pi / 180 - math.pi / 2;
    final minAngle  = min * 6  * math.pi / 180 - math.pi / 2;
    final secAngle  = sec * 6  * math.pi / 180 - math.pi / 2;

    // ── HANDS ──
    // Hour hand shadow
    _hand(canvas, c, hourAngle, r * 0.40, 7.0,
        Colors.black.withOpacity(0.5), offset: const Offset(3, 4));
    // Minute hand shadow
    _hand(canvas, c, minAngle, r * 0.60, 5.0,
        Colors.black.withOpacity(0.4), offset: const Offset(2, 3));

    // Hour hand (bright white)
    _hand(canvas, c, hourAngle, r * 0.40, 7.0, const Color(0xFFFFFFFF));
    // Hour hand highlight edge
    _hand(canvas, c, hourAngle, r * 0.40, 2.0, const Color(0xFFE8E8FF),
        strokeCap: StrokeCap.round);

    // Minute hand
    _hand(canvas, c, minAngle, r * 0.60, 5.0, const Color(0xFFD0D0EE));

    // Second hand (flat red-orange, sharp)
    const secColor = Color(0xFFFF3B30);
    final secTail = r * 0.15;
    final secTip  = r * 0.72;
    // tail
    canvas.drawLine(
      c,
      Offset(c.dx - secTail * math.cos(secAngle),
             c.dy - secTail * math.sin(secAngle)),
      Paint()..color = secColor..strokeWidth = 2..strokeCap = StrokeCap.round,
    );
    // tip
    canvas.drawLine(
      c,
      Offset(c.dx + secTip * math.cos(secAngle),
             c.dy + secTip * math.sin(secAngle)),
      Paint()..color = secColor..strokeWidth = 2..strokeCap = StrokeCap.round,
    );

    // ── CENTER CAP (3D layered circles) ──
    canvas.drawCircle(c, 10, Paint()..color = const Color(0xFF0A0914));
    canvas.drawCircle(c, 7,  Paint()..color = const Color(0xFF2A2840));
    canvas.drawCircle(c, 4,  Paint()..color = const Color(0xFFFF3B30));
    canvas.drawCircle(c, 1.5, Paint()..color = const Color(0xFFFFFFFF));

    // ── GLASS SHEEN — flat white arc (NOT gradient) ──
    canvas.drawArc(
      Rect.fromCircle(center: c - const Offset(12, 14), radius: r * 0.55),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.28,
    );
  }

  void _hand(Canvas canvas, Offset c, double angle, double length,
      double width, Color color,
      {Offset offset = Offset.zero, StrokeCap strokeCap = StrokeCap.round}) {
    canvas.drawLine(
      c + offset,
      Offset(c.dx + offset.dx + length * math.cos(angle),
             c.dy + offset.dy + length * math.sin(angle)),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = strokeCap,
    );
  }

  @override
  bool shouldRepaint(covariant _Clock3DPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
// Apple Pay Sheet — iOS authentic (white)
// ─────────────────────────────────────────────
class ApplePaySheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const ApplePaySheet({super.key, required this.onSuccess});
  @override
  State<ApplePaySheet> createState() => _ApplePaySheetState();
}

class _ApplePaySheetState extends State<ApplePaySheet> {
  bool _pinMode = false;
  bool _processing = false;
  String _pin = '';

  void _press(String v) {
    if (_pin.length >= 4) return;
    setState(() => _pin += v);
    HapticFeedback.lightImpact();
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() { _pinMode = false; _processing = true; });
        Future.delayed(const Duration(milliseconds: 1800), () {
          Navigator.pop(context);
          widget.onSuccess();
        });
      });
    }
  }

  void _del() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: _processing ? _loadingView()
            : _pinMode ? _pinView()
            : _mainView(),
      ),
    );
  }

  Widget _mainView() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 36, height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFC7C7CC),
          borderRadius: BorderRadius.circular(2),
        ),
      )),
      const SizedBox(height: 18),
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8EE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.alarm_off_rounded,
            color: Color(0xFF1C1C1E), size: 30),
      ),
      const SizedBox(height: 12),
      const Text('Unlock Alarm Stop',
          style: TextStyle(color: Color(0xFF1C1C1E),
              fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('One-time payment to silence the alarm',
          style: TextStyle(color: Color(0xFF8A8A8E), fontSize: 13)),
      const SizedBox(height: 6),
      const Text('\$19.00',
          style: TextStyle(color: Color(0xFF1C1C1E),
              fontSize: 15, fontWeight: FontWeight.w600)),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(color: Color(0xFFD1D1D6), height: 1),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          Expanded(child: Text('Stop Alarm',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15))),
          Text('\$19.00',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ]),
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GestureDetector(
          onTap: () {
            setState(() => _pinMode = true);
            HapticFeedback.mediumImpact();
          },
          child: Container(
            height: 52, width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('\uF8FF',
                    style: TextStyle(color: Colors.white, fontSize: 20, height: 1.1)),
                SizedBox(width: 6),
                Text('Pay',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(height: 44, alignment: Alignment.center,
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF007AFF), fontSize: 16)),
        ),
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _pinView() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 28),
      const Text('Enter Device Passcode',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E))),
      const SizedBox(height: 6),
      const Text('Confirm identity to approve  Pay',
          style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8E))),
      const SizedBox(height: 28),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final f = _pin.length > i;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: f ? const Color(0xFF1C1C1E) : Colors.transparent,
              border: Border.all(
                  color: const Color(0xFF1C1C1E).withOpacity(0.4), width: 1.5),
            ),
          );
        }),
      ),
      const SizedBox(height: 28),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.6,
          mainAxisSpacing: 10, crossAxisSpacing: 10,
        ),
        itemCount: 12,
        itemBuilder: (_, i) {
          if (i == 9) return TextButton(
            onPressed: () => setState(() { _pinMode = false; _pin = ''; }),
            child: const Text('Back',
                style: TextStyle(color: Color(0xFF007AFF), fontSize: 15)),
          );
          if (i == 11) return IconButton(
            onPressed: _del,
            icon: const Icon(Icons.backspace_outlined,
                color: Color(0xFF1C1C1E), size: 18),
          );
          final lbl = i == 10 ? '0' : '${i + 1}';
          return GestureDetector(
            onTap: () => _press(lbl),
            child: Container(
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFE5E5EA)),
              alignment: Alignment.center,
              child: Text(lbl,
                  style: const TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w400, color: Color(0xFF1C1C1E))),
            ),
          );
        },
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _loadingView() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 36, height: 36,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: Color(0xFF007AFF))),
        SizedBox(height: 20),
        Text('Contacting Issuer...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E))),
        SizedBox(height: 4),
        Text('Verifying payment — please wait',
            style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8E))),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// Success Screen
// ─────────────────────────────────────────────
class SuccessScreen extends StatefulWidget {
  final VoidCallback onClose;
  const SuccessScreen({super.key, required this.onClose});
  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _check;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _scale = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.5, curve: Curves.elasticOut)));
    _check = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut)));
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 150), HapticFeedback.lightImpact);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg.withOpacity(0.97),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kSuccess,
                  boxShadow: [
                    BoxShadow(color: kSuccess.withOpacity(0.28),
                        blurRadius: 32, spreadRadius: 4)
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _check,
                  builder: (_, __) => CustomPaint(
                    size: const Size(44, 44),
                    painter: _CheckPainter(_check.value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('Payment Successful',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700,
                  color: kText, letterSpacing: -0.5)),
            const SizedBox(height: 10),
            Text('We received your \$19.00.\nThe alarm has been silenced.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: kMuted, height: 1.6)),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                alignment: Alignment.center,
                child: Text('Dismiss',
                  style: GoogleFonts.outfit(color: kText, fontSize: 16,
                      fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double p;
  _CheckPainter(this.p);
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * 0.22, s.height * 0.52)
      ..lineTo(s.width * 0.44, s.height * 0.72)
      ..lineTo(s.width * 0.78, s.height * 0.32);
    final pm = path.computeMetrics().first;
    canvas.drawPath(pm.extractPath(0, pm.length * p),
      Paint()..color = Colors.white..strokeWidth = 5
        ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(_CheckPainter o) => o.p != p;
}
