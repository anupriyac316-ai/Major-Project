import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> with TickerProviderStateMixin {

  // ── Design tokens ─────────────────────────────────────────────────
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

  String department = 'All';

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

  Future<void> deleteStaff(String departmentId, String docId) async {
    await FirebaseFirestore.instance
        .collection('staff_of_college')
        .doc(departmentId)
        .collection('staff')
        .doc(docId)
        .delete();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> buildStaffStream() async* {
    final staffCollection = FirebaseFirestore.instance.collection('staff_of_college');

    if (department == 'All') {
      final deptSnapshot = await staffCollection.get();
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allStaff = [];
      for (var deptDoc in deptSnapshot.docs) {
        final staffSnap = await deptDoc.reference.collection('staff').get();
        allStaff.addAll(staffSnap.docs);
      }
      yield allStaff;
    } else {
      final staffSnap = await staffCollection.doc(department).collection('staff').get();
      yield staffSnap.docs;
    }
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
                    const Text("Staff Management",
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Text("Filter and manage staff records",
                        style: TextStyle(color: _textSec, fontSize: 11)),
                  ]),
                ),
                // Live staff count badge
                StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  stream: buildStaffStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.length : 0;
                    return Container(
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
                        Text("$count STAFF",
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

                    // ── Department filter card ─────────────────
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
                                border: Border.all(color: _indigo.withOpacity(0.25)),
                              ),
                              child: const Icon(Icons.account_tree_rounded,
                                  color: _indigo, size: 18),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("Filter by Department",
                                    style: TextStyle(
                                        color: _textPri,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                Text("Select a department to narrow results",
                                    style: TextStyle(color: _textSec, fontSize: 10)),
                              ]),
                            ),
                          ]),

                          const SizedBox(height: 14),

                          // Dropdown
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('staff_of_college')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox(
                                  height: 20,
                                  child: LinearProgressIndicator(color: _teal),
                                );
                              }

                              final departmentList = [
                                'All',
                                ...snapshot.data!.docs.map((e) => e.id).toList()
                              ];

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: _indigo.withOpacity(0.2)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: departmentList.contains(department)
                                        ? department
                                        : 'All',
                                    isExpanded: true,
                                    dropdownColor: _card,
                                    iconEnabledColor: _textSec,
                                    style: const TextStyle(
                                        color: _textPri, fontSize: 14),
                                    items: departmentList
                                        .map((d) => DropdownMenuItem(
                                        value: d, child: Text(d)))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null && mounted) {
                                        setState(() => department = value);
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Section label ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        Container(
                            width: 3, height: 20,
                            decoration: BoxDecoration(
                                color: _teal,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        const Icon(Icons.people_alt_rounded,
                            color: _teal, size: 16),
                        const SizedBox(width: 7),
                        const Text("Staff Members",
                            style: TextStyle(
                                color: _textPri,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3)),
                        const Spacer(),
                        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                          stream: buildStaffStream(),
                          builder: (context, snapshot) {
                            final count = snapshot.hasData
                                ? snapshot.data!.length
                                : 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _teal.withOpacity(0.2)),
                              ),
                              child: Text("$count found",
                                  style: const TextStyle(
                                      color: _teal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            );
                          },
                        ),
                      ]),
                    ),

                    const SizedBox(height: 12),

                    // ── Staff list ────────────────────────────
                    Expanded(
                      child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                        stream: buildStaffStream(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}',
                                  style: const TextStyle(color: _coral)),
                            );
                          }

                          if (!snapshot.hasData) {
                            return Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                    const Text("Loading staff...",
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

                          final staffList = snapshot.data!;

                          if (staffList.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                  const Text("No staff found",
                                      style: TextStyle(
                                          color: _textPri,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text(
                                    department == 'All'
                                        ? "Add staff members to get started"
                                        : "No staff found in $department",
                                    style: const TextStyle(
                                        color: _textSec, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: staffList.length,
                            itemBuilder: (context, index) {
                              final s = staffList[index];
                              return _buildStaffCard(s.id, s);
                            },
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

  // ── Staff card ────────────────────────────────────────────────────
  Widget _buildStaffCard(String docId, QueryDocumentSnapshot staffDoc) {
    final staffData = staffDoc.data() as Map<String, dynamic>;
    final deptName  = staffDoc.reference.parent.parent?.id ?? 'N/A';
    final firstName = staffData['firstName'] as String? ?? '';
    final lastName  = staffData['lastName']  as String? ?? '';
    final email     = staffData['email']     as String? ?? 'N/A';
    final phone     = staffData['phone']     ?? staffData['mobile'] ?? 'N/A';
    final role      = staffData['role']      as String? ?? '';

    final isHod     = role.toLowerCase().contains('hod');
    final roleColor = isHod ? _coral : _indigo;
    final initial   = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: roleColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: roleColor.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: roleColor.withOpacity(0.28)),
            ),
            child: Center(
              child: Text(initial,
                  style: TextStyle(
                      color: roleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
          ),

          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Name + role badge
              Row(children: [
                Expanded(
                  child: Text(
                    "$firstName $lastName".trim(),
                    style: const TextStyle(
                        color: _textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (role.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(role,
                        style: TextStyle(
                            color: roleColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                  ),
              ]),

              const SizedBox(height: 8),

              // Dept
              _infoRow(Icons.domain_rounded, _indigo, deptName),
              const SizedBox(height: 4),
              _infoRow(Icons.email_rounded, _teal, email),
              const SizedBox(height: 4),
              _infoRow(Icons.phone_rounded, _green, phone.toString()),
            ]),
          ),

          const SizedBox(width: 8),

          // Delete button
          GestureDetector(
            onTap: () async {
              final confirm = await _showDeleteDialog(staffData);
              if (confirm == true) {
                final deptId = staffDoc.reference.parent.parent!.id;
                await deleteStaff(deptId, docId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text("Staff deleted successfully"),
                    backgroundColor: _green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                }
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

  Widget _infoRow(IconData icon, Color color, String text) {
    return Row(children: [
      Icon(icon, color: color.withOpacity(0.7), size: 12),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: const TextStyle(color: _textSec, fontSize: 11),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  // ── Delete confirm dialog ─────────────────────────────────────────
  Future<bool?> _showDeleteDialog(Map<String, dynamic> staffData) {
    final name =
    "${staffData['firstName'] ?? ''} ${staffData['lastName'] ?? ''}".trim();

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
            const Text("Delete Staff",
                style: TextStyle(
                    color: _textPri,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              "Are you sure you want to delete $name? This action cannot be undone.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _textSec, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
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
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _coral.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _coral.withOpacity(0.35)),
                      boxShadow: [
                        BoxShadow(
                            color: _coral.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Text("Delete",
                          style: TextStyle(
                              color: _coral,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
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