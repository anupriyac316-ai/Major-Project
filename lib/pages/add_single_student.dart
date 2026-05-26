import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AddSingleStudentPage extends StatefulWidget {
  const AddSingleStudentPage({super.key});

  @override
  State<AddSingleStudentPage> createState() => _AddSingleStudentPageState();
}

class _AddSingleStudentPageState extends State<AddSingleStudentPage>
    with TickerProviderStateMixin {

  // ── Design tokens ─────────────────────────────────────────────────
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

  // ── Firebase ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth           = FirebaseAuth.instance;
  FirebaseAuth? _secondaryAuth;

  String? selectedCourse;
  String? selectedDepartment;
  String? selectedYear;
  String? academicFrom;
  String? academicTo;

  List<String> academicYears = [];
  List<String> courses       = [];
  List<String> departments   = [];
  List<String> years         = [];

  final firstNameController      = TextEditingController();
  final lastNameController       = TextEditingController();
  final emailController          = TextEditingController();
  final phoneController          = TextEditingController();
  final classPasswordController  = TextEditingController();

  bool isLoading       = false;
  bool classExists     = false;
  bool _obscurePassword = true;

  // Track last added student for fees
  String? lastAddedStudentId;
  String? lastAddedClassId;
  String? lastAddedCourse;
  int?    lastAddedAdmissionYear;
  int?    lastAddedAcademicTo;

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
    _orb1Anim  = Tween<double>(begin: 0, end: 26)
        .animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim  = Tween<double>(begin: 0, end: 20)
        .animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));

    fetchCourses();
    initializeSecondaryApp();
    final currentYear = DateTime.now().year;
    academicYears = List.generate(10, (i) => (currentYear + i).toString());

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
    classPasswordController.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ─────────────────────────────────────────────

  Future<void> initializeSecondaryApp() async {
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );
    _secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
  }

  Future<void> fetchCourses() async {
    final snap = await _firestore.collection('departments').get();
    final uniqueCourses =
    snap.docs.map((e) => e['course'] as String).toSet().toList();
    setState(() => courses = uniqueCourses);
  }

  Future<void> fetchDepartments(String course) async {
    final snap = await _firestore
        .collection('departments')
        .where('course', isEqualTo: course)
        .get();
    setState(() {
      departments        = snap.docs.map((e) => e['name'] as String).toList();
      years              = [];
      selectedDepartment = null;
      selectedYear       = null;
      academicFrom       = null;
      academicTo         = null;
      classExists        = false;
    });
  }

  Future<void> fetchYears(String department) async {
    final snap = await _firestore
        .collection('departments')
        .where('name', isEqualTo: department)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      setState(() => years = List<String>.from(snap.docs.first['years']));
    }
  }

  Future<void> checkClassExists() async {
    if (selectedCourse == null ||
        selectedDepartment == null ||
        selectedYear == null) return;
    final classIdPattern =
        "${selectedCourse}_${selectedDepartment}_${selectedYear}";
    final querySnap = await _firestore
        .collection('Student_Of_College')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: classIdPattern)
        .where(FieldPath.documentId,
        isLessThanOrEqualTo: "$classIdPattern\uf8ff")
        .limit(1)
        .get();

    if (querySnap.docs.isNotEmpty) {
      final doc = querySnap.docs.first;
      setState(() {
        academicFrom = doc['academicFrom'];
        academicTo   = doc['academicTo'];
        classExists  = true;
      });
    } else {
      setState(() {
        academicFrom = null;
        academicTo   = null;
        classExists  = false;
      });
    }
  }

  Future<void> saveStudent() async {
    if (selectedCourse == null ||
        selectedDepartment == null ||
        selectedYear == null ||
        academicFrom == null ||
        academicTo == null ||
        firstNameController.text.isEmpty ||
        emailController.text.isEmpty ||
        classPasswordController.text.isEmpty) {
      _showSnack("Fill all required fields", _coral);
      return;
    }

    setState(() => isLoading = true);

    try {
      final studentEmail    = emailController.text.trim();
      final studentPassword = classPasswordController.text.trim();

      var methods = await _auth.fetchSignInMethodsForEmail(studentEmail);
      if (methods.isNotEmpty) {
        _showSnack("Email already registered", _coral);
        setState(() => isLoading = false);
        return;
      }

      final userCredential =
      await _secondaryAuth!.createUserWithEmailAndPassword(
        email: studentEmail,
        password: studentPassword,
      );
      final uid = userCredential.user!.uid;

      final classId =
          "${selectedCourse}_${selectedDepartment}_${selectedYear}_${academicFrom!}-${academicTo!}";

      await _firestore
          .collection('Student_Of_College')
          .doc(classId)
          .set({
        'course':        selectedCourse,
        'department':    selectedDepartment,
        'year':          selectedYear,
        'academicFrom':  academicFrom,
        'academicTo':    academicTo,
        'classPassword': studentPassword,
        'createdAt':     FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore
          .collection('Student_Of_College')
          .doc(classId)
          .collection('students')
          .doc(uid)
          .set({
        'uid':           uid,
        'firstName':     firstNameController.text.trim(),
        'lastName':      lastNameController.text.trim(),
        'email':         studentEmail,
        'phone':         phoneController.text.trim(),
        'role':          'student',
        'admissionYear': int.parse(academicFrom!),
        'course':        selectedCourse,
        'createdAt':     FieldValue.serverTimestamp(),
      });

      lastAddedStudentId    = uid;
      lastAddedClassId      = classId;
      lastAddedCourse       = selectedCourse;
      lastAddedAdmissionYear = int.parse(academicFrom!);
      lastAddedAcademicTo   = int.parse(academicTo!);

      // Create fees subcollection
      final feeStructSnapshot =
      await _firestore.collection('fees_structure').get();
      if (feeStructSnapshot.docs.isNotEmpty) {
        String degreeType;
        final bachelorCourses = ["B.A", "B.Com", "B.Sc"];
        final masterCourses   = ["M.Com"];
        if (bachelorCourses.contains(lastAddedCourse))      degreeType = "bachelor";
        else if (masterCourses.contains(lastAddedCourse))   degreeType = "master";
        else                                                 degreeType = "";

        if (degreeType.isNotEmpty) {
          final feeStructDoc = feeStructSnapshot.docs.first;
          final feeDataMap   = feeStructDoc.data() as Map<String, dynamic>;
          if (feeDataMap.containsKey(degreeType)) {
            final degreeStruct    = feeDataMap[degreeType] as Map<String, dynamic>;
            final totalSemesters  = degreeStruct['totalSemesters'] as int;
            final semestersData   = Map<String, dynamic>.from(degreeStruct['semesters']);
            final batch           = _firestore.batch();

            int studentEndYear = lastAddedAdmissionYear! + (totalSemesters ~/ 2) - 1;
            if (studentEndYear > lastAddedAcademicTo!) studentEndYear = lastAddedAcademicTo!;

            for (int year = lastAddedAdmissionYear!; year <= studentEndYear; year++) {
              final feeDocRef = _firestore
                  .collection('Student_Of_College')
                  .doc(lastAddedClassId)
                  .collection('students')
                  .doc(lastAddedStudentId)
                  .collection('fees')
                  .doc(year.toString());

              Map<String, dynamic> feeData = {};
              int semIndex = (year - lastAddedAdmissionYear!) * 2;

              for (int semOffset = 1; semOffset <= 2; semOffset++) {
                final semNumber = semIndex + semOffset;
                if (semNumber > totalSemesters) break;
                final semAmounts = Map<String, dynamic>.from(
                    semestersData['sem$semNumber'] ??
                        {"firstHalf": 0, "secondHalf": 0});
                feeData['sem$semNumber'] = {
                  "firstHalf":  false,
                  "secondHalf": false,
                  "amount":     semAmounts,
                  "deadline":   null,
                };
              }

              batch.set(feeDocRef,
                  {"createdAt": FieldValue.serverTimestamp(), ...feeData});
              batch.update(
                _firestore
                    .collection('Student_Of_College')
                    .doc(lastAddedClassId)
                    .collection('students')
                    .doc(lastAddedStudentId),
                {"fees.$year": false},
              );
            }

            await batch.commit();
          }
        }
      }

      _showSnack("Student Added & Fees Created Successfully", _green);
      clearForm();
    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong";
      if (e.code == 'email-already-in-use') message = "Email already registered";
      else if (e.code == 'invalid-email')   message = "Invalid email format";
      else if (e.code == 'weak-password')   message = "Password must be at least 6 characters";
      _showSnack(message, _coral);
    } catch (e) {
      _showSnack("Error: $e", _coral);
    }

    setState(() => isLoading = false);
  }

  void clearForm() {
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    phoneController.clear();
    classPasswordController.clear();
    setState(() {
      selectedCourse     = null;
      selectedDepartment = null;
      selectedYear       = null;
      academicFrom       = null;
      academicTo         = null;
      classExists        = false;
    });
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // ── Animated orbs ─────────────────────────────────────────
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

            // ── AppBar ────────────────────────────────────────────
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
                    const Text("Add Student",
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Text("Single student registration",
                        style: TextStyle(color: _textSec, fontSize: 11)),
                  ]),
                ),
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
                        decoration: const BoxDecoration(
                            color: _teal, shape: BoxShape.circle)),
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

                      // ── Info card ──────────────────────────────
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
                            child: const Icon(Icons.school_rounded,
                                color: _teal, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("New Student Registration",
                                  style: TextStyle(
                                      color: _textPri,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                "An account & fee structure will be created automatically",
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

                      // ── Section: Class Assignment ──────────────
                      _sectionLabel("Class Assignment", Icons.class_rounded, _indigo),
                      const SizedBox(height: 12),

                      // Course dropdown
                      _styledDropdown<String>(
                        hint: "Select Course",
                        value: selectedCourse,
                        icon: Icons.menu_book_rounded,
                        accentColor: _indigo,
                        items: courses
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          selectedCourse = v;
                          fetchDepartments(v!);
                        },
                      ),

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
                        onChanged: (v) {
                          selectedDepartment = v;
                          fetchYears(v!);
                        },
                      ),

                      const SizedBox(height: 12),

                      // Year dropdown
                      _styledDropdown<String>(
                        hint: "Select Year",
                        value: selectedYear,
                        icon: Icons.calendar_today_rounded,
                        accentColor: _indigo,
                        items: years
                            .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                            .toList(),
                        onChanged: (v) {
                          selectedYear = v;
                          checkClassExists();
                        },
                      ),

                      const SizedBox(height: 12),

                      // Academic Year From / To row
                      Row(children: [
                        Expanded(
                          child: _styledDropdown<String>(
                            hint: "From",
                            value: academicFrom,
                            icon: Icons.arrow_right_alt_rounded,
                            accentColor: classExists ? _textSec : _gold,
                            items: academicYears
                                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                                .toList(),
                            onChanged: classExists
                                ? null
                                : (v) => setState(() => academicFrom = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _styledDropdown<String>(
                            hint: "To",
                            value: academicTo,
                            icon: Icons.arrow_right_alt_rounded,
                            accentColor: classExists ? _textSec : _gold,
                            items: academicYears
                                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                                .toList(),
                            onChanged: classExists
                                ? null
                                : (v) => setState(() => academicTo = v),
                          ),
                        ),
                      ]),

                      // Class exists info badge
                      if (classExists) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _green.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            Icon(Icons.check_circle_rounded,
                                color: _green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Class exists — Academic year auto-filled ($academicFrom–$academicTo)",
                                style: const TextStyle(
                                    color: _green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Section: Personal Info ─────────────────
                      _sectionLabel("Personal Info", Icons.account_circle_rounded, _teal),
                      const SizedBox(height: 12),

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

                      // ── Section: Security ──────────────────────
                      _sectionLabel("Security", Icons.lock_rounded, _coral),
                      const SizedBox(height: 12),

                      // Class password with eye toggle
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
                          controller: classPasswordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: _textPri, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: "Class Password",
                            labelStyle:
                            TextStyle(color: _textSec, fontSize: 13),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(10),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _coral.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.lock_rounded,
                                  color: _coral, size: 16),
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: _textSec,
                                  size: 20,
                                ),
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            floatingLabelBehavior:
                            FloatingLabelBehavior.never,
                          ),
                        ),
                      ),

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

                      // ── Submit button ──────────────────────────
                      GestureDetector(
                        onTap: isLoading ? null : saveStudent,
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
                              const Text("Creating Student...",
                                  style: TextStyle(
                                      color: _textSec,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ])
                                : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.person_add_alt_1_rounded,
                                  color: _bg, size: 20),
                              const SizedBox(width: 10),
                              const Text("Add Student & Create Fees",
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

                      // Clear form ghost button
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
    required ValueChanged<T?>? onChanged,
  }) {
    final disabled = onChanged == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: disabled ? _surface.withOpacity(0.5) : _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(disabled ? 0.08 : 0.2)),
        boxShadow: disabled
            ? []
            : [
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
            color: accentColor.withOpacity(disabled ? 0.06 : 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: disabled ? accentColor.withOpacity(0.4) : accentColor,
              size: 16),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              hint: Text(hint,
                  style: TextStyle(
                      color: disabled
                          ? _textSec.withOpacity(0.4)
                          : _textSec,
                      fontSize: 13)),
              value: value,
              dropdownColor: _card,
              iconEnabledColor: disabled ? _textSec.withOpacity(0.3) : _textSec,
              iconDisabledColor: _textSec.withOpacity(0.2),
              style: TextStyle(
                  color: disabled ? _textPri.withOpacity(0.4) : _textPri,
                  fontSize: 14),
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

// ── Dot painter ───────────────────────────────────────────────────────
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