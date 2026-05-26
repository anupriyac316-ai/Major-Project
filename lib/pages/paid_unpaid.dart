import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ── Design tokens (matching FeeMainPage) ────────────────────────
const Color _bg         = Color(0xFF070B14);
const Color _surface    = Color(0xFF0F1624);
const Color _card       = Color(0xFF151E30);
const Color _cardBorder = Color(0xFF1E2D47);
const Color _teal       = Color(0xFF00E5CC);
const Color _indigo     = Color(0xFF7C6FFF);
const Color _coral      = Color(0xFFFF6B6B);
const Color _gold       = Color(0xFFFFB547);
const Color _green      = Color(0xFF36E8A0);
const Color _textPri    = Color(0xFFEEF2FF);
const Color _textSec    = Color(0xFF7A8DB0);

// ── Data Models ──────────────────────────────────────────────────
class StudentFeeRecord {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String className;
  final String department;
  final String year;
  final double totalFee;
  final double paidFee;
  final List<SemesterRecord> semesters;

  StudentFeeRecord({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.className,
    required this.department,
    required this.year,
    required this.totalFee,
    required this.paidFee,
    required this.semesters,
  });

  double get pendingFee => totalFee - paidFee;
  bool get isFullyPaid => pendingFee <= 0 && totalFee > 0;
  bool get isPartiallyPaid => paidFee > 0 && pendingFee > 0;
  bool get isUnpaid => paidFee == 0;
  String get fullName => '$firstName $lastName';
  double get paymentPercent => totalFee > 0 ? paidFee / totalFee : 0;
}

class SemesterRecord {
  final String semKey;
  final double firstHalfAmount;
  final double secondHalfAmount;
  final bool firstHalfPaid;
  final bool secondHalfPaid;
  final DateTime? deadline;

  SemesterRecord({
    required this.semKey,
    required this.firstHalfAmount,
    required this.secondHalfAmount,
    required this.firstHalfPaid,
    required this.secondHalfPaid,
    this.deadline,
  });

  double get totalAmount => firstHalfAmount + secondHalfAmount;
  double get paidAmount =>
      (firstHalfPaid ? firstHalfAmount : 0) +
          (secondHalfPaid ? secondHalfAmount : 0);
  bool get isFullyPaid => firstHalfPaid && secondHalfPaid;
}

// ── Main Page ────────────────────────────────────────────────────
class PaidUnpaidStudentsPage extends StatefulWidget {
  const PaidUnpaidStudentsPage({super.key});

  @override
  State<PaidUnpaidStudentsPage> createState() =>
      _PaidUnpaidStudentsPageState();
}

class _PaidUnpaidStudentsPageState extends State<PaidUnpaidStudentsPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<StudentFeeRecord> _allStudents = [];
  List<StudentFeeRecord> _filteredStudents = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter state
  String _activeTab = 'all'; // all, paid, partial, unpaid
  String _searchQuery = '';
  String _selectedClass = 'All Classes';
  List<String> _classOptions = ['All Classes'];

  // Expand state for detail view
  String? _expandedUid;

  late AnimationController _fadeCtrl;
  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;

  final TextEditingController _searchCtrl = TextEditingController();
  final DateFormat _df = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _orb1Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _orb2Ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _orb1Anim = Tween<double>(begin: 0, end: 26).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim = Tween<double>(begin: 0, end: 20).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));

    _fetchAllStudents();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAllStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final List<StudentFeeRecord> records = [];
    final Set<String> classNames = {};

    try {
      final classesSnap = await _firestore.collection('Student_Of_College').get();

      for (final classDoc in classesSnap.docs) {
        final classData = classDoc.data();
        final className  = classDoc.id;
        final department = classData['department'] as String? ?? '';
        final year       = classData['year']       as String? ?? '';

        classNames.add(className);

        final studentsSnap = await classDoc.reference.collection('students').get();

        for (final studentDoc in studentsSnap.docs) {
          final sd = studentDoc.data();
          final uid       = studentDoc.id;
          final firstName = sd['firstName'] as String? ?? '';
          final lastName  = sd['lastName']  as String? ?? '';
          final email     = sd['email']     as String? ?? '';
          final phone     = sd['phone']     as String? ?? '';

          double totalFee = 0;
          double paidFee  = 0;
          final List<SemesterRecord> semRecords = [];

          final feesYearSnap = await studentDoc.reference.collection('fees').get();

          for (final yearDoc in feesYearSnap.docs) {
            final yearData = yearDoc.data();

            yearData.forEach((key, value) {
              if (key.startsWith('sem') && value is Map) {
                final semMap = Map<String, dynamic>.from(value);
                final rawAmount = semMap['amount'];

                double fh = 0, sh = 0;
                if (rawAmount is Map) {
                  final amtMap = Map<String, dynamic>.from(rawAmount);
                  fh = (amtMap['firstHalf']  as num?)?.toDouble() ?? 0;
                  sh = (amtMap['secondHalf'] as num?)?.toDouble() ?? 0;
                }

                final bool fhPaid = semMap['firstHalf']  as bool? ?? false;
                final bool shPaid = semMap['secondHalf'] as bool? ?? false;

                totalFee += fh + sh;
                if (fhPaid) paidFee += fh;
                if (shPaid) paidFee += sh;

                DateTime? deadline;
                final dlRaw = semMap['deadline'];
                if (dlRaw is Timestamp) deadline = dlRaw.toDate();

                semRecords.add(SemesterRecord(
                  semKey:            key,
                  firstHalfAmount:   fh,
                  secondHalfAmount:  sh,
                  firstHalfPaid:     fhPaid,
                  secondHalfPaid:    shPaid,
                  deadline:          deadline,
                ));
              }
            });
          }

          // sort semesters
          semRecords.sort((a, b) => a.semKey.compareTo(b.semKey));

          records.add(StudentFeeRecord(
            uid:        uid,
            firstName:  firstName,
            lastName:   lastName,
            email:      email,
            phone:      phone,
            className:  className,
            department: department,
            year:       year,
            totalFee:   totalFee,
            paidFee:    paidFee,
            semesters:  semRecords,
          ));
        }
      }

      // sort by name
      records.sort((a, b) => a.fullName.compareTo(b.fullName));

      final sortedClasses = classNames.toList()..sort();

      setState(() {
        _allStudents  = records;
        _classOptions = ['All Classes', ...sortedClasses];
        _isLoading    = false;
      });
      _applyFilters();
      _fadeCtrl.forward();
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        _isLoading    = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilters() {
    List<StudentFeeRecord> result = List.from(_allStudents);

    // Tab filter
    switch (_activeTab) {
      case 'paid':
        result = result.where((s) => s.isFullyPaid).toList();
        break;
      case 'partial':
        result = result.where((s) => s.isPartiallyPaid).toList();
        break;
      case 'unpaid':
        result = result.where((s) => s.isUnpaid).toList();
        break;
    }

    // Class filter
    if (_selectedClass != 'All Classes') {
      result = result.where((s) => s.className == _selectedClass).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) =>
      s.fullName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q)    ||
          s.phone.contains(q)                  ||
          s.department.toLowerCase().contains(q)
      ).toList();
    }

    setState(() => _filteredStudents = result);
  }

  // ── Counts ──────────────────────────────────────────────────────
  int get _paidCount    => _allStudents.where((s) => s.isFullyPaid).length;
  int get _partialCount => _allStudents.where((s) => s.isPartiallyPaid).length;
  int get _unpaidCount  => _allStudents.where((s) => s.isUnpaid).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // Orbs
        AnimatedBuilder(
          animation: Listenable.merge([_orb1Ctrl, _orb2Ctrl]),
          builder: (_, __) => Stack(children: [
            Positioned(
              top: -60 + _orb1Anim.value, right: -60,
              child: _orb(260, _teal,   0.13),
            ),
            Positioned(
              bottom: 100 - _orb2Anim.value, left: -70,
              child: _orb(220, _indigo, 0.15),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _DotPainter(color: _teal.withOpacity(0.04))),
            ),
          ]),
        ),

        SafeArea(child: Column(children: [

          // ── App Bar ──────────────────────────────────────────
          Container(
            color: _surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _card, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Paid / Unpaid Students',
                      style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(
                    _isLoading ? 'Loading...' : '${_allStudents.length} students total',
                    style: const TextStyle(color: _textSec, fontSize: 11),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: _isLoading ? null : () {
                  _fadeCtrl.reset();
                  _fetchAllStudents();
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _card, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Icon(
                    _isLoading ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
                    color: _textSec, size: 18,
                  ),
                ),
              ),
            ]),
          ),

          // ── Body ─────────────────────────────────────────────
          Expanded(child: _isLoading
              ? _buildLoading()
              : _errorMessage != null
              ? _buildError()
              : FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [
              _buildSummaryRow(),
              _buildTabBar(),
              _buildSearchAndFilter(),
              Expanded(child: _buildStudentList()),
            ]),
          ),
          ),
        ])),
      ]),
    );
  }

  // ── Summary Row ──────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        _summaryChip('Paid',    _paidCount,    _green,  Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _summaryChip('Partial', _partialCount, _gold,   Icons.pending_rounded),
        const SizedBox(width: 8),
        _summaryChip('Unpaid',  _unpaidCount,  _coral,  Icons.cancel_rounded),
      ]),
    );
  }

  Widget _summaryChip(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
            Text(label,    style: const TextStyle(color: _textSec, fontSize: 10)),
          ])),
        ]),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      ('all',     'All',     _teal,  _allStudents.length),
      ('paid',    'Paid',    _green, _paidCount),
      ('partial', 'Partial', _gold,  _partialCount),
      ('unpaid',  'Unpaid',  _coral, _unpaidCount),
    ];

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: tabs.map((t) {
        final isActive = _activeTab == t.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _activeTab = t.$1);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? t.$3.withOpacity(0.15) : _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? t.$3.withOpacity(0.5) : _cardBorder),
              ),
              child: Column(children: [
                Text('${t.$4}', style: TextStyle(color: isActive ? t.$3 : _textSec, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(t.$2,     style: TextStyle(color: isActive ? t.$3.withOpacity(0.8) : _textSec, fontSize: 9)),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }

  // ── Search & Filter ──────────────────────────────────────────────
  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        // Search
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: _textPri, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name, email, phone…',
              hintStyle: const TextStyle(color: _textSec, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _textSec, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                  _applyFilters();
                },
                child: const Icon(Icons.close_rounded, color: _textSec, size: 18),
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (v) {
              setState(() => _searchQuery = v);
              _applyFilters();
            },
          ),
        ),
        const SizedBox(height: 10),

        // Class dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: DropdownButton<String>(
            value: _selectedClass,
            isExpanded: true,
            dropdownColor: _card,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textSec),
            style: const TextStyle(color: _textPri, fontSize: 13),
            items: _classOptions.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c, style: TextStyle(
                color: c == 'All Classes' ? _textSec : _textPri, fontSize: 13,
              )),
            )).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _selectedClass = v);
                _applyFilters();
              }
            },
          ),
        ),

        const SizedBox(height: 10),

        // Result count
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${_filteredStudents.length} student${_filteredStudents.length != 1 ? 's' : ''} found',
            style: const TextStyle(color: _textSec, fontSize: 11),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Student List ─────────────────────────────────────────────────
  Widget _buildStudentList() {
    if (_filteredStudents.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_search_rounded, color: _textSec.withOpacity(0.4), size: 56),
          const SizedBox(height: 16),
          const Text('No students found', style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Try adjusting your filters', style: TextStyle(color: _textSec, fontSize: 13)),
        ]),
      );
    }

    return RefreshIndicator(
      color: _teal,
      backgroundColor: _card,
      onRefresh: _fetchAllStudents,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _filteredStudents.length,
        itemBuilder: (_, i) => _StudentCard(
          record: _filteredStudents[i],
          isExpanded: _expandedUid == _filteredStudents[i].uid,
          onTap: () => setState(() =>
          _expandedUid = _expandedUid == _filteredStudents[i].uid ? null : _filteredStudents[i].uid,
          ),
          dateFormat: _df,
        ),
      ),
    );
  }

  // ── Loading & Error ──────────────────────────────────────────────
  Widget _buildLoading() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _teal.withOpacity(0.3), width: 1.5),
          gradient: RadialGradient(colors: [_teal.withOpacity(0.15), Colors.transparent]),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: _teal, strokeWidth: 2.5, backgroundColor: _teal.withOpacity(0.1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text('Loading students…', style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text('Fetching fee records', style: TextStyle(color: _textSec, fontSize: 12)),
    ]),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: _coral.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded, color: _coral, size: 36),
        ),
        const SizedBox(height: 18),
        const Text('Failed to Load', style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_errorMessage ?? 'Unknown error', style: const TextStyle(color: _textSec, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _fetchAllStudents,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(30)),
            child: const Text('Try Again', style: TextStyle(color: _bg, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ),
  );

  Widget _orb(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );
}

// ── Student Card ─────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final StudentFeeRecord record;
  final bool isExpanded;
  final VoidCallback onTap;
  final DateFormat dateFormat;

  const _StudentCard({
    required this.record,
    required this.isExpanded,
    required this.onTap,
    required this.dateFormat,
  });

  Color get _statusColor {
    if (record.isFullyPaid)    return _green;
    if (record.isPartiallyPaid) return _gold;
    return _coral;
  }

  String get _statusLabel {
    if (record.isFullyPaid)    return 'FULLY PAID';
    if (record.isPartiallyPaid) return 'PARTIAL';
    return 'UNPAID';
  }

  IconData get _statusIcon {
    if (record.isFullyPaid)    return Icons.check_circle_rounded;
    if (record.isPartiallyPaid) return Icons.pending_rounded;
    return Icons.cancel_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isExpanded ? color.withOpacity(0.4) : _cardBorder),
          boxShadow: [
            BoxShadow(color: color.withOpacity(isExpanded ? 0.12 : 0.05), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [

          // ── Header row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [

              // Avatar
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    record.firstName.isNotEmpty ? record.firstName[0].toUpperCase() : '?',
                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(
                    record.fullName,
                    style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  )),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_statusIcon, color: color, size: 10),
                      const SizedBox(width: 3),
                      Text(_statusLabel, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(record.className, style: const TextStyle(color: _textSec, fontSize: 11), overflow: TextOverflow.ellipsis),
              ])),

              // Chevron
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: _textSec, size: 20),
              ),
            ]),
          ),

          // ── Progress bar ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('₹${record.paidFee.toStringAsFixed(0)} paid',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                Text('₹${record.pendingFee.toStringAsFixed(0)} pending',
                    style: const TextStyle(color: _textSec, fontSize: 11)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: record.paymentPercent,
                  backgroundColor: _cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
            ]),
          ),

          // ── Expanded details ─────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 14),
            secondChild: _buildDetails(color),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ]),
      ),
    );
  }

  Widget _buildDetails(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Divider
        Divider(color: _cardBorder, height: 1),
        const SizedBox(height: 12),

        // Contact info
        _infoRow(Icons.email_outlined,     record.email, _indigo),
        const SizedBox(height: 6),
        _infoRow(Icons.phone_outlined,     record.phone, _teal),
        const SizedBox(height: 6),
        _infoRow(Icons.school_outlined,    '${record.department} • Year ${record.year}', _gold),

        const SizedBox(height: 14),

        // Semester breakdown
        const Text('Semester Breakdown',
            style: TextStyle(color: _textPri, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 8),

        ...record.semesters.map((sem) => _SemesterTile(sem: sem, dateFormat: dateFormat)),

        const SizedBox(height: 10),
        Divider(color: _cardBorder, height: 1),
        const SizedBox(height: 10),

        // Total summary
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _totalCell('Total Fee',  '₹${record.totalFee.toStringAsFixed(0)}',   _textSec),
          _totalCell('Paid',       '₹${record.paidFee.toStringAsFixed(0)}',    _green),
          _totalCell('Pending',    '₹${record.pendingFee.toStringAsFixed(0)}', _coral),
        ]),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) => Row(children: [
    Icon(icon, color: color, size: 14),
    const SizedBox(width: 8),
    Flexible(child: Text(text, style: const TextStyle(color: _textSec, fontSize: 12), overflow: TextOverflow.ellipsis)),
  ]);

  Widget _totalCell(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: _textSec, fontSize: 10)),
    const SizedBox(height: 2),
    Text(value,  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
  ]);
}

// ── Semester Tile ─────────────────────────────────────────────────
class _SemesterTile extends StatelessWidget {
  final SemesterRecord sem;
  final DateFormat dateFormat;
  const _SemesterTile({required this.sem, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final semLabel = sem.semKey.replaceFirst('sem', 'Semester ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(semLabel.toUpperCase(),
              style: const TextStyle(color: _textPri, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          if (sem.deadline != null)
            Text('Due: ${dateFormat.format(sem.deadline!)}',
                style: const TextStyle(color: _textSec, fontSize: 10)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _halfBadge('1st Half', sem.firstHalfAmount,  sem.firstHalfPaid)),
          const SizedBox(width: 8),
          Expanded(child: _halfBadge('2nd Half', sem.secondHalfAmount, sem.secondHalfPaid)),
        ]),
      ]),
    );
  }

  Widget _halfBadge(String label, double amount, bool paid) {
    final color = paid ? _green : _coral;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _textSec, fontSize: 9)),
          Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        Icon(paid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: color, size: 16),
      ]),
    );
  }
}

// ── Dot Painter ───────────────────────────────────────────────────
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