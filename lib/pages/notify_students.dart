import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotifyStudentsPage extends StatefulWidget {
  const NotifyStudentsPage({super.key});

  @override
  State<NotifyStudentsPage> createState() => _NotifyStudentsPageState();
}

class _NotifyStudentsPageState extends State<NotifyStudentsPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String academicYear = DateTime.now().year.toString();

  List<Map<String, dynamic>> unpaidStudents = [];
  bool isLoading    = true;
  bool isSendingAll = false;

  int totalClasses  = 0;
  int totalStudents = 0;
  int overdueCount  = 0;
  int upcomingCount = 0;

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
    fetchUnpaidStudents();
  }

  @override
  void dispose() {
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ────────────────────────────────────────────
  String formatDate(Timestamp timestamp) {
    final d = timestamp.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }

  Future<void> fetchUnpaidStudents() async {
    setState(() => isLoading = true);
    List<Map<String, dynamic>> tempList = [];
    int classCount = 0, studentCount = 0, overdue = 0, upcoming = 0;

    try {
      final classesSnapshot = await _firestore.collection("Student_Of_College").get();
      classCount = classesSnapshot.docs.length;

      for (var classDoc in classesSnapshot.docs) {
        final classData = classDoc.data() as Map<String, dynamic>;
        final className = "${classData['course'] ?? ''} ${classData['department'] ?? ''}".trim();
        final studentsSnapshot = await classDoc.reference.collection("students").get();
        studentCount += studentsSnapshot.docs.length;

        for (var student in studentsSnapshot.docs) {
          final studentData = student.data() as Map<String, dynamic>;
          final feeDoc = await student.reference.collection("fees").doc(academicYear).get();
          if (!feeDoc.exists) continue;
          final data = feeDoc.data();
          if (data == null) continue;

          DateTime now = DateTime.now();
          for (var entry in data.entries) {
            String fieldName = entry.key;
            var value = entry.value;
            if (value is Map<String, dynamic>) {
              Timestamp? deadline = value['deadline'];
              if (deadline == null) continue;
              DateTime deadlineDate = deadline.toDate();
              DateTime reminderStart = deadlineDate.subtract(const Duration(days: 10));
              if (now.isAfter(reminderStart)) {
                bool firstHalf  = value['firstHalf']  ?? false;
                bool secondHalf = value['secondHalf'] ?? false;
                if (!firstHalf || !secondHalf) {
                  final reminderDocId = "${student.id}_${fieldName}_$academicYear";
                  final reminderDoc   = await _firestore.collection("feesnotify").doc(reminderDocId).get();
                  bool alreadySent    = reminderDoc.exists;
                  final daysRemaining = deadlineDate.difference(now).inDays;
                  if (daysRemaining < 0) overdue++; else upcoming++;
                  tempList.add({
                    "studentId":   student.id,
                    "studentName": "${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}".trim(),
                    "semester":    fieldName,
                    "deadline":    deadline,
                    "alreadySent": alreadySent,
                    "className":   className,
                    "classId":     classDoc.id,
                    "course":      classData['course']      ?? '',
                    "department":  classData['department']  ?? '',
                    "daysRemaining": daysRemaining,
                  });
                }
              }
            }
          }
        }
      }
      tempList.sort((a, b) => (a['daysRemaining'] ?? 0).compareTo(b['daysRemaining'] ?? 0));
    } catch (e) {
      if (mounted) _snack("Error loading students: $e", _coral, Icons.error_rounded);
    }

    setState(() {
      unpaidStudents = tempList;
      totalClasses   = classCount;
      totalStudents  = studentCount;
      overdueCount   = overdue;
      upcomingCount  = upcoming;
      isLoading      = false;
    });
  }

  Future<void> sendReminder(String studentId, String studentName, String semester,
      Timestamp deadline, String className, String course, String department) async {
    try {
      final now           = DateTime.now();
      final deadlineDate  = deadline.toDate();
      final daysRemaining = deadlineDate.difference(now).inDays;
      final docId         = "${studentId}_${semester}_$academicYear";
      final docRef        = _firestore.collection("feesnotify").doc(docId);
      final existingDoc   = await docRef.get();
      if (existingDoc.exists) return;
      String message;
      if (daysRemaining < 0) {
        message = "Dear $studentName, your $semester fees was due on ${formatDate(deadline)}. Please pay immediately.";
      } else if (daysRemaining <= 3) {
        message = "URGENT: Dear $studentName, your $semester fees is due in $daysRemaining days (${formatDate(deadline)}).";
      } else {
        message = "Dear $studentName, please pay your $semester fees before ${formatDate(deadline)}. $daysRemaining days remaining.";
      }
      await docRef.set({
        "studentId": studentId, "studentName": studentName, "year": academicYear,
        "semester": semester, "course": course, "department": department,
        "className": className,
        "title":   daysRemaining < 0 ? "⚠️ Overdue Fees Reminder" : "Fees Reminder",
        "message": message, "deadline": deadline, "daysRemaining": daysRemaining,
        "status": daysRemaining < 0 ? "overdue" : "pending",
        "createdAt": Timestamp.now(), "sentVia": "manual",
      });
    } catch (e) { rethrow; }
  }

  Future<void> sendReminderToAll() async {
    if (unpaidStudents.isEmpty) return;
    final confirm = await _showConfirmDialog();
    if (confirm != true) return;

    setState(() => isSendingAll = true);
    int successCount = 0, failCount = 0, skippedCount = 0;

    _showProgressDialog("0/${unpaidStudents.length}");

    for (int i = 0; i < unpaidStudents.length; i++) {
      final student = unpaidStudents[i];
      if (student['alreadySent'] == true) { skippedCount++; continue; }
      try {
        await sendReminder(student['studentId'], student['studentName'],
            student['semester'], student['deadline'],
            student['className'] ?? '', student['course'] ?? '', student['department'] ?? '');
        setState(() => student['alreadySent'] = true);
        successCount++;
      } catch (e) { failCount++; }
      if (i % 10 == 0 && i > 0) {
        Navigator.pop(context);
        _showProgressDialog("$i/${unpaidStudents.length}");
      }
    }
    Navigator.pop(context);
    setState(() => isSendingAll = false);
    if (mounted) {
      _snack("Sent: $successCount | Skipped: $skippedCount | Failed: $failCount",
          successCount > 0 ? _green : _gold,
          successCount > 0 ? Icons.check_circle_rounded : Icons.info_rounded);
    }
  }

  Future<bool?> _showConfirmDialog() {
    final newCount      = unpaidStudents.where((s) => s['alreadySent'] == false).length;
    final sentCount     = unpaidStudents.where((s) => s['alreadySent'] == true).length;
    return showDialog<bool>(
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
                  child: const Icon(Icons.campaign_rounded, color: _gold, size: 22)),
              const SizedBox(width: 14),
              const Text("Send to All?", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
                child: Column(children: [
                  _dialogRow(Icons.people_rounded,      "Total",   "${unpaidStudents.length}", _teal),
                  const SizedBox(height: 8),
                  _dialogRow(Icons.send_rounded,         "New",     "$newCount",  _green),
                  const SizedBox(height: 8),
                  _dialogRow(Icons.check_circle_rounded, "Sent",   "$sentCount", _textSec),
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
                      decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: const Text("Send All", style: TextStyle(color: _bg, fontWeight: FontWeight.w700))))),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showProgressDialog(String progress) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 52, height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: _teal.withOpacity(0.3), width: 1.5),
                      gradient: RadialGradient(colors: [_teal.withOpacity(0.15), Colors.transparent])),
                  child: Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5, backgroundColor: _teal.withOpacity(0.1)))),
              const SizedBox(height: 16),
              const Text("Sending reminders...", style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(progress, style: const TextStyle(color: _textSec, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dialogRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: _textSec, fontSize: 13)),
      const Spacer(),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
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

  String _getFeeAmount(String semester) => "15,000";

  Color _getStatusColor(int days) {
    if (days < 0)  return _coral;
    if (days <= 3) return const Color(0xFFFF8C42);
    if (days <= 7) return _gold;
    return _green;
  }

  String _getStatusText(int days) {
    if (days < 0)  return "Overdue";
    if (days == 0) return "Due Today";
    if (days == 1) return "Due Tomorrow";
    return "$days days left";
  }

  Color _getSemColor(String semester) {
    final n = int.tryParse(semester.replaceAll("sem", "")) ?? 1;
    const colors = [_teal, _green, _gold, _indigo, _coral, _rose];
    return colors[(n - 1) % colors.length];
  }

  Widget _orb(double size, Color color, double opacity) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent])));

  // ── Build ────────────────────────────────────────────────────────
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
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 16))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Fee Reminders", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
                Text(isLoading ? "Loading..." : "$totalClasses Classes • $totalStudents Students",
                    style: const TextStyle(color: _textSec, fontSize: 11)),
              ])),
              // Year badge
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _indigo.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _indigo.withOpacity(0.25))),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, color: _indigo, size: 12),
                    const SizedBox(width: 5),
                    Text(academicYear, style: const TextStyle(color: _indigo, fontSize: 11, fontWeight: FontWeight.w700)),
                  ])),
              const SizedBox(width: 8),
              // Send all button
              if (!isLoading && unpaidStudents.isNotEmpty)
                GestureDetector(
                    onTap: (isSendingAll || unpaidStudents.isEmpty) ? null : sendReminderToAll,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: isSendingAll ? _cardBorder : _coral.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSendingAll ? _cardBorder : _coral.withOpacity(0.3))),
                          child: isSendingAll
                              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _coral, strokeWidth: 2, backgroundColor: _coral.withOpacity(0.1)))
                              : const Icon(Icons.campaign_rounded, color: _coral, size: 18)),
                      if (!isSendingAll)
                        Positioned(top: -4, right: -4,
                            child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: _coral, shape: BoxShape.circle),
                                child: Text("${unpaidStudents.where((s) => s['alreadySent'] == false).length}",
                                    style: const TextStyle(color: _bg, fontSize: 7, fontWeight: FontWeight.w800)))),
                    ])),
            ]),
          ),

          // Body
          Expanded(child: isLoading
              ? _buildLoading()
              : unpaidStudents.isEmpty
              ? _buildEmpty()
              : Column(children: [
            // Stats card
            _buildStatsCard(),
            // List
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: unpaidStudents.length,
              itemBuilder: (_, i) => _buildStudentCard(unpaidStudents[i], i),
            )),
          ])),
        ])),
      ]),
    );
  }

  Widget _buildLoading() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 56, height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _teal.withOpacity(0.3), width: 1.5),
            gradient: RadialGradient(colors: [_teal.withOpacity(0.15), Colors.transparent])),
        child: Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5, backgroundColor: _teal.withOpacity(0.1)))),
    const SizedBox(height: 18),
    const Text("Loading dashboard...", style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    const Text("Checking all classes for fees", style: TextStyle(color: _textSec, fontSize: 12)),
  ]));

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: _card, shape: BoxShape.circle, border: Border.all(color: _green.withOpacity(0.3))),
          child: const Icon(Icons.check_circle_rounded, size: 48, color: _green)),
      const SizedBox(height: 20),
      const Text("All Clear!", style: TextStyle(color: _textPri, fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text("No pending fee reminders", style: TextStyle(color: _textSec, fontSize: 14)),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorder)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _statPill("$totalClasses", "Classes", _indigo),
            Container(width: 1, height: 36, color: _cardBorder),
            _statPill("$totalStudents", "Students", _teal),
          ])),
    ]),
  ));

  Widget _statPill(String value, String label, Color color) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: _textSec, fontSize: 12)),
  ]);

  Widget _buildStatsCard() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _coral.withOpacity(0.2)),
      boxShadow: [BoxShadow(color: _coral.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Column(children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: _coral.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _coral.withOpacity(0.25))),
            child: const Icon(Icons.notifications_active_rounded, color: _coral, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Pending Reminders", style: TextStyle(color: _textSec, fontSize: 12)),
          Text("${unpaidStudents.length} student${unpaidStudents.length > 1 ? 's' : ''} need notification",
              style: const TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w700)),
        ])),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _statChip("Overdue", "$overdueCount", _coral, Icons.warning_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _statChip("Upcoming", "$upcomingCount", _gold, Icons.access_time_rounded)),
      ]),
    ]),
  );

  Widget _statChip(String label, String count, Color color, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text("$label: $count", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]));

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final semColor      = _getSemColor(student['semester']);
    final daysRemaining = student['daysRemaining'] ?? 0;
    final statusColor   = _getStatusColor(daysRemaining);
    final statusText    = _getStatusText(daysRemaining);
    final alreadySent   = student['alreadySent'] == true;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutQuad,
      builder: (_, v, child) => Transform.translate(offset: Offset(0, 16 * (1 - v)), child: Opacity(opacity: v, child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: daysRemaining < 0 ? _coral.withOpacity(0.3) : _cardBorder),
          boxShadow: [BoxShadow(color: semColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Semester badge
            Container(width: 46, height: 46,
                decoration: BoxDecoration(color: semColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: semColor.withOpacity(0.3))),
                alignment: Alignment.center,
                child: Text(student['semester'].replaceAll("sem", ""),
                    style: TextStyle(color: semColor, fontSize: 16, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(student['studentName'],
                    style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 4),
              Text(student['className'] ?? '', style: const TextStyle(color: _textSec, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                _chip(student['semester'].toString().toUpperCase(), semColor),
                if (alreadySent) ...[const SizedBox(width: 8), _chip("✓ Sent", _green)],
              ]),
            ])),
          ]),
          const SizedBox(height: 12),
          // Deadline row
          Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
              child: Row(children: [
                Icon(Icons.access_time_rounded, size: 15, color: statusColor),
                const SizedBox(width: 8),
                Expanded(child: Text("Deadline: ${formatDate(student['deadline'])}",
                    style: const TextStyle(color: _textSec, fontSize: 12))),
                Text("₹${_getFeeAmount(student['semester'])}",
                    style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w700)),
              ])),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)));
}

// ── Dot painter ───────────────────────────────────────────────────
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