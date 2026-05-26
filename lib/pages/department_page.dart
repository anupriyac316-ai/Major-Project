import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentPage extends StatefulWidget {
  const DepartmentPage({super.key});

  @override
  State<DepartmentPage> createState() => _DepartmentPageState();
}

class _DepartmentPageState extends State<DepartmentPage> {
  final TextEditingController _deptCtrl = TextEditingController();
  String? selectedCourse;
  String? selectedYear;

  final List<String> yearOptions = ['I', 'II', 'III', 'IV', 'V'];

  // ── Design tokens ────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F1117);
  static const _surface = Color(0xFF1A1D27);
  static const _surfaceAlt = Color(0xFF22263A);
  static const _accent = Color(0xFFF5A623);
  static const _accentSoft = Color(0x26F5A623);
  static const _pink = Color(0xFFE8568A);
  static const _pinkSoft = Color(0x1AE8568A);
  static const _blue = Color(0xFF4A9EFF);
  static const _blueSoft = Color(0x1A4A9EFF);
  static const _red = Color(0xFFEF5350);
  static const _redSoft = Color(0x1AEF5350);
  static const _green = Color(0xFF4CAF50);
  static const _textPrimary = Color(0xFFF0F2FF);
  static const _textSecondary = Color(0xFF8A8FAD);
  static const _border = Color(0xFF2E3350);

  // ── Input decoration ─────────────────────────────────────────────────────────
  InputDecoration _inputDecoration(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        labelStyle:
        const TextStyle(color: _textSecondary, fontSize: 13),
        filled: true,
        fillColor: _bg,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: _textSecondary)
            : null,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      );

  // ── Dropdown container decoration ────────────────────────────────────────────
  BoxDecoration get _dropdownDecoration => BoxDecoration(
    color: _bg,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _border),
  );

  // ── Section label ─────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );

  // ── Snackbar helper ───────────────────────────────────────────────────────────
  void _showSnackbar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_rounded
                  : Icons.check_circle_rounded,
              color: isError ? _red : _green,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                  color: _textPrimary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ── ADD DEPARTMENT ────────────────────────────────────────────────────────────
  void _addDepartment(BuildContext context) async {
    if (_deptCtrl.text.trim().isEmpty ||
        selectedCourse == null ||
        selectedYear == null) return;

    List<String> years =
    yearOptions.sublist(0, yearOptions.indexOf(selectedYear!) + 1);

    await FirebaseFirestore.instance.collection('departments').add({
      'name': _deptCtrl.text.trim(),
      'course': selectedCourse,
      'years': years,
      'createdAt': Timestamp.now(),
    });

    _deptCtrl.clear();
    selectedCourse = null;
    selectedYear = null;
    Navigator.pop(context);
  }

  // ── EDIT DEPARTMENT ───────────────────────────────────────────────────────────
  void _editDepartment(String id, String oldName, String course,
      List<dynamic> oldYears, BuildContext context) {
    _deptCtrl.text = oldName;
    selectedCourse = course;
    selectedYear = oldYears.isNotEmpty ? oldYears.last : null;

    showDialog(
      context: context,
      builder: (_) => _buildFormDialog(
        context: context,
        title: "Edit Department",
        icon: Icons.edit_rounded,
        iconColor: _blue,
        iconBg: _blueSoft,
        confirmLabel: "Update",
        onConfirm: () async {
          if (selectedYear == null) return;
          List<String> years = yearOptions.sublist(
              0, yearOptions.indexOf(selectedYear!) + 1);
          await FirebaseFirestore.instance
              .collection('departments')
              .doc(id)
              .update({
            'name': _deptCtrl.text.trim(),
            'course': selectedCourse,
            'years': years,
          });
          _deptCtrl.clear();
          selectedCourse = null;
          selectedYear = null;
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── DELETE DEPARTMENT ─────────────────────────────────────────────────────────
  void _deleteDepartment(
      String id, String deptName, BuildContext context) async {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: _redSoft, shape: BoxShape.circle),
                child: const Icon(Icons.delete_rounded,
                    color: _red, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                "Delete Department",
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete\n"$deptName"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: _textSecondary,
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: _border),
                        ),
                      ),
                      child: const Text("Cancel",
                          style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('departments')
                            .doc(id)
                            .delete();
                        Navigator.pop(context);
                        _showSnackbar(
                            context, '"$deptName" deleted successfully');
                      },
                      child: const Text("Delete",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── COURSE DROPDOWN ───────────────────────────────────────────────────────────
  Widget _courseDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream:
      FirebaseFirestore.instance.collection('courses').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 48,
            decoration: _dropdownDecoration,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: _accent, strokeWidth: 2),
              ),
            ),
          );
        }

        final courses = snapshot.data!.docs
            .map((doc) => doc['name'] as String)
            .toList();

        return Container(
          decoration: _dropdownDecoration,
          child: DropdownButtonFormField<String>(
            value: selectedCourse,
            hint: const Text('Select Course',
                style:
                TextStyle(color: Color(0xFF4A4F6A), fontSize: 13)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
              EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              prefixIcon: Icon(Icons.school_rounded,
                  size: 18, color: _textSecondary),
            ),
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            dropdownColor: _surfaceAlt,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: _accent, size: 20),
            borderRadius: BorderRadius.circular(12),
            items: courses
                .map((course) => DropdownMenuItem(
              value: course,
              child: Text(course),
            ))
                .toList(),
            onChanged: (value) =>
                setState(() => selectedCourse = value),
          ),
        );
      },
    );
  }

  // ── YEAR DROPDOWN ─────────────────────────────────────────────────────────────
  Widget _yearDropdown() {
    return Container(
      decoration: _dropdownDecoration,
      child: DropdownButtonFormField<String>(
        value: selectedYear,
        hint: const Text('Select Highest Year',
            style: TextStyle(color: Color(0xFF4A4F6A), fontSize: 13)),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          prefixIcon: Icon(Icons.calendar_today_rounded,
              size: 18, color: _textSecondary),
        ),
        style: const TextStyle(color: _textPrimary, fontSize: 14),
        dropdownColor: _surfaceAlt,
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: _accent, size: 20),
        borderRadius: BorderRadius.circular(12),
        items: yearOptions
            .map((year) => DropdownMenuItem(
          value: year,
          child: Text('Year $year'),
        ))
            .toList(),
        onChanged: (value) => setState(() => selectedYear = value),
      ),
    );
  }

  // ── FORM DIALOG (add / edit) ──────────────────────────────────────────────────
  Widget _buildFormDialog({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Course dropdown
            const Text("Course",
                style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            _courseDropdown(),
            const SizedBox(height: 14),

            // Department name
            TextField(
              controller: _deptCtrl,
              autofocus: true,
              style:
              const TextStyle(color: _textPrimary, fontSize: 14),
              decoration: _inputDecoration("Department Name",
                  icon: Icons.account_tree_rounded),
            ),
            const SizedBox(height: 14),

            // Year dropdown
            const Text("Highest Year",
                style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            _yearDropdown(),
            const SizedBox(height: 22),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _deptCtrl.clear();
                    selectedCourse = null;
                    selectedYear = null;
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: _textSecondary),
                  child: const Text("Cancel",
                      style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_accent, _pink]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFAB(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          Expanded(child: _buildDeptList(context)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textSecondary, size: 18),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Departments",
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            "Admin Management",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _pink.withOpacity(0.15),
            _accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pink.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _pinkSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _pink.withOpacity(0.3)),
            ),
            child: const Icon(Icons.account_tree_rounded,
                color: _pink, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Academic Departments",
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  "Add and manage departments",
                  style:
                  TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Live count badge
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('departments')
                .snapshots(),
            builder: (context, snapshot) {
              final count =
              snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border:
                  Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      "$count",
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const Text(
                      "total",
                      style: TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeptList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('departments')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _accent));
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.account_tree_outlined,
                      size: 40, color: _textSecondary),
                ),
                const SizedBox(height: 20),
                const Text(
                  "No Departments Yet",
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Tap + to add your first department",
                  style:
                  TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final years = List<String>.from(doc['years'] ?? []);
            final createdAt = doc['createdAt'] as Timestamp;
            final date = createdAt.toDate();
            return _buildDepartmentCard(
              id: doc.id,
              name: doc['name'],
              course: doc['course'],
              years: years,
              date: date,
              index: index,
              context: context,
            );
          },
        );
      },
    );
  }

  Widget _buildDepartmentCard({
    required String id,
    required String name,
    required String course,
    required List<String> years,
    required DateTime date,
    required int index,
    required BuildContext context,
  }) {
    final colors = [_pink, _blue, _accent, _green];
    final softs = [_pinkSoft, _blueSoft, _accentSoft,
      const Color(0x1A4CAF50)];
    final color = colors[index % colors.length];
    final soft = softs[index % softs.length];

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ─────────────────────────────────────────────
            Row(
              children: [
                // Index badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: color.withOpacity(0.25)),
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name + course
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.school_rounded,
                              size: 11, color: _textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              course,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton(
                      icon: Icons.edit_rounded,
                      color: _blue,
                      soft: _blueSoft,
                      onTap: () => _editDepartment(
                          id, name, course, years, context),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.delete_rounded,
                      color: _red,
                      soft: _redSoft,
                      onTap: () =>
                          _deleteDepartment(id, name, context),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Years strip ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "YEARS OFFERED",
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: years.map((year) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _pinkSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _pink.withOpacity(0.2)),
                        ),
                        child: Text(
                          "Year $year",
                          style: const TextStyle(
                            color: _pink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Date row ─────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 11, color: _textSecondary),
                const SizedBox(width: 4),
                Text(
                  "Added ${_formatDate(date)}",
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required Color soft,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _deptCtrl.clear();
        setState(() {
          selectedCourse = null;
          selectedYear = null;
        });
        showDialog(
          context: context,
          builder: (_) => _buildFormDialog(
            context: context,
            title: "Add New Department",
            icon: Icons.add_rounded,
            iconColor: _accent,
            iconBg: _accentSoft,
            confirmLabel: "Add Department",
            onConfirm: () => _addDepartment(context),
          ),
        );
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_accent, _pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded,
            color: Colors.white, size: 26),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}