import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DayOrderPage extends StatefulWidget {
  const DayOrderPage({super.key});

  @override
  State<DayOrderPage> createState() => _DayOrderPageState();
}

class _DayOrderPageState extends State<DayOrderPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> dayOrders = ["I", "II", "III", "IV", "V", "VI"];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Design tokens (mirrors timetable page) ──────────────────────────────────
  static const _bg = Color(0xFF0F1117);
  static const _surface = Color(0xFF1A1D27);
  static const _surfaceAlt = Color(0xFF22263A);
  static const _accent = Color(0xFFF5A623);
  static const _accentSoft = Color(0x26F5A623);
  static const _pink = Color(0xFFE8568A);
  static const _pinkSoft = Color(0x1AE8568A);
  static const _green = Color(0xFF4CAF50);
  static const _greenSoft = Color(0x1A4CAF50);
  static const _red = Color(0xFFEF5350);
  static const _redSoft = Color(0x1AEF5350);
  static const _blue = Color(0xFF4A9EFF);
  static const _blueSoft = Color(0x1A4A9EFF);
  static const _textPrimary = Color(0xFFF0F2FF);
  static const _textSecondary = Color(0xFF8A8FAD);
  static const _border = Color(0xFF2E3350);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Manual Override Dialog ───────────────────────────────────────────────────
  void showManualOverrideDialog(Map<String, dynamic> data) {
    String selectedDay = data["current"] ?? "I";

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _border),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: 480,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dialog header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _pinkSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: _pink, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Manual Override",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              "Select a day order to apply",
                              style: TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Day grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.1,
                      children: dayOrders.map((day) {
                        final isSelected = selectedDay == day;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedDay = day),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected ? _pink : _bg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? _pink
                                    : _border,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                BoxShadow(
                                  color: _pink.withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: isSelected
                                      ? Colors.white
                                      : _textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Day $day",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : _textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: _textSecondary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          child: const Text("Cancel",
                              style: TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            final now = DateTime.now();
                            final todayKey =
                                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                            await _firestore
                                .collection("settings")
                                .doc("dayOrder")
                                .update({
                              "current": selectedDay,
                              "lastUpdatedDate": todayKey,
                              "updatedAt": FieldValue.serverTimestamp(),
                              "autoUpdated": false,
                              "rotationEnabled": true,
                            });
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_accent, _pink],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              "Save Changes",
                              style: TextStyle(
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
            ),
          );
        },
      ),
    );
  }

  // ── Rotation toggle ──────────────────────────────────────────────────────────
  Future<void> toggleRotation(bool value) async {
    await _firestore.collection("settings").doc("dayOrder").update({
      "rotationEnabled": value,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

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

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color colorSoft,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: colorSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
        _firestore.collection("settings").doc("dayOrder").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          final data =
          snapshot.data!.data() as Map<String, dynamic>;
          final currentDay = data["current"] ?? "I";
          final rotationEnabled = data["rotationEnabled"] ?? true;

          final now = DateTime.now();
          final weekDay = [
            "Monday", "Tuesday", "Wednesday",
            "Thursday", "Friday", "Saturday", "Sunday"
          ][now.weekday - 1];
          final isSunday = now.weekday == DateTime.sunday;

          int index = dayOrders.indexOf(currentDay);
          final nextDay =
          dayOrders[(index + 1) % dayOrders.length];

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero card ──────────────────────────────────────
                  _buildHeroCard(
                      currentDay, weekDay, isSunday, now),
                  const SizedBox(height: 24),

                  // ── Info cards ─────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          icon: Icons.skip_next_rounded,
                          title: "NEXT DAY",
                          value: "Day $nextDay",
                          color: _blue,
                          colorSoft: _blueSoft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoCard(
                          icon: Icons.autorenew_rounded,
                          title: "ROTATION",
                          value: rotationEnabled
                              ? "Enabled"
                              : "Disabled",
                          color: rotationEnabled ? _green : _red,
                          colorSoft: rotationEnabled
                              ? _greenSoft
                              : _redSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Rotation toggle ────────────────────────────────
                  _sectionLabel("Auto Rotation"),
                  _buildRotationToggle(
                      rotationEnabled, isSunday),
                  const SizedBox(height: 24),

                  // ── Manual override ────────────────────────────────
                  _sectionLabel("Manual Control"),
                  _buildManualOverrideTile(data),
                  const SizedBox(height: 24),

                  // ── Day cycle ──────────────────────────────────────
                  _sectionLabel("Day Order Cycle"),
                  _buildDayCycle(currentDay),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
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
            "Day Order",
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
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 16),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _greenSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                "LIVE",
                style: TextStyle(
                  color: _green,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
      String currentDay, String weekDay, bool isSunday, DateTime now) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _pink.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: _pink.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Date strip
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.today_rounded,
                    color: _textSecondary, size: 14),
                const SizedBox(width: 7),
                Text(
                  "$weekDay  ·  ${now.day.toString().padLeft(2, '0')} / ${now.month.toString().padLeft(2, '0')} / ${now.year}",
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Big day display
          ScaleTransition(
            scale: isSunday
                ? const AlwaysStoppedAnimation(1.0)
                : _pulseAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isSunday
                      ? [_surfaceAlt, _bg]
                      : [
                    _pink.withOpacity(0.18),
                    _pink.withOpacity(0.04),
                  ],
                ),
                border: Border.all(
                  color: isSunday
                      ? _border
                      : _pink.withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: isSunday
                    ? null
                    : [
                  BoxShadow(
                    color: _pink.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!isSunday) ...[
                      const Text(
                        "DAY",
                        style: TextStyle(
                          color: _pink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentDay,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.wb_sunny_rounded,
                          color: _textSecondary, size: 28),
                      const SizedBox(height: 6),
                      const Text(
                        "Sunday",
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Label
          Text(
            isSunday ? "No classes today" : "Today's Day Order",
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationToggle(bool rotationEnabled, bool isSunday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rotationEnabled ? _greenSoft : _redSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.autorenew_rounded,
              color: rotationEnabled ? _green : _red,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Automatic Rotation",
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rotationEnabled
                      ? "Day order advances automatically each day"
                      : "Day order is frozen — manual control only",
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: rotationEnabled,
            activeColor: _green,
            activeTrackColor: _greenSoft,
            inactiveThumbColor: _textSecondary,
            inactiveTrackColor: _bg,
            onChanged: isSunday ? null : toggleRotation,
          ),
        ],
      ),
    );
  }

  Widget _buildManualOverrideTile(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => showManualOverrideDialog(data),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _pinkSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: _pink, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Manual Override",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Manually set today's day order",
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _pinkSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Override",
                    style: TextStyle(
                      color: _pink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: _pink, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCycle(String currentDay) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator row
          Row(
            children: dayOrders.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final isCurrent = currentDay == day;
              final isPast = dayOrders.indexOf(currentDay) > i;
              final isLast = i == dayOrders.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? _pink
                                  : isPast
                                  ? _pinkSoft
                                  : _bg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCurrent
                                    ? _pink
                                    : isPast
                                    ? _pink.withOpacity(0.4)
                                    : _border,
                                width: isCurrent ? 2 : 1,
                              ),
                              boxShadow: isCurrent
                                  ? [
                                BoxShadow(
                                  color: _pink.withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                day,
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.white
                                      : isPast
                                      ? _pink
                                      : _textSecondary,
                                  fontSize: day.length > 2 ? 8 : 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Day $day",
                            style: TextStyle(
                              color: isCurrent
                                  ? _textPrimary
                                  : _textSecondary,
                              fontSize: 10,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 1.5,
                          margin: const EdgeInsets.only(bottom: 20),
                          color: isPast
                              ? _pink.withOpacity(0.3)
                              : _border,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Current indicator
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.my_location_rounded,
                    color: _accent, size: 14),
                const SizedBox(width: 7),
                Text(
                  "Currently on Day $currentDay",
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}