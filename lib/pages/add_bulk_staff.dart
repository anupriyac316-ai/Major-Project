import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AddBulkStaffPage extends StatefulWidget {
  const AddBulkStaffPage({super.key});

  @override
  State<AddBulkStaffPage> createState() => _AddBulkStaffPageState();
}

class _AddBulkStaffPageState extends State<AddBulkStaffPage>
    with TickerProviderStateMixin {

  // ── Design tokens (identical to FeeMainPage) ─────────────────────
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

  // ── Firebase ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth           = FirebaseAuth.instance;
  FirebaseAuth? _secondaryAuth;

  List<Map<String, dynamic>> staffList = [];
  List<String> departments = [];

  String? selectedDepartment;
  String? departmentPassword;

  bool isLoading = false;

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

    fetchDepartments();
    initializeSecondaryApp();

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
    super.dispose();
  }

  // ── Logic (unchanged) ─────────────────────────────────────────────

  Future<void> initializeSecondaryApp() async {
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryBulkStaffApp',
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

  Future<void> askDepartmentPassword() async {
    TextEditingController passController = TextEditingController();
    bool obscure = true;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _indigo.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                      color: _indigo.withOpacity(0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 16)),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Icon header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _indigo.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _indigo.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.lock_rounded, color: _indigo, size: 28),
                ),
                const SizedBox(height: 16),
                const Text("Department Password",
                    style: TextStyle(
                        color: _textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  "This password will be assigned to all uploaded staff members",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textSec, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Password field
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _indigo.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: passController,
                    obscureText: obscure,
                    style: const TextStyle(color: _textPri, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Enter Department Password",
                      hintStyle: TextStyle(color: _textSec.withOpacity(0.6), fontSize: 13),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _indigo.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.key_rounded, color: _indigo, size: 16),
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () => setDialogState(() => obscure = !obscure),
                        child: Icon(
                          obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: _textSec, size: 18,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: const Center(
                          child: Text("Cancel",
                              style: TextStyle(
                                  color: _textSec,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        departmentPassword = passController.text;
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_indigo.withOpacity(0.85), _teal.withOpacity(0.85)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: _indigo.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 5)),
                          ],
                        ),
                        child: const Center(
                          child: Text("Save",
                              style: TextStyle(
                                  color: _bg,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );
  }

  Future<void> pickExcelFile() async {
    if (selectedDepartment == null) {
      _showSnack("Select a department first", _coral);
      return;
    }

    await askDepartmentPassword();

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    var excel = ex.Excel.decodeBytes(bytes);
    List<Map<String, dynamic>> tempList = [];

    for (var table in excel.tables.keys) {
      for (var row in excel.tables[table]!.rows.skip(1)) {
        if (row.isEmpty) continue;
        tempList.add({
          "firstName": row[0]?.value.toString() ?? "",
          "lastName":  row[1]?.value.toString() ?? "",
          "email":     row[2]?.value.toString() ?? "",
          "phone":     row[3]?.value.toString() ?? "",
          "role":      row[4]?.value.toString() ?? "",
        });
      }
    }

    setState(() => staffList = tempList);
  }

  Future<void> uploadStaff() async {
    if (selectedDepartment == null || departmentPassword == null) {
      _showSnack("Department or password missing", _coral);
      return;
    }
    if (staffList.isEmpty) return;

    setState(() => isLoading = true);

    int successCount = 0;

    await _firestore.collection('staff_of_college').doc(selectedDepartment).set({
      'department': selectedDepartment,
      'departmentPassword': departmentPassword,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (var staff in staffList) {
      try {
        if (staff['email'] == "") continue;
        var methods = await _auth.fetchSignInMethodsForEmail(staff['email']);
        if (methods.isNotEmpty) continue;

        UserCredential userCredential =
        await _secondaryAuth!.createUserWithEmailAndPassword(
          email: staff['email'],
          password: departmentPassword!,
        );

        String uid = userCredential.user!.uid;

        await _firestore
            .collection('staff_of_college')
            .doc(selectedDepartment)
            .collection('staff')
            .doc(uid)
            .set({
          'uid': uid,
          'firstName': staff['firstName'],
          'lastName':  staff['lastName'],
          'email':     staff['email'],
          'phone':     staff['phone'],
          'role':      staff['role'],
          'department': selectedDepartment,
          'createdAt': FieldValue.serverTimestamp(),
        });

        successCount++;
      } catch (e) {
        debugPrint("Error adding staff: $e");
      }
    }

    setState(() {
      isLoading = false;
      staffList.clear();
    });

    _showSnack("$successCount staff uploaded successfully", _green);
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
                    const Text("Bulk Upload Staff",
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Text("Import from Excel (.xlsx)",
                        style: TextStyle(color: _textSec, fontSize: 11)),
                  ]),
                ),
                // Badge showing count if file is loaded
                if (staffList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _gold.withOpacity(0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text("${staffList.length} ROWS",
                          style: const TextStyle(
                              color: _gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                    ]),
                  )
                else
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
                      const Text("BULK",
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
                                  const SizedBox(height: 4),
                                  Text(
                                    "Columns: First Name · Last Name · Email · Phone · Role",
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

                          // ── Section: Department ───────────────
                          _sectionLabel("Department", Icons.domain_rounded, _indigo),
                          const SizedBox(height: 12),

                          _styledDropdown<String>(
                            hint: "Select Department",
                            value: selectedDepartment,
                            icon: Icons.domain_rounded,
                            accentColor: _indigo,
                            items: departments
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              selectedDepartment = v;
                              staffList.clear();
                            }),
                          ),

                          const SizedBox(height: 24),

                          // ── Section: File ─────────────────────
                          _sectionLabel("Excel File", Icons.upload_file_rounded, _gold),
                          const SizedBox(height: 12),

                          // Pick file button
                          GestureDetector(
                            onTap: pickExcelFile,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: staffList.isEmpty
                                        ? _gold.withOpacity(0.25)
                                        : _green.withOpacity(0.35),
                                    style: BorderStyle.solid),
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
                                    color: staffList.isEmpty
                                        ? _gold.withOpacity(0.1)
                                        : _green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    staffList.isEmpty
                                        ? Icons.upload_file_rounded
                                        : Icons.check_circle_rounded,
                                    color: staffList.isEmpty ? _gold : _green,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  staffList.isEmpty
                                      ? "Tap to Choose Excel File"
                                      : "File Loaded — ${staffList.length} records",
                                  style: TextStyle(
                                      color: staffList.isEmpty ? _textPri : _green,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  staffList.isEmpty
                                      ? "Only .xlsx files are supported"
                                      : "Tap to pick a different file",
                                  style: const TextStyle(
                                      color: _textSec, fontSize: 11),
                                ),
                              ]),
                            ),
                          ),

                          // ── Preview list ──────────────────────
                          if (staffList.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionLabel("Preview", Icons.preview_rounded, _teal),
                            const SizedBox(height: 12),

                            // Summary pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _teal.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _teal.withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.people_alt_rounded,
                                    color: _teal, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  "Total Staff in Excel: ${staffList.length}",
                                  style: const TextStyle(
                                      color: _teal,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _teal.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${staffList.length} rows",
                                    style: const TextStyle(
                                        color: _teal,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ]),
                            ),

                            const SizedBox(height: 10),

                            // Staff list (fixed height so it doesn't scroll inside scroll)
                            SizedBox(
                              height: staffList.length > 4
                                  ? 280
                                  : (staffList.length * 70.0),
                              child: ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: staffList.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final staff = staffList[index];
                                  final isHod =
                                  (staff['role'] as String)
                                      .toLowerCase()
                                      .contains('hod');
                                  final roleColor = isHod ? _coral : _indigo;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _card,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: roleColor.withOpacity(0.15)),
                                    ),
                                    child: Row(children: [
                                      // Avatar initials
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: roleColor.withOpacity(0.25)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (staff['firstName'] as String)
                                                .isNotEmpty
                                                ? (staff['firstName'] as String)[0]
                                                .toUpperCase()
                                                : "?",
                                            style: TextStyle(
                                                color: roleColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${staff['firstName']} ${staff['lastName']}",
                                                style: const TextStyle(
                                                    color: _textPri,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                staff['email'],
                                                style: const TextStyle(
                                                    color: _textSec, fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ]),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          staff['role'],
                                          style: TextStyle(
                                              color: roleColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5),
                                        ),
                                      ),
                                    ]),
                                  );
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),

                    // ── Bottom action area ────────────────────────
                    Container(
                      color: _surface,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [

                        if (staffList.isNotEmpty) ...[
                          // Upload button
                          GestureDetector(
                            onTap: isLoading ? null : uploadStaff,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isLoading
                                      ? [_card, _card]
                                      : [_teal.withOpacity(0.85),
                                    _indigo.withOpacity(0.85)],
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
                                  const Text("Uploading Staff...",
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
                                    "Upload ${staffList.length} Staff Members",
                                    style: const TextStyle(
                                        color: _bg,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Choose / re-pick file button (always visible)
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
                                    staffList.isEmpty
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
      Text(title,
          style: const TextStyle(
              color: _textPri,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    ]);
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