import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fees_structure.dart';

class ViewFeesStructurePage extends StatefulWidget {
  const ViewFeesStructurePage({super.key});

  @override
  State<ViewFeesStructurePage> createState() => _ViewFeesStructurePageState();
}

class _ViewFeesStructurePageState extends State<ViewFeesStructurePage>
    with TickerProviderStateMixin {

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
  }

  @override
  void dispose() {
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    super.dispose();
  }

  Widget _orb(double size, Color color, double opacity) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent])));

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
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Logic (unchanged) ────────────────────────────────────────────
  int _calculateTotal(Map<String, dynamic> semesters, int total, String half) {
    int totalSum = 0;
    for (int i = 1; i <= total; i++) {
      if (semesters.containsKey("sem$i")) {
        totalSum += (semesters["sem$i"][half] as num?)?.toInt() ?? 0;
      }
    }
    return totalSum;
  }

  void _confirmDelete(BuildContext context, String year) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _coral.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _coral.withOpacity(0.3))),
                  child: const Icon(Icons.delete_outline_rounded, color: _coral, size: 22)),
              const SizedBox(width: 14),
              const Text("Confirm Delete", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
                child: Text("Are you sure you want to delete the fee structure for academic year $year? This cannot be undone.",
                    style: const TextStyle(color: _textSec, fontSize: 13, height: 1.5))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                      alignment: Alignment.center,
                      child: const Text("Cancel", style: TextStyle(color: _textSec, fontWeight: FontWeight.w600))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseFirestore.instance.collection("fees_structure").doc(year).delete();
                    if (context.mounted) _snack("Fee structure for $year deleted", _green, Icons.check_circle_rounded);
                  },
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: const Text("Delete", style: TextStyle(color: _bg, fontWeight: FontWeight.w700))))),
            ]),
          ]),
        ),
      ),
    );
  }

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
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 16))),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Fee Structure Details", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
                Text("View & manage fee structures", style: TextStyle(color: _textSec, fontSize: 11)),
              ])),
              GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeesStructurePage())),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: _teal.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: _teal.withOpacity(0.25))),
                      child: const Row(children: [
                        Icon(Icons.add_rounded, color: _teal, size: 16),
                        SizedBox(width: 5),
                        Text("Add New", style: TextStyle(color: _teal, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]))),
            ]),
          ),

          // Body
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("fees_structure").orderBy("academicYear", descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _buildError();
              if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmpty();
              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc  = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final year = doc.id;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + index * 80),
                    builder: (_, v, child) => Transform.translate(offset: Offset(0, 16 * (1 - v)), child: Opacity(opacity: v, child: child)),
                    child: _buildYearCard(context, year, data),
                  );
                },
              );
            },
          )),
        ])),
      ]),
    );
  }

  Widget _buildLoading() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 52, height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _teal.withOpacity(0.3), width: 1.5),
            gradient: RadialGradient(colors: [_teal.withOpacity(0.15), Colors.transparent])),
        child: Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5, backgroundColor: _teal.withOpacity(0.1)))),
    const SizedBox(height: 18),
    const Text("Loading structures...", style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)),
  ]));

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _coral.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.error_outline_rounded, size: 40, color: _coral)),
    const SizedBox(height: 16),
    const Text("Error loading data", style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w700)),
  ]));

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: _card, shape: BoxShape.circle, border: Border.all(color: _cardBorder)),
          child: const Icon(Icons.account_balance_wallet_outlined, size: 48, color: _textSec)),
      const SizedBox(height: 20),
      const Text("No Fee Structures Found", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text("Tap 'Add New' to create your first fee structure", style: TextStyle(color: _textSec, fontSize: 13), textAlign: TextAlign.center),
    ]),
  ));

  Widget _buildYearCard(BuildContext context, String year, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorder),
          boxShadow: [BoxShadow(color: _teal.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(color: _surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), border: Border(bottom: BorderSide(color: _cardBorder))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _indigo.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.calendar_today_rounded, color: _indigo, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text("Academic Year $year", style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700))),
            // Edit
            GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeesStructurePage(editYear: year))),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _teal.withOpacity(0.25))),
                    child: const Row(children: [
                      Icon(Icons.edit_outlined, color: _teal, size: 14),
                      SizedBox(width: 4),
                      Text("Edit", style: TextStyle(color: _teal, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]))),
            const SizedBox(width: 8),
            // Delete
            GestureDetector(
                onTap: () => _confirmDelete(context, year),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _coral.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _coral.withOpacity(0.25))),
                    child: const Row(children: [
                      Icon(Icons.delete_outline, color: _coral, size: 14),
                      SizedBox(width: 4),
                      Text("Delete", style: TextStyle(color: _coral, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]))),
          ]),
        ),

        // Tables
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            if (data.containsKey("bachelor"))
              _buildDegreeTable("BACHELOR DEGREE (UG)", Map<String, dynamic>.from(data["bachelor"]), 6, _teal),
            if (data.containsKey("master"))
              Padding(padding: const EdgeInsets.only(top: 20),
                  child: _buildDegreeTable("MASTER DEGREE (PG)", Map<String, dynamic>.from(data["master"]), 4, _indigo)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDegreeTable(String title, Map<String, dynamic> degreeData, int totalSemesters, Color color) {
    final semesters = Map<String, dynamic>.from(degreeData["semesters"] ?? {});
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Degree label
      Container(margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: color, width: 3))),
          child: Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4))),

      // Table header
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: color.withOpacity(0.15))),
        child: Row(children: [
          Expanded(flex: 2, child: Text("Semester", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(flex: 3, child: Text("First Half (₹)", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text("Second Half (₹)", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
        ]),
      ),

      // Rows
      Container(
        decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color.withOpacity(0.15)), right: BorderSide(color: color.withOpacity(0.15)), bottom: BorderSide(color: color.withOpacity(0.15))),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10))),
        child: Column(children: List.generate(totalSemesters, (index) {
          final semNum = index + 1;
          if (!semesters.containsKey("sem$semNum")) return const SizedBox();
          final firstHalf  = (semesters["sem$semNum"]["firstHalf"]  ?? 0).toInt();
          final secondHalf = (semesters["sem$semNum"]["secondHalf"] ?? 0).toInt();
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
                border: index < totalSemesters - 1 ? Border(bottom: BorderSide(color: color.withOpacity(0.08))) : null,
                color: index % 2 == 0 ? Colors.transparent : color.withOpacity(0.02)),
            child: Row(children: [
              Expanded(flex: 2, child: Row(children: [
                Container(width: 22, height: 22, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    alignment: Alignment.center,
                    child: Text("$semNum", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
                const SizedBox(width: 7),
                const Text("Semester", style: TextStyle(color: _textSec, fontSize: 12)),
              ])),
              Expanded(flex: 3, child: Text("₹ $firstHalf", style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
              Expanded(flex: 3, child: Text("₹ $secondHalf", style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
            ]),
          );
        })),
      ),

      // Total row
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
        child: Row(children: [
          Expanded(flex: 2, child: Text("Total / Year", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(flex: 3, child: Text("₹ ${_calculateTotal(semesters, totalSemesters, 'firstHalf')}", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text("₹ ${_calculateTotal(semesters, totalSemesters, 'secondHalf')}", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
        ]),
      ),
    ]);
  }
}

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