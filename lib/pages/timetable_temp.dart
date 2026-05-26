import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimetableTemplatePage extends StatefulWidget {
  const TimetableTemplatePage({super.key});

  @override
  State<TimetableTemplatePage> createState() => _TimetableTemplatePageState();
}

class _TimetableTemplatePageState extends State<TimetableTemplatePage>
    with TickerProviderStateMixin {
  int periodCount = 5;
  bool loading = true;

  final List<String> dayOrders = ["I", "II", "III", "IV", "V", "VI"];

  Map<int, TextEditingController> timeControllers = {};
  int lunchAfterPeriod = 3;
  TextEditingController lunchTimeController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Design tokens ────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F1117);
  static const _surface = Color(0xFF1A1D27);
  static const _surfaceAlt = Color(0xFF22263A);
  static const _accent = Color(0xFFF5A623);
  static const _accentSoft = Color(0x26F5A623);
  static const _pink = Color(0xFFE8568A);
  static const _pinkSoft = Color(0x1AE8568A);
  static const _textPrimary = Color(0xFFF0F2FF);
  static const _textSecondary = Color(0xFF8A8FAD);
  static const _border = Color(0xFF2E3350);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadTemplate();
  }

  void _initTimeControllers() {
    timeControllers.clear();
    for (int i = 1; i <= periodCount; i++) {
      timeControllers[i] = TextEditingController();
    }
    if (lunchAfterPeriod >= periodCount) lunchAfterPeriod = periodCount - 1;
    if (lunchAfterPeriod < 1) lunchAfterPeriod = 1;
  }

  Future<void> _loadTemplate() async {
    final doc = await FirebaseFirestore.instance
        .collection("settings")
        .doc("timetableTemplate")
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      periodCount = data['periods'] ?? 5;
      final lunchData = data['lunch'] as Map<String, dynamic>?;
      if (lunchData != null) {
        lunchAfterPeriod = lunchData['afterPeriod'] ?? 3;
        lunchTimeController.text = lunchData['time'] ?? '';
      }
      _initTimeControllers();
      final times = Map<String, dynamic>.from(data['periodTimes'] ?? {});
      times.forEach((key, value) {
        final index = int.tryParse(key.replaceAll("P", ""));
        if (index != null && timeControllers[index] != null) {
          timeControllers[index]!.text = value;
        }
      });
    } else {
      _initTimeControllers();
    }

    setState(() => loading = false);
    _fadeController.forward();
  }

  Future<void> _saveTemplate() async {
    Map<String, String> periodTimes = {};
    for (int i = 1; i <= periodCount; i++) {
      periodTimes["P$i"] = timeControllers[i]!.text.trim();
    }
    await FirebaseFirestore.instance
        .collection("settings")
        .doc("timetableTemplate")
        .set({
      "periods": periodCount,
      "days": dayOrders,
      "periodTimes": periodTimes,
      "lunch": {
        "afterPeriod": lunchAfterPeriod,
        "time": lunchTimeController.text.trim(),
      },
      "updatedAt": Timestamp.now(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20),
            SizedBox(width: 10),
            Text(
              "Template saved successfully!",
              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _changePeriodCount(int count) {
    setState(() {
      periodCount = count;
      _initTimeControllers();
    });
  }

  @override
  void dispose() {
    for (var c in timeControllers.values) {
      c.dispose();
    }
    lunchTimeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, String hint,
      {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF4A4F6A), fontSize: 13),
      filled: true,
      fillColor: _bg,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: _textSecondary)
          : null,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
  }

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

  List<DataColumn> _buildColumns() {
    List<DataColumn> columns = [
      const DataColumn(
        label: Text(
          "DAY",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ];

    for (int i = 1; i <= periodCount; i++) {
      columns.add(DataColumn(
        label: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _pinkSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "P$i",
                  style: const TextStyle(
                    color: _pink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                timeControllers[i]!.text.isEmpty
                    ? "—"
                    : timeControllers[i]!.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ));

      if (i == lunchAfterPeriod) {
        columns.add(DataColumn(
          label: SizedBox(
            width: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("🍽", style: TextStyle(fontSize: 10)),
                      SizedBox(width: 3),
                      Text(
                        "Lunch",
                        style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lunchTimeController.text.isEmpty
                      ? "—"
                      : lunchTimeController.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: _textSecondary),
                ),
              ],
            ),
          ),
        ));
      }
    }
    return columns;
  }

  List<DataRow> _buildRows() {
    return dayOrders.asMap().entries.map((entry) {
      final idx = entry.key;
      final day = entry.value;
      final isEven = idx.isEven;

      List<DataCell> cells = [
        DataCell(
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _pinkSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Day $day",
              style: const TextStyle(
                color: _pink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ];

      for (int i = 1; i <= periodCount; i++) {
        cells.add(DataCell(
          Center(
            child: Text(
              "—",
              style: TextStyle(
                color: _textSecondary.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ),
        ));

        if (i == lunchAfterPeriod) {
          cells.add(DataCell(
            Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _accent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  "🍽 Break",
                  style: TextStyle(
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ));
        }
      }

      return DataRow(
        color: MaterialStateProperty.all(
          isEven ? _surface : _surfaceAlt,
        ),
        cells: cells,
      );
    }).toList();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: _buildBody(),
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Timetable Template",
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            "Admin Configuration",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        // Period count selector
        PopupMenuButton<int>(
          onSelected: _changePeriodCount,
          color: _surface,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          offset: const Offset(0, 48),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _pinkSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _pink.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded, color: _pink, size: 16),
                const SizedBox(width: 5),
                Text(
                  "$periodCount Periods",
                  style: const TextStyle(
                    color: _pink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          itemBuilder: (_) => [5, 6, 7]
              .map((n) => PopupMenuItem(
            value: n,
            child: Text(
              "$n Periods",
              style: TextStyle(
                color: n == periodCount ? _accent : _textPrimary,
                fontWeight: n == periodCount
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ))
              .toList(),
        ),

        // Save button
        GestureDetector(
          onTap: _saveTemplate,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5A623), Color(0xFFE8568A)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  "Save",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header card ──────────────────────────────────────────────
          _buildHeaderCard(),
          const SizedBox(height: 24),

          // ── Period timings ───────────────────────────────────────────
          _sectionLabel("Period Timings"),
          _buildPeriodTimingsCard(),
          const SizedBox(height: 24),

          // ── Lunch settings ───────────────────────────────────────────
          _sectionLabel("Lunch Break Settings"),
          _buildLunchCard(),
          const SizedBox(height: 24),

          // ── Preview ──────────────────────────────────────────────────
          _sectionLabel("Schedule Preview"),
          _buildPreviewCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _pinkSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _pink.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: _pink,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Configure Timetable",
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "$periodCount periods · ${dayOrders.length} day-orders · Lunch after P$lunchAfterPeriod",
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A2F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A5E42)),
            ),
            child: const Text(
              "LIVE",
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTimingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        children: List.generate(periodCount, (i) {
          return SizedBox(
            width: 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _pinkSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          "${i + 1}",
                          style: const TextStyle(
                            color: _pink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      "Period ${i + 1}",
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: timeControllers[i + 1],
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                  ),
                  decoration: _inputDecoration(
                    "",
                    "09:00 – 09:50",
                    icon: Icons.access_time_rounded,
                  ).copyWith(
                    labelText: null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLunchCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge row
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text("🍽", style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      "Lunch Break",
                      style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lunch time input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Lunch Time",
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: lunchTimeController,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _inputDecoration(
                        "",
                        "12:30 – 13:15",
                        icon: Icons.access_time_rounded,
                      ).copyWith(labelText: null),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // After period dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Insert After",
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: lunchAfterPeriod,
                        dropdownColor: _surface,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: _accent, size: 20),
                        items: List.generate(
                          periodCount - 1,
                              (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text("Period ${i + 1}"),
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => lunchAfterPeriod = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Info strip
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _accent, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Lunch break will appear after Period $lunchAfterPeriod in the timetable.",
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table header strip
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _surfaceAlt,
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded,
                    color: _textSecondary, size: 15),
                const SizedBox(width: 8),
                const Text(
                  "SCHEDULE OVERVIEW",
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _pinkSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${dayOrders.length} DAYS",
                    style: const TextStyle(
                      color: _pink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: DataTable(
              headingRowHeight: 56,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              columnSpacing: 8,
              horizontalMargin: 12,
              dividerThickness: 0,
              headingRowColor:
              MaterialStateProperty.all(_surfaceAlt),
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: _border,
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              columns: _buildColumns(),
              rows: _buildRows(),
            ),
          ),
        ],
      ),
    );
  }
}