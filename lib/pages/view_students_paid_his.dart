import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewStudentsPaidPage extends StatefulWidget {
  const ViewStudentsPaidPage({super.key});

  @override
  State<ViewStudentsPaidPage> createState() => _ViewStudentsPaidPageState();
}

class _ViewStudentsPaidPageState extends State<ViewStudentsPaidPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedCourse;
  String? selectedDepartment;
  String? selectedYear;
  String  searchQuery = '';
  String? classDocId;

  final TextEditingController searchController = TextEditingController();

  List<QueryDocumentSnapshot> students         = [];
  List<QueryDocumentSnapshot> filteredStudents = [];
  List<String> courses     = [];
  List<String> departments = [];
  List<String> years       = [];

  bool isLoading        = false;
  bool isLoadingFilters = false;
  bool hasLoadedStudents = false;

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

  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late Animation<double>   _orb1Anim;
  late Animation<double>   _orb2Anim;

  @override
  void initState() {
    super.initState();
    _orb1Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _orb2Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);
    _orb1Anim = Tween<double>(begin: 0, end: 26).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim = Tween<double>(begin: 0, end: 20).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    fetchCourses();
  }

  @override
  void dispose() {
    searchController.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ────────────────────────────────────────────
  Future<void> fetchCourses() async {
    setState(() => isLoadingFilters = true);
    try {
      final snapshot = await _firestore.collection('Student_Of_College').get();
      final courseSet = snapshot.docs.map((e) => ((e.data())['course'] ?? '').toString().trim()).where((c) => c.isNotEmpty).toSet();
      setState(() { courses = courseSet.toList()..sort(); isLoadingFilters = false; });
    } catch (e) {
      setState(() => isLoadingFilters = false);
      _snack("Error loading courses: $e", _coral, Icons.error_rounded);
    }
  }

  Future<void> fetchDepartments(String course) async {
    setState(() { isLoadingFilters = true; selectedDepartment = null; selectedYear = null; years = []; departments = []; students = []; filteredStudents = []; classDocId = null; hasLoadedStudents = false; });
    try {
      final snapshot = await _firestore.collection('Student_Of_College').where('course', isEqualTo: course).get();
      final deptSet = snapshot.docs.map((e) => ((e.data())['department'] ?? '').toString().trim()).where((d) => d.isNotEmpty).toSet();
      setState(() { departments = deptSet.toList()..sort(); isLoadingFilters = false; });
    } catch (e) { setState(() => isLoadingFilters = false); _snack("Error loading departments: $e", _coral, Icons.error_rounded); }
  }

  Future<void> fetchYears(String course, String department) async {
    setState(() { isLoadingFilters = true; selectedYear = null; years = []; students = []; filteredStudents = []; classDocId = null; hasLoadedStudents = false; });
    try {
      final snapshot = await _firestore.collection('Student_Of_College').where('course', isEqualTo: course).where('department', isEqualTo: department).get();
      if (snapshot.docs.isEmpty) { setState(() => isLoadingFilters = false); return; }
      classDocId = snapshot.docs.first.id;
      final docData = snapshot.docs.first.data() as Map<String, dynamic>;
      final from = int.tryParse(docData['academicFrom']?.toString() ?? '') ?? 0;
      final to   = int.tryParse(docData['academicTo']?.toString()   ?? '') ?? 0;
      List<String> yearList = [];
      for (int y = from; y <= to; y++) yearList.add(y.toString());
      setState(() { years = yearList; isLoadingFilters = false; });
    } catch (e) { setState(() => isLoadingFilters = false); _snack("Error loading years: $e", _coral, Icons.error_rounded); }
  }

  Future<void> loadStudents() async {
    if (selectedCourse == null || selectedDepartment == null || selectedYear == null) {
      _snack("Please select all filters first", _gold, Icons.warning_rounded); return;
    }
    setState(() { isLoading = true; students = []; filteredStudents = []; });
    try {
      if (classDocId == null) {
        final snapshot = await _firestore.collection('Student_Of_College').where('course', isEqualTo: selectedCourse).where('department', isEqualTo: selectedDepartment).get();
        if (snapshot.docs.isEmpty) { setState(() { isLoading = false; hasLoadedStudents = true; }); return; }
        classDocId = snapshot.docs.first.id;
      }
      final studentSnap = await _firestore.collection('Student_Of_College').doc(classDocId).collection('students').get();
      setState(() { students = studentSnap.docs.toList(); hasLoadedStudents = true; });
      if (students.isNotEmpty) await createFeesIfNeeded();
      filterStudents();
    } catch (e) { _snack("Error loading students: $e", _coral, Icons.error_rounded); }
    finally { setState(() => isLoading = false); }
  }

  Future<void> createFeesIfNeeded() async {
    if (students.isEmpty || selectedYear == null || classDocId == null) return;
    final batch    = _firestore.batch();
    bool hasChanges = false;
    final classDoc  = await _firestore.collection('Student_Of_College').doc(classDocId).get();
    final classData = classDoc.data() as Map<String, dynamic>;
    final from      = int.tryParse(classData['academicFrom']?.toString() ?? '') ?? 0;
    final yearIndex = int.parse(selectedYear!) - from;
    final semA = (yearIndex * 2) + 1;
    final semB = (yearIndex * 2) + 2;
    for (var student in students) {
      final feesRef = _firestore.collection('Student_Of_College').doc(classDocId).collection('students').doc(student.id).collection('fees').doc(selectedYear);
      final docSnapshot = await feesRef.get();
      if (!docSnapshot.exists) {
        batch.set(feesRef, {"createdAt": FieldValue.serverTimestamp(), "sem$semA": {"firstHalf": false, "secondHalf": false}, "sem$semB": {"firstHalf": false, "secondHalf": false}});
        batch.update(_firestore.collection('Student_Of_College').doc(classDocId).collection('students').doc(student.id), {"fees.$selectedYear": false});
        hasChanges = true;
      }
    }
    if (hasChanges) await batch.commit();
  }

  Future<void> markPaid(String studentId, String sem, String half) async {
    try {
      final ref = _firestore.collection('Student_Of_College').doc(classDocId).collection('students').doc(studentId).collection('fees').doc(selectedYear);
      await ref.update({"$sem.$half": true});
      final doc  = await ref.get();
      final data = doc.data() as Map<String, dynamic>;
      await checkAndUpdateYearStatus(studentId, data);
      _snack("Marked as Paid successfully", _green, Icons.check_circle_rounded);
    } catch (e) { _snack("Error marking as paid: $e", _coral, Icons.error_rounded); }
  }

  Future<void> checkAndUpdateYearStatus(String studentId, Map<String, dynamic> data) async {
    bool allPaid = true;
    data.forEach((key, value) {
      if (key.startsWith("sem")) {
        if (value is Map) { if (value["firstHalf"] != true || value["secondHalf"] != true) allPaid = false; }
        else allPaid = false;
      }
    });
    await _firestore.collection('Student_Of_College').doc(classDocId).collection('students').doc(studentId).update({"fees.$selectedYear": allPaid});
  }

  void filterStudents() {
    if (searchQuery.isEmpty) {
      filteredStudents = List.from(students);
    } else {
      filteredStudents = students.where((student) {
        final d        = student.data() as Map<String, dynamic>;
        final fullName = "${d['firstName'] ?? ''} ${d['lastName'] ?? ''}".toLowerCase();
        final email    = (d['email']  ?? '').toString().toLowerCase();
        final rollNo   = (d['rollNo'] ?? '').toString().toLowerCase();
        final q        = searchQuery.toLowerCase();
        return fullName.contains(q) || email.contains(q) || rollNo.contains(q);
      }).toList();
    }
    setState(() {});
  }

  void _snack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: _bg, size: 18), const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: _bg, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _orb(double size, Color color, double opacity) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent])));

  // ── Dark dropdown ────────────────────────────────────────────────
  Widget _buildDropdown<T>({required String hint, required T? value, required List<T> items,
    required String Function(T) display, required void Function(T?) onChanged, required Color accentColor, required IconData icon, bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value != null ? accentColor.withOpacity(0.35) : _cardBorder),
          boxShadow: [BoxShadow(color: accentColor.withOpacity(value != null ? 0.07 : 0), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Theme(data: Theme.of(context).copyWith(canvasColor: _card),
          child: DropdownButtonFormField<T>(
            value: value, isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: value != null ? accentColor : _textSec),
            decoration: InputDecoration(
                hintText: hint, hintStyle: const TextStyle(color: _textSec, fontSize: 13),
                prefixIcon: Padding(padding: const EdgeInsets.all(10),
                    child: Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: accentColor, size: 15))),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                filled: true, fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
            style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600),
            dropdownColor: _card,
            items: items.map((item) => DropdownMenuItem<T>(value: item,
                child: Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Text(display(item), style: const TextStyle(color: _textPri, fontSize: 13)),
                ]))).toList(),
            onChanged: enabled ? onChanged : null,
          )),
    );
  }

  // ── Semester tile ────────────────────────────────────────────────
  Widget _semesterTile(String studentId, String sem, String half, bool isPaid) {
    final semNum   = sem.replaceAll("sem", "");
    final halfText = half == "firstHalf" ? "First Half" : "Second Half";
    final color    = isPaid ? _green : _coral;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: isPaid ? _green.withOpacity(0.05) : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isPaid ? _green.withOpacity(0.2) : _cardBorder)),
      child: Row(children: [
        Container(width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
            alignment: Alignment.center,
            child: Text(semNum, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(halfText, style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(isPaid ? "Paid" : "Unpaid", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600))),
        ])),
        if (isPaid)
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: _green, size: 20))
        else
          GestureDetector(
              onTap: () => markPaid(studentId, sem, half),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: _teal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: const Row(children: [
                    Icon(Icons.payments_rounded, color: _bg, size: 14),
                    SizedBox(width: 5),
                    Text("Mark Paid", style: TextStyle(color: _bg, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        AnimatedBuilder(
          animation: Listenable.merge([_orb1Ctrl, _orb2Ctrl]),
          builder: (_, __) => Stack(children: [
            Positioned(top: -60 + _orb1Anim.value, right: -60, child: _orb(260, _teal, 0.13)),
            Positioned(bottom: 100 - _orb2Anim.value, left: -70, child: _orb(220, _indigo, 0.15)),
            Positioned.fill(child: CustomPaint(painter: _DotPainter(color: _teal.withOpacity(0.04)))),
          ]),
        ),
        SafeArea(child: Column(children: [

          // AppBar
          Container(
            color: _surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 16))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("View & Update Fees", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
                Text(hasLoadedStudents && students.isNotEmpty
                    ? "${filteredStudents.length} of ${students.length} students"
                    : "Select filters to load students",
                    style: const TextStyle(color: _textSec, fontSize: 11)),
              ])),
              if (hasLoadedStudents && students.isNotEmpty)
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _green.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _green.withOpacity(0.25))),
                    child: Text("${filteredStudents.length}", style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w800))),
            ]),
          ),

          // Body
          Expanded(child: Column(children: [

            // Filters card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorder),
                  boxShadow: [BoxShadow(color: _indigo.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 5))]),
              child: Column(children: [
                _buildDropdown<String>(hint: "Select Course", value: selectedCourse, items: courses,
                    display: (c) => c, accentColor: _teal, icon: Icons.school_rounded,
                    enabled: !isLoadingFilters,
                    onChanged: (v) { setState(() { selectedCourse = v; selectedDepartment = null; selectedYear = null; departments = []; years = []; students = []; filteredStudents = []; classDocId = null; hasLoadedStudents = false; }); if (v != null) fetchDepartments(v); }),
                if (departments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDropdown<String>(hint: "Select Department", value: selectedDepartment, items: departments,
                      display: (d) => d, accentColor: _indigo, icon: Icons.business_rounded,
                      enabled: !isLoadingFilters,
                      onChanged: (v) { setState(() { selectedDepartment = v; selectedYear = null; years = []; students = []; filteredStudents = []; classDocId = null; hasLoadedStudents = false; }); if (v != null && selectedCourse != null) fetchYears(selectedCourse!, v); }),
                ],
                if (years.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDropdown<String>(hint: "Select Academic Year", value: selectedYear, items: years,
                      display: (y) => y, accentColor: _gold, icon: Icons.calendar_month_rounded,
                      onChanged: (v) { setState(() { selectedYear = v; students = []; filteredStudents = []; hasLoadedStudents = false; }); }),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: (isLoading || isLoadingFilters) ? null : loadStudents,
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                          color: (isLoading || isLoadingFilters) ? _cardBorder : _teal,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: (isLoading || isLoadingFilters) ? [] : [BoxShadow(color: _teal.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))]),
                      child: (isLoading || isLoadingFilters)
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _teal, strokeWidth: 2, backgroundColor: _teal.withOpacity(0.2))),
                        const SizedBox(width: 10),
                        const Text("Loading...", style: TextStyle(color: _textSec, fontSize: 14, fontWeight: FontWeight.w700)),
                      ])
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.people_alt_rounded, color: _bg, size: 18),
                        SizedBox(width: 8),
                        Text("Load Students", style: TextStyle(color: _bg, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      ])),
                ),
              ]),
            ),

            // Search
            if (hasLoadedStudents)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: _textPri, fontSize: 13),
                    onChanged: (v) { searchQuery = v; filterStudents(); },
                    decoration: InputDecoration(
                        hintText: "Search by name, email or roll number...",
                        hintStyle: const TextStyle(color: _textSec, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: _textSec, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close_rounded, color: _textSec, size: 18),
                            onPressed: () { searchController.clear(); searchQuery = ''; filterStudents(); })
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _teal.withOpacity(0.4))),
                        filled: true, fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ),

            if (hasLoadedStudents) const SizedBox(height: 12),

            // List
            Expanded(child: isLoading
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 48, height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _teal.withOpacity(0.3), width: 1.5),
                      gradient: RadialGradient(colors: [_teal.withOpacity(0.15), Colors.transparent])),
                  child: Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5, backgroundColor: _teal.withOpacity(0.1)))),
            ]))
                : !hasLoadedStudents
                ? _buildEmptyState("Select filters above and tap Load Students", Icons.filter_alt_outlined)
                : students.isEmpty
                ? _buildEmptyState("No students found for this class", Icons.school_outlined)
                : filteredStudents.isEmpty
                ? _buildEmptyState("No matching students found", Icons.search_off_rounded)
                : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: filteredStudents.length,
                itemBuilder: (_, index) {
                  final student     = filteredStudents[index];
                  final studentData = student.data() as Map<String, dynamic>;
                  return StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('Student_Of_College').doc(classDocId).collection('students').doc(student.id).collection('fees').doc(selectedYear).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return Container(margin: const EdgeInsets.only(bottom: 14), height: 80,
                            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
                            child: Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2)));
                      if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                      final data         = snapshot.data!.data() as Map<String, dynamic>;
                      final semesterKeys = data.keys.where((k) => k.startsWith("sem")).toList()
                        ..sort((a, b) => int.parse(a.replaceAll("sem", "")).compareTo(int.parse(b.replaceAll("sem", ""))));
                      final firstName = studentData['firstName']?.toString() ?? '';
                      final initials  = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorder),
                            boxShadow: [BoxShadow(color: _indigo.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Student header
                            Row(children: [
                              Container(width: 50, height: 50,
                                  decoration: BoxDecoration(color: _indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: _indigo.withOpacity(0.3))),
                                  alignment: Alignment.center,
                                  child: Text(initials, style: const TextStyle(color: _indigo, fontSize: 20, fontWeight: FontWeight.w800))),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}".trim(),
                                    style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  if (studentData['rollNo'] != null)
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
                                        child: Text(studentData['rollNo'].toString(), style: const TextStyle(color: _textSec, fontSize: 11))),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text("${studentData['course'] ?? ''} - $selectedDepartment",
                                      style: const TextStyle(color: _textSec, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                ]),
                              ])),
                            ]),
                            const SizedBox(height: 12),
                            // Academic year badge
                            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
                                child: Row(children: [
                                  const Icon(Icons.calendar_today_rounded, size: 14, color: _textSec),
                                  const SizedBox(width: 8),
                                  Text("Academic Year: $selectedYear", style: const TextStyle(color: _textSec, fontSize: 12, fontWeight: FontWeight.w500)),
                                ])),
                            const SizedBox(height: 12),
                            Container(width: double.infinity, height: 1, color: _cardBorder),
                            const SizedBox(height: 12),
                            const Text("Fee Details", style: TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...semesterKeys.expand((semKey) {
                              final semData = data[semKey];
                              if (semData is Map) {
                                return [
                                  _semesterTile(student.id, semKey, "firstHalf",  semData["firstHalf"]  ?? false),
                                  _semesterTile(student.id, semKey, "secondHalf", semData["secondHalf"] ?? false),
                                ];
                              }
                              return <Widget>[];
                            }).toList(),
                          ]),
                        ),
                      );
                    },
                  );
                }),
            ),
          ])),
        ])),
      ]),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _card, shape: BoxShape.circle, border: Border.all(color: _cardBorder)),
          child: Icon(icon, size: 40, color: _textSec)),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]),
  ));
}

class _DotPainter extends CustomPainter {
  final Color color;
  _DotPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const s = 28.0;
    for (double x = 0; x < size.width; x += s)
      for (double y = 0; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.1, p);
  }
  @override
  bool shouldRepaint(_DotPainter o) => o.color != color;
}