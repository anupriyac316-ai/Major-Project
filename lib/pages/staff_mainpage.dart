import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_single_staff.dart';
import 'add_bulk_staff.dart';
import 'staff_page.dart';

class StaffMainPage extends StatefulWidget {
  const StaffMainPage({super.key});

  @override
  State<StaffMainPage> createState() => _StaffMainPageState();
}

class _StaffMainPageState extends State<StaffMainPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int totalStaff = 0;
  int totalDepartments = 0;
  bool isLoading = true;

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Design tokens (matches Dashboard) ──────────────────────────
  static const Color _bg         = Color(0xFF070B14);
  static const Color _surface    = Color(0xFF0F1624);
  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _coral      = Color(0xFFFF6B6B);
  static const Color _gold       = Color(0xFFFFB547);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    fetchStats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Logic unchanged ─────────────────────────────────────────────
  Future<void> fetchStats() async {
    try {
      setState(() => isLoading = true);

      QuerySnapshot deptSnapshot =
      await _firestore.collection('staff_of_college').get();

      int staffCount = 0;
      totalDepartments = deptSnapshot.docs.length;

      for (var deptDoc in deptSnapshot.docs) {
        QuerySnapshot staffSnap =
        await deptDoc.reference.collection('staff').get();
        staffCount += staffSnap.docs.length;
      }

      setState(() {
        totalStaff = staffCount;
        isLoading = false;
      });

      _fadeCtrl.forward();
      _slideCtrl.forward();
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
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
          _fadeCtrl.reset();
          _slideCtrl.reset();
          await fetchStats();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sliver App Bar ──────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: _surface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _textPri, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    _fadeCtrl.reset();
                    _slideCtrl.reset();
                    fetchStats();
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const Icon(Icons.refresh_outlined,
                        color: _textSec, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0.5),
                child: Container(height: 0.5, color: _cardBorder),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient bg
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

                    // Glow orbs
                    Positioned(
                      top: -50,
                      right: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            _indigo.withOpacity(0.18),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            _teal.withOpacity(0.12),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),

                    // Dot grid
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DotGridPainter(
                          color: _indigo.withOpacity(0.06),
                        ),
                      ),
                    ),

                    // Header text
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _indigo.withOpacity(0.15),
                                borderRadius:
                                BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                    _indigo.withOpacity(0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                        color: _indigo,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "ADMIN PANEL",
                                    style: TextStyle(
                                      color: _indigo,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Staff\nManagement",
                              style: TextStyle(
                                color: _textPri,
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

            // ── Body content ────────────────────────────────
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // ── Stat Cards ──────────────────────
                        Row(children: [
                          Expanded(
                            child: _StatCard(
                              label: "Total Staff",
                              value: totalStaff.toString(),
                              icon: Icons.people_alt_rounded,
                              accentColor: _indigo,
                              subLabel: "Members",
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StatCard(
                              label: "Departments",
                              value: totalDepartments.toString(),
                              icon: Icons.apartment_rounded,
                              accentColor: _teal,
                              subLabel: "Units",
                            ),
                          ),
                        ]),

                        const SizedBox(height: 32),

                        // ── Section label ────────────────────
                        Row(children: [
                          Container(
                            width: 3,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _indigo,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Quick Actions",
                            style: TextStyle(
                              color: _textPri,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // ── Action Cards ─────────────────────
                        _ActionCard(
                          title: "Add Single Staff",
                          subtitle:
                          "Manually create individual staff account",
                          icon: Icons.person_add_alt_1_rounded,
                          accentColor: _indigo,
                          badgeLabel: "MANUAL",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                const AddSingleStaffPage()),
                          ).then((_) => fetchStats()),
                        ),

                        const SizedBox(height: 14),

                        _ActionCard(
                          title: "Bulk Upload Staff",
                          subtitle:
                          "Upload multiple staff using Excel file",
                          icon: Icons.upload_file_rounded,
                          accentColor: _teal,
                          badgeLabel: "EXCEL",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                const AddBulkStaffPage()),
                          ).then((_) => fetchStats()),
                        ),

                        const SizedBox(height: 14),

                        _ActionCard(
                          title: "Manage Staff",
                          subtitle:
                          "View, filter and delete staff members",
                          icon: Icons.manage_accounts_rounded,
                          accentColor: _coral,
                          badgeLabel: "MANAGE",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StaffPage()),
                          ).then((_) => fetchStats()),
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

  static const Color _card       = Color(0xFF151E30);
  static const Color _textSec    = Color(0xFF7A8DB0);

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
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.09),
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
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
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
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _textSec,
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
  late AnimationController _pressCtrl;

  static const Color _card       = Color(0xFF151E30);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pressCtrl,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.reverse(),
        onTapUp: (_) {
          _pressCtrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.forward(),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border:
            Border.all(color: widget.accentColor.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accentColor.withOpacity(0.26),
                      widget.accentColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: widget.accentColor.withOpacity(0.32)),
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
                        Flexible(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: _textPri,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
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
                    const SizedBox(height: 5),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: _textSec,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

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