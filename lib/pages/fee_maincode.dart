import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'fees_structure.dart';
import 'view_students_paid_his.dart';
import 'notify_students.dart';
import 'view_fees_structure.dart';
import 'set_deadline.dart';
import 'paid_unpaid.dart';

class FeeMainPage extends StatefulWidget {
  const FeeMainPage({super.key});

  @override
  State<FeeMainPage> createState() => _FeeMainPageState();
}

class _FeeMainPageState extends State<FeeMainPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double totalAmount   = 0;
  double paidAmount    = 0;
  double pendingAmount = 0;
  String dueDate       = "No Deadline";
  Timestamp? latestDeadline;

  int totalClasses     = 0;
  int totalStudents    = 0;
  int pendingReminders = 0;
  int overdueCount     = 0;

  bool isLoading = true;
  String? errorMessage;

  final DateFormat _dateFormat     = DateFormat('dd MMM yyyy');
  final DateFormat _fullDateFormat = DateFormat('EEEE, dd MMM yyyy');

  // ── Design tokens ───────────────────────────────────────────────
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

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _orb1Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _orb2Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _orb1Anim  = Tween<double>(begin: 0, end: 26).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim  = Tween<double>(begin: 0, end: 20).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));

    fetchDashboardData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    super.dispose();
  }

  // ── FIXED fetchDashboardData ─────────────────────────────────────
  Future<void> fetchDashboardData() async {
    setState(() {
      isLoading    = true;
      errorMessage = null;
    });

    double total = 0, paid = 0;
    Timestamp? latestDeadlineTemp;
    int classCount = 0, studentCount = 0, reminderCount = 0, overdue = 0;

    try {
      final classesSnapshot =
      await _firestore.collection("Student_Of_College").get();
      classCount = classesSnapshot.docs.length;

      if (classCount == 0) {
        setState(() {
          totalClasses     = 0;
          totalStudents    = 0;
          totalAmount      = 0;
          paidAmount       = 0;
          pendingAmount    = 0;
          dueDate          = "No Deadline";
          latestDeadline   = null;
          pendingReminders = 0;
          overdueCount     = 0;
          isLoading        = false;
        });
        _fadeCtrl.forward();
        _slideCtrl.forward();
        return;
      }

      for (var classDoc in classesSnapshot.docs) {
        final studentsSnapshot =
        await classDoc.reference.collection("students").get();
        studentCount += studentsSnapshot.docs.length;

        for (var student in studentsSnapshot.docs) {
          double studentTotalFee = 0;
          double studentPaidFee  = 0;
          Timestamp? studentDeadline;

          // fees is a sub-collection: students/{id}/fees/{year}
          final feesYearSnapshot =
          await student.reference.collection("fees").get();

          for (var yearDoc in feesYearSnapshot.docs) {
            final yearData = yearDoc.data();

            // Iterate over each semester key (sem1, sem2, …)
            yearData.forEach((key, value) {
              if (key.startsWith('sem') && value is Map) {
                final semMap = Map<String, dynamic>.from(value);

                // Amounts stored inside the student's fees doc
                final rawAmount = semMap['amount'];
                double firstHalfAmt  = 0;
                double secondHalfAmt = 0;

                if (rawAmount != null && rawAmount is Map) {
                  final amountMap = Map<String, dynamic>.from(rawAmount);
                  firstHalfAmt  = (amountMap['firstHalf']  as num?)?.toDouble() ?? 0;
                  secondHalfAmt = (amountMap['secondHalf'] as num?)?.toDouble() ?? 0;
                }

                final bool firstHalfPaid  = semMap['firstHalf']  as bool? ?? false;
                final bool secondHalfPaid = semMap['secondHalf'] as bool? ?? false;

                studentTotalFee += firstHalfAmt + secondHalfAmt;
                if (firstHalfPaid)  studentPaidFee += firstHalfAmt;
                if (secondHalfPaid) studentPaidFee += secondHalfAmt;

                // Track the latest non-null deadline
                final deadlineRaw = semMap['deadline'];
                if (deadlineRaw != null && deadlineRaw is Timestamp) {
                  if (studentDeadline == null ||
                      deadlineRaw.compareTo(studentDeadline!) > 0) {
                    studentDeadline = deadlineRaw;
                  }
                  if (latestDeadlineTemp == null ||
                      deadlineRaw.compareTo(latestDeadlineTemp!) > 0) {
                    latestDeadlineTemp = deadlineRaw;
                  }
                }
              }
            });
          }

          total += studentTotalFee;
          paid  += studentPaidFee;

          // Reminder logic
          if (studentDeadline != null) {
            final daysRemaining =
                studentDeadline!.toDate().difference(DateTime.now()).inDays;
            if (daysRemaining < 0) {
              overdue++;
            } else if (daysRemaining <= 10) {
              reminderCount++;
            }
          } else if (studentTotalFee > studentPaidFee) {
            reminderCount++;
          }
        }
      }

      String formattedDate = "No Deadline";
      if (latestDeadlineTemp != null) {
        formattedDate = _dateFormat.format(latestDeadlineTemp!.toDate());
      }

      setState(() {
        totalAmount      = total;
        paidAmount       = paid;
        pendingAmount    = total - paid;
        latestDeadline   = latestDeadlineTemp;
        dueDate          = formattedDate;
        totalClasses     = classCount;
        totalStudents    = studentCount;
        pendingReminders = reminderCount;
        overdueCount     = overdue;
        isLoading        = false;
      });

      _fadeCtrl.forward();
      _slideCtrl.forward();

      debugPrint('=== Fee Summary ===');
      debugPrint('Total Classes: $classCount');
      debugPrint('Total Students: $studentCount');
      debugPrint('Total Fee: ₹$total');
      debugPrint('Paid Fee: ₹$paid');
      debugPrint('Pending Fee: ₹${total - paid}');
      debugPrint('Pending Reminders: $reminderCount');
      debugPrint('Overdue: $overdue');
      debugPrint('==================');
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
      setState(() {
        isLoading    = false;
        errorMessage = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading data: ${e.toString()}"),
            backgroundColor: _coral,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getDaysUntilDeadline() {
    if (latestDeadline == null) return "No deadline set";
    final daysRemaining =
        latestDeadline!.toDate().difference(DateTime.now()).inDays;
    if      (daysRemaining < 0)  return "Overdue by ${daysRemaining.abs()} days";
    else if (daysRemaining == 0) return "Due today";
    else if (daysRemaining == 1) return "Due tomorrow";
    else                         return "$daysRemaining days remaining";
  }

  Color _getDeadlineColor() {
    if (latestDeadline == null) return _textSec;
    final daysRemaining =
        latestDeadline!.toDate().difference(DateTime.now()).inDays;
    if      (daysRemaining < 0)  return _coral;
    else if (daysRemaining <= 3) return const Color(0xFFFF8C42);
    else if (daysRemaining <= 7) return _gold;
    else                         return _green;
  }

  @override
  Widget build(BuildContext context) {
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

            // AppBar
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
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Fee Management",
                            style: TextStyle(
                                color: _textPri,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text(
                          isLoading ? "Updating..." : "Real-time dashboard",
                          style: const TextStyle(color: _textSec, fontSize: 11),
                        ),
                      ]),
                ),
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () {
                    _fadeCtrl.reset();
                    _slideCtrl.reset();
                    fetchDashboardData();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Icon(
                      isLoading
                          ? Icons.hourglass_empty_rounded
                          : Icons.refresh_rounded,
                      color: _textSec,
                      size: 18,
                    ),
                  ),
                ),
              ]),
            ),

            // Body
            Expanded(
              child: isLoading
                  ? _buildLoadingShimmer()
                  : errorMessage != null
                  ? _buildErrorWidget()
                  : RefreshIndicator(
                color: _teal,
                backgroundColor: _card,
                onRefresh: fetchDashboardData,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [

                        // Summary card
                        _buildSummaryCard(),
                        const SizedBox(height: 20),

                        // Mini stat row
                        Row(children: [
                          Expanded(
                              child: _MiniStatCard(
                                label: "Total Fees",
                                value: "₹${totalAmount.toStringAsFixed(0)}",
                                icon: Icons.account_balance_wallet_rounded,
                                color: _indigo,
                              )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _MiniStatCard(
                                label: "Collected",
                                value: "₹${paidAmount.toStringAsFixed(0)}",
                                icon: Icons.check_circle_rounded,
                                color: _green,
                                progress: totalAmount > 0
                                    ? paidAmount / totalAmount
                                    : 0,
                              )),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: _MiniStatCard(
                                label: "Pending",
                                value: "₹${pendingAmount.toStringAsFixed(0)}",
                                icon: Icons.pending_actions_rounded,
                                color: _coral,
                                subtitle: "$pendingReminders nearing deadline",
                              )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _MiniStatCard(
                                label: "Deadline",
                                value: dueDate,
                                icon: Icons.calendar_month_rounded,
                                color: _getDeadlineColor(),
                                subtitle: _getDaysUntilDeadline(),
                                smallValue: true,
                              )),
                        ]),

                        const SizedBox(height: 28),

                        // Section label
                        Row(children: [
                          Container(
                            width: 3,
                            height: 20,
                            decoration: BoxDecoration(
                                color: _teal,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 10),
                          const Text("Quick Actions",
                              style: TextStyle(
                                  color: _textPri,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                          const Spacer(),
                          if (pendingReminders > 0 || overdueCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _coral.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _coral.withOpacity(0.25)),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                          color: _coral,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${pendingReminders + overdueCount} pending",
                                      style: const TextStyle(
                                          color: _coral,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ]),
                            ),
                        ]),

                        const SizedBox(height: 14),

                        // Nav buttons
                        _NavCard(
                          title: "Create Fees Structure",
                          subtitle: "Set academic fees, semester charges",
                          icon: Icons.account_balance_wallet_rounded,
                          accentColor: _indigo,
                          badge: "NEW",
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const FeesStructurePage()));
                            fetchDashboardData();
                          },
                        ),
                        const SizedBox(height: 12),
                        _NavCard(
                          title: "View & Update Fees",
                          subtitle: "Track department-wise payments",
                          icon: Icons.people_alt_rounded,
                          accentColor: _green,
                          badge: "ACTIVE",
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const ViewStudentsPaidPage()));
                            fetchDashboardData();
                          },
                        ),
                        _NavCard(
                          title: "Paid / Unpaid Status",
                          subtitle: "Admin view — all student payment status",
                          icon: Icons.people_alt_rounded,
                          accentColor: _teal,
                          badge: "ADMIN",
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PaidUnpaidStudentsPage()),
                            );
                            fetchDashboardData();
                          },
                        ),
                        const SizedBox(height: 12),
                        _NavCard(
                          title: "View Fees Structure",
                          subtitle: "Review academic year structures",
                          icon: Icons.visibility_rounded,
                          accentColor: _coral,
                          badge: "VIEW",
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const ViewFeesStructurePage()));
                            fetchDashboardData();
                          },
                        ),
                        const SizedBox(height: 12),
                        _NavCard(
                          title: "Notify Unpaid Students",
                          subtitle: "Send reminders for pending dues",
                          icon: Icons.notifications_active_rounded,
                          accentColor: _gold,
                          badge: "REMIND",
                          badgeCount: pendingReminders + overdueCount,
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const NotifyStudentsPage()));
                            fetchDashboardData();
                          },
                        ),
                        const SizedBox(height: 12),
                        _NavCard(
                          title: "Set Deadline",
                          subtitle: "Configure payment deadlines",
                          icon: Icons.calendar_month_rounded,
                          accentColor: _rose,
                          badge: dueDate == "No Deadline"
                              ? "SET"
                              : "UPDATE",
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const SetDeadlinePage()));
                            fetchDashboardData();
                          },
                        ),

                        const SizedBox(height: 24),

                        // Last updated
                        Text(
                          "Last updated: ${DateFormat('hh:mm a').format(DateTime.now())}",
                          style: const TextStyle(
                              color: _textSec, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: _coral, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              "Failed to Load Data",
              style: TextStyle(
                  color: _textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ?? "Unknown error occurred",
              style: const TextStyle(color: _textSec, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            GestureDetector(
              onTap: fetchDashboardData,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                decoration: BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "Try Again",
                  style: TextStyle(
                      color: _bg, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _teal.withOpacity(0.3), width: 1.5),
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
        const SizedBox(height: 20),
        const Text("Loading dashboard...",
            style: TextStyle(
                color: _textPri,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text("Fetching real-time data",
            style: TextStyle(color: _textSec, fontSize: 12)),
      ]),
    );
  }

  Widget _buildSummaryCard() {
    final progress = totalAmount > 0 ? paidAmount / totalAmount : 0.0;
    final deadlineColor = _getDeadlineColor();

    return Container(
      padding: const EdgeInsets.all(22),
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
      child: Column(children: [
        // Header row
        Row(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _teal.withOpacity(0.25)),
            ),
            child: const Icon(Icons.analytics_rounded, color: _teal, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Fee Overview",
                      style: TextStyle(
                          color: _textPri,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const Text("Current Academic Year",
                      style: TextStyle(color: _textSec, fontSize: 11)),
                ]),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: deadlineColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: deadlineColor.withOpacity(0.3)),
            ),
            child: Text(
              _getDaysUntilDeadline(),
              style: TextStyle(
                  color: deadlineColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        // Progress bar
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Collection Progress",
                style: TextStyle(color: _textSec, fontSize: 12)),
            Text(
              "${(progress * 100).toInt()}%",
              style: const TextStyle(
                  color: _textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _cardBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(_teal),
              minHeight: 8,
            ),
          ),
        ]),

        const SizedBox(height: 20),

        // Stats row
        Row(children: [
          _summaryItem("Classes", "$totalClasses"),
          _vDivider(),
          _summaryItem("Students", "$totalStudents"),
          _vDivider(),
          _summaryItem("Pending",
              "₹${pendingAmount.toStringAsFixed(0)}",
              valueColor: _coral),
        ]),
      ]),
    );
  }

  Widget _summaryItem(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: _textSec, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: valueColor ?? _textPri,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: _cardBorder,
  );

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

// ── Mini Stat Card ───────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;
  final String? subtitle;
  final bool smallValue;

  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _textSec    = Color(0xFF7A8DB0);
  static const Color _textPri    = Color(0xFFEEF2FF);

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.progress,
    this.subtitle,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          if (progress != null)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${(progress! * 100).toInt()}%",
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(
                color: _textSec,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: smallValue ? 13 : 18,
            fontWeight: FontWeight.w800,
            letterSpacing: smallValue ? 0 : -0.5,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!,
              style: const TextStyle(color: _textSec, fontSize: 10),
              overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}

// ── Nav Card ─────────────────────────────────────────────────────
class _NavCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String badge;
  final int? badgeCount;
  final VoidCallback onTap;

  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.badge,
    required this.onTap,
    this.badgeCount,
  });

  @override
  State<_NavCard> createState() => _NavCardState();
}

class _NavCardState extends State<_NavCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);
  static const Color _coral      = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasBadgeCount =
        widget.badgeCount != null && widget.badgeCount! > 0;

    return ScaleTransition(
      scale: _ctrl,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border:
            Border.all(color: widget.accentColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: widget.accentColor.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(children: [
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accentColor.withOpacity(0.24),
                    widget.accentColor.withOpacity(0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: widget.accentColor.withOpacity(0.3)),
              ),
              child: Icon(widget.icon,
                  color: widget.accentColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(widget.title,
                            style: const TextStyle(
                                color: _textPri,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasBadgeCount
                              ? _coral.withOpacity(0.15)
                              : widget.accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasBadgeCount) ...[
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                      color: _coral,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                hasBadgeCount
                                    ? "${widget.badgeCount}"
                                    : widget.badge,
                                style: TextStyle(
                                  color: hasBadgeCount
                                      ? _coral
                                      : widget.accentColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ]),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(widget.subtitle,
                        style: const TextStyle(
                            color: _textSec,
                            fontSize: 11,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            const SizedBox(width: 10),

            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  color: widget.accentColor, size: 13),
            ),
          ]),
        ),
      ),
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