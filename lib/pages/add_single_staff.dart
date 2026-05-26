import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AddSingleStaffPage extends StatefulWidget {
  const AddSingleStaffPage({super.key});

  @override
  State<AddSingleStaffPage> createState() =>
      _AddSingleStaffPageState();
}

class _AddSingleStaffPageState
    extends State<AddSingleStaffPage> with TickerProviderStateMixin {

  // ── Design tokens (identical to FeeMainPage) ─────────────────────
  static const Color _bg         = Color(0xFF070B14);
  static const Color _surface    = Color(0xFF0F1624);
  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _coral      = Color(0xFFFF6B6B);
  static const Color _green      = Color(0xFF36E8A0);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  // ── Firebase ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth           = FirebaseAuth.instance;
  FirebaseAuth? _secondaryAuth;

  List<String> departments = [];
  String? selectedDepartment;
  String? selectedRole;

  final firstNameController = TextEditingController();
  final lastNameController  = TextEditingController();
  final emailController     = TextEditingController();
  final phoneController     = TextEditingController();
  final passwordController  = TextEditingController();

  bool isLoading       = false;
  bool _obscurePassword = true;

  // ── Animations ────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _orb1Anim;
  late Animation<double>   _orb2Anim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _orb1Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _orb2Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _orb1Anim  = Tween<double>(begin: 0, end: 26).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim  = Tween<double>(begin: 0, end: 20).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));

    fetchDepartments();
    initializeSecondaryApp();

    // Kick off entrance animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeCtrl.forward();
      _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ─────────────────────────────────────────────

  Future<void> initializeSecondaryApp() async {
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryStaffApp',
      options: Firebase.app().options,
    );
    _secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
  }

  Future<void> fetchDepartments() async {
    final snap = await _firestore.collection('departments').get();
    setState(() {
      departments = snap.docs.map((e) => e['name'] as String).toList();
    });
  }

  Future<void> saveStaff() async {
    if (selectedDepartment == null ||
        selectedRole == null ||
        firstNameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Fill all required fields"),
            backgroundColor: _coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
      return;
    }

    setState(() => isLoading = true);

    try {
      String staffEmail    = emailController.text.trim();
      String staffPassword = passwordController.text.trim();

      var methods = await _auth.fetchSignInMethodsForEmail(staffEmail);
      if (methods.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Email already registered"),
              backgroundColor: _coral,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
        setState(() => isLoading = false);
        return;
      }

      UserCredential userCredential =
      await _secondaryAuth!.createUserWithEmailAndPassword(
        email: staffEmail,
        password: staffPassword,
      );

      String uid = userCredential.user!.uid;

      await _firestore
          .collection('staff_of_college')
          .doc(selectedDepartment)
          .set({
        'department': selectedDepartment,
        'departmentPassword': staffPassword,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore
          .collection('staff_of_college')
          .doc(selectedDepartment)
          .collection('staff')
          .doc(uid)
          .set({
        'uid': uid,
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': staffEmail,
        'phone': phoneController.text.trim(),
        'role': selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Staff Added Successfully"),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));

      clearForm();

    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong";
      if (e.code == 'email-already-in-use')  message = "Email already registered";
      else if (e.code == 'invalid-email')    message = "Invalid email format";
      else if (e.code == 'weak-password')    message = "Password must be at least 6 characters";

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: _coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
    }

    setState(() => isLoading = false);
  }

  void clearForm() {
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
    selectedDepartment = null;
    selectedRole       = null;
    setState(() {});
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // ── Animated orbs (same as FeeMainPage) ──────────────────
        AnimatedBuilder(
          animation: Listenable.merge([_orb1Ctrl, _orb2Ctrl]),
          builder: (_, __) => Stack(children: [
            Positioned(
              top: -60 + _orb1Anim.value,
              right: -60,
              child: _orb(260, _teal, 0.13),
            ),
            Positioned(
              bottom: 100 - _orb2Anim.value,
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

            // ── AppBar (matches FeeMainPage) ──────────────────────
            Container(
              color: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Add Staff Member",
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Text("Fill in staff details below",
                        style: TextStyle(color: _textSec, fontSize: 11)),
                  ]),
                ),
                // Staff count badge placeholder
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _teal.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text("SINGLE",
                        style: TextStyle(
                            color: _teal,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ]),
                ),
              ]),
            ),

            // ── Body ─────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── Info card at top ──────────────────────
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _teal.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                                color: _teal.withOpacity(0.07),
                                blurRadius: 30,
                                offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: _teal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _teal.withOpacity(0.25)),
                            ),
                            child: const Icon(Icons.person_add_rounded,
                                color: _teal, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("New Staff Registration",
                                  style: TextStyle(
                                      color: _textPri,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                "An account will be created with the provided email & password",
                                style: TextStyle(
                                    color: _textSec.withOpacity(0.85),
                                    fontSize: 11,
                                    height: 1.4),
                              ),
                            ]),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 24),

                      // ── Section label ─────────────────────────
                      _sectionLabel("Assignment", Icons.category_rounded, _indigo),
                      const SizedBox(height: 12),

                      // Department dropdown
                      _styledDropdown<String>(
                        hint: "Select Department",
                        value: selectedDepartment,
                        icon: Icons.domain_rounded,
                        accentColor: _indigo,
                        items: departments
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedDepartment = v),
                      ),

                      const SizedBox(height: 12),

                      // Role dropdown
                      _styledDropdown<String>(
                        hint: "Select Role",
                        value: selectedRole,
                        icon: Icons.badge_rounded,
                        accentColor: _indigo,
                        items: const [
                          DropdownMenuItem(value: "HOD", child: Text("HOD")),
                          DropdownMenuItem(
                              value: "Assistant Professor",
                              child: Text("Assistant Professor")),
                        ],
                        onChanged: (v) => setState(() => selectedRole = v),
                      ),

                      const SizedBox(height: 24),

                      // ── Section label ─────────────────────────
                      _sectionLabel("Personal Info", Icons.account_circle_rounded, _teal),
                      const SizedBox(height: 12),

                      // First + Last name row
                      Row(children: [
                        Expanded(
                          child: _styledField(
                            controller: firstNameController,
                            label: "First Name",
                            icon: Icons.person_rounded,
                            accentColor: _teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _styledField(
                            controller: lastNameController,
                            label: "Last Name",
                            icon: Icons.person_outline_rounded,
                            accentColor: _teal,
                          ),
                        ),
                      ]),

                      const SizedBox(height: 12),

                      _styledField(
                        controller: emailController,
                        label: "Email Address",
                        icon: Icons.email_rounded,
                        accentColor: _teal,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 12),

                      _styledField(
                        controller: phoneController,
                        label: "Phone Number",
                        icon: Icons.phone_rounded,
                        accentColor: _teal,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 24),

                      // ── Section label ─────────────────────────
                      _sectionLabel("Security", Icons.lock_rounded, _coral),
                      const SizedBox(height: 12),

                      // Password field
                      Container(
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _coral.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                                color: _coral.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: _textPri, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: "Department Password",
                            labelStyle: TextStyle(
                                color: _textSec, fontSize: 13),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(10),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _coral.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.lock_rounded,
                                  color: _coral, size: 16),
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: _textSec,
                                size: 20,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                          ),
                        ),
                      ),

                      // Password hint
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded,
                              color: _textSec.withOpacity(0.6), size: 12),
                          const SizedBox(width: 5),
                          Text("Minimum 6 characters required",
                              style: TextStyle(
                                  color: _textSec.withOpacity(0.6),
                                  fontSize: 10)),
                        ]),
                      ),

                      const SizedBox(height: 32),

                      // ── Add Staff button ──────────────────────
                      GestureDetector(
                        onTap: isLoading ? null : saveStaff,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isLoading
                                  ? [_card, _card]
                                  : [
                                _teal.withOpacity(0.85),
                                _indigo.withOpacity(0.85),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: isLoading
                                    ? _cardBorder
                                    : _teal.withOpacity(0.4)),
                            boxShadow: isLoading
                                ? []
                                : [
                              BoxShadow(
                                  color: _teal.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Center(
                            child: isLoading
                                ? Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: _teal,
                                    strokeWidth: 2.5,
                                    backgroundColor:
                                    _teal.withOpacity(0.1)),
                              ),
                              const SizedBox(width: 12),
                              const Text("Creating Account...",
                                  style: TextStyle(
                                      color: _textSec,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ])
                                : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.person_add_alt_1_rounded,
                                  color: _bg, size: 20),
                              const SizedBox(width: 10),
                              const Text("Add Staff Member",
                                  style: TextStyle(
                                      color: _bg,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3)),
                            ]),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Clear form button ─────────────────────
                      GestureDetector(
                        onTap: clearForm,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: const Center(
                            child: Text("Clear Form",
                                style: TextStyle(
                                    color: _textSec,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
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

  // ── Helpers ───────────────────────────────────────────────────────

  Widget _sectionLabel(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
          width: 3, height: 20,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 7),
      Text(title,
          style: const TextStyle(
              color: _textPri,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    ]);
  }

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color accentColor,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: _textPri, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: _textSec, fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
      ),
    );
  }

  Widget _styledDropdown<T>({
    required String hint,
    required T? value,
    required IconData icon,
    required Color accentColor,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              hint: Text(hint,
                  style: TextStyle(color: _textSec, fontSize: 13)),
              value: value,
              dropdownColor: _card,
              iconEnabledColor: _textSec,
              style: const TextStyle(color: _textPri, fontSize: 14),
              items: items,
              onChanged: onChanged,
              isExpanded: true,
            ),
          ),
        ),
      ]),
    );
  }

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
}

// ── Dot painter (identical to FeeMainPage) ────────────────────────────
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