import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SetDeadlinePage extends StatefulWidget {
  const SetDeadlinePage({super.key});

  @override
  State<SetDeadlinePage> createState() => _SetDeadlinePageState();
}

class _SetDeadlinePageState extends State<SetDeadlinePage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _yearController = TextEditingController();

  String    selectedSemester = "first";
  Timestamp? currentDeadline;
  bool      isLoading    = false;
  int       totalClasses  = 0;
  int       totalStudents = 0;

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
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;
  late Animation<double> _fadeAnim;
  late Animation<Offset>  _slideAnim;

  @override
  void initState() {
    super.initState();
    _orb1Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _orb2Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _orb1Anim  = Tween<double>(begin: 0, end: 26).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim  = Tween<double>(begin: 0, end: 20).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
    _slideCtrl.forward();
    _fetchCollegeStats();
  }

  @override
  void dispose() {
    _yearController.dispose();
    _orb1Ctrl.dispose(); _orb2Ctrl.dispose();
    _fadeCtrl.dispose(); _slideCtrl.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ────────────────────────────────────────────
  Future<void> _fetchCollegeStats() async {
    try {
      final classesSnapshot = await _firestore.collection("Student_Of_College").get();
      totalClasses = classesSnapshot.docs.length;
      int studentCount = 0;
      for (var classDoc in classesSnapshot.docs) {
        final s = await classDoc.reference.collection("students").count().get();
        studentCount += s.count ?? 0;
      }
      setState(() => totalStudents = studentCount);
    } catch (e) { debugPrint("Error fetching stats: $e"); }
  }

  Future<int?> _getClassStartYear(DocumentReference classRef) async {
    try {
      final classDoc = await classRef.get();
      if (classDoc.exists) {
        final fromYear = classDoc['academicFrom'];
        if (fromYear != null) return int.tryParse(fromYear.toString());
      }
    } catch (e) { debugPrint("Error getting class start year: $e"); }
    return null;
  }

  Future<DateTime?> _pickDate({DateTime? initial}) async {
    return await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: _teal, surface: _card, onSurface: _textPri),
          dialogBackgroundColor: _card,
        ),
        child: child!,
      ),
    );
  }

  String formatDate(Timestamp timestamp) {
    final d = timestamp.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }

  Future<void> _fetchDeadline() async {
    if (_yearController.text.isEmpty) return;
    final year = _yearController.text.trim();
    try {
      final classesSnapshot = await _firestore.collection("Student_Of_College").limit(1).get();
      if (classesSnapshot.docs.isEmpty) { setState(() => currentDeadline = null); return; }
      final firstClass     = classesSnapshot.docs.first;
      final classStartYear = await _getClassStartYear(firstClass.reference);
      if (classStartYear == null) { setState(() => currentDeadline = null); return; }
      final yearInt    = int.tryParse(year) ?? 0;
      final yearIndex  = yearInt - classStartYear;
      final semNumber  = (yearIndex * 2) + (selectedSemester == "first" ? 1 : 2);
      final actualSemester = "sem$semNumber";
      final studentSnapshot = await firstClass.reference.collection("students").limit(1).get();
      if (studentSnapshot.docs.isEmpty) { setState(() => currentDeadline = null); return; }
      final feeDoc = await studentSnapshot.docs.first.reference.collection("fees").doc(year).get();
      if (feeDoc.exists && feeDoc.data()?[actualSemester]?['deadline'] != null) {
        setState(() => currentDeadline = feeDoc.data()![actualSemester]['deadline']);
      } else {
        setState(() => currentDeadline = null);
      }
    } catch (e) { setState(() => currentDeadline = null); }
  }

  Future<void> _saveDeadlineForAllClasses(DateTime pickedDate) async {
    if (_yearController.text.isEmpty) return;
    setState(() => isLoading = true);
    final yearInput   = _yearController.text.trim();
    final newDeadline = Timestamp.fromDate(pickedDate);
    int updatedCount = 0, classCount = 0, skippedCount = 0;
    try {
      final classesSnapshot = await _firestore.collection("Student_Of_College").get();
      classCount = classesSnapshot.docs.length;
      WriteBatch batch = _firestore.batch();
      int operationCount = 0;
      const int batchSize = 400;
      for (var classDoc in classesSnapshot.docs) {
        final classStartYear = await _getClassStartYear(classDoc.reference);
        if (classStartYear == null) { skippedCount++; continue; }
        final yearInt   = int.tryParse(yearInput) ?? 0;
        final yearIndex = yearInt - classStartYear;
        if (yearIndex < 0) { skippedCount++; continue; }
        final semNumber      = (yearIndex * 2) + (selectedSemester == "first" ? 1 : 2);
        final actualSemester = "sem$semNumber";
        final studentsSnapshot = await classDoc.reference.collection("students").get();
        for (var student in studentsSnapshot.docs) {
          final feeRef = student.reference.collection("fees").doc(yearInput);
          batch.set(feeRef, {actualSemester: {"deadline": newDeadline}}, SetOptions(merge: true));
          operationCount++;
          updatedCount++;
          if (operationCount >= batchSize) {
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      }
      if (operationCount > 0) await batch.commit();
      setState(() => currentDeadline = newDeadline);
      _snack("Updated $updatedCount students in ${classCount - skippedCount} classes", _green, Icons.check_circle_rounded);
    } catch (e) {
      _snack("Error: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}", _coral, Icons.error_rounded);
    }
    setState(() => isLoading = false);
  }

  Future<void> _setNewDeadline() async {
    if (_yearController.text.isEmpty) { _snack("Enter academic year", _gold, Icons.warning_rounded); return; }
    final confirm = await _showConfirmDialog();
    if (confirm != true) return;
    final picked = await _pickDate();
    if (picked != null) await _saveDeadlineForAllClasses(picked);
  }

  Future<void> _updateExistingDeadline() async {
    if (currentDeadline == null) return;
    final picked = await _pickDate(initial: currentDeadline!.toDate());
    if (picked != null) await _saveDeadlineForAllClasses(picked);
  }

  Future<bool?> _showConfirmDialog() => showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.3))),
                child: const Icon(Icons.warning_amber_rounded, color: _gold, size: 22)),
            const SizedBox(width: 14),
            const Expanded(child: Text("Bulk Update Warning", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
              child: Column(children: [
                _dialogRow(Icons.class_rounded,    "Classes",  "$totalClasses",  _indigo),
                const SizedBox(height: 8),
                _dialogRow(Icons.people_rounded,   "Students", "$totalStudents", _teal),
                const SizedBox(height: 8),
                _dialogRow(Icons.calendar_month_rounded, "Year", _yearController.text, _green),
                const SizedBox(height: 8),
                _dialogRow(Icons.event_rounded, "Semester", selectedSemester == "first" ? "First" : "Second", _gold),
              ])),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _coral.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _coral.withOpacity(0.2))),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: _coral, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text("This will update ALL students across all classes", style: TextStyle(color: _coral, fontSize: 12))),
              ])),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(onTap: () => Navigator.pop(context, false),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                    alignment: Alignment.center,
                    child: const Text("Cancel", style: TextStyle(color: _textSec, fontWeight: FontWeight.w600))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(onTap: () => Navigator.pop(context, true),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: const Text("Yes, Update All", style: TextStyle(color: _bg, fontWeight: FontWeight.w700))))),
          ]),
        ]),
      ),
    ),
  );

  Widget _dialogRow(IconData icon, String label, String value, Color color) => Row(children: [
    Icon(icon, color: color, size: 15),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(color: _textSec, fontSize: 13)),
    const Spacer(),
    Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
  ]);

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
      duration: const Duration(seconds: 4),
    ));
  }

  Widget _sectionLabel(String title, IconData icon, Color color) => Row(children: [
    Container(width: 3, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Icon(icon, color: color, size: 15),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
  ]);

  Widget _orb(double size, Color color, double opacity) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent])));

  Widget _buildField({required TextEditingController controller, required String hint,
    required IconData icon, required Color accentColor, TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: accentColor.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: TextField(
        controller: controller, keyboardType: keyboardType, onChanged: onChanged,
        style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: _textSec, fontSize: 13),
            prefixIcon: Padding(padding: const EdgeInsets.all(10),
                child: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: accentColor, size: 16))),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5)),
            filled: true, fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
      ),
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
            Positioned(bottom: 80 - _orb2Anim.value, left: -70, child: _orb(220, _indigo, 0.15)),
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
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Set Deadline", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
                Text("Configure college-wide deadlines", style: TextStyle(color: _textSec, fontSize: 11)),
              ])),
              Container(padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: _gold.withOpacity(0.25))),
                  child: const Icon(Icons.calendar_month_rounded, color: _gold, size: 18)),
            ]),
          ),

          Expanded(child: FadeTransition(opacity: _fadeAnim, child: SlideTransition(position: _slideAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Hero card
                Container(padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _gold.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: _gold.withOpacity(0.07), blurRadius: 30, offset: const Offset(0, 10)),
                          BoxShadow(color: _indigo.withOpacity(0.05), blurRadius: 50, offset: const Offset(0, 14))]),
                    child: Column(children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _gold.withOpacity(0.25))),
                            child: const Icon(Icons.calendar_month_rounded, color: _gold, size: 24)),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("College-Wide Deadline", style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                          Text("Updates ALL students across ALL classes", style: TextStyle(color: _textSec, fontSize: 11)),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _statTile("$totalClasses", "Classes", _indigo)),
                        const SizedBox(width: 10),
                        Expanded(child: _statTile("$totalStudents", "Students", _teal)),
                      ]),
                    ])),

                const SizedBox(height: 24),
                _sectionLabel("Deadline Details", Icons.tune_rounded, _indigo),
                const SizedBox(height: 12),

                // Year field
                _buildField(
                    controller: _yearController, hint: "e.g., 2026",
                    icon: Icons.calendar_today_rounded, accentColor: _indigo,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _fetchDeadline()),
                const SizedBox(height: 12),

                // Semester dropdown
                Container(
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _teal.withOpacity(0.25)),
                      boxShadow: [BoxShadow(color: _teal.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: Theme(data: Theme.of(context).copyWith(canvasColor: _card),
                      child: DropdownButtonFormField<String>(
                        value: selectedSemester,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _teal),
                        decoration: InputDecoration(
                            hintStyle: const TextStyle(color: _textSec, fontSize: 13),
                            prefixIcon: Padding(padding: const EdgeInsets.all(10),
                                child: Container(padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(color: _teal.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.calendar_view_month_rounded, color: _teal, size: 16))),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            filled: true, fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                        style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w600),
                        dropdownColor: _card,
                        items: const [
                          DropdownMenuItem(value: "first",  child: Text("First Semester",  style: TextStyle(color: _textPri, fontSize: 13))),
                          DropdownMenuItem(value: "second", child: Text("Second Semester", style: TextStyle(color: _textPri, fontSize: 13))),
                        ],
                        onChanged: (v) { setState(() => selectedSemester = v!); _fetchDeadline(); },
                      )),
                ),

                const SizedBox(height: 12),

                // Info note
                Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _indigo.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _indigo.withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: _indigo, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text("Each class's semester is calculated based on its academicFrom year",
                          style: TextStyle(color: _textSec, fontSize: 12))),
                    ])),
                const SizedBox(height: 12),

                // Warning
                Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _gold.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: _gold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text("This will update $totalStudents students across $totalClasses classes",
                          style: const TextStyle(color: _textSec, fontSize: 12))),
                    ])),

                const SizedBox(height: 24),

                // Set deadline button
                GestureDetector(
                  onTap: isLoading ? null : _setNewDeadline,
                  child: Container(width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                          color: isLoading ? _cardBorder : _teal,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isLoading ? [] : [BoxShadow(color: _teal.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 7))]),
                      child: isLoading
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5, backgroundColor: _teal.withOpacity(0.2))),
                        const SizedBox(width: 12),
                        const Text("Updating All Classes...", style: TextStyle(color: _textSec, fontSize: 15, fontWeight: FontWeight.w700)),
                      ])
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.update_rounded, color: _bg, size: 20),
                        SizedBox(width: 10),
                        Text("Set Deadline For ALL Classes", style: TextStyle(color: _bg, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      ])),
                ),

                const SizedBox(height: 24),

                // Current deadline card
                if (currentDeadline != null) ...[
                  _sectionLabel("Current Deadline", Icons.event_available_rounded, _gold),
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _gold.withOpacity(0.25)),
                          boxShadow: [BoxShadow(color: _gold.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 6))]),
                      child: Column(children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.25))),
                              child: const Icon(Icons.event_available_rounded, color: _gold, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text("Sample Current Deadline", style: TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                            Text("Year: ${_yearController.text} • ${selectedSemester == 'first' ? 'First' : 'Second'} Sem",
                                style: const TextStyle(color: _textSec, fontSize: 11)),
                          ])),
                          GestureDetector(onTap: _updateExistingDeadline,
                              child: Container(padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: _gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _gold.withOpacity(0.25))),
                                  child: const Icon(Icons.edit_rounded, color: _gold, size: 16))),
                        ]),
                        const SizedBox(height: 14),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.2))),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_rounded, color: _gold, size: 14),
                              const SizedBox(width: 8),
                              Text(formatDate(currentDeadline!), style: const TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w800)),
                              const Spacer(),
                              const Text("Sample from 1 class", style: TextStyle(color: _textSec, fontSize: 11)),
                            ])),
                      ])),
                ] else if (_yearController.text.isNotEmpty) ...[
                  _sectionLabel("Deadline Status", Icons.event_busy_rounded, _textSec),
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorder)),
                      child: Column(children: [
                        const Icon(Icons.event_busy_rounded, size: 36, color: _textSec),
                        const SizedBox(height: 12),
                        const Text("No Deadline Set", style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text("Set a deadline for ${_yearController.text}", style: const TextStyle(color: _textSec, fontSize: 12), textAlign: TextAlign.center),
                      ])),
                ],

                const SizedBox(height: 20),
              ]),
            ),
          ))),
        ])),
      ]),
    );
  }

  Widget _statTile(String value, String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSec, fontSize: 11)),
      ]));
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