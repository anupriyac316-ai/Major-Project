import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage>
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

  String course     = 'All';
  String department = 'All';
  String year       = 'All';

  bool isAdmin       = false;
  bool loadingFilters = false;
  bool deletingAll   = false;

  List<String> courseList     = ['All'];
  List<String> departmentList = ['All'];
  List<String> yearList       = ['All'];

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

    _init();
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

  Future<void> _init() async {
    await checkAdmin();
    if (isAdmin) {
      await fetchCourses();
    }
    if (mounted) {
      _fadeCtrl.forward();
      _slideCtrl.forward();
    }
  }

  Future<void> checkAdmin() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!mounted) return;
    setState(() => isAdmin = doc.exists && doc['role'] == 'admin');
  }

  Future<void> fetchCourses() async {
    final snap = await FirebaseFirestore.instance
        .collection('courses')
        .orderBy('name')
        .get();
    setState(() {
      courseList = ['All', ...snap.docs.map((e) => e['name'].toString())];
    });
  }

  Future<void> fetchDepartments(String selectedCourse) async {
    if (selectedCourse == 'All') {
      setState(() {
        departmentList = ['All'];
        yearList       = ['All'];
      });
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('departments')
        .where('course', isEqualTo: selectedCourse)
        .orderBy('name')
        .get();
    setState(() {
      departmentList = ['All', ...snap.docs.map((e) => e['name'].toString())];
      yearList       = ['All'];
    });
  }

  Future<void> fetchYears(String selectedDepartment) async {
    if (selectedDepartment == 'All') {
      setState(() => yearList = ['All']);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('departments')
        .where('name', isEqualTo: selectedDepartment)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;
    setState(() {
      yearList = ['All', ...List<String>.from(snap.docs.first['years'])];
    });
  }

  Future<List<Map<String, dynamic>>> getFilteredStudents() async {
    Query<Map<String, dynamic>> classQuery =
    FirebaseFirestore.instance.collection('Student_Of_College');

    if (course     != 'All') classQuery = classQuery.where('course',     isEqualTo: course);
    if (department != 'All') classQuery = classQuery.where('department', isEqualTo: department);
    if (year       != 'All') classQuery = classQuery.where('year',       isEqualTo: year);

    final classSnap = await classQuery.get();
    List<Map<String, dynamic>> allStudents = [];

    for (final classDoc in classSnap.docs) {
      final studentsSnap = await classDoc.reference.collection('students').get();
      for (final studentDoc in studentsSnap.docs) {
        final studentData = studentDoc.data();
        studentData['docId']           = studentDoc.id;
        studentData['classId']         = classDoc.id;
        studentData['classRef']        = classDoc.reference;
        studentData['studentRef']      = studentDoc.reference;
        studentData['classCourse']     = classDoc.data()['course'];
        studentData['classDepartment'] = classDoc.data()['department'];
        studentData['classYear']       = classDoc.data()['year'];
        allStudents.add(studentData);
      }
    }

    allStudents.sort((a, b) {
      final nameA = (a['firstName'] ?? '').toLowerCase();
      final nameB = (b['firstName'] ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });

    return allStudents;
  }

  Future<void> deleteStudent(DocumentReference studentRef) async {
    await studentRef.delete();
    if (mounted) {
      _showSnack("Student deleted successfully", _green);
      setState(() {});
    }
  }

  Future<void> deleteAllFilteredStudents() async {
    final confirm = await _showDeleteAllDialog();
    if (confirm != true) return;

    setState(() => deletingAll = true);
    try {
      final students = await getFilteredStudents();
      int deletedCount = 0;
      for (final student in students) {
        if (student['studentRef'] != null) {
          await (student['studentRef'] as DocumentReference).delete();
          deletedCount++;
        }
      }
      if (mounted) {
        _showSnack("$deletedCount students deleted successfully", _green);
        setState(() {});
      }
    } catch (e) {
      if (mounted) _showSnack("Error deleting students: $e", _coral);
    } finally {
      if (mounted) setState(() => deletingAll = false);
    }
  }

  String getFilterSummary() {
    List<String> filters = [];
    if (course     != 'All') filters.add("Course: $course");
    if (department != 'All') filters.add("Dept: $department");
    if (year       != 'All') filters.add("Year: $year");
    return filters.isNotEmpty ? filters.join(", ") : "All Students";
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
                    const Text("Students",
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Text("Filter and manage student records",
                        style: TextStyle(color: _textSec, fontSize: 11)),
                  ]),
                ),
                // Live count badge
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: getFilteredStudents(),
                  builder: (context, snap) {
                    final count = snap.hasData ? snap.data!.length : 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                        Text("$count STUDENTS",
                            style: const TextStyle(
                                color: _teal,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                      ]),
                    );
                  },
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

                    // ── Filter card ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Container(
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
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                          // Card header
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: _indigo.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _indigo.withOpacity(0.25)),
                              ),
                              child: const Icon(Icons.filter_list_rounded,
                                  color: _indigo, size: 18),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Filter Students",
                                        style: TextStyle(
                                            color: _textPri,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                    Text("Narrow by course, department, year",
                                        style: TextStyle(
                                            color: _textSec, fontSize: 10)),
                                  ]),
                            ),
                            // Clear filters button
                            if (course != 'All' ||
                                department != 'All' ||
                                year != 'All')
                              GestureDetector(
                                onTap: () => setState(() {
                                  course     = 'All';
                                  department = 'All';
                                  year       = 'All';
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _coral.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _coral.withOpacity(0.2)),
                                  ),
                                  child: const Text("Clear",
                                      style: TextStyle(
                                          color: _coral,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                          ]),

                          const SizedBox(height: 14),

                          if (loadingFilters)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(color: _teal),
                            )
                          else ...[
                            _filterDropdown(
                              icon: Icons.school_rounded,
                              label: "Course",
                              value: course,
                              items: courseList,
                              accentColor: _indigo,
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() {
                                  course     = v;
                                  department = 'All';
                                  year       = 'All';
                                  loadingFilters = true;
                                });
                                await fetchDepartments(course);
                                setState(() => loadingFilters = false);
                              },
                            ),
                            const SizedBox(height: 10),
                            _filterDropdown(
                              icon: Icons.account_tree_rounded,
                              label: "Department",
                              value: department,
                              items: departmentList,
                              accentColor: _teal,
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() {
                                  department     = v;
                                  year           = 'All';
                                  loadingFilters = true;
                                });
                                await fetchYears(department);
                                setState(() => loadingFilters = false);
                              },
                            ),
                            const SizedBox(height: 10),
                            _filterDropdown(
                              icon: Icons.calendar_today_rounded,
                              label: "Year",
                              value: year,
                              items: yearList,
                              accentColor: _gold,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => year = v);
                              },
                            ),
                          ],
                        ]),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Action bar: count + delete all ────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: getFilteredStudents(),
                        builder: (context, snap) {
                          final count =
                          snap.hasData ? snap.data!.length : 0;

                          return Row(children: [
                            // Section label
                            Container(
                                width: 3, height: 20,
                                decoration: BoxDecoration(
                                    color: _teal,
                                    borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 10),
                            const Icon(Icons.people_alt_rounded,
                                color: _teal, size: 16),
                            const SizedBox(width: 7),
                            const Text("All Students",
                                style: TextStyle(
                                    color: _textPri,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _teal.withOpacity(0.2)),
                              ),
                              child: Text("$count found",
                                  style: const TextStyle(
                                      color: _teal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const Spacer(),

                            // Delete All button
                            if (count > 0)
                              GestureDetector(
                                onTap: deletingAll
                                    ? null
                                    : deleteAllFilteredStudents,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _coral.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _coral.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (deletingAll) ...[
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                color: _coral,
                                                strokeWidth: 2,
                                                backgroundColor:
                                                _coral.withOpacity(0.1)),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text("Deleting...",
                                              style: TextStyle(
                                                  color: _coral,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700)),
                                        ] else ...[
                                          const Icon(
                                              Icons.delete_sweep_rounded,
                                              color: _coral,
                                              size: 15),
                                          const SizedBox(width: 5),
                                          const Text("Delete All",
                                              style: TextStyle(
                                                  color: _coral,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ]),
                                ),
                              ),
                          ]);
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Student list ──────────────────────────────
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: getFilteredStudents(),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: CircularProgressIndicator(
                                          color: _teal,
                                          strokeWidth: 2.5,
                                          backgroundColor:
                                          _teal.withOpacity(0.1)),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text("Loading students...",
                                        style: TextStyle(
                                            color: _textPri,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    const Text("Fetching records",
                                        style: TextStyle(
                                            color: _textSec, fontSize: 11)),
                                  ]),
                            );
                          }

                          if (!snap.hasData || snap.data!.isEmpty) {
                            return Center(
                              child: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: _card,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _cardBorder),
                                      ),
                                      child: const Icon(
                                          Icons.search_off_rounded,
                                          color: _textSec,
                                          size: 40),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text("No students found",
                                        style: TextStyle(
                                            color: _textPri,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    const Text("Try different filters",
                                        style: TextStyle(
                                            color: _textSec,
                                            fontSize: 12)),
                                    if (course     != 'All' ||
                                        department != 'All' ||
                                        year       != 'All') ...[
                                      const SizedBox(height: 16),
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          course     = 'All';
                                          department = 'All';
                                          year       = 'All';
                                        }),
                                        child: Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 11),
                                          decoration: BoxDecoration(
                                            color: _teal.withOpacity(0.1),
                                            borderRadius:
                                            BorderRadius.circular(12),
                                            border: Border.all(
                                                color:
                                                _teal.withOpacity(0.25)),
                                          ),
                                          child: const Text("Clear Filters",
                                              style: TextStyle(
                                                  color: _teal,
                                                  fontSize: 13,
                                                  fontWeight:
                                                  FontWeight.w700)),
                                        ),
                                      ),
                                    ],
                                  ]),
                            );
                          }

                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                20, 0, 20, 24),
                            itemCount: snap.data!.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _buildStudentCard(snap.data![index]),
                          );
                        },
                      ),
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

  // ── Student card ──────────────────────────────────────────────────
  Widget _buildStudentCard(Map<String, dynamic> studentData) {
    String firstName = studentData['firstName'] ?? '';
    String lastName  = studentData['lastName']  ?? '';
    String fullName  = "$firstName $lastName".trim();
    if (fullName.isEmpty) fullName = "Unknown Student";

    String studentCourse =
        studentData['course'] ?? studentData['classCourse'] ?? 'N/A';
    String studentDepartment =
        studentData['department'] ?? studentData['classDepartment'] ?? 'N/A';
    String studentYear =
        studentData['year'] ?? studentData['classYear'] ?? 'N/A';
    if (studentYear != 'N/A' && !studentYear.startsWith('Year ')) {
      studentYear = 'Year $studentYear';
    }

    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _indigo.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: _indigo.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _indigo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _indigo.withOpacity(0.28)),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: _indigo,
                      fontSize: 19,
                      fontWeight: FontWeight.w800)),
            ),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fullName,
                  style: const TextStyle(
                      color: _textPri,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _infoChip(Icons.school_rounded,      studentCourse,     _indigo),
                _infoChip(Icons.account_tree_rounded, studentDepartment, _teal),
                _infoChip(Icons.calendar_today_rounded, studentYear,     _gold),
              ]),
              if ((studentData['email'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.email_rounded,
                      color: _textSec.withOpacity(0.6), size: 11),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(studentData['email'],
                        style: const TextStyle(
                            color: _textSec, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
            ]),
          ),

          const SizedBox(width: 8),

          // Delete button
          GestureDetector(
            onTap: () async {
              final confirm =
              await _showDeleteStudentDialog(fullName);
              if (confirm == true) {
                await deleteStudent(studentData['studentRef']);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _coral.withOpacity(0.2)),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _coral, size: 18),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Filter dropdown row ───────────────────────────────────────────
  Widget _filterDropdown({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required Color accentColor,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: accentColor, size: 15),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                TextStyle(color: _textSec.withOpacity(0.7), fontSize: 10)),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: _card,
                iconEnabledColor: _textSec,
                style: const TextStyle(color: _textPri, fontSize: 13),
                items: items
                    .map((e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                ))
                    .toList(),
                onChanged: onChanged,
                isDense: true,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────
  Future<bool?> _showDeleteStudentDialog(String fullName) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _coral.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                  color: _coral.withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _coral.withOpacity(0.25)),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: _coral, size: 28),
            ),
            const SizedBox(height: 16),
            const Text("Delete Student",
                style: TextStyle(
                    color: _textPri,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              "Are you sure you want to delete $fullName? This action cannot be undone.",
              textAlign: TextAlign.center,
              style:
              const TextStyle(color: _textSec, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _dialogBtn("Cancel", false, ghost: true)),
              const SizedBox(width: 12),
              Expanded(child: _dialogBtn("Delete", true, danger: true)),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteAllDialog() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _coral.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: _coral.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 16)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _coral.withOpacity(0.25)),
              ),
              child: const Icon(Icons.delete_sweep_rounded,
                  color: _coral, size: 28),
            ),
            const SizedBox(height: 16),
            const Text("Delete All Filtered Students",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _textPri,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              "This will permanently delete all students matching: ${getFilterSummary()}",
              textAlign: TextAlign.center,
              style:
              const TextStyle(color: _textSec, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
            // Warning banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _coral.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: _coral, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "This action cannot be undone!",
                    style: TextStyle(
                        color: _coral,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _dialogBtn("Cancel", false, ghost: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _dialogBtn("Delete All", true, danger: true)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _dialogBtn(String label, bool value,
      {bool ghost = false, bool danger = false}) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: ghost
              ? Colors.transparent
              : danger
              ? _coral.withOpacity(0.15)
              : _teal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: ghost
                  ? _cardBorder
                  : danger
                  ? _coral.withOpacity(0.35)
                  : _teal.withOpacity(0.35)),
          boxShadow: ghost
              ? []
              : [
            BoxShadow(
                color: (danger ? _coral : _teal).withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: ghost
                      ? _textSec
                      : danger
                      ? _coral
                      : _teal,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────
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