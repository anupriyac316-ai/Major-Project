import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Firestore paths used:
//
//  settings/dayOrder                          → current day order string
//  attendance/{className}/{date}/{hour_doc}   → actual attendance
//  Student_Of_College/{className}             → class registry
//  staff_of_college/{dept}/years/{year}/semesters/{sem}/timetable/schedule
//                                             → timetable for that class
//
//  Missing staff logic:
//    1. Get today's day order (e.g. "III")
//    2. For each known class, find its dept/year/sem from className string
//    3. Read timetable → get periods for that day order
//    4. Extract expected staff names from period strings like "Python (Riya J)"
//    5. Compare with staff who actually submitted attendance
//    6. Diff = missing staff
// ─────────────────────────────────────────────────────────────────────────────

// ── Models ────────────────────────────────────────────────────────────────────

class HourEntry {
  final String className;
  final String subject;
  final String staffName;
  final String department;
  final String periodTime;
  final String dayOrder;
  final int hour;
  final int total;
  final List<String> present;
  final List<String> absent;
  final Timestamp? timestamp;

  HourEntry({
    required this.className,
    required this.subject,
    required this.staffName,
    required this.department,
    required this.periodTime,
    required this.dayOrder,
    required this.hour,
    required this.total,
    required this.present,
    required this.absent,
    this.timestamp,
  });

  int get presentCount => present.length;
  int get absentCount  => absent.length;
  double get pct       => total > 0 ? presentCount / total : 0.0;
}

/// Represents one period that was scheduled but has NO attendance record.
class MissingPeriod {
  final int    period;
  final String subject;
  final String staffName;

  const MissingPeriod({
    required this.period,
    required this.subject,
    required this.staffName,
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────

class AdminAttendanceMonitorPage extends StatefulWidget {
  const AdminAttendanceMonitorPage({super.key});

  @override
  State<AdminAttendanceMonitorPage> createState() =>
      _AdminAttendanceMonitorPageState();
}

class _AdminAttendanceMonitorPageState
    extends State<AdminAttendanceMonitorPage> with TickerProviderStateMixin {

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Design tokens ────────────────────────────────────────────────────────
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

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _orb1Ctrl, _orb2Ctrl, _fadeCtrl, _slideCtrl;
  late Animation<double>   _orb1Anim, _orb2Anim, _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  bool     _isLoading    = true;
  String?  _error;

  String _currentDayOrder = '';

  /// className → sorted list of attended hours
  Map<String, List<HourEntry>> _classGroups = {};

  /// className → list of periods that have no attendance record
  Map<String, List<MissingPeriod>> _missingByClass = {};

  Set<String> _expandedClasses = {};

  final DateFormat _dateLabel   = DateFormat('dd MMM yyyy');
  final DateFormat _docIdFormat = DateFormat('yyyy-MM-dd');

  // ── Init / dispose ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _orb1Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _orb2Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _orb1Anim  = Tween<double>(begin: 0, end: 26).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim  = Tween<double>(begin: 0, end: 20).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fetchAll();
  }

  @override
  void dispose() {
    _orb1Ctrl.dispose(); _orb2Ctrl.dispose();
    _fadeCtrl.dispose(); _slideCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN FETCH
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchAll() async {
    setState(() { _isLoading = true; _error = null; });
    _fadeCtrl.reset(); _slideCtrl.reset();

    try {
      // 1. Day order
      final dayOrderDoc = await _db.collection('settings').doc('dayOrder').get();
      final dayOrder = dayOrderDoc.exists
          ? (dayOrderDoc.data()?['current'] as String? ?? '')
          : '';

      // 2. Attendance records
      final dateId = _docIdFormat.format(_selectedDate);
      final Map<String, List<HourEntry>> classMap = {};

      bool used = false;
      try {
        final snap = await _db.collectionGroup(dateId).get();
        if (snap.docs.isNotEmpty) {
          used = true;
          for (final doc in snap.docs) {
            final segs      = doc.reference.path.split('/');
            final className = segs.length >= 2 ? segs[1] : '—';
            final entry     = _parseDoc(doc.data(), className);
            classMap.putIfAbsent(className, () => []).add(entry);
          }
        }
      } catch (e) {
        debugPrint('collectionGroup failed: $e');
      }

      if (!used) {
        final classIds = <String>{};
        try {
          final s = await _db.collection('attendance').get();
          classIds.addAll(s.docs.map((d) => d.id));
        } catch (_) {}
        try {
          final s = await _db.collection('Student_Of_College').get();
          classIds.addAll(s.docs.map((d) => d.id));
        } catch (_) {}

        for (final className in classIds) {
          final hourSnaps = await _db
              .collection('attendance')
              .doc(className)
              .collection(dateId)
              .get();
          for (final doc in hourSnaps.docs) {
            final entry = _parseDoc(doc.data(), className);
            classMap.putIfAbsent(className, () => []).add(entry);
          }
        }
      }

      for (final list in classMap.values) {
        list.sort((a, b) => a.hour.compareTo(b.hour));
      }

      // 3. Missing staff — only meaningful for today's date
      final Map<String, List<MissingPeriod>> missingMap = {};
      final isToday = _isToday(_selectedDate);

      if (dayOrder.isNotEmpty) {
        // Get all known classes (from attendance records + Student_Of_College)
        final allClassIds = classMap.keys.toSet();
        try {
          final s = await _db.collection('Student_Of_College').get();
          allClassIds.addAll(s.docs.map((d) => d.id));
        } catch (_) {}

        for (final className in allClassIds) {
          final missing = await _computeMissingPeriods(
            className: className,
            dayOrder:  dayOrder,
            attendedEntries: classMap[className] ?? [],
          );
          if (missing.isNotEmpty) {
            missingMap[className] = missing;
          }
        }
      }

      final sorted = Map.fromEntries(
          classMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));

      // Also add classes that only appear in missing (no attendance at all)
      for (final cn in missingMap.keys) {
        sorted.putIfAbsent(cn, () => []);
      }

      setState(() {
        _currentDayOrder = dayOrder;
        _classGroups     = sorted;
        _missingByClass  = missingMap;
        _isLoading       = false;
        _expandedClasses = sorted.keys.toSet();
      });

      _fadeCtrl.forward(); _slideCtrl.forward();
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMPUTE MISSING PERIODS FOR A CLASS
  // Path: staff_of_college/{dept}/years/{year}/semesters/{sem}/timetable/schedule
  //
  // className format: "B.Sc_Computer Science_I_2026-2028"
  //   parts[0] = degree  (B.Sc)
  //   parts[1] = dept    (Computer Science)
  //   parts[2] = year    (I)
  //   parts[3] = batch   (2026-2028)
  //
  // Semester is derived from Student_Of_College doc (stored as field 'semester')
  // OR we try both sem 1&2 for year I, 3&4 for year II, 5&6 for year III.
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<MissingPeriod>> _computeMissingPeriods({
    required String className,
    required String dayOrder,
    required List<HourEntry> attendedEntries,
  }) async {
    try {
      final parts = className.split('_');
      if (parts.length < 3) return [];

      final dept = parts.length > 1 ? parts[1] : '';
      final year = parts.length > 2 ? parts[2] : '';
      if (dept.isEmpty || year.isEmpty) return [];

      // Determine which semesters to try based on year
      final semOptions = year == 'I'
          ? ['1', '2']
          : year == 'II'
          ? ['3', '4']
          : ['5', '6'];

      // Try to find the timetable in any matching semester
      Map<String, dynamic>? timetableMap;
      int? periods;

      for (final sem in semOptions) {
        try {
          final doc = await _db
              .collection('staff_of_college')
              .doc(dept)
              .collection('years')
              .doc(year)
              .collection('semesters')
              .doc(sem)
              .collection('timetable')
              .doc('schedule')
              .get();

          if (doc.exists) {
            final data = doc.data()!;
            final tt   = data['timetable'] as Map<String, dynamic>?;
            if (tt != null && tt.containsKey(dayOrder)) {
              timetableMap = tt[dayOrder] as Map<String, dynamic>;
              periods      = (data['periods'] as int?) ?? timetableMap.length;
              break;
            }
          }
        } catch (_) {}
      }

      if (timetableMap == null || periods == null) return [];

      // Build set of hours already attended (by period number)
      final attendedHours = attendedEntries.map((e) => e.hour).toSet();

      // Find periods not in attendance
      final List<MissingPeriod> missing = [];
      for (int p = 1; p <= periods; p++) {
        if (!attendedHours.contains(p)) {
          final raw = (timetableMap['P$p'] as String? ?? '').trim();
          if (raw.isEmpty) continue;

          // Parse "Subject (Staff Name)" format
          String subject   = raw;
          String staffName = '';
          if (raw.contains('(') && raw.endsWith(')')) {
            subject   = raw.substring(0, raw.lastIndexOf('(')).trim();
            staffName = raw.substring(
                raw.lastIndexOf('(') + 1, raw.length - 1).trim();
          }

          missing.add(MissingPeriod(
            period:    p,
            subject:   subject,
            staffName: staffName,
          ));
        }
      }
      return missing;
    } catch (e) {
      debugPrint('_computeMissingPeriods error for $className: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  HourEntry _parseDoc(Map<String, dynamic> d, String className) {
    final presentList = List<String>.from(d['present'] as List? ?? []);
    final absentList  = List<String>.from(d['absent']  as List? ?? []);
    int hourNum = 0;
    final rawHour = d['hour'];
    if (rawHour is int)         hourNum = rawHour;
    else if (rawHour is String) hourNum = int.tryParse(rawHour) ?? 0;
    final total = (d['total'] as int?) ??
        (presentList.length + absentList.length);
    return HourEntry(
      className:  className,
      subject:    d['subject']    as String? ?? '—',
      staffName:  d['staffName']  as String? ?? '—',
      department: d['department'] as String? ?? '—',
      periodTime: d['periodTime'] as String? ?? '—',
      dayOrder:   d['dayOrder']   as String? ?? '—',
      hour:       hourNum,
      total:      total,
      present:    presentList,
      absent:     absentList,
      timestamp:  d['timestamp']  as Timestamp?,
    );
  }

  Widget _orb(double size, Color color, double opacity) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color.withOpacity(opacity), Colors.transparent])));

  Color _attendanceColor(double pct) {
    if (pct >= 0.85) return _green;
    if (pct >= 0.60) return _gold;
    return _coral;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _ordinal(int n) {
    switch (n) {
      case 1:  return '1st';
      case 2:  return '2nd';
      case 3:  return '3rd';
      default: return '${n}th';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
              primary: _teal, surface: _card, onSurface: _textPri),
          dialogBackgroundColor: _card,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchAll();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isWeekend = _selectedDate.weekday == DateTime.saturday ||
        _selectedDate.weekday == DateTime.sunday;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        AnimatedBuilder(
          animation: Listenable.merge([_orb1Ctrl, _orb2Ctrl]),
          builder: (_, __) => Stack(children: [
            Positioned(top: -60 + _orb1Anim.value, right: -60,
                child: _orb(260, _teal, 0.13)),
            Positioned(bottom: 100 - _orb2Anim.value, left: -70,
                child: _orb(220, _indigo, 0.15)),
            Positioned.fill(child: CustomPaint(
                painter: _DotPainter(color: _teal.withOpacity(0.04)))),
          ]),
        ),

        SafeArea(child: Column(children: [

          // ── AppBar ──────────────────────────────────────────────────────
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
                          border: Border.all(color: _cardBorder)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _textPri, size: 16))),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Attendance Monitor",
                        style: TextStyle(color: _textPri,
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(_isLoading ? "Loading…" : "Admin view — read only",
                        style: const TextStyle(color: _textSec, fontSize: 11)),
                  ])),
              // Day order chip
              if (_currentDayOrder.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _indigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _indigo.withOpacity(0.3))),
                  child: Text("Day $_currentDayOrder",
                      style: const TextStyle(color: _indigo,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              GestureDetector(
                  onTap: _isLoading ? null : _fetchAll,
                  child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _cardBorder)),
                      child: Icon(
                          _isLoading
                              ? Icons.hourglass_empty_rounded
                              : Icons.refresh_rounded,
                          color: _textSec, size: 18))),
            ]),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(child: RefreshIndicator(
            color: _teal,
            backgroundColor: _card,
            onRefresh: _fetchAll,
            child: FadeTransition(opacity: _fadeAnim,
                child: SlideTransition(position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          _buildDateCard(isWeekend),
                          const SizedBox(height: 16),

                          if (_isLoading)
                            _buildShimmer()
                          else if (_error != null)
                            _buildErrorCard()
                          else if (isWeekend)
                              _buildWeekendCard()
                            else if (_classGroups.isEmpty &&
                                  _missingByClass.isEmpty)
                                _buildNoAttendanceCard()
                              else ...[
                                  ..._classGroups.entries.toList()
                                      .asMap()
                                      .entries
                                      .map((outer) => _buildClassAccordion(
                                      outer.value.key,
                                      outer.value.value,
                                      outer.key)),
                                ],

                          const SizedBox(height: 24),
                        ]),
                  ),
                )),
          )),
        ])),
      ]),
    );
  }

  // ── Date card ──────────────────────────────────────────────────────────────
  Widget _buildDateCard(bool isWeekend) {
    final today = _isToday(_selectedDate);
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _teal.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: _teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _teal.withOpacity(0.25))),
              child: const Icon(Icons.calendar_month_rounded,
                  color: _teal, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateLabel.format(_selectedDate),
                    style: const TextStyle(color: _textPri,
                        fontSize: 17, fontWeight: FontWeight.w700)),
                Text(today ? "Today"
                    : DateFormat('EEEE').format(_selectedDate),
                    style: const TextStyle(
                        color: _textSec, fontSize: 12)),
              ])),
          Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _teal.withOpacity(0.25))),
              child: const Row(children: [
                Icon(Icons.edit_calendar_rounded,
                    size: 12, color: _textSec),
                SizedBox(width: 5),
                Text("Change",
                    style: TextStyle(color: _textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ])),
        ]),
      ),
    );
  }

  // ── Class accordion ────────────────────────────────────────────────────────
  Widget _buildClassAccordion(
      String className, List<HourEntry> entries, int idx) {
    final isExpanded   = _expandedClasses.contains(className);
    final missingList  = _missingByClass[className] ?? [];

    final parts  = className.split('_');
    final degree = parts.isNotEmpty ? parts[0] : className;
    final dept   = parts.length > 1 ? parts[1] : '';
    final year   = parts.length > 2 ? parts[2] : '';
    final batch  = parts.length > 3 ? parts[3] : '';

    final classPresent = entries.fold(0, (s, e) => s + e.presentCount);
    final classAbsent  = entries.fold(0, (s, e) => s + e.absentCount);
    final classTotal   = entries.fold(0, (s, e) => s + e.total);
    final classPct     = classTotal > 0 ? classPresent / classTotal : 0.0;
    final classColor   = entries.isEmpty ? _coral : _attendanceColor(classPct);

    final hasMissing   = missingList.isNotEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + idx * 60),
      builder: (_, v, child) => Transform.translate(
          offset: Offset(0, 14 * (1 - v)),
          child: Opacity(opacity: v, child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: classColor.withOpacity(0.25)),
        ),
        child: Column(children: [

          // ── Header ────────────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedClasses.remove(className);
              } else {
                _expandedClasses.add(className);
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: classColor.withOpacity(0.07),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(18),
                  bottom: isExpanded
                      ? Radius.zero
                      : const Radius.circular(18),
                ),
              ),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      color: classColor.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: classColor.withOpacity(0.28))),
                  child: Icon(Icons.school_rounded,
                      color: classColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$degree${dept.isNotEmpty ? ' — $dept' : ''}",
                        style: const TextStyle(color: _textPri,
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(children: [
                        if (year.isNotEmpty) ...[
                          _tag("Year $year", _indigo),
                          const SizedBox(width: 6),
                        ],
                        if (batch.isNotEmpty) _tag(batch, _teal),
                        if (hasMissing) ...[
                          const SizedBox(width: 6),
                          _tag("${missingList.length} missing", _coral),
                        ],
                      ]),
                    ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (entries.isNotEmpty)
                        Row(children: [
                          _chip(Icons.how_to_reg_rounded,
                              "$classPresent", _green),
                          const SizedBox(width: 4),
                          _chip(Icons.person_off_rounded,
                              "$classAbsent", _coral),
                        ])
                      else
                        _chip(Icons.warning_amber_rounded,
                            "No record", _coral),
                      const SizedBox(height: 4),
                      Text(
                        "${entries.length} hour${entries.length == 1 ? '' : 's'}"
                            " done",
                        style: const TextStyle(
                            color: _textSec, fontSize: 10),
                      ),
                    ]),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _textSec, size: 24),
                ),
              ]),
            ),
          ),

          // ── Expanded content ──────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(children: [

              // Attended hours
              ...entries.asMap().entries.map((e) {
                final isLast = !hasMissing &&
                    e.key == entries.length - 1;
                return _buildHourRow(e.value, isLast);
              }),

              // Missing staff section
              if (hasMissing)
                _buildMissingSection(missingList,
                    isOnlyContent: entries.isEmpty),

            ]),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 260),
          ),
        ]),
      ),
    );
  }

  // ── Attended hour row ──────────────────────────────────────────────────────
  Widget _buildHourRow(HourEntry entry, bool isLast) {
    final color = _attendanceColor(entry.pct);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _cardBorder, width: 1),
          bottom: isLast
              ? const BorderSide(color: Colors.transparent)
              : BorderSide(
              color: _cardBorder.withOpacity(0.4), width: 0.5),
        ),
      ),
      child: Row(children: [
        // Hour badge
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.28))),
          child: Center(
            child: Text("${entry.hour}",
                style: TextStyle(color: color,
                    fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.subject,
                  style: const TextStyle(color: _textPri,
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.badge_rounded,
                    color: _textSec, size: 11),
                const SizedBox(width: 4),
                Flexible(child: Text(entry.staffName,
                    style: const TextStyle(
                        color: _textSec, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
                if (entry.periodTime.isNotEmpty &&
                    entry.periodTime != '—') ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time_rounded,
                      color: _textSec, size: 11),
                  const SizedBox(width: 3),
                  Flexible(child: Text(entry.periodTime,
                      style: const TextStyle(
                          color: _textSec, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: [
                _chip(Icons.how_to_reg_rounded,
                    "${entry.presentCount}", _green),
                const SizedBox(width: 4),
                _chip(Icons.person_off_rounded,
                    "${entry.absentCount}", _coral),
              ]),
              const SizedBox(height: 4),
              Text("/ ${entry.total} students",
                  style: const TextStyle(
                      color: _textSec, fontSize: 10)),
            ]),
      ]),
    );
  }

  // ── Missing staff section ──────────────────────────────────────────────────
  Widget _buildMissingSection(
      List<MissingPeriod> missing, {bool isOnlyContent = false}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: _coral.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _coral.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.10),
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(12)),
                border: Border(
                    bottom: BorderSide(
                        color: _coral.withOpacity(0.2))),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: _coral, size: 15),
                const SizedBox(width: 8),
                Text(
                  "Attendance not submitted — "
                      "${missing.length} period${missing.length == 1 ? '' : 's'}",
                  style: const TextStyle(color: _coral,
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ]),
            ),

            // One row per missing period
            ...missing.asMap().entries.map((e) {
              final idx    = e.key;
              final mp     = e.value;
              final isLast = idx == missing.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: isLast
                        ? BorderSide.none
                        : BorderSide(
                        color: _coral.withOpacity(0.15),
                        width: 0.5),
                  ),
                ),
                child: Row(children: [
                  // Period badge
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: _coral.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: _coral.withOpacity(0.3))),
                    child: Center(
                      child: Text("P${mp.period}",
                          style: const TextStyle(color: _coral,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Subject + staff
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mp.subject,
                            style: const TextStyle(color: _textPri,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (mp.staffName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.person_off_rounded,
                                color: _coral, size: 11),
                            const SizedBox(width: 4),
                            Text(mp.staffName,
                                style: const TextStyle(
                                    color: _coral, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ]),
                        ],
                      ])),
                  // "Not submitted" badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: _coral.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text("Not submitted",
                        style: TextStyle(color: _coral,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
            }),
          ]),
    );
  }

  // ── Small widgets ──────────────────────────────────────────────────────────
  Widget _tag(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.28))),
      child: Text(label,
          style: TextStyle(color: color,
              fontSize: 10, fontWeight: FontWeight.w600)));

  Widget _chip(IconData icon, String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(color: color,
                fontSize: 10, fontWeight: FontWeight.w600)),
      ]));

  // ── Special states ─────────────────────────────────────────────────────────
  Widget _buildNoAttendanceCard() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _coral.withOpacity(0.2))),
    child: Column(children: [
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _coral.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _coral.withOpacity(0.25))),
          child: const Icon(Icons.notifications_off_rounded,
              color: _coral, size: 36)),
      const SizedBox(height: 18),
      const Text("No Attendance Recorded",
          style: TextStyle(color: _textPri,
              fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
          "No classes were marked on "
              "${_dateLabel.format(_selectedDate)}.",
          style: const TextStyle(color: _textSec, fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _coral.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _coral.withOpacity(0.2))),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: _coral, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
                "This may require follow-up with concerned staff.",
                style: TextStyle(color: _coral, fontSize: 12))),
          ])),
    ]),
  );

  Widget _buildWeekendCard() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold.withOpacity(0.2))),
    child: Column(children: [
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _gold.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withOpacity(0.25))),
          child: const Icon(Icons.weekend_rounded,
              color: _gold, size: 36)),
      const SizedBox(height: 18),
      const Text("Weekend",
          style: TextStyle(color: _textPri,
              fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
          "${DateFormat('EEEE').format(_selectedDate)}"
              " — no classes scheduled.",
          style: const TextStyle(color: _textSec, fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _buildErrorCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _coral.withOpacity(0.25))),
    child: Column(children: [
      const Icon(Icons.error_outline_rounded, color: _coral, size: 36),
      const SizedBox(height: 14),
      const Text("Failed to load",
          style: TextStyle(color: _textPri,
              fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(_error ?? "Unknown error",
          style: const TextStyle(color: _textSec, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 18),
      GestureDetector(
          onTap: _fetchAll,
          child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 11),
              decoration: BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: _teal.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5))]),
              child: const Text("Try Again",
                  style: TextStyle(
                      color: _bg,
                      fontWeight: FontWeight.w700)))),
    ]),
  );

  Widget _buildShimmer() => Column(children: [
    ...List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorder)))),
  ]);
}

// ── Dot painter ────────────────────────────────────────────────────────────────
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