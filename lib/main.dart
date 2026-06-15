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
// Design System / Constants
// ─────────────────────────────────────────────
const Color kBackground = Color(0xFF070709);
const Color kCardColor = Color(0xFF121217);
const Color kAccent = Color(0xFFFF4B2B);
const Color kAccentGlow = Color(0x22FF4B2B);
const Color kAccentBorder = Color(0x44FF4B2B);
const Color kSuccess = Color(0xFF34C759);
const Color kMuted = Color(0xFF555566);
const Color kDim = Color(0xFF333344);

// ─────────────────────────────────────────────
// Audio Player Helper
// ─────────────────────────────────────────────
class AlarmAudio {
  static final AlarmAudio _instance = AlarmAudio._internal();
  factory AlarmAudio() => _instance;
  AlarmAudio._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> startAlarm() async {
    if (_isPlaying) return;
    _player = AudioPlayer();
    try {
      // Use loopable beep tone URL
      await _player!.setUrl(
        'https://www.soundjay.com/buttons/sounds/beep-07.mp3',
        preload: true,
      );
      await _player!.setLoopMode(LoopMode.one);
      await _player!.play();
      _isPlaying = true;
    } catch (e) {
      debugPrint("Audio Error: $e");
      _isPlaying = true; // Fallback so UI still behaves as alarm is active
    }
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying) return;
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (e) {
      debugPrint("Error stopping audio: $e");
    }
    _player = null;
    _isPlaying = false;
  }
}

// ─────────────────────────────────────────────
// Main Entry Point
// ─────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBackground,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const AlarmProApp());
}

class AlarmProApp extends StatelessWidget {
  const AlarmProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlarmPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackground,
        colorScheme: const ColorScheme.dark(
          primary: kAccent,
          surface: kBackground,
        ),
        textTheme: GoogleFonts.syneTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AlarmHomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// Shake Animation Widget
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
    final animation = listenable as Animation<double>;
    
    // Create translation offsets and tilt based on fast oscillations
    final double dx = math.sin(animation.value * math.pi * 12) * 7.0;
    final double dy = math.cos(animation.value * math.pi * 9) * 5.0;
    final double rotation = math.sin(animation.value * math.pi * 6) * 0.04;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: rotation,
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

class _AlarmHomeScreenState extends State<AlarmHomeScreen> with TickerProviderStateMixin {
  late Timer _clockTimer;
  Timer? _hapticTimer;
  DateTime _now = DateTime.now();
  bool _alarmFiring = true;
  bool _showSuccessOverlay = false;

  final AlarmAudio _audio = AlarmAudio();

  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });

    // Pulse animation for alert neon lines
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Violent shaking animation controller
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat();

    // Start Alarm instantly on app launch
    _startPrankAlarm();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) {
      await [Permission.notification].request();
    }
  }

  void _startPrankAlarm() async {
    setState(() {
      _alarmFiring = true;
    });

    // Play loop audio
    await _audio.startAlarm();

    // Loop physical vibration
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_alarmFiring) {
        HapticFeedback.vibrate();
      }
    });
  }

  void _stopPrankAlarm() async {
    _hapticTimer?.cancel();
    await _audio.stopAlarm();
    if (mounted) {
      setState(() {
        _alarmFiring = false;
      });
    }
  }

  void _resetPrankAlarm() {
    _startPrankAlarm();
  }

  void _showApplePay() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApplePaySheet(
        onSuccess: () {
          setState(() {
            _showSuccessOverlay = true;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _hapticTimer?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');

    final months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dayStr =
        '${days[_now.weekday - 1]}, ${_now.day} ${months[_now.month - 1]} ${_now.year}';

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient and Glowing spots
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    Color(0xFF13141F),
                    Color(0xFF070709),
                  ],
                ),
              ),
            ),
          ),

          // Orbital neon back glow behind clock
          if (_alarmFiring)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.12,
              left: MediaQuery.of(context).size.width * 0.1,
              right: MediaQuery.of(context).size.width * 0.1,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) => Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kAccent.withOpacity(0.12 * _pulseAnim.value),
                        blurRadius: 100,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Main Layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 10), // Safe Spacer instead of Header

                  // Clock & Visual Status Section
                  Column(
                    children: [
                      // Enormous 3D Shaking Clock
                      ShakeWidget(
                        animation: _shakeController,
                        isShaking: _alarmFiring,
                        child: const SizedBox(
                          width: 250,
                          height: 250,
                          child: PremiumAnalogClock(),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Status Badge
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _alarmFiring
                            ? Container(
                                key: const ValueKey('firing_badge'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: kAccent.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: kAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ALARM ACTIVE',
                                      style: GoogleFonts.syne(
                                        fontSize: 10,
                                        letterSpacing: 3,
                                        color: kAccent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                key: const ValueKey('silenced_badge'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kSuccess.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: kSuccess.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: kSuccess,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'SILENCED — STATUS: PAID',
                                      style: GoogleFonts.syne(
                                        fontSize: 10,
                                        letterSpacing: 2,
                                        color: kSuccess,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Digital Display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$h:$m',
                            style: GoogleFonts.dmMono(
                              fontSize: 72,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: -3,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ':$s',
                            style: GoogleFonts.dmMono(
                              fontSize: 24,
                              color: kMuted,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayStr,
                        style: GoogleFonts.syne(
                          fontSize: 12,
                          color: kMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),

                  // Bottom Action Button Section
                  Column(
                    children: [
                      if (_alarmFiring)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            "TO DEACTIVATE SOUND & VIBRATION",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.syne(
                              fontSize: 10,
                              color: kMuted,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      _alarmFiring
                          ? GestureDetector(
                              onTap: _showApplePay,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.12),
                                      blurRadius: 25,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      " ",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "Pay \$19.00 to Stop Alarm",
                                      style: GoogleFonts.syne(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                Text(
                                  "Payment Verified. Sweet Dreams!",
                                  style: GoogleFonts.syne(
                                    color: kSuccess,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: _resetPrankAlarm,
                                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                                  label: Text(
                                    "ARM ALARM AGAIN",
                                    style: GoogleFonts.syne(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: kMuted,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      side: const BorderSide(color: kDim),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Success Overlay Screen
          if (_showSuccessOverlay)
            Positioned.fill(
              child: SuccessScreen(
                onClose: () {
                  setState(() {
                    _showSuccessOverlay = false;
                  });
                  _stopPrankAlarm();
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Premium Analog Clock Painter & Widget
// ─────────────────────────────────────────────
class PremiumAnalogClock extends StatefulWidget {
  const PremiumAnalogClock({super.key});

  @override
  State<PremiumAnalogClock> createState() => _PremiumAnalogClockState();
}

class _PremiumAnalogClockState extends State<PremiumAnalogClock>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        return CustomPaint(
          painter: PremiumAnalogClockPainter(time: DateTime.now()),
        );
      },
    );
  }
}

class PremiumAnalogClockPainter extends CustomPainter {
  final DateTime time;

  PremiumAnalogClockPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // 1. Dark glowing drop shadow under the 3D bezel
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center + const Offset(0, 12), radius - 4, shadowPaint);

    // 2. Bezel outer rim (graduated charcoal/metallic gradient)
    final bezelPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.grey.shade900,
          Colors.black,
        ],
        stops: const [0.88, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bezelPaint);

    // Metallic highlight sheen on top-left edge
    final bezelHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.18),
          Colors.transparent,
          Colors.black.withOpacity(0.5),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bezelHighlight);

    // Inner rim stroke
    final innerRimPaint = Paint()
      ..color = const Color(0xFF282A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 6, innerRimPaint);

    // 3. Dial Plate Face (Concave feel gradient)
    final dialPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.15, -0.15),
        colors: [
          const Color(0xFF1E2130),
          const Color(0xFF090A0D),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 8))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 8, dialPaint);

    // Glowing subtle outer rim on face
    final dialFaceGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          kAccent.withOpacity(0.06),
          Colors.transparent,
        ],
        stops: const [0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 8))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 8, dialFaceGlow);

    // 4. Tick markings (Hour and Minute bars)
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i < 60; i++) {
      final double angle = i * 6 * math.pi / 180;
      final bool isHour = i % 5 == 0;
      final double startRadius = radius * (isHour ? 0.73 : 0.81);
      final double endRadius = radius * 0.86;

      tickPaint.color = isHour
          ? kAccent.withOpacity(0.85)
          : Colors.white.withOpacity(0.2);
      tickPaint.strokeWidth = isHour ? 3.0 : 1.2;

      final startOffset = Offset(
        center.dx + startRadius * math.cos(angle - math.pi / 2),
        center.dy + startRadius * math.sin(angle - math.pi / 2),
      );
      final endOffset = Offset(
        center.dx + endRadius * math.cos(angle - math.pi / 2),
        center.dy + endRadius * math.sin(angle - math.pi / 2),
      );
      canvas.drawLine(startOffset, endOffset, tickPaint);
    }

    // 5. Get time components
    final double milli = time.millisecond.toDouble();
    final double second = time.second + milli / 1000.0;
    final double minute = time.minute + second / 60.0;
    final double hour = (time.hour % 12) + minute / 60.0;

    // 6. Draw Hands with 3D shadows to simulate depth
    final shadowOffset = const Offset(4, 5);

    // Hour hand angle & coords
    final hourAngle = (hour * 30) * math.pi / 180 - math.pi / 2;
    final hourHandLength = radius * 0.44;
    final handShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + shadowOffset,
      Offset(
        center.dx + shadowOffset.dx + hourHandLength * math.cos(hourAngle),
        center.dy + shadowOffset.dy + hourHandLength * math.sin(hourAngle),
      ),
      handShadowPaint,
    );

    // Minute hand angle & coords
    final minuteAngle = (minute * 6) * math.pi / 180 - math.pi / 2;
    final minuteHandLength = radius * 0.65;
    final minHandShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + shadowOffset,
      Offset(
        center.dx + shadowOffset.dx + minuteHandLength * math.cos(minuteAngle),
        center.dy + shadowOffset.dy + minuteHandLength * math.sin(minuteAngle),
      ),
      minHandShadowPaint,
    );

    // Render Hour Hand (Clean silver-white)
    final hourPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + hourHandLength * math.cos(hourAngle),
        center.dy + hourHandLength * math.sin(hourAngle),
      ),
      hourPaint,
    );

    // Render Minute Hand (Greyish silver)
    final minutePaint = Paint()
      ..color = const Color(0xFFE5E6EA)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + minuteHandLength * math.cos(minuteAngle),
        center.dy + minuteHandLength * math.sin(minuteAngle),
      ),
      minutePaint,
    );

    // Second Hand Shadow
    final secondAngle = (second * 6) * math.pi / 180 - math.pi / 2;
    final secondHandLength = radius * 0.77;
    final secondTailLength = radius * 0.16;
    final secHandShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      center + shadowOffset - Offset(secondTailLength * math.cos(secondAngle), secondTailLength * math.sin(secondAngle)),
      center + shadowOffset + Offset(secondHandLength * math.cos(secondAngle), secondHandLength * math.sin(secondAngle)),
      secHandShadowPaint,
    );

    // Render Second Hand (Sweeping neon red/orange)
    final secondPaint = Paint()
      ..color = kAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final secondEnd = Offset(
      center.dx + secondHandLength * math.cos(secondAngle),
      center.dy + secondHandLength * math.sin(secondAngle),
    );
    final secondTail = Offset(
      center.dx - secondTailLength * math.cos(secondAngle),
      center.dy - secondTailLength * math.sin(secondAngle),
    );
    canvas.drawLine(secondTail, secondEnd, secondPaint);

    // 7. Bevel center pinion cap (stacked layers)
    final capShadow = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center + const Offset(1, 1), 7.0, capShadow);

    canvas.drawCircle(center, 6.0, Paint()..color = const Color(0xFF2C2E3C));
    canvas.drawCircle(center, 4.0, Paint()..color = kAccent);
    canvas.drawCircle(center, 1.5, Paint()..color = Colors.white);

    // 8. Domed Glass Lens sheen reflection
    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.01),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 8))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 8, glassPaint);
  }

  @override
  bool shouldRepaint(covariant PremiumAnalogClockPainter oldDelegate) =>
      oldDelegate.time != time;
}

// ─────────────────────────────────────────────
// Simulated Apple Pay Sheet
// ─────────────────────────────────────────────
class ApplePaySheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const ApplePaySheet({super.key, required this.onSuccess});

  @override
  State<ApplePaySheet> createState() => _ApplePaySheetState();
}

class _ApplePaySheetState extends State<ApplePaySheet> {
  bool _isEnteringPin = false;
  bool _isProcessing = false;
  String _pin = "";

  void _onKeyPress(String val) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += val;
    });
    HapticFeedback.lightImpact();

    if (_pin.length == 4) {
      // Completed pin
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() {
          _isEnteringPin = false;
          _isProcessing = true;
        });

        // Mock 1.5s card verification & charge
        Future.delayed(const Duration(milliseconds: 1800), () {
          Navigator.pop(context); // close bottom sheet
          widget.onSuccess();    // trigger success screen
        });
      });
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF16161B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 34.0,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _isProcessing
            ? _buildProcessingState()
            : _isEnteringPin
                ? _buildPinKeypad()
                : _buildApplePayOptions(),
      ),
    );
  }

  // State 1: Normal Apple Pay Dialog showing Card, Total and Pay button
  Widget _buildApplePayOptions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.syne(
                  color: Colors.blueAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              children: [
                const Text(
                  " ",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Pay",
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 48), // Spacer symmetry
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFF2C2C32), height: 1),

        // CARD ROW
        _buildInfoRow(
          title: "CARD",
          contentWidget: Row(
            children: [
              Container(
                width: 38,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5D5E6A), Color(0xFF2E2E3E)],
                  ),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 4),
                child: const Text("", style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      " Card (•••• 1984)",
                      style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "Apple Account Balance",
                      style: GoogleFonts.syne(fontSize: 11, color: kMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kMuted, size: 18),
            ],
          ),
        ),
        const Divider(color: Color(0xFF2C2C32), height: 1),

        // BILLING ROW
        _buildInfoRow(
          title: "BILLING",
          contentWidget: Row(
            children: [
              Expanded(
                child: Text(
                  "Steve Jobs, 1 Infinite Loop, Cupertino, CA",
                  style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, color: kMuted, size: 18),
            ],
          ),
        ),
        const Divider(color: Color(0xFF2C2C32), height: 1),

        // DELIVERY ROW
        _buildInfoRow(
          title: "METHOD",
          contentWidget: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Instant Alarm Silence",
                      style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "Delivered immediately",
                      style: GoogleFonts.syne(fontSize: 11, color: kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF2C2C32), height: 1),

        // AMOUNT ROW
        _buildInfoRow(
          title: "TOTAL",
          contentWidget: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "USD",
                style: GoogleFonts.syne(fontSize: 13, color: kMuted),
              ),
              Text(
                "\$19.00",
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Trigger PIN button
        GestureDetector(
          onTap: () {
            setState(() {
              _isEnteringPin = true;
            });
            HapticFeedback.mediumImpact();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              "Pay with Passcode",
              style: GoogleFonts.syne(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            "Double-click side button to confirm (Simulated)",
            style: GoogleFonts.syne(color: kMuted, fontSize: 10),
          ),
        ),
      ],
    );
  }

  // State 2: Passcode Entry Screen mimicking iOS Lock PIN input
  Widget _buildPinKeypad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN Title
        Text(
          "Enter Device Passcode",
          style: GoogleFonts.syne(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Enter your device password to approve Pay",
          style: GoogleFonts.syne(
            fontSize: 12,
            color: kMuted,
          ),
        ),
        const SizedBox(height: 24),

        // Passcode indicators (4 circles)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            bool active = _pin.length > index;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? Colors.white : Colors.transparent,
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),

        // Keypad numbers 1-9, 0
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            // Keypad layout maps
            if (index == 9) {
              // Cancel
              return TextButton(
                onPressed: () {
                  setState(() {
                    _isEnteringPin = false;
                    _pin = "";
                  });
                },
                child: Text(
                  "Back",
                  style: GoogleFonts.syne(color: Colors.white, fontSize: 14),
                ),
              );
            }
            if (index == 11) {
              // Delete
              return IconButton(
                onPressed: _onDelete,
                icon: const Icon(Icons.backspace_outlined, color: Colors.white, size: 18),
              );
            }

            final label = index == 10 ? "0" : "${index + 1}";
            return GestureDetector(
              onTap: () => _onKeyPress(label),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF25252D),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: GoogleFonts.dmMono(
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // State 3: Processing screen with custom spinner
  Widget _buildProcessingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Contacting Issuer...",
            style: GoogleFonts.syne(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Verifying simulated transaction",
            style: GoogleFonts.syne(
              fontSize: 11,
              color: kMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required String title, required Widget contentWidget}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              title,
              style: GoogleFonts.syne(
                fontSize: 10,
                color: kMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(child: contentWidget),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Success / Thank You Screen Overlay
// ─────────────────────────────────────────────
class SuccessScreen extends StatefulWidget {
  final VoidCallback onClose;

  const SuccessScreen({super.key, required this.onClose});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animController.forward();

    // Trigger success system beep and sound
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.92),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular green success checkmark
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: kSuccess,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3334C759),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(44, 44),
                      painter: CheckmarkPainter(progress: _checkAnimation.value),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Success Text
            Text(
              "Payment Successful",
              style: GoogleFonts.syne(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "We have successfully received your \$19.00 payment.\nThe alarm will be silenced immediately.",
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(
                fontSize: 13,
                color: kMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 48),

            // Close button
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F29),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2E3C)),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Dismiss Alarm",
                  style: GoogleFonts.syne(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;

  CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Starting point of checkmark relative to box (44x44)
    path.moveTo(size.width * 0.22, size.height * 0.52);
    
    // Corner point
    path.lineTo(size.width * 0.44, size.height * 0.72);
    
    // End point
    path.lineTo(size.width * 0.78, size.height * 0.32);

    // Compute progress of the path
    final pms = path.computeMetrics();
    final drawingPath = Path();
    
    for (final pm in pms) {
      final length = pm.length * progress;
      drawingPath.addPath(pm.extractPath(0, length), Offset.zero);
    }

    canvas.drawPath(drawingPath, paint);
  }

  @override
  bool shouldRepaint(covariant CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
