import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeesStructurePage extends StatefulWidget {
  final String? editYear;

  const FeesStructurePage({super.key, this.editYear});

  @override
  State<FeesStructurePage> createState() => _FeesStructurePageState();
}

class _FeesStructurePageState extends State<FeesStructurePage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedYear;
  bool isBachelorSelected = false;
  bool isMasterSelected   = false;

  final List<String> academicYears =
  List.generate(10, (i) => (2024 + i).toString());

  final Map<int, TextEditingController> bachelorFirst  = {};
  final Map<int, TextEditingController> bachelorSecond = {};
  final Map<int, TextEditingController> masterFirst    = {};
  final Map<int, TextEditingController> masterSecond   = {};

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
  static const Color _rose       = Color(0xFFFF4D8D);
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
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _slideCtrl, curve: Curves.easeOutCubic));

    for (int i = 1; i <= 6; i++) {
      bachelorFirst[i]  = TextEditingController();
      bachelorSecond[i] = TextEditingController();
    }
    for (int i = 1; i <= 4; i++) {
      masterFirst[i]  = TextEditingController();
      masterSecond[i] = TextEditingController();
    }

    if (widget.editYear != null) {
      selectedYear = widget.editYear;
      _loadExistingData(widget.editYear!);
    }

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    for (int i = 1; i <= 6; i++) {
      bachelorFirst[i]?.dispose();
      bachelorSecond[i]?.dispose();
    }
    for (int i = 1; i <= 4; i++) {
      masterFirst[i]?.dispose();
      masterSecond[i]?.dispose();
    }
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ────────────────────────────────────────────
  Future<void> _loadExistingData(String year) async {
    final doc =
    await _firestore.collection("fees_structure").doc(year).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    setState(() => selectedYear = data["academicYear"]);

    if (data.containsKey("bachelor")) {
      isBachelorSelected = true;
      final semesters =
      Map<String, dynamic>.from(data["bachelor"]["semesters"]);
      for (int i = 1; i <= 6; i++) {
        if (semesters.containsKey("sem$i")) {
          bachelorFirst[i]?.text  = semesters["sem$i"]["firstHalf"].toString();
          bachelorSecond[i]?.text = semesters["sem$i"]["secondHalf"].toString();
        }
      }
    }

    if (data.containsKey("master")) {
      isMasterSelected = true;
      final semesters =
      Map<String, dynamic>.from(data["master"]["semesters"]);
      for (int i = 1; i <= 4; i++) {
        if (semesters.containsKey("sem$i")) {
          masterFirst[i]?.text  = semesters["sem$i"]["firstHalf"].toString();
          masterSecond[i]?.text = semesters["sem$i"]["secondHalf"].toString();
        }
      }
    }
    setState(() {});
  }

  Future<void> saveStructure() async {
    if (selectedYear == null) {
      _snack("Select Academic Year", _gold, Icons.warning_rounded);
      return;
    }

    Map<String, dynamic> data = {
      "academicYear": selectedYear,
      "createdAt":    FieldValue.serverTimestamp(),
    };

    if (isBachelorSelected) {
      Map<String, dynamic> semesters = {};
      for (int i = 1; i <= 6; i++) {
        semesters["sem$i"] = {
          "firstHalf":  int.tryParse(bachelorFirst[i]?.text  ?? "0") ?? 0,
          "secondHalf": int.tryParse(bachelorSecond[i]?.text ?? "0") ?? 0,
        };
      }
      data["bachelor"] = {"totalSemesters": 6, "semesters": semesters};
    }

    if (isMasterSelected) {
      Map<String, dynamic> semesters = {};
      for (int i = 1; i <= 4; i++) {
        semesters["sem$i"] = {
          "firstHalf":  int.tryParse(masterFirst[i]?.text  ?? "0") ?? 0,
          "secondHalf": int.tryParse(masterSecond[i]?.text ?? "0") ?? 0,
        };
      }
      data["master"] = {"totalSemesters": 4, "semesters": semesters};
    }

    await _firestore
        .collection("fees_structure")
        .doc(selectedYear)
        .set(data, SetOptions(merge: true));

    _snack(
      widget.editYear != null
          ? "Fees Structure Updated Successfully"
          : "Fees Structure Created Successfully",
      _green,
      Icons.check_circle_rounded,
    );

    Navigator.pop(context);
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

  Widget _orb(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );

  Widget _sectionLabel(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        width: 3,
        height: 20,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 10),
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              color: _textPri,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    ]);
  }

  // ── Degree selection card ────────────────────────────────────────
  Widget _buildDegreeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : _cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 5)),
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.2)
                  : color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withOpacity(isSelected ? 0.4 : 0.2)),
            ),
            child: Icon(icon,
                color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  color: isSelected ? color : _textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: _textSec, fontSize: 11)),
          if (isSelected) ...[
            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("Selected",
                  style: TextStyle(
                      color: _bg,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Semester amount text field ───────────────────────────────────
  Widget _buildAmountField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: TextField(
        controller:   controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(
            color: _textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: const TextStyle(color: _textSec, fontSize: 12),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
          ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color.withOpacity(0.5), width: 1.5),
          ),
          floatingLabelStyle: TextStyle(color: color, fontSize: 11),
          filled:          true,
          fillColor:       Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  // ── Semester section ─────────────────────────────────────────────
  Widget _buildSemesterSection({
    required String title,
    required int totalSemesters,
    required Map<int, TextEditingController> first,
    required Map<int, TextEditingController> second,
    required Color color,
    required IconData icon,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),

      // Degree header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text("$totalSemesters Semesters",
                      style:
                      const TextStyle(color: _textSec, fontSize: 11)),
                ]),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Text("₹",
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      ),

      const SizedBox(height: 14),

      // Semester cards
      ...List.generate(totalSemesters, (index) {
        final sem = index + 1;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + index * 80),
          builder: (_, v, child) => Transform.translate(
            offset: Offset(0, 16 * (1 - v)),
            child: Opacity(opacity: v, child: child),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(children: [
              // Semester label row
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text("$sem",
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                const Text("Semester",
                    style: TextStyle(
                        color: _textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("Sem $sem",
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 14),

              // Amount inputs
              Row(children: [
                Expanded(
                  child: _buildAmountField(
                    controller: first[sem]!,
                    label:      "First Half  ₹",
                    icon:       Icons.payments_rounded,
                    color:      color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAmountField(
                    controller: second[sem]!,
                    label:      "Second Half  ₹",
                    icon:       Icons.account_balance_wallet_rounded,
                    color:      color,
                  ),
                ),
              ]),
            ]),
          ),
        );
      }),
    ]);
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editYear != null;

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
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? "Edit Fees Structure"
                              : "Create Fees Structure",
                          style: const TextStyle(
                              color: _textPri,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                        const Text("Set semester-wise fees",
                            style:
                            TextStyle(color: _textSec, fontSize: 11)),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                    Border.all(color: _teal.withOpacity(0.25)),
                  ),
                  child: Icon(
                    isEdit
                        ? Icons.edit_rounded
                        : Icons.add_circle_outline_rounded,
                    color: _teal,
                    size: 18,
                  ),
                ),
              ]),
            ),

            // ── Scrollable body ─────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Hero card
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
                                  border: Border.all(
                                      color: _teal.withOpacity(0.25)),
                                ),
                                child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: _teal,
                                    size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEdit
                                            ? "Editing ${widget.editYear}"
                                            : "New Fee Structure",
                                        style: const TextStyle(
                                            color: _textPri,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const Text(
                                          "Configure semester-wise amounts",
                                          style: TextStyle(
                                              color: _textSec, fontSize: 11)),
                                    ]),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (isEdit ? _gold : _green)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: (isEdit ? _gold : _green)
                                          .withOpacity(0.3)),
                                ),
                                child: Text(
                                  isEdit ? "EDIT" : "NEW",
                                  style: TextStyle(
                                      color: isEdit ? _gold : _green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8),
                                ),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 24),

                          // Academic Year section
                          _sectionLabel("Academic Year",
                              Icons.calendar_month_rounded, _indigo),
                          const SizedBox(height: 12),

                          Container(
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: selectedYear != null
                                      ? _indigo.withOpacity(0.4)
                                      : _cardBorder),
                              boxShadow: [
                                BoxShadow(
                                    color: _indigo.withOpacity(
                                        selectedYear != null ? 0.08 : 0),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5)),
                              ],
                            ),
                            child: Theme(
                              data: Theme.of(context)
                                  .copyWith(canvasColor: _card),
                              child: DropdownButtonFormField<String>(
                                value: selectedYear,
                                isExpanded: true,
                                icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: selectedYear != null
                                        ? _indigo
                                        : _textSec),
                                decoration: InputDecoration(
                                  hintText: "Select Academic Year",
                                  hintStyle: const TextStyle(
                                      color: _textSec, fontSize: 13),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: _indigo.withOpacity(0.12),
                                        borderRadius:
                                        BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.school_rounded,
                                          color: _indigo,
                                          size: 16),
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none),
                                  filled:          true,
                                  fillColor:       Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                                style: const TextStyle(
                                    color: _textPri,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                dropdownColor: _card,
                                items: academicYears
                                    .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Row(children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                          color: _indigo,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(y,
                                        style: const TextStyle(
                                            color: _textPri,
                                            fontSize: 13)),
                                  ]),
                                ))
                                    .toList(),
                                onChanged: isEdit
                                    ? null
                                    : (val) =>
                                    setState(() => selectedYear = val),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Degree selection
                          _sectionLabel("Degree Type",
                              Icons.library_books_rounded, _teal),
                          const SizedBox(height: 12),

                          Row(children: [
                            Expanded(
                              child: _buildDegreeCard(
                                title:      "Bachelor",
                                subtitle:   "6 Semesters",
                                icon:       Icons.school_rounded,
                                color:      _teal,
                                isSelected: isBachelorSelected,
                                onTap: () => setState(() =>
                                isBachelorSelected = !isBachelorSelected),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDegreeCard(
                                title:      "Master",
                                subtitle:   "4 Semesters",
                                icon:       Icons.account_balance_rounded,
                                color:      _indigo,
                                isSelected: isMasterSelected,
                                onTap: () => setState(
                                        () => isMasterSelected = !isMasterSelected),
                              ),
                            ),
                          ]),

                          // Bachelor semesters
                          if (isBachelorSelected) ...[
                            const SizedBox(height: 8),
                            _sectionLabel("Bachelor — Semester Fees",
                                Icons.school_rounded, _teal),
                            _buildSemesterSection(
                              title:          "Bachelor Degree (UG)",
                              totalSemesters: 6,
                              first:          bachelorFirst,
                              second:         bachelorSecond,
                              color:          _teal,
                              icon:           Icons.school_rounded,
                            ),
                          ],

                          // Master semesters
                          if (isMasterSelected) ...[
                            const SizedBox(height: 8),
                            _sectionLabel("Master — Semester Fees",
                                Icons.account_balance_rounded, _indigo),
                            _buildSemesterSection(
                              title:          "Master Degree (PG)",
                              totalSemesters: 4,
                              first:          masterFirst,
                              second:         masterSecond,
                              color:          _indigo,
                              icon:           Icons.account_balance_rounded,
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Save button
                          GestureDetector(
                            onTap: saveStructure,
                            child: Container(
                              width: double.infinity,
                              padding:
                              const EdgeInsets.symmetric(vertical: 16),
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
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isEdit
                                          ? Icons.update_rounded
                                          : Icons.save_rounded,
                                      color: _bg,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isEdit
                                          ? "Update Fees Structure"
                                          : "Save Fees Structure",
                                      style: const TextStyle(
                                          color: _bg,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3),
                                    ),
                                  ]),
                            ),
                          ),

                          const SizedBox(height: 20),
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