import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgetPassPage extends StatefulWidget {
  const ForgetPassPage({super.key});

  @override
  State<ForgetPassPage> createState() => _ForgetPassPageState();
}

class _ForgetPassPageState extends State<ForgetPassPage>
    with TickerProviderStateMixin {
  final emailCtrl = TextEditingController();
  final codeCtrl  = TextEditingController();
  final passCtrl  = TextEditingController();

  bool codeSent     = false;
  bool codeVerified = false;
  bool obscure      = true;

  int    secondsLeft = 0;
  Timer? timer;

  final backendUrl = "http://127.0.0.1:5000";

  // ── Design tokens ────────────────────────────────────────────────
  static const Color _bg         = Color(0xFF070B14);
  static const Color _surface    = Color(0xFF0F1624);
  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _coral      = Color(0xFFFF6B6B);
  static const Color _gold       = Color(0xFFFFB547);
  static const Color _green      = Color(0xFF36E8A0);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  // Animations
  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;
  late Animation<double> _fadeAnim;
  late Animation<Offset>  _slideAnim;

  @override
  void initState() {
    super.initState();
    _orb1Ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))
      ..repeat(reverse: true);
    _orb2Ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 9))
      ..repeat(reverse: true);
    _fadeCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _orb1Anim = Tween<double>(begin: 0, end: 26).animate(
        CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim = Tween<double>(begin: 0, end: 20).animate(
        CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    timer?.cancel();
    emailCtrl.dispose();
    codeCtrl.dispose();
    passCtrl.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ────────────────────────────────────────────
  Future<void> sendCode() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) { snack("Please enter email", _gold, Icons.warning_rounded); return; }

    final res = await http.post(
      Uri.parse("$backendUrl/send-verification-code"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "role": "admin"}),
    );
    final data = jsonDecode(res.body);

    if (data["success"] == true) {
      setState(() { codeSent = true; secondsLeft = 60; });
      startTimer();
      snack("Verification code sent", _green, Icons.check_circle_rounded);
    } else {
      snack(data["message"] ?? "Admin email not registered", _coral, Icons.error_rounded);
    }
  }

  Future<void> verifyCode() async {
    final res = await http.post(
      Uri.parse("$backendUrl/verify-code"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": emailCtrl.text.trim(),
        "code":  codeCtrl.text.trim(),
      }),
    );
    final data = jsonDecode(res.body);

    if (data["success"] == true) {
      setState(() => codeVerified = true);
      snack("Code verified", _green, Icons.verified_rounded);
    } else {
      snack(data["message"] ?? "Invalid or expired code", _coral, Icons.error_rounded);
    }
  }

  Future<void> resetPassword() async {
    final res = await http.post(
      Uri.parse("$backendUrl/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email":        emailCtrl.text.trim(),
        "code":         codeCtrl.text.trim(),
        "new_password": passCtrl.text.trim(),
        "role":         "admin",
      }),
    );
    final data = jsonDecode(res.body);

    if (data["success"] == true) {
      snack("Password reset successful", _green, Icons.check_circle_rounded);
      Navigator.pop(context);
    } else {
      snack(data["message"] ?? "Error resetting password", _coral, Icons.error_rounded);
    }
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void snack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: _bg, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: _bg, fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Reusable dark text field ─────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color accentColor,
    bool enabled       = true,
    bool obscureText   = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: enabled ? accentColor.withOpacity(0.3) : _cardBorder),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(enabled ? 0.07 : 0),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: TextField(
        controller:    controller,
        enabled:       enabled,
        obscureText:   obscureText,
        keyboardType:  keyboardType,
        style: TextStyle(
            color: enabled ? _textPri : _textSec,
            fontSize: 14,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textSec, fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(enabled ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  color: enabled ? accentColor : _textSec, size: 16),
            ),
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentColor.withOpacity(0.5)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ── Primary action button ────────────────────────────────────────
  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 7)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: _bg, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: _bg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
        ]),
      ),
    );
  }

  // ── Step indicator ───────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final steps = [
      ("Email", Icons.email_rounded,     _teal),
      ("Verify", Icons.verified_rounded, _indigo),
      ("Reset", Icons.lock_reset_rounded,_green),
    ];
    final currentStep = codeVerified ? 2 : codeSent ? 1 : 0;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // connector line
          final filled = (i ~/ 2) < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: filled ? _teal.withOpacity(0.6) : _cardBorder,
            ),
          );
        }
        final idx   = i ~/ 2;
        final done  = idx < currentStep;
        final active = idx == currentStep;
        final color = steps[idx].$3;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: done || active
                  ? color.withOpacity(0.15)
                  : _card,
              shape: BoxShape.circle,
              border: Border.all(
                  color: done || active ? color : _cardBorder,
                  width: 1.5),
            ),
            child: Icon(
              done ? Icons.check_rounded : steps[idx].$2,
              color: done || active ? color : _textSec,
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(steps[idx].$1,
              style: TextStyle(
                  color: done || active ? color : _textSec,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]);
      }),
    );
  }

  Widget _orb(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // Animated orbs
        AnimatedBuilder(
          animation: Listenable.merge([_orb1Ctrl, _orb2Ctrl]),
          builder: (_, __) => Stack(children: [
            Positioned(
              top: -60 + _orb1Anim.value,
              right: -60,
              child: _orb(260, _teal, 0.13),
            ),
            Positioned(
              bottom: 80 - _orb2Anim.value,
              left: -70,
              child: _orb(220, _indigo, 0.15),
            ),
            Positioned.fill(
              child: CustomPaint(
                  painter: _DotPainter(color: _teal.withOpacity(0.04))),
            ),
          ]),
        ),

        SafeArea(
          child: Column(children: [

            // ── AppBar ──────────────────────────────────────────────
            Container(
              color: _surface,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _textPri, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Forgot Password",
                            style: TextStyle(
                                color: _textPri,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text("Reset your admin password",
                            style:
                            TextStyle(color: _textSec, fontSize: 11)),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _teal.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: _teal, size: 18),
                ),
              ]),
            ),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Hero card
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(24),
                              border:
                              Border.all(color: _teal.withOpacity(0.2)),
                              boxShadow: [
                                BoxShadow(
                                    color: _teal.withOpacity(0.07),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10)),
                                BoxShadow(
                                    color: _indigo.withOpacity(0.05),
                                    blurRadius: 50,
                                    offset: const Offset(0, 14)),
                              ],
                            ),
                            child: Column(children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _teal.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: _teal.withOpacity(0.25)),
                                  ),
                                  child: const Icon(
                                      Icons.admin_panel_settings_rounded,
                                      color: _teal,
                                      size: 24),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text("Admin Recovery",
                                            style: TextStyle(
                                                color: _textPri,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700)),
                                        Text("3-step verification process",
                                            style: TextStyle(
                                                color: _textSec, fontSize: 11)),
                                      ]),
                                ),
                              ]),

                              const SizedBox(height: 20),

                              // Step indicator
                              _buildStepIndicator(),
                            ]),
                          ),

                          const SizedBox(height: 24),

                          // ── Step 1: Email ──────────────────────────────
                          _sectionLabel("Step 1 — Email",
                              Icons.email_rounded, _teal),
                          const SizedBox(height: 12),

                          _buildField(
                            controller:   emailCtrl,
                            hint:         "Admin email address",
                            icon:         Icons.email_rounded,
                            accentColor:  _teal,
                            enabled:      !codeSent,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 12),

                          if (!codeSent)
                            _buildButton(
                              label: "Send Verification Code",
                              icon:  Icons.send_rounded,
                              color: _teal,
                              onTap: sendCode,
                            ),

                          // ── Step 2: Verify code ────────────────────────
                          if (codeSent && !codeVerified) ...[
                            const SizedBox(height: 24),

                            _sectionLabel("Step 2 — Verify Code",
                                Icons.verified_rounded, _indigo),
                            const SizedBox(height: 12),

                            _buildField(
                              controller:   codeCtrl,
                              hint:         "Enter 6-digit code",
                              icon:         Icons.pin_rounded,
                              accentColor:  _indigo,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 12),

                            _buildButton(
                              label: "Verify Code",
                              icon:  Icons.check_circle_rounded,
                              color: _indigo,
                              onTap: verifyCode,
                            ),

                            const SizedBox(height: 12),

                            // Resend row
                            Center(
                              child: GestureDetector(
                                onTap: secondsLeft == 0 ? sendCode : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: secondsLeft == 0
                                        ? _teal.withOpacity(0.1)
                                        : _card,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: secondsLeft == 0
                                            ? _teal.withOpacity(0.3)
                                            : _cardBorder),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          secondsLeft == 0
                                              ? Icons.refresh_rounded
                                              : Icons.hourglass_empty_rounded,
                                          size: 14,
                                          color: secondsLeft == 0
                                              ? _teal
                                              : _textSec,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          secondsLeft == 0
                                              ? "Resend Code"
                                              : "Resend in ${secondsLeft}s",
                                          style: TextStyle(
                                              color: secondsLeft == 0
                                                  ? _teal
                                                  : _textSec,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ]),
                                ),
                              ),
                            ),
                          ],

                          // ── Step 3: New password ───────────────────────
                          if (codeVerified) ...[
                            const SizedBox(height: 24),

                            _sectionLabel("Step 3 — New Password",
                                Icons.lock_reset_rounded, _green),
                            const SizedBox(height: 12),

                            _buildField(
                              controller:  passCtrl,
                              hint:        "Enter new password",
                              icon:        Icons.lock_rounded,
                              accentColor: _green,
                              obscureText: obscure,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: _textSec,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                              ),
                            ),

                            const SizedBox(height: 12),

                            _buildButton(
                              label: "Reset Password",
                              icon:  Icons.lock_reset_rounded,
                              color: _green,
                              onTap: resetPassword,
                            ),
                          ],

                          const SizedBox(height: 20),
                        ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        width: 3,
        height: 20,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              color: _textPri,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    ]);
  }
}

// ── Dot painter ───────────────────────────────────────────────────
class _DotPainter extends CustomPainter {
  final Color color;
  _DotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const s = 28.0;
    for (double x = 0; x < size.width; x += s) {
      for (double y = 0; y < size.height; y += s) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter o) => o.color != color;
}