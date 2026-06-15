import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────
const Color kBackground = Color(0xFF0D0D0D);
const Color kCard = Color(0xFF141414);
const Color kAccent = Color(0xFFFF6B2B);
const Color kAccentGlow = Color(0x18FF6B2B);
const Color kAccentBorder = Color(0x33FF6B2B);
const Color kDim = Color(0xFF444444);
const Color kDimmer = Color(0xFF333333);
const Color kMuted = Color(0xFF666666);
const Color kPill = Color(0xFF222222);

// ─────────────────────────────────────────────
// Alarm Model
// ─────────────────────────────────────────────
class AlarmModel {
  final int id;
  final TimeOfDay time;
  bool isActive;

  AlarmModel({required this.id, required this.time, this.isActive = true});

  String get label {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ─────────────────────────────────────────────
// App State (Provider)
// ─────────────────────────────────────────────
class AlarmState extends ChangeNotifier {
  final List<AlarmModel> alarms = [];
  int _nextId = 1;

  AlarmModel addAlarm(TimeOfDay time) {
    final alarm = AlarmModel(id: _nextId++, time: time);
    alarms.add(alarm);
    notifyListeners();
    return alarm;
  }

  void toggleAlarm(int id) {
    final idx = alarms.indexWhere((a) => a.id == id);
    if (idx != -1) {
      alarms[idx].isActive = !alarms[idx].isActive;
      notifyListeners();
    }
  }

  void removeAlarm(int id) {
    alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
// Notifications Service
// ─────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  if (kIsWeb) return;
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await _notificationsPlugin.initialize(initSettings);
}

Future<void> scheduleAlarmNotification(AlarmModel alarm) async {
  // For demonstration, we use periodic checks in the app itself.
  // flutter_local_notifications is initialized and ready.
  // Real scheduling would require timezone package — simplified here.
}

// ─────────────────────────────────────────────
// Grain/Noise Texture Painter
// ─────────────────────────────────────────────
class GrainPainter extends CustomPainter {
  final double opacity;
  final int seed;
  GrainPainter({this.opacity = 0.035, this.seed = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 6000; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final alpha = (rng.nextDouble() * opacity * 255).toInt().clamp(0, 255);
      paint.color = Color.fromARGB(alpha, 255, 255, 255);
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(GrainPainter old) => old.seed != seed;
}

// ─────────────────────────────────────────────
// Premium Analog Clock Widget
// ─────────────────────────────────────────────
class AnalogClock extends StatefulWidget {
  const AnalogClock({super.key});

  @override
  State<AnalogClock> createState() => _AnalogClockState();
}

class _AnalogClockState extends State<AnalogClock> with SingleTickerProviderStateMixin {
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
    return CustomPaint(
      size: const Size(180, 180),
      painter: AnalogClockPainter(repaint: _ticker),
    );
  }
}

class AnalogClockPainter extends CustomPainter {
  AnalogClockPainter({required Listenable repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // 1. Draw outer glowing clock face / plate (Dark glassmorphism style)
    final paintPlate = Paint()
      ..color = const Color(0xFF141414) // Dark card color
      ..style = PaintingStyle.fill;
    
    // Draw subtle outer shadow/glow
    final paintGlow = Paint()
      ..color = kAccent.withValues(alpha: 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);
    canvas.drawCircle(center, radius, paintGlow);
    canvas.drawCircle(center, radius, paintPlate);

    // Draw thin elegant border
    final paintBorder = Paint()
      ..color = const Color(0xFF1C1C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, paintBorder);
    
    // Draw an inner accent ring for visual depth
    final paintInnerRing = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.9, paintInnerRing);

    // 2. Draw Ticks (Hours and Minutes)
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      final double angle = i * 6 * math.pi / 180;
      final bool isHour = i % 5 == 0;
      
      final double startRadius = radius * (isHour ? 0.78 : 0.84);
      final double endRadius = radius * 0.88;
      
      tickPaint.color = isHour 
          ? kAccent.withValues(alpha: 0.6) 
          : const Color(0xFF333333);
      tickPaint.strokeWidth = isHour ? 2.0 : 1.0;

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

    // 3. Get exact time (including milliseconds for sweeping second hand)
    final now = DateTime.now();
    final double milli = now.millisecond.toDouble();
    final double second = now.second + milli / 1000.0;
    final double minute = now.minute + second / 60.0;
    final double hour = (now.hour % 12) + minute / 60.0;

    // 4. Draw Hour Hand (Bold, short, matte white)
    final hourAngle = (hour * 30) * math.pi / 180 - math.pi / 2;
    final hourHandLength = radius * 0.48;
    final hourPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    
    final hourEnd = Offset(
      center.dx + hourHandLength * math.cos(hourAngle),
      center.dy + hourHandLength * math.sin(hourAngle),
    );
    canvas.drawLine(center, hourEnd, hourPaint);

    // 5. Draw Minute Hand (Sleek, medium-long, light grey/white)
    final minuteAngle = (minute * 6) * math.pi / 180 - math.pi / 2;
    final minuteHandLength = radius * 0.68;
    final minutePaint = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    final minuteEnd = Offset(
      center.dx + minuteHandLength * math.cos(minuteAngle),
      center.dy + minuteHandLength * math.sin(minuteAngle),
    );
    canvas.drawLine(center, minuteEnd, minutePaint);

    // 6. Draw Second Hand (Thin, sweeping orange, with tail)
    final secondAngle = (second * 6) * math.pi / 180 - math.pi / 2;
    final secondHandLength = radius * 0.78;
    final secondTailLength = radius * 0.15;
    
    final secondPaint = Paint()
      ..color = kAccent
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    final secondEnd = Offset(
      center.dx + secondHandLength * math.cos(secondAngle),
      center.dy + secondHandLength * math.sin(secondAngle),
    );
    final secondTail = Offset(
      center.dx - secondTailLength * math.cos(secondAngle),
      center.dy - secondTailLength * math.sin(secondAngle),
    );
    
    canvas.drawLine(secondTail, secondEnd, secondPaint);

    // 7. Draw Pinion Center Cap (Glowing orange center dot)
    final centerCapPaint = Paint()
      ..color = kAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.5, centerCapPaint);

    // Draw tiny inner metal pin
    final centerPinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.5, centerPinPaint);
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────
// Audio Player Singleton
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
      // Use a beep tone URL as fallback since we can't bundle assets easily
      await _player!.setUrl(
        'https://www.soundjay.com/buttons/sounds/beep-07.mp3',
        preload: true,
      );
      await _player!.setLoopMode(LoopMode.one);
      await _player!.play();
      _isPlaying = true;
    } catch (e) {
      // If audio fails, still show the UI
      _isPlaying = true;
    }
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying) return;
    await _player?.stop();
    await _player?.dispose();
    _player = null;
    _isPlaying = false;
  }
}

// ─────────────────────────────────────────────
// Main Entry
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));
  await initNotifications();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AlarmState(),
      child: const AlarmProApp(),
    ),
  );
}

// ─────────────────────────────────────────────
// App Root
// ─────────────────────────────────────────────
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
  late Timer _alarmCheckTimer;
  late Timer _grainTimer;
  DateTime _now = DateTime.now();
  int _selectedNavIndex = 0;
  int _grainSeed = 0;
  bool _alarmFiring = false;
  int? _firingAlarmId;

  final AlarmAudio _audio = AlarmAudio();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });

    // Slightly change grain seed every 4 seconds for subtle animation
    _grainTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _grainSeed = math.Random().nextInt(9999));
    });

    // Check alarm firing every 5 seconds
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkAlarms();
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) {
      await [
        Permission.notification,
        Permission.scheduleExactAlarm,
      ].request();
    }
  }

  void _checkAlarms() {
    if (_alarmFiring) return;
    final state = context.read<AlarmState>();
    for (final alarm in state.alarms) {
      if (!alarm.isActive) continue;
      final now = DateTime.now();
      if (alarm.time.hour == now.hour && alarm.time.minute == now.minute) {
        _triggerAlarm(alarm.id);
        break;
      }
    }
  }

  void _triggerAlarm(int alarmId) async {
    if (_alarmFiring) return;
    setState(() {
      _alarmFiring = true;
      _firingAlarmId = alarmId;
    });

    HapticFeedback.heavyImpact();
    await _audio.startAlarm();

    if (!mounted) return;
    _showAlarmSheet();
  }

  void _showAlarmSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlarmFiringSheet(
        onSnooze: () {
          Navigator.pop(context);
          _showSnoozePaywall();
        },
        onDismiss: () {
          Navigator.pop(context);
          _showDismissPaywall();
        },
      ),
    );
  }

  void _showSnoozePaywall() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SnoozePaywallSheet(
        onPay: () {
          Navigator.pop(context);
          _stopAlarm(snooze: true);
        },
        onCancel: () {
          Navigator.pop(context);
          // alarm keeps ringing
          _showAlarmSheet();
        },
      ),
    );
  }

  void _showDismissPaywall() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DismissPaywallSheet(
        onSubscribe: () {
          Navigator.pop(context);
          _stopAlarm(snooze: false);
        },
        onLater: () {
          Navigator.pop(context);
          // alarm keeps ringing
          _showAlarmSheet();
        },
      ),
    );
  }

  void _stopAlarm({required bool snooze}) async {
    await _audio.stopAlarm();
    if (!mounted) return;
    setState(() {
      _alarmFiring = false;
    });

    if (snooze && _firingAlarmId != null) {
      // Schedule a new alarm 5 minutes from now (show visual feedback)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kCard,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'Snoozed for 5 minutes. That\'ll be \$0.49.',
            style: GoogleFonts.syne(color: Colors.white, fontSize: 13),
          ),
          action: SnackBarAction(label: 'OK', textColor: kAccent, onPressed: () {}),
        ),
      );
    }
    _firingAlarmId = null;
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _alarmCheckTimer.cancel();
    _grainTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          // Grain texture
          Positioned.fill(
            child: CustomPaint(painter: GrainPainter(seed: _grainSeed)),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildClock(),
                const SizedBox(height: 32),
                _buildAlarmList(),
                _buildAddButton(),
                const Spacer(),
                _buildBottomCaption(),
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'RISE & GRIND.',
            style: GoogleFonts.syne(
              fontSize: 9,
              letterSpacing: 4,
              color: kDim,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kAccentBorder),
            ),
            child: Text(
              'PRO',
              style: GoogleFonts.syne(
                fontSize: 8,
                letterSpacing: 3,
                color: kAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClock() {
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

    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          // Glowing accent line
          Container(
            width: 32,
            height: 2,
            decoration: BoxDecoration(
              color: kAccent,
              borderRadius: BorderRadius.circular(1),
              boxShadow: [
                BoxShadow(color: kAccent.withValues(alpha: 0.6), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const AnalogClock(),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) => Opacity(
              opacity: _alarmFiring ? _pulseAnim.value : 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$h:$m',
                    style: GoogleFonts.dmMono(
                      fontSize: 72,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ':$s',
                    style: GoogleFonts.dmMono(
                      fontSize: 24,
                      color: kMuted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dayStr,
            style: GoogleFonts.syne(
              fontSize: 11,
              color: const Color(0xFF555555),
              letterSpacing: 1,
            ),
          ),
          if (_alarmFiring) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: kAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: kAccent, blurRadius: 4, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ALARM FIRING',
                    style: GoogleFonts.syne(
                      fontSize: 9,
                      letterSpacing: 3,
                      color: kAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlarmList() {
    return Consumer<AlarmState>(
      builder: (context, state, _) {
        if (state.alarms.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                Text(
                  'No alarms set.',
                  style: GoogleFonts.syne(color: kMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add one to start paying for your sleep.',
                  style: GoogleFonts.syne(color: const Color(0xFF3A3A3A), fontSize: 11),
                ),
              ],
            ),
          );
        }
        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: state.alarms.length,
            itemBuilder: (_, i) => _buildAlarmCard(state.alarms[i], state),
          ),
        );
      },
    );
  }

  Widget _buildAlarmCard(AlarmModel alarm, AlarmState state) {
    return GestureDetector(
      onLongPress: () => _confirmDelete(alarm, state),
      onDoubleTap: () => _triggerAlarm(alarm.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alarm.isActive ? kAccentBorder : const Color(0xFF1E1E1E),
          ),
          boxShadow: alarm.isActive
              ? [BoxShadow(color: kAccentGlow, blurRadius: 20, spreadRadius: 2)]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm.label,
                    style: GoogleFonts.dmMono(
                      fontSize: 32,
                      color: alarm.isActive ? Colors.white : kMuted,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alarm.isActive ? 'ACTIVE — DOUBLE-TAP TO TEST FIRE' : 'INACTIVE',
                    style: GoogleFonts.syne(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: alarm.isActive ? kAccent.withValues(alpha: 0.7) : kMuted,
                    ),
                  ),
                ],
              ),
            ),
            _buildToggle(alarm.isActive, () => state.toggleAlarm(alarm.id)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: isActive ? kAccent : kPill,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isActive
              ? [BoxShadow(color: kAccent.withValues(alpha: 0.4), blurRadius: 10)]
              : [],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(AlarmModel alarm, AlarmState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Alarm?',
            style: GoogleFonts.syne(color: Colors.white, fontSize: 16)),
        content: Text(
          'Removing ${alarm.label}. This is free (for now).',
          style: GoogleFonts.syne(color: kMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.syne(color: kMuted, fontSize: 13)),
          ),
          TextButton(
            onPressed: () {
              state.removeAlarm(alarm.id);
              Navigator.pop(context);
            },
            child: Text('Delete',
                style:
                    GoogleFonts.syne(color: kAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Consumer<AlarmState>(
      builder: (context, state, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: kAccent,
                        surface: kCard,
                        onSurface: Colors.white,
                      ),
                      timePickerTheme: TimePickerThemeData(
                        backgroundColor: kCard,
                        dialHandColor: kAccent,
                        dialBackgroundColor: kPill,
                        hourMinuteShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        hourMinuteColor: kBackground,
                        hourMinuteTextColor: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                state.addAlarm(picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: kMuted, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '+ Add Alarm',
                    style: GoogleFonts.syne(
                      fontSize: 13,
                      color: kMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomCaption() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'PRODUCTIVITY. MONETIZED.',
        style: GoogleFonts.syne(
          fontSize: 9,
          letterSpacing: 3,
          color: kDimmer,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: Icons.alarm, label: 'Alarms'),
      _NavItem(icon: Icons.timer_outlined, label: 'Timer'),
      _NavItem(icon: Icons.settings_outlined, label: 'Settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: const Color(0xFF1C1C1C))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          items.length,
          (i) => GestureDetector(
            onTap: () => setState(() => _selectedNavIndex = i),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _selectedNavIndex == i ? 1.0 : 0.35,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[i].icon,
                    color: _selectedNavIndex == i ? kAccent : Colors.white,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].label,
                    style: GoogleFonts.syne(
                      fontSize: 9,
                      letterSpacing: 1,
                      color: _selectedNavIndex == i ? kAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_selectedNavIndex == i)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: kAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: kAccent, blurRadius: 6, spreadRadius: 1),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────
// Alarm Firing Sheet (non-dismissible)
// ─────────────────────────────────────────────
class AlarmFiringSheet extends StatefulWidget {
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  const AlarmFiringSheet({
    super.key,
    required this.onSnooze,
    required this.onDismiss,
  });

  @override
  State<AlarmFiringSheet> createState() => _AlarmFiringSheetState();
}

class _AlarmFiringSheetState extends State<AlarmFiringSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _shakeAnim = Tween<double>(begin: -4, end: 4)
        .animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: kPill,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          // Alarm icon with glow
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccent.withValues(alpha: 0.12),
                border: Border.all(color: kAccentBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(color: kAccent.withValues(alpha: 0.3), blurRadius: 30),
                ],
              ),
              child: const Icon(Icons.alarm, color: kAccent, size: 36),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            '$h:$m',
            style: GoogleFonts.dmMono(
              fontSize: 56,
              color: Colors.white,
              fontWeight: FontWeight.w400,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'WAKE UP.',
            style: GoogleFonts.syne(
              fontSize: 11,
              letterSpacing: 5,
              color: kDim,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 40),

          // Two action buttons
          Row(
            children: [
              Expanded(
                child: _AlarmButton(
                  label: 'SNOOZE',
                  sublabel: '\$0.49',
                  icon: Icons.snooze_rounded,
                  onTap: widget.onSnooze,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AlarmButton(
                  label: 'DISMISS',
                  sublabel: '\$4.99/mo',
                  icon: Icons.lock_rounded,
                  onTap: widget.onDismiss,
                  isPrimary: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Both options are premium features.',
            style: GoogleFonts.syne(
              fontSize: 10,
              color: const Color(0xFF3A3A3A),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _AlarmButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isPrimary ? kAccent : kPill,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isPrimary
              ? [BoxShadow(color: kAccent.withValues(alpha: 0.35), blurRadius: 20)]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isPrimary ? Colors.white : kMuted, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.syne(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : kMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: GoogleFonts.dmMono(
                fontSize: 10,
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.7)
                    : const Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Snooze Paywall Sheet
// ─────────────────────────────────────────────
class SnoozePaywallSheet extends StatelessWidget {
  final VoidCallback onPay;
  final VoidCallback onCancel;

  const SnoozePaywallSheet({
    super.key,
    required this.onPay,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _PaywallBase(
      title: "Snooze? That'll cost you.",
      badge: '\$0.49',
      subtitle:
          '5 minutes of extra sleep costs \$0.49.\nSmall price for big dreams. 😴',
      children: [
        _PayButton(
          label: 'Pay with Apple Pay',
          icon: Icons.apple,
          isDark: true,
          onTap: onPay,
        ),
        const SizedBox(height: 12),
        _GhostButton(
          label: 'Cancel (alarm keeps ringing)',
          onTap: onCancel,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Dismiss Paywall Sheet
// ─────────────────────────────────────────────
class DismissPaywallSheet extends StatelessWidget {
  final VoidCallback onSubscribe;
  final VoidCallback onLater;

  const DismissPaywallSheet({
    super.key,
    required this.onSubscribe,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return _PaywallBase(
      title: '🔒 Pro Feature',
      badge: '\$4.99/mo',
      subtitle:
          'Dismissing alarms is available in AlarmPro.\nUpgrade to make the noise stop. Forever.',
      children: [
        _PayButton(
          label: 'Subscribe Now — \$4.99/month',
          icon: null,
          isDark: false,
          onTap: onSubscribe,
        ),
        const SizedBox(height: 12),
        _GhostButton(
          label: 'Maybe Later (alarm keeps ringing 🔔)',
          onTap: onLater,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shared Paywall Base
// ─────────────────────────────────────────────
class _PaywallBase extends StatelessWidget {
  final String title;
  final String badge;
  final String subtitle;
  final List<Widget> children;

  const _PaywallBase({
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kPill,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Title row with badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: kAccent.withValues(alpha: 0.4), blurRadius: 12),
                  ],
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.dmMono(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            subtitle,
            style: GoogleFonts.syne(
              fontSize: 12,
              color: kMuted,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 28),

          ...children,

          const SizedBox(height: 16),

          Center(
            child: Text(
              'By tapping, you agree to our Terms and that you are desperate.',
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(
                fontSize: 9,
                color: const Color(0xFF2E2E2E),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pay Button (white bg, dark text)
// ─────────────────────────────────────────────
class _PayButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isDark;
  final VoidCallback onTap;

  const _PayButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : kAccent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark
              ? [
                  BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08), blurRadius: 20),
                ]
              : [
                  BoxShadow(color: kAccent.withValues(alpha: 0.4), blurRadius: 20),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: isDark ? Colors.black : Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Ghost / Cancel Button
// ─────────────────────────────────────────────
class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.syne(
            fontSize: 13,
            color: const Color(0xFF444444),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
