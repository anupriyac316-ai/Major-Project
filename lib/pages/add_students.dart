import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;

class AddStudentsPage extends StatefulWidget {
  const AddStudentsPage({super.key});

  @override
  State<AddStudentsPage> createState() => _AddStudentsPageState();
}

class _AddStudentsPageState extends State<AddStudentsPage>
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

  String? selectedCourse;
  String? selectedDepartment;
  String? selectedYear;
  String? academicFrom;
  String? academicTo;

  List<String> academicYears = [];
  List<String> courses       = [];
  List<String> departments   = [];
  List<String> years         = [];

  final passwordController      = TextEditingController();
  final adminPasswordController = TextEditingController();

  String? adminEmail;

  bool isLoading          = false;
  bool showAdminPassword  = false;
  bool showClassPassword  = false;
  bool classExists        = false;

  List<Map<String, String>> excelStudents          = [];
  List<String>              duplicateExcelEmails    = [];
  List<String>              duplicateFirestoreEmails = [];

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

    adminEmail = _auth.currentUser?.email;
    fetchCourses();
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
    passwordController.dispose();
    adminPasswordController.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ─────────────────────────────────────────────

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

  Future<void> pickExcelFile() async {
    duplicateExcelEmails.clear();
    duplicateFirestoreEmails.clear();

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) return;
    var bytes = result.files.single.bytes;
    if (bytes == null) return;

    var excel = ex.Excel.decodeBytes(bytes);
    List<Map<String, String>> students = [];
    Set<String> emailSet = {};

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table];
      for (int i = 1; i < sheet!.rows.length; i++) {
        var row = sheet.rows[i];

        String firstName = row[0]?.value.toString().trim() ?? "";
        String lastName  = row[1]?.value.toString().trim() ?? "";
        String email     = row[2]?.value.toString().trim() ?? "";
        String phone     = row[3]?.value.toString().trim() ?? "";

        if (email.isEmpty || firstName.isEmpty) continue;

        if (emailSet.contains(email)) {
          duplicateExcelEmails.add(email);
          continue;
        }

        emailSet.add(email);
        students.add({
          "firstName": firstName,
          "lastName":  lastName,
          "email":     email,
          "phone":     phone,
        });
      }
    }

    for (var student in students) {
      var methods = await _auth.fetchSignInMethodsForEmail(student["email"]!);
      if (methods.isNotEmpty) duplicateFirestoreEmails.add(student["email"]!);
    }

    setState(() {
      excelStudents = students
          .where((s) => !duplicateFirestoreEmails.contains(s["email"]))
          .toList();
    });

    _showSnack("Loaded ${excelStudents.length} valid students", _green);
  }

  Future<void> assignFeesToStudent(
      String classId, String uid, String course, int academicFromYear, int academicToYear) async {
    try {
      String degreeType = course.startsWith('B')
          ? 'bachelor'
          : course.startsWith('M')
          ? 'master'
          : 'bachelor';

      final feeStructSnapshot =
      await _firestore.collection('fees_structure').get();
      QueryDocumentSnapshot<Map<String, dynamic>>? feeStructDoc;

      try {
        feeStructDoc = feeStructSnapshot.docs
            .firstWhere((doc) => doc.data()[degreeType] != null);
      } catch (e) {
        feeStructDoc = null;
      }

      if (feeStructDoc == null) return;

      final degreeStruct   = feeStructDoc.data()[degreeType];
      final totalSemesters = degreeStruct['totalSemesters'] as int;
      final semestersData  = degreeStruct['semesters'] as Map<String, dynamic>;

      for (int year = academicFromYear; year <= academicToYear; year++) {
        final feeDocRef = _firestore
            .collection('Student_Of_College')
            .doc(classId)
            .collection('students')
            .doc(uid)
            .collection('fees')
            .doc(year.toString());
        final feeDoc = await feeDocRef.get();
        if (feeDoc.exists) continue;

        Map<String, dynamic> feeData = {};
        int semIndex = (year - academicFromYear) * 2;

        for (int semOffset = 1; semOffset <= 2; semOffset++) {
          final semNumber  = semIndex + semOffset;
          if (semNumber > totalSemesters) break;
          final semAmounts = semestersData['sem$semNumber'] ??
              {"firstHalf": 0, "secondHalf": 0};
          feeData['sem$semNumber'] = {
            "firstHalf":  false,
            "secondHalf": false,
            "amount":     semAmounts,
            "deadline":   null,
          };
        }

        await feeDocRef.set({"createdAt": FieldValue.serverTimestamp(), ...feeData});
        await _firestore
            .collection('Student_Of_College')
            .doc(classId)
            .collection('students')
            .doc(uid)
            .update({"fees.$year": false});
      }
    } catch (e) {
      debugPrint("Error assigning fees: $e");
    }
  }

  Future<void> saveStudents() async {
    if (selectedCourse == null ||
        selectedDepartment == null ||
        selectedYear == null ||
        passwordController.text.isEmpty ||
        adminPasswordController.text.isEmpty ||
        excelStudents.isEmpty ||
        academicFrom == null ||
        academicTo == null) {
      _showSnack("Fill all details", _coral);
      return;
    }

    setState(() => isLoading = true);

    String classId =
        "${selectedCourse}_${selectedDepartment}_${selectedYear}_${academicFrom!}-${academicTo!}";

    await _firestore.collection('Student_Of_College').doc(classId).set({
      'course':        selectedCourse,
      'department':    selectedDepartment,
      'year':          selectedYear,
      'academicFrom':  academicFrom,
      'academicTo':    academicTo,
      'classPassword': passwordController.text.trim(),
      'createdAt':     FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    int successCount = 0;
    int failCount    = 0;

    for (var student in excelStudents) {
      try {
        UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email:    student["email"]!,
          password: passwordController.text.trim(),
        );

        String uid = userCredential.user!.uid;

        await _auth.signInWithEmailAndPassword(
          email:    adminEmail!,
          password: adminPasswordController.text.trim(),
        );

        await _firestore
            .collection('Student_Of_College')
            .doc(classId)
            .collection('students')
            .doc(uid)
            .set({
          'uid':           uid,
          'firstName':     student["firstName"],
          'lastName':      student["lastName"],
          'email':         student["email"],
          'phone':         student["phone"],
          'role':          'student',
          'admissionYear': int.parse(academicFrom!),
          'course':        selectedCourse,
          'createdAt':     FieldValue.serverTimestamp(),
        });

        await assignFeesToStudent(classId, uid, selectedCourse!,
            int.parse(academicFrom!), int.parse(academicTo!));

        successCount++;
      } catch (e) {
        failCount++;
        debugPrint("Error adding student ${student["email"]}: $e");
      }
    }

    setState(() => isLoading = false);
    _showSnack(
        "Completed — Success: $successCount | Failed: $failCount",
        successCount > 0 ? _green : _coral);
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
                    const Text("Bulk Student Upload",
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Text("Import from Excel (.xlsx)",
                        style: TextStyle(color: _textSec, fontSize: 11)),
                  ]),
                ),
                // Dynamic badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: excelStudents.isNotEmpty
                        ? _gold.withOpacity(0.1)
                        : _teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: excelStudents.isNotEmpty
                            ? _gold.withOpacity(0.25)
                            : _teal.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: excelStudents.isNotEmpty ? _gold : _teal,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(
                      excelStudents.isNotEmpty
                          ? "${excelStudents.length} ROWS"
                          : "BULK",
                      style: TextStyle(
                          color: excelStudents.isNotEmpty ? _gold : _teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8),
                    ),
                  ]),
                ),
              ]),
            ),

            // ── Scrollable body + pinned bottom ──────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(children: [

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                          // ── Info card ──────────────────────────
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
                                child: const Icon(Icons.table_chart_rounded,
                                    color: _teal, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text("Excel Format Required",
                                      style: TextStyle(
                                          color: _textPri,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Columns: First Name · Last Name · Email · Phone",
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

                          // ── Section: Class Assignment ──────────
                          _sectionLabel("Class Assignment", Icons.class_rounded, _indigo),
                          const SizedBox(height: 12),

                          _styledDropdown<String>(
                            hint: "Select Course",
                            value: selectedCourse,
                            icon: Icons.menu_book_rounded,
                            accentColor: _indigo,
                            items: courses.map((c) =>
                                DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) {
                              selectedCourse = v;
                              fetchDepartments(v!);
                            },
                          ),
                          const SizedBox(height: 12),

                          _styledDropdown<String>(
                            hint: "Select Department",
                            value: selectedDepartment,
                            icon: Icons.domain_rounded,
                            accentColor: _indigo,
                            items: departments.map((d) =>
                                DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (v) {
                              selectedDepartment = v;
                              fetchYears(v!);
                            },
                          ),
                          const SizedBox(height: 12),

                          _styledDropdown<String>(
                            hint: "Select Year",
                            value: selectedYear,
                            icon: Icons.calendar_today_rounded,
                            accentColor: _indigo,
                            items: years.map((y) =>
                                DropdownMenuItem(value: y, child: Text(y))).toList(),
                            onChanged: (v) {
                              selectedYear = v;
                              checkClassExists();
                            },
                          ),
                          const SizedBox(height: 12),

                          // Academic From / To
                          Row(children: [
                            Expanded(
                              child: _styledDropdown<String>(
                                hint: "From",
                                value: academicFrom,
                                icon: Icons.arrow_right_alt_rounded,
                                accentColor: classExists ? _textSec : _gold,
                                items: academicYears.map((y) =>
                                    DropdownMenuItem(value: y, child: Text(y))).toList(),
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
                                items: academicYears.map((y) =>
                                    DropdownMenuItem(value: y, child: Text(y))).toList(),
                                onChanged: classExists
                                    ? null
                                    : (v) => setState(() => academicTo = v),
                              ),
                            ),
                          ]),

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
                                const Icon(Icons.check_circle_rounded,
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

                          // ── Section: Security ──────────────────
                          _sectionLabel("Security", Icons.lock_rounded, _coral),
                          const SizedBox(height: 12),

                          // Class password
                          _passwordField(
                            controller: passwordController,
                            label: "Class Password",
                            obscure: showClassPassword == false,
                            accentColor: _coral,
                            icon: Icons.lock_rounded,
                            onToggle: () => setState(
                                    () => showClassPassword = !showClassPassword),
                          ),
                          const SizedBox(height: 12),

                          // Admin password
                          _passwordField(
                            controller: adminPasswordController,
                            label: "Admin Password",
                            obscure: !showAdminPassword,
                            accentColor: _indigo,
                            icon: Icons.admin_panel_settings_rounded,
                            onToggle: () => setState(
                                    () => showAdminPassword = !showAdminPassword),
                          ),

                          const SizedBox(height: 24),

                          // ── Section: Excel File ────────────────
                          _sectionLabel("Excel File", Icons.upload_file_rounded, _gold),
                          const SizedBox(height: 12),

                          // File pick zone
                          GestureDetector(
                            onTap: pickExcelFile,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: excelStudents.isEmpty
                                        ? _gold.withOpacity(0.25)
                                        : _green.withOpacity(0.35)),
                                boxShadow: [
                                  BoxShadow(
                                      color: _gold.withOpacity(0.06),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6)),
                                ],
                              ),
                              child: Column(children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: excelStudents.isEmpty
                                        ? _gold.withOpacity(0.1)
                                        : _green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    excelStudents.isEmpty
                                        ? Icons.upload_file_rounded
                                        : Icons.check_circle_rounded,
                                    color: excelStudents.isEmpty ? _gold : _green,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  excelStudents.isEmpty
                                      ? "Tap to Choose Excel File"
                                      : "File Loaded — ${excelStudents.length} valid records",
                                  style: TextStyle(
                                      color: excelStudents.isEmpty
                                          ? _textPri
                                          : _green,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  excelStudents.isEmpty
                                      ? "Only .xlsx files are supported"
                                      : "Tap to pick a different file",
                                  style: const TextStyle(
                                      color: _textSec, fontSize: 11),
                                ),
                              ]),
                            ),
                          ),

                          // ── Duplicate warnings ─────────────────
                          if (duplicateExcelEmails.isNotEmpty ||
                              duplicateFirestoreEmails.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            if (duplicateExcelEmails.isNotEmpty)
                              _warningBadge(
                                icon: Icons.file_copy_rounded,
                                color: _coral,
                                text:
                                "${duplicateExcelEmails.length} duplicate email(s) in Excel — skipped",
                              ),
                            if (duplicateFirestoreEmails.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _warningBadge(
                                icon: Icons.cloud_off_rounded,
                                color: _gold,
                                text:
                                "${duplicateFirestoreEmails.length} already registered in Firebase — skipped",
                              ),
                            ],
                          ],

                          // ── Preview ────────────────────────────
                          if (excelStudents.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionLabel(
                                "Preview (${excelStudents.length > 10 ? '10 of ${excelStudents.length}' : excelStudents.length.toString()})",
                                Icons.preview_rounded,
                                _teal),
                            const SizedBox(height: 12),

                            ...excelStudents.take(10).map((student) {
                              final initial = (student["firstName"] ?? "?")
                                  .isNotEmpty
                                  ? student["firstName"]![0].toUpperCase()
                                  : "?";
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: _indigo.withOpacity(0.15)),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: _indigo.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                          color: _indigo.withOpacity(0.25)),
                                    ),
                                    child: Center(
                                      child: Text(initial,
                                          style: const TextStyle(
                                              color: _indigo,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${student["firstName"]} ${student["lastName"]}",
                                            style: const TextStyle(
                                                color: _textPri,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            student["email"] ?? "",
                                            style: const TextStyle(
                                                color: _textSec, fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ]),
                                  ),
                                  if ((student["phone"] ?? "").isNotEmpty)
                                    Text(student["phone"]!,
                                        style: const TextStyle(
                                            color: _textSec, fontSize: 10)),
                                ]),
                              );
                            }),

                            if (excelStudents.length > 10)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Center(
                                  child: Text(
                                    "+ ${excelStudents.length - 10} more students",
                                    style: const TextStyle(
                                        color: _textSec,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ),
                          ],

                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),

                    // ── Pinned bottom buttons ─────────────────────
                    Container(
                      color: _surface,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [

                        if (excelStudents.isNotEmpty) ...[
                          GestureDetector(
                            onTap: isLoading ? null : saveStudents,
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
                                  const Text("Uploading Students...",
                                      style: TextStyle(
                                          color: _textSec,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                ])
                                    : Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.cloud_upload_rounded,
                                      color: _bg, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Save ${excelStudents.length} Students & Assign Fees",
                                    style: const TextStyle(
                                        color: _bg,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        GestureDetector(
                          onTap: pickExcelFile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _cardBorder),
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.upload_file_rounded,
                                      color: _textSec, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    excelStudents.isEmpty
                                        ? "Choose Excel File"
                                        : "Pick Different File",
                                    style: const TextStyle(
                                        color: _textSec,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ]),
                          ),
                        ),
                      ]),
                    ),
                  ]),
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
      Expanded(
        child: Text(title,
            style: const TextStyle(
                color: _textPri,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ),
    ]);
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
        border: Border.all(
            color: accentColor.withOpacity(disabled ? 0.08 : 0.2)),
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
              color: disabled
                  ? accentColor.withOpacity(0.4)
                  : accentColor,
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
              iconEnabledColor:
              disabled ? _textSec.withOpacity(0.3) : _textSec,
              iconDisabledColor: _textSec.withOpacity(0.2),
              style: TextStyle(
                  color: disabled
                      ? _textPri.withOpacity(0.4)
                      : _textPri,
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onToggle,
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
        obscureText: obscure,
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
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: _textSec,
                size: 20,
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
      ),
    );
  }

  Widget _warningBadge({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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