import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard_page.dart';
import 'admin_login.dart';

class AdminRegisterPage extends StatefulWidget {
  const AdminRegisterPage({super.key});

  @override
  State<AdminRegisterPage> createState() => _AdminRegisterPageState();
}

class _AdminRegisterPageState extends State<AdminRegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl  = TextEditingController();
  final emailCtrl     = TextEditingController();
  final phoneCtrl     = TextEditingController();
  final passCtrl      = TextEditingController();

  bool _isLoading        = false;
  bool _obscurePassword  = true;
  bool _adminExists      = false;

  final RegExp strongPassword =
  RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$&*~]).{6,}$');

  // ── Design tokens ────────────────────────────────────────────────
  static const Color _bg         = Color(0xFF070B14);
  static const Color _surface    = Color(0xFF0F1624);
  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _coral      = Color(0xFFFF6B6B);
  static const Color _green      = Color(0xFF36E8A0);
  static const Color _gold       = Color(0xFFFFB547);
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
            CurvedAnimation(
                parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
    _slideCtrl.forward();
    _checkAdminExists();
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passCtrl.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ────────────────────────────────────────────
  Future<void> _checkAdminExists() async {
    try {
      final systemDoc =
      FirebaseFirestore.instance.collection('system').doc('admin_lock');
      final lockSnapshot = await systemDoc.get();
      if (lockSnapshot.exists && lockSnapshot.data()?['locked'] == true) {
        setState(() => _adminExists = true);
      }
    } catch (e) {
      setState(() => _adminExists = true);
    }
  }

  Future<void> registerAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final usersCollection =
      FirebaseFirestore.instance.collection('users');
      final systemDoc =
      FirebaseFirestore.instance.collection('system').doc('admin_lock');

      bool isFirstAdmin = false;
      try {
        final lockSnapshot = await systemDoc.get();
        if (!lockSnapshot.exists ||
            lockSnapshot.data()?['locked'] != true) {
          isFirstAdmin = true;
        }
      } catch (e) {
        isFirstAdmin = false;
      }

      if (!isFirstAdmin) {
        _snack("Admin already exists", _coral, Icons.error_rounded);
        setState(() => _adminExists = true);
        return;
      }

      final cred =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      final uid = cred.user!.uid;

      await usersCollection.doc(uid).set({
        'firstName': firstNameCtrl.text.trim(),
        'lastName':  lastNameCtrl.text.trim(),
        'email':     emailCtrl.text.trim(),
        'phone':     phoneCtrl.text.trim(),
        'role':      'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await systemDoc.set({'locked': true, 'adminId': uid});

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == 'email-already-in-use') msg = "Email already registered";
      else if (e.code == 'weak-password')   msg = "Password is too weak";
      else if (e.code == 'invalid-email')   msg = "Invalid email address";
      _snack(msg, _coral, Icons.error_rounded);
    } catch (e) {
      _snack(e.toString(), _coral, Icons.error_rounded);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color, IconData icon) {
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

  // ── Dark text field ──────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color accentColor,
    bool obscureText              = false,
    Widget? suffixIcon,
    TextInputType keyboardType    = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        controller:   controller,
        obscureText:  obscureText,
        keyboardType: keyboardType,
        validator:    validator,
        style: const TextStyle(
            color: _textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textSec, fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 16),
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
            borderSide:
            BorderSide(color: accentColor.withOpacity(0.5), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
            BorderSide(color: _coral.withOpacity(0.5), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _coral, width: 1.5),
          ),
          errorStyle: const TextStyle(color: _coral, fontSize: 11),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ── Primary button ───────────────────────────────────────────────
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

  Widget _sectionLabel(String title, Color color) {
    return Row(children: [
      Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              color: _textPri,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2)),
    ]);
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
                        Text("Admin Register",
                            style: TextStyle(
                                color: _textPri,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text("Create your admin account",
                            style:
                            TextStyle(color: _textSec, fontSize: 11)),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _indigo.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                    Border.all(color: _indigo.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: _indigo, size: 18),
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
                    child: _adminExists
                        ? _buildAdminExistsState()
                        : _buildForm(),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Admin-exists state ───────────────────────────────────────────
  Widget _buildAdminExistsState() {
    return Column(children: [
      const SizedBox(height: 60),
      Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _coral.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: _coral.withOpacity(0.07),
                blurRadius: 30,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _coral.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _coral.withOpacity(0.25)),
            ),
            child: const Icon(Icons.lock_rounded, color: _coral, size: 36),
          ),
          const SizedBox(height: 20),
          const Text("Admin Already Exists",
              style: TextStyle(
                  color: _textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            "An admin account has already been\ncreated for this system.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSec, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          _buildButton(
            label: "Go to Login",
            icon:  Icons.login_rounded,
            color: _teal,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Registration form ────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Hero card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _indigo.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: _indigo.withOpacity(0.07),
                  blurRadius: 30,
                  offset: const Offset(0, 10)),
              BoxShadow(
                  color: _teal.withOpacity(0.04),
                  blurRadius: 50,
                  offset: const Offset(0, 14)),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _indigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _indigo.withOpacity(0.25)),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: _indigo, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("First-time Setup",
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text("Fill in your admin details below",
                        style: TextStyle(color: _textSec, fontSize: 11)),
                  ]),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withOpacity(0.3)),
              ),
              child: const Text("NEW",
                  style: TextStyle(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        // Personal info section
        _sectionLabel("Personal Info", _teal),
        const SizedBox(height: 12),

        // First & Last name row
        Row(children: [
          Expanded(
            child: _buildField(
              controller:  firstNameCtrl,
              hint:        "First Name",
              icon:        Icons.person_rounded,
              accentColor: _teal,
              validator:   (v) => v!.isEmpty ? "Required" : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildField(
              controller:  lastNameCtrl,
              hint:        "Last Name",
              icon:        Icons.person_outline_rounded,
              accentColor: _teal,
              validator:   (v) => v!.isEmpty ? "Required" : null,
            ),
          ),
        ]),

        const SizedBox(height: 24),

        // Contact section
        _sectionLabel("Contact", _indigo),
        const SizedBox(height: 12),

        _buildField(
          controller:   emailCtrl,
          hint:         "Email address",
          icon:         Icons.email_rounded,
          accentColor:  _indigo,
          keyboardType: TextInputType.emailAddress,
          validator:    (v) => v!.isEmpty ? "Enter email" : null,
        ),
        const SizedBox(height: 12),

        _buildField(
          controller:   phoneCtrl,
          hint:         "Phone number",
          icon:         Icons.phone_rounded,
          accentColor:  _indigo,
          keyboardType: TextInputType.phone,
          validator:    (v) => v!.isEmpty ? "Enter phone" : null,
        ),

        const SizedBox(height: 24),

        // Security section
        _sectionLabel("Security", _green),
        const SizedBox(height: 12),

        _buildField(
          controller:  passCtrl,
          hint:        "Create password",
          icon:        Icons.lock_rounded,
          accentColor: _green,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: _textSec,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return "Enter password";
            if (!strongPassword.hasMatch(v)) {
              return "Min 6 chars, upper, lower, number & special";
            }
            return null;
          },
        ),

        // Password hint
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 12, color: _textSec),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                "Uppercase, lowercase, number & special character required",
                style: TextStyle(color: _textSec, fontSize: 11),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 28),

        // Register button / loader
        _isLoading
            ? Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: _teal.withOpacity(0.3), width: 1.5),
              gradient: RadialGradient(colors: [
                _teal.withOpacity(0.15),
                Colors.transparent,
              ]),
            ),
            child: Center(
              child: CircularProgressIndicator(
                  color: _teal,
                  strokeWidth: 2.5,
                  backgroundColor: _teal.withOpacity(0.1)),
            ),
          ),
        )
            : _buildButton(
          label: "Create Admin Account",
          icon:  Icons.admin_panel_settings_rounded,
          color: _indigo,
          onTap: registerAdmin,
        ),

        const SizedBox(height: 20),

        // Login link
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text("Already have an account? ",
                style: TextStyle(color: _textSec, fontSize: 13)),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminLoginPage()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _teal.withOpacity(0.3)),
                ),
                child: const Text("Login",
                    style: TextStyle(
                        color: _teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),
      ]),
    );
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