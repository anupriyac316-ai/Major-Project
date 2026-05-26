import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateYearStudentsPage extends StatefulWidget {
  const UpdateYearStudentsPage({super.key});

  @override
  State<UpdateYearStudentsPage> createState() => _UpdateYearStudentsPageState();
}

class _UpdateYearStudentsPageState extends State<UpdateYearStudentsPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;

  String? selectedYear;
  String? selectedDepartment;

  List<String> availableYears       = [];
  List<String> availableDepartments = [];
  List<QueryDocumentSnapshot> filteredStudents = [];

  // ── Design tokens (same as FeeMainPage) ─────────────────────────
  static const Color _bg         = Color(0xFF070B14);
  static const Color _surface    = Color(0xFF0F1624);
  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _coral      = Color(0xFFFF6B6B);
  static const Color _gold       = Color(0xFFFFB547);
  static const Color _green      = Color(0xFF36E8A0);
  static const Color _rose       = Color(0xFFFF4D8D);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  // Animations
  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _orb1Anim;
  late Animation<double>   _orb2Anim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _orb1Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..repeat(reverse: true);
    _orb2Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 9))
      ..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _orb1Anim = Tween<double>(begin: 0, end: 26)
        .animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim = Tween<double>(begin: 0, end: 20)
        .animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    fetchYears();
    fetchDepartments();
  }

  @override
  void dispose() {
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Firestore helpers ────────────────────────────────────────────
  Future<void> fetchYears() async {
    final snapshot = await _firestore.collection('students').get();
    final years = snapshot.docs
        .map((doc) => (doc.data())['year']?.toString() ?? "")
        .where((y) => y.isNotEmpty)
        .toSet()
        .toList();

    years.sort((a, b) {
      const order = {'I': 1, 'II': 2, 'III': 3, 'IV': 4};
      return (order[a] ?? 0).compareTo(order[b] ?? 0);
    });

    setState(() => availableYears = years);
  }

  Future<void> fetchDepartments() async {
    final snapshot = await _firestore.collection('students').get();
    final depts = snapshot.docs
        .map((doc) => (doc.data())['department']?.toString() ?? "")
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    setState(() => availableDepartments = depts);
  }

  Future<void> fetchStudents() async {
    if (selectedYear == null || selectedDepartment == null) return;
    _fadeCtrl.reset();

    final snapshot = await _firestore
        .collection('students')
        .where('year', isEqualTo: selectedYear)
        .where('department', isEqualTo: selectedDepartment)
        .get();

    setState(() => filteredStudents = snapshot.docs);
    _fadeCtrl.forward();
  }

  Future<void> promoteStudents() async {
    if (selectedYear == null ||
        selectedDepartment == null ||
        filteredStudents.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final index = availableYears.indexOf(selectedYear!);

      if (index == -1 || index == availableYears.length - 1) {
        _showSnackBar("No next year available", _gold, Icons.warning_rounded);
        setState(() => isLoading = false);
        return;
      }

      final nextYear  = availableYears[index + 1];
      final batch     = _firestore.batch();

      for (var doc in filteredStudents) {
        batch.update(doc.reference, {'year': nextYear});
      }

      await batch.commit();

      _showSnackBar(
        "✨ ${filteredStudents.length} students promoted to Year $nextYear",
        _green,
        Icons.check_circle_rounded,
      );

      selectedYear = nextYear;
      await fetchStudents();
    } catch (e) {
      debugPrint("Promotion error: $e");
      _showSnackBar("Error promoting students", _coral, Icons.error_rounded);
    }

    setState(() => isLoading = false);
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: _bg, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: _bg, fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _card,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gold.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: _gold, size: 22),
                ),
                const SizedBox(width: 14),
                const Text("Confirm Promotion",
                    style: TextStyle(
                        color: _textPri,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ]),

              const SizedBox(height: 20),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(children: [
                  _dialogInfoRow(Icons.business_rounded, "Department",
                      selectedDepartment!, _indigo),
                  _divider(),
                  _dialogInfoRow(Icons.grade_rounded, "Current Year",
                      "Year ${selectedYear!}", _teal),
                  _divider(),
                  _dialogInfoRow(Icons.people_rounded, "Students",
                      "${filteredStudents.length}", _green),
                ]),
              ),

              const SizedBox(height: 16),

              // Warning note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _coral.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _coral.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _coral, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text("This action cannot be undone",
                        style: TextStyle(
                            color: _coral,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      alignment: Alignment.center,
                      child: const Text("Cancel",
                          style: TextStyle(
                              color: _textSec,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      promoteStudents();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text("Promote Now",
                          style: TextStyle(
                              color: _bg, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogInfoRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(color: _textSec, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _divider() => Container(
      height: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: _cardBorder);

  Widget _orb(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );

  // ── Dropdown builder ─────────────────────────────────────────────
  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required Color accentColor,
    required String? value,
    required List<String> items,
    required String hint,
    required String Function(String) display,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: value != null
                ? accentColor.withOpacity(0.4)
                : _cardBorder),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(value != null ? 0.08 : 0),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Theme(
        // Override the canvas color so the dropdown popup is also dark
        data: Theme.of(context).copyWith(
          canvasColor: _card,
        ),
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: value != null ? accentColor : _textSec,
          ),
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
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: const TextStyle(
              color: _textPri, fontSize: 14, fontWeight: FontWeight.w600),
          dropdownColor: _card,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
              value: item,
              child: Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: accentColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Text(
                  display(item),
                  style: const TextStyle(
                      color: _textPri, fontSize: 13),
                ),
              ]),
            ),
          )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Main build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // Animated orbs background
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
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Promote Students",
                            style: TextStyle(
                                color: _textPri,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text(
                          selectedDepartment != null && selectedYear != null
                              ? "$selectedDepartment  •  Year $selectedYear"
                              : "Select filters to continue",
                          style:
                          const TextStyle(color: _textSec, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                ),
                GestureDetector(
                  onTap: () {
                    fetchYears();
                    fetchDepartments();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: _textSec, size: 18),
                  ),
                ),
              ]),
            ),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Header banner card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _teal.withOpacity(0.2)),
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
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _teal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _teal.withOpacity(0.25)),
                            ),
                            child: const Icon(Icons.school_rounded,
                                color: _teal, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Student Promotion",
                                      style: TextStyle(
                                          color: _textPri,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    filteredStudents.isNotEmpty
                                        ? "${filteredStudents.length} student${filteredStudents.length > 1 ? 's' : ''} ready to promote"
                                        : "Select department & year below",
                                    style: const TextStyle(
                                        color: _textSec, fontSize: 12),
                                  ),
                                ]),
                          ),
                          if (filteredStudents.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                Border.all(color: _green.withOpacity(0.3)),
                              ),
                              child: Text(
                                "${filteredStudents.length}",
                                style: const TextStyle(
                                    color: _green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // Section label
                      _sectionLabel("Filters", Icons.tune_rounded, _indigo),
                      const SizedBox(height: 12),

                      // Department dropdown
                      _buildDropdown(
                        label: "Department",
                        icon: Icons.business_rounded,
                        accentColor: _indigo,
                        value: selectedDepartment,
                        items: availableDepartments,
                        hint: "Select Department",
                        display: (d) => d,
                        onChanged: (v) async {
                          setState(() {
                            selectedDepartment = v;
                            filteredStudents   = [];
                          });
                          if (v != null) await fetchStudents();
                        },
                      ),

                      const SizedBox(height: 12),

                      // Year dropdown
                      _buildDropdown(
                        label: "Year",
                        icon: Icons.grade_rounded,
                        accentColor: _teal,
                        value: selectedYear,
                        items: availableYears,
                        hint: "Select Year",
                        display: (y) => "Year $y",
                        onChanged: (v) async {
                          setState(() {
                            selectedYear     = v;
                            filteredStudents = [];
                          });
                          if (v != null) await fetchStudents();
                        },
                      ),

                      const SizedBox(height: 28),

                      // Student list section
                      if (selectedYear != null && selectedDepartment != null) ...[
                        Row(children: [
                          _sectionLabel(
                              "Student List", Icons.people_alt_rounded, _green),
                          const Spacer(),
                          if (filteredStudents.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                Border.all(color: _green.withOpacity(0.25)),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                          color: _green,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${filteredStudents.length} found",
                                      style: const TextStyle(
                                          color: _green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ]),
                            ),
                        ]),

                        const SizedBox(height: 12),

                        if (filteredStudents.isEmpty)
                          _emptyState()
                        else
                          FadeTransition(
                            opacity: _fadeAnim,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredStudents.length,
                              separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                              itemBuilder: (_, i) =>
                                  _studentCard(filteredStudents[i]),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Promote button
                        if (filteredStudents.isNotEmpty)
                          GestureDetector(
                            onTap: _showConfirmDialog,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _teal,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                      color: _teal.withOpacity(0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.upgrade_rounded,
                                        color: _bg, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Promote ${filteredStudents.length} Student${filteredStudents.length > 1 ? 's' : ''}",
                                      style: const TextStyle(
                                        color: _bg,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                      ],

                      const SizedBox(height: 20),
                    ]),
              ),
            ),
          ]),
        ),

        // Loading overlay
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _teal.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                        color: _teal.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 56,
                    height: 56,
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
                  const SizedBox(height: 18),
                  const Text("Promoting students...",
                      style: TextStyle(
                          color: _textPri,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Please wait",
                      style: TextStyle(color: _textSec, fontSize: 12)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Reusable widgets ─────────────────────────────────────────────
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    ]);
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            shape: BoxShape.circle,
            border: Border.all(color: _cardBorder),
          ),
          child: const Icon(Icons.people_outline_rounded,
              size: 40, color: _textSec),
        ),
        const SizedBox(height: 16),
        const Text("No students found",
            style: TextStyle(
                color: _textPri,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text("Try selecting a different filter",
            style: TextStyle(color: _textSec, fontSize: 13)),
      ]),
    );
  }

  Widget _studentCard(QueryDocumentSnapshot doc) {
    final data       = doc.data() as Map<String, dynamic>;
    final firstName  = data['firstName']  ?? "";
    final lastName   = data['lastName']   ?? "";
    final email      = data['email']      ?? "No Email";
    final year       = data['year']       ?? "N/A";
    final department = data['department'] ?? "N/A";
    final fullName   = "$firstName $lastName".trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
              color: _indigo.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _indigo.withOpacity(0.24),
                _indigo.withOpacity(0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _indigo.withOpacity(0.3)),
          ),
          child: const Icon(Icons.person_rounded, color: _indigo, size: 22),
        ),
        const SizedBox(width: 14),

        // Info
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? "No Name" : fullName,
                  style: const TextStyle(
                      color: _textPri,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.email_outlined, size: 12, color: _textSec),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(email,
                        style:
                        const TextStyle(color: _textSec, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _chip("Year $year", Icons.grade_rounded, _teal),
                  const SizedBox(width: 8),
                  _chip(department, Icons.business_rounded, _indigo),
                ]),
              ]),
        ),

        // Arrow
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.arrow_forward_ios_rounded,
              color: _teal, size: 12),
        ),
      ]),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Dot painter (same as FeeMainPage) ────────────────────────────
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