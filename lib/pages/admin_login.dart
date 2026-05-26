import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard_page.dart';
import 'admin_register.dart';
import 'forget_pass.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage>
    with TickerProviderStateMixin {

  final _formKey   = GlobalKey<FormState>();
  final emailCtrl  = TextEditingController();
  final passCtrl   = TextEditingController();

  bool _isLoading        = false;
  bool _obscurePassword  = true;

  // ── Design tokens ───────────────────────────────────────────────
  static const Color _bg         = Color(0xFF050810);
  static const Color _card       = Color(0xFF0F1624);
  static const Color _cardBorder = Color(0xFF1A2740);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _rose       = Color(0xFFFF4D8D);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;
  late Animation<double> _fadeAnim;
  late Animation<Offset>  _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _orb1Ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _orb2Ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _orb1Anim = Tween<double>(begin: 0, end: 28)
        .animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim = Tween<double>(begin: 0, end: 20)
        .animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Logic unchanged ─────────────────────────────────────────────
  Future<void> loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      final uid = cred.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists || doc['role'] != 'admin') throw "Unauthorized admin";
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> forgotPassword() async {
    if (emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your email to reset password")),
      );
      return;
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: emailCtrl.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Password reset email sent! Check your inbox.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  // ── UI ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // ── Animated orbs ──────────────────────────────────────────
        AnimatedBuilder(
          animation: Listenable.merge([_orb1Ctrl, _orb2Ctrl]),
          builder: (_, __) => Stack(children: [
            Positioned(
              top: -60 + _orb1Anim.value,
              right: -60,
              child: _orb(260, _teal, 0.16),
            ),
            Positioned(
              bottom: 60 - _orb2Anim.value,
              left: -70,
              child: _orb(220, _indigo, 0.18),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.45,
              right: -40,
              child: _orb(160, _rose, 0.12),
            ),
            Positioned.fill(
              child: CustomPaint(
                  painter: _DotPainter(color: _teal.withOpacity(0.04))),
            ),
          ]),
        ),

        // ── Content ────────────────────────────────────────────────
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(children: [

                    // ── Logo mark ───────────────────────────────
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100 * _pulseAnim.value,
                              height: 100 * _pulseAnim.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _teal.withOpacity(
                                      0.12 * _pulseAnim.value),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _teal.withOpacity(0.28),
                                    width: 1.5),
                              ),
                            ),
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    _teal.withOpacity(0.55),
                                    _indigo.withOpacity(0.55),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _teal.withOpacity(0.3),
                                    blurRadius: 24,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ]),
                    ),

                    const SizedBox(height: 22),

                    // Title
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [_teal, _indigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(b),
                      child: const Text(
                        'Admin Login',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Sign in to your admin account',
                      style: TextStyle(
                          color: _textSec,
                          fontSize: 13,
                          letterSpacing: 0.3),
                    ),

                    const SizedBox(height: 32),

                    // ── Form card ─────────────────────────────────
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: _teal.withOpacity(0.18), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _teal.withOpacity(0.07),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: _indigo.withOpacity(0.05),
                            blurRadius: 60,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── Email field ──────────────────────
                            _fieldLabel("Email Address"),
                            const SizedBox(height: 8),
                            _DarkField(
                              controller: emailCtrl,
                              hint: "admin@college.edu",
                              icon: Icons.email_outlined,
                              accentColor: _teal,
                              validator: (v) =>
                              v!.isEmpty ? "Enter email" : null,
                            ),

                            const SizedBox(height: 18),

                            // ── Password field ───────────────────
                            _fieldLabel("Password"),
                            const SizedBox(height: 8),
                            _DarkField(
                              controller: passCtrl,
                              hint: "••••••••",
                              icon: Icons.lock_outline_rounded,
                              accentColor: _teal,
                              obscure: _obscurePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _textSec,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) =>
                              v!.isEmpty ? "Enter password" : null,
                            ),

                            const SizedBox(height: 10),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ForgetPassPage()),
                                ),
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: _teal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Login button ─────────────────────
                            _isLoading
                                ? Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: _teal,
                                  strokeWidth: 2.5,
                                  backgroundColor:
                                  _teal.withOpacity(0.1),
                                ),
                              ),
                            )
                                : _GlowButton(
                              label: "LOGIN",
                              icon: Icons.login_rounded,
                              accentColor: _teal,
                              onPressed: loginAdmin,
                            ),

                            const SizedBox(height: 22),

                            // Divider
                            Row(children: [
                              Expanded(
                                  child: Divider(
                                      color: _cardBorder, thickness: 0.8)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _teal.withOpacity(0.4),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: _cardBorder, thickness: 0.8)),
                            ]),

                            const SizedBox(height: 18),

                            // Register link
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                        color: _textSec, fontSize: 13),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                          const AdminRegisterPage()),
                                    ),
                                    child: const Text(
                                      "Register",
                                      style: TextStyle(
                                        color: _teal,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Footer dots
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _dot(_teal), const SizedBox(width: 6),
                          _dot(_indigo), const SizedBox(width: 6),
                          _dot(_rose),
                        ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _textSec,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );

  Widget _orb(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [
        color.withOpacity(opacity),
        Colors.transparent,
      ]),
    ),
  );

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(
        color: color.withOpacity(0.45), shape: BoxShape.circle),
  );
}

// ── Dark text field ───────────────────────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;

  static const Color _surface    = Color(0xFF070B14);
  static const Color _cardBorder = Color(0xFF1A2740);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  const _DarkField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.obscure = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: _textPri, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _textSec.withOpacity(0.5), fontSize: 13),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }
}

// ── Glow button ───────────────────────────────────────────────────────
class _GlowButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPressed;

  const _GlowButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const Color _bg = Color(0xFF050810);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _ctrl,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onPressed();
        },
        onTapCancel: () => _ctrl.forward(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: widget.accentColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.38),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: widget.accentColor.withOpacity(0.16),
                blurRadius: 44,
                spreadRadius: 2,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 20, color: _bg),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                  color: _bg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dot grid painter ──────────────────────────────────────────────────
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