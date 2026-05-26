import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_single_student.dart';
import 'add_students.dart';
import 'students_page.dart';

class StudentMainPage extends StatefulWidget {
  const StudentMainPage({super.key});

  @override
  State<StudentMainPage> createState() => _StudentMainPageState();
}

class _StudentMainPageState extends State<StudentMainPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int totalStudents = 0;
  int totalClasses = 0;
  bool isLoading = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ── Design tokens ──────────────────────────────────────────────
  static const Color _bg = Color(0xFF0A0E1A);
  static const Color _surface = Color(0xFF131929);
  static const Color _card = Color(0xFF1A2236);
  static const Color _teal = Color(0xFF00E5CC);
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _gold = Color(0xFFFFB547);
  static const Color _indigo = Color(0xFF6C63FF);
  static const Color _textPrimary = Color(0xFFEEF2FF);
  static const Color _textSecondary = Color(0xFF8B9CC8);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    fetchDashboardStats();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ── Logic unchanged ─────────────────────────────────────────────
  Future<void> fetchDashboardStats() async {
    try {
      setState(() => isLoading = true);

      QuerySnapshot classSnapshot =
      await _firestore.collection('Student_Of_College').get();

      int studentsCount = 0;
      totalClasses = classSnapshot.docs.length;

      for (var classDoc in classSnapshot.docs) {
        QuerySnapshot studentSnapshot =
        await classDoc.reference.collection('students').get();
        studentsCount += studentSnapshot.docs.length;
      }

      setState(() {
        totalStudents = studentsCount;
        isLoading = false;
      });

      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error fetching stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: _teal),
      )
          : RefreshIndicator(
        color: _teal,
        backgroundColor: _card,
        onRefresh: () async {
          _fadeController.reset();
          _slideController.reset();
          await fetchDashboardStats();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Custom App Bar ──────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: _surface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _textPrimary, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Deep gradient bg
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0D1B3E),
                            Color(0xFF131929),
                            Color(0xFF0A1628),
                          ],
                        ),
                      ),
                    ),

                    // Decorative glow circles
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _teal.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _indigo.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Dot grid pattern
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DotGridPainter(
                          color: _teal.withOpacity(0.06),
                        ),
                      ),
                    ),

                    // Header content
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _teal.withOpacity(0.15),
                                    borderRadius:
                                    BorderRadius.circular(20),
                                    border: Border.all(
                                        color: _teal.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                            color: _teal,
                                            shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "ADMIN PANEL",
                                        style: TextStyle(
                                          color: _teal,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Student\nManagement",
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Stats Row ──────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: "Total Students",
                                value: totalStudents.toString(),
                                icon: Icons.people_alt_rounded,
                                accentColor: _teal,
                                subLabel: "Enrolled",
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _StatCard(
                                label: "Total Classes",
                                value: totalClasses.toString(),
                                icon: Icons.school_rounded,
                                accentColor: _gold,
                                subLabel: "Active",
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ── Section label ──────────────────────
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _teal,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Quick Actions",
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Action Cards ───────────────────────
                        _ActionCard(
                          title: "Add Single Student",
                          subtitle:
                          "Manually create individual student account",
                          icon: Icons.person_add_alt_1_rounded,
                          accentColor: _indigo,
                          badgeLabel: "MANUAL",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                const AddSingleStudentPage()),
                          ),
                        ),

                        const SizedBox(height: 14),

                        _ActionCard(
                          title: "Bulk Upload",
                          subtitle:
                          "Upload multiple students via Excel file",
                          icon: Icons.upload_file_rounded,
                          accentColor: _teal,
                          badgeLabel: "EXCEL",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddStudentsPage()),
                          ),
                        ),

                        const SizedBox(height: 14),

                        _ActionCard(
                          title: "Manage Students",
                          subtitle:
                          "View, filter and delete student records",
                          icon: Icons.manage_accounts_rounded,
                          accentColor: _coral,
                          badgeLabel: "MANAGE",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StudentsPage()),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String subLabel;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2236),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B9CC8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Card ──────────────────────────────────────────────────────
class _ActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String badgeLabel;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.badgeLabel,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _pressController;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _pressController.reverse(),
        onTapUp: (_) {
          _pressController.forward();
          widget.onTap();
        },
        onTapCancel: () => _pressController.forward(),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2236),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.accentColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container with glow
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accentColor.withOpacity(0.25),
                      widget.accentColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: widget.accentColor.withOpacity(0.3)),
                ),
                child: Icon(widget.icon,
                    color: widget.accentColor, size: 26),
              ),

              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFFEEF2FF),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.badgeLabel,
                            style: TextStyle(
                              color: widget.accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8B9CC8),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Arrow
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: widget.accentColor,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dot Grid Painter ─────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 24.0;
    const radius = 1.2;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}