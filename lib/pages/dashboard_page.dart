import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'staff_mainpage.dart';
import 'notification.dart';
import 'course_page.dart';
import 'department_page.dart';
import 'order.dart';
import 'admin_login.dart';
import 'admin_register.dart';
import 'timetable_temp.dart';
import 'reset.dart';
import 'update_year_students.dart';
import 'fee_maincode.dart';
import 'student_mainpage.dart';
import 'admin_attendance_monitor_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String userName = '';
  String userEmail = '';
  String userPhone = '';
  bool isLoading = true;
  bool isAdmin = false;
  String staffDept = '';

  int studentCount    = 0;
  int staffCount      = 0;
  int courseCount     = 0;
  int departmentCount = 0;

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset>  _slideAnim;

  // ── Design tokens ─────────────────────────────────────────────
  static const Color _bg         = Color(0xFF070B14);
  static const Color _surface    = Color(0xFF0F1624);
  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _coral      = Color(0xFFFF6B6B);
  static const Color _gold       = Color(0xFFFFB547);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _rose       = Color(0xFFFF4D8D);
  static const Color _green      = Color(0xFF36E8A0);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    fetchAllData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ─────────────────── LOGIC ────────────────────────────────────

  Future<void> fetchAllData() async {
    await fetchUserData();
    await Future.wait([
      fetchStudentCount(),
      fetchStaffCount(),
      fetchCourseCount(),
      fetchDepartmentCount(),
    ]);
    setState(() => isLoading = false);
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  Future<void> fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    setState(() {
      userName  = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
      userEmail = data['email'] ?? '';
      userPhone = data['phone'] ?? '';
      isAdmin   = data['role'] == 'admin';
    });
    final staffDoc = await _firestore.collection('staff').doc(user.uid).get();
    if (staffDoc.exists) staffDept = staffDoc.data()?['department'] ?? '';
  }

  Future<void> fetchStudentCount() async {
    try {
      int count = 0;
      final snap = await _firestore.collection('Student_Of_College').get();
      for (var d in snap.docs) {
        final s = await d.reference.collection('students').get();
        count += s.docs.length;
      }
      setState(() => studentCount = count);
    } catch (e) { debugPrint("Error fetching students: $e"); }
  }

  Future<void> fetchStaffCount() async {
    try {
      int count = 0;
      final snap = await _firestore.collection('staff_of_college').get();
      for (var d in snap.docs) {
        final s = await d.reference.collection('staff').get();
        count += s.docs.length;
      }
      setState(() => staffCount = count);
    } catch (e) { debugPrint("Error fetching staff: $e"); }
  }

  Future<void> fetchCourseCount() async {
    try {
      final snap = await _firestore.collection('courses').get();
      setState(() => courseCount = snap.docs.length);
    } catch (e) { debugPrint("Error fetching courses: $e"); }
  }

  Future<void> fetchDepartmentCount() async {
    try {
      final snap = await _firestore.collection('departments').get();
      setState(() => departmentCount = snap.docs.length);
    } catch (e) { debugPrint("Error fetching departments: $e"); }
  }

  Future<void> logoutAdmin() async {
    await _auth.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const AdminLoginPage()));
  }

  Future<void> resetAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).delete();
    await user.delete();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminRegisterPage()),
          (route) => false,
    );
  }

  void showResetAdminDialog() {
    showDialog(
      context: context,
      builder: (_) => _StyledDialog(
        title: "Reset Admin",
        titleColor: _coral,
        icon: Icons.warning_amber_rounded,
        iconColor: _coral,
        content:
        "This will permanently delete this admin account.\n⚠ You cannot register again using the same details.\nDo you want to continue?",
        confirmLabel: "Reset",
        confirmColor: _coral,
        onConfirm: () {
          Navigator.pop(context);
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ResetPage()));
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void showEditProfileDialog() {
    final emailController = TextEditingController(text: userEmail);
    final phoneController = TextEditingController(text: userPhone);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_outlined, color: _teal, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("Update Profile",
                  style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 20),
            _darkField(label: "Name", value: userName, icon: Icons.person_outline, enabled: false),
            const SizedBox(height: 12),
            _darkTextField(controller: emailController, label: "Email",  icon: Icons.email_outlined),
            const SizedBox(height: 12),
            _darkTextField(controller: phoneController, label: "Phone",  icon: Icons.phone_outlined),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _textSec,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _cardBorder)),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: _bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
                      'email': emailController.text.trim(),
                      'phone': phoneController.text.trim(),
                    });
                    setState(() {
                      userEmail = emailController.text.trim();
                      userPhone = phoneController.text.trim();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ─────────────────── UI ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 56, height: 56,
              child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5, backgroundColor: _teal.withOpacity(0.1))),
          const SizedBox(height: 24),
          const Text("Loading Dashboard...",
              style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text("Please wait", style: TextStyle(color: _textSec, fontSize: 13)),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _textPri),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _teal.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text("DASHBOARD",
                  style: TextStyle(color: _teal, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            onPressed: () {
              _fadeCtrl.reset();
              _slideCtrl.reset();
              fetchAllData();
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
              child: const Icon(Icons.refresh_outlined, color: _textSec, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _cardBorder),
        ),
      ),

      // ── Drawer ──────────────────────────────────────────────────
      drawer: Drawer(
        backgroundColor: _surface,
        child: Column(children: [
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1B3E), Color(0xFF131929)],
              ),
            ),
            child: Stack(children: [
              Positioned(
                top: -30, right: -20,
                child: Container(width: 160, height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [_teal.withOpacity(0.12), Colors.transparent]))),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 56, left: 20, right: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _teal.withOpacity(0.5), width: 2),
                        color: _teal.withOpacity(0.15),
                      ),
                      child: Center(
                        child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : "A",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _teal)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPri),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(userEmail, style: const TextStyle(fontSize: 11, color: _textSec),
                          overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _teal.withOpacity(0.3)),
                    ),
                    child: Text(isAdmin ? "Administrator Access" : "Staff Access",
                        style: const TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ]),
          ),

          Expanded(
            child: ListView(padding: const EdgeInsets.all(12), children: [
              _drawerItem("Manage Students",    Icons.school_outlined,          () => _push(const StudentMainPage())),
              _drawerItem("Manage Staff",       Icons.people_outline,           () => _push(const StaffMainPage())),
              _drawerItem("Notifications",      Icons.notifications_outlined,   () => _push(const NotificationPage())),
              _drawerItem("Courses",            Icons.menu_book_outlined,       () => _push(CoursePage())),
              _drawerItem("Departments",        Icons.account_tree_outlined,    () => _push(const DepartmentPage())),
              _divider(),
              _drawerItem("Fees Management",    Icons.currency_rupee_outlined,  () => _push(const FeeMainPage())),
              _drawerItem("Timetable Template", Icons.table_chart_outlined,     () => _push(const TimetableTemplatePage())),
              _drawerItem("Attendance Monitor", Icons.fact_check_outlined,      () => _push(const AdminAttendanceMonitorPage())),
              _divider(),
              _drawerItem("Promote Students",   Icons.upgrade_outlined,         () => _push(const UpdateYearStudentsPage())),
              _drawerItem("Reset Admin",        Icons.warning_outlined, showResetAdminDialog, color: _coral),
              _drawerItem("Logout",             Icons.logout_outlined,  logoutAdmin,          color: _coral),
            ]),
          ),
        ]),
      ),

      // ── Body ────────────────────────────────────────────────────
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _buildProfileCard(),
              const SizedBox(height: 28),

              _sectionLabel("Overview"),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _MiniStatCard(label: "Students",   value: studentCount,    color: _teal,   icon: Icons.school_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _MiniStatCard(label: "Staff",      value: staffCount,      color: _green,  icon: Icons.people_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _MiniStatCard(label: "Courses",    value: courseCount,     color: _gold,   icon: Icons.menu_book_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _MiniStatCard(label: "Depts",      value: departmentCount, color: _rose,   icon: Icons.account_tree_outlined)),
              ]),

              const SizedBox(height: 28),
              _sectionLabel("Quick Access"),
              const SizedBox(height: 14),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  _GridCard(title: "Students",    count: studentCount,    icon: Icons.school_outlined,               accent: _teal,   badge: "ENROLLED", onTap: () => _push(const StudentMainPage())),
                  _GridCard(title: "Staff",       count: staffCount,      icon: Icons.people_outlined,               accent: _green,  badge: "ACTIVE",   onTap: () => _push(const StaffMainPage())),
                  _GridCard(title: "Courses",     count: courseCount,     icon: Icons.menu_book_outlined,            accent: _gold,   badge: "TOTAL",    onTap: () => _push(CoursePage())),
                  _GridCard(title: "Departments", count: departmentCount, icon: Icons.account_tree_outlined,         accent: _rose,   badge: "UNITS",    onTap: () => _push(const DepartmentPage())),
                  _GridCard(title: "Notifications",                       icon: Icons.notifications_active_outlined, accent: _indigo, badge: "SEND",     onTap: () => _push(const NotificationPage())),
                  // ── Attendance — no count, just a shortcut ──────
                  _GridCard(
                    title: "Attendance",
                    icon:  Icons.fact_check_outlined,
                    accent: _teal,
                    badge: "MONITOR",
                    onTap: () => _push(const AdminAttendanceMonitorPage()),
                  ),
                  _buildDayOrderCard(),
                ],
              ),

              const SizedBox(height: 28),
              _sectionLabel("System Overview"),
              const SizedBox(height: 14),
              _buildSystemOverview(),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _fadeCtrl.reset();
          _slideCtrl.reset();
          fetchAllData();
        },
        backgroundColor: _teal,
        foregroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        tooltip: "Refresh Data",
        child: const Icon(Icons.refresh_outlined),
      ),
    );
  }

  // ─────────── helpers ──────────────────────────────────────────

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 3, height: 18,
        decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Text(text, style: const TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
  ]);

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Divider(color: _cardBorder, height: 1),
  );

  Widget _drawerItem(String title, IconData icon, VoidCallback onTap, {Color? color}) {
    final c = color ?? _textSec;
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: c),
      ),
      title: Text(title, style: TextStyle(color: color ?? _textPri, fontSize: 13, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      hoverColor: _teal.withOpacity(0.05),
    );
  }

  Widget _buildProfileCard() {
    final initials = userName.isNotEmpty
        ? userName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : "A";
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _cardBorder),
        boxShadow: [BoxShadow(color: _teal.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Stack(children: [
          Container(
            width: 66, height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_teal.withOpacity(0.3), _indigo.withOpacity(0.3)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: _teal.withOpacity(0.5), width: 2),
            ),
            child: Center(child: Text(initials,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _teal))),
          ),
          Positioned(bottom: 2, right: 2,
              child: Container(width: 14, height: 14,
                  decoration: BoxDecoration(color: _green, shape: BoxShape.circle, border: Border.all(color: _card, width: 2)))),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Welcome back,", style: TextStyle(color: _textSec, fontSize: 12)),
          const SizedBox(height: 2),
          Text(userName, style: const TextStyle(color: _textPri, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(userEmail, style: const TextStyle(color: _textSec, fontSize: 12), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _teal.withOpacity(0.3))),
            child: Text(isAdmin ? "Administrator" : "Staff",
                style: const TextStyle(color: _teal, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ])),
        GestureDetector(
          onTap: showEditProfileDialog,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _teal.withOpacity(0.25))),
            child: const Icon(Icons.edit_outlined, color: _teal, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildDayOrderCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection("settings").doc("dayOrder").snapshots(),
      builder: (context, snapshot) {
        String displayDay = "I";
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayDay = data["current"] ?? "I";
        }
        final today   = DateTime.now();
        final weekDay = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][today.weekday - 1];
        return _GridCard(
          title: "Today's Day", icon: Icons.calendar_today_outlined,
          accent: _indigo, badge: weekDay.toUpperCase(),
          extraLabel: "Day $displayDay",
          onTap: () => _push(const DayOrderPage()),
        );
      },
    );
  }

  Widget _buildSystemOverview() {
    final items = [
      ("Students",    studentCount,    _teal,  Icons.school_outlined),
      ("Staff",       staffCount,      _green, Icons.people_outlined),
      ("Courses",     courseCount,     _gold,  Icons.menu_book_outlined),
      ("Depts",       departmentCount, _rose,  Icons.account_tree_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cardBorder)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) => Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: item.$3.withOpacity(0.1), shape: BoxShape.circle,
                border: Border.all(color: item.$3.withOpacity(0.25), width: 1.5)),
            child: Icon(item.$4, size: 22, color: item.$3),
          ),
          const SizedBox(height: 10),
          Text(item.$2.toString(), style: TextStyle(color: item.$3, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 3),
          Text(item.$1, style: const TextStyle(color: _textSec, fontSize: 11, fontWeight: FontWeight.w500)),
        ])).toList(),
      ),
    );
  }

  Widget _darkField({required String label, required String value, required IconData icon, bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
      child: Row(children: [
        Padding(padding: const EdgeInsets.all(14), child: Icon(icon, color: _textSec, size: 18)),
        Expanded(child: Text(value, style: TextStyle(color: enabled ? _textPri : _textSec, fontSize: 14))),
      ]),
    );
  }

  Widget _darkTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textPri, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: _textSec, fontSize: 13),
        prefixIcon: Icon(icon, color: _textSec, size: 18),
        filled: true, fillColor: _surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _teal)),
        isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ── Mini Stat Card ─────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String  label;
  final int     value;
  final Color   color;
  final IconData icon;

  const _MiniStatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151E30), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value.toString(), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF7A8DB0), fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Grid Card ──────────────────────────────────────────────────────
class _GridCard extends StatefulWidget {
  final String   title;
  final int?     count;
  final IconData icon;
  final Color    accent;
  final String   badge;
  final String?  extraLabel;
  final String?  subLabel;
  final VoidCallback onTap;

  const _GridCard({
    required this.title,
    this.count,
    required this.icon,
    required this.accent,
    required this.badge,
    this.extraLabel,
    this.subLabel,
    required this.onTap,
  });

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110),
        lowerBound: 0.96, upperBound: 1.0, value: 1.0);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  static const Color _card    = Color(0xFF151E30);
  static const Color _textSec = Color(0xFF7A8DB0);

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _ctrl,
      child: GestureDetector(
        onTapDown:   (_) => _ctrl.reverse(),
        onTapUp:     (_) { _ctrl.forward(); widget.onTap(); },
        onTapCancel: ()  => _ctrl.forward(),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(22),
            border: Border.all(color: widget.accent.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [widget.accent.withOpacity(0.25), widget.accent.withOpacity(0.07)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.accent.withOpacity(0.3)),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(widget.badge,
                    style: TextStyle(color: widget.accent, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
              ),
            ]),

            const Spacer(),

            if (widget.count != null)
              Text(widget.count.toString(),
                  style: TextStyle(color: widget.accent, fontSize: 34, fontWeight: FontWeight.w800,
                      letterSpacing: -1.5, height: 1))
            else if (widget.extraLabel != null)
              Text(widget.extraLabel!,
                  style: TextStyle(color: widget.accent, fontSize: 22, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),

            if (widget.subLabel != null) ...[
              const SizedBox(height: 2),
              Text(widget.subLabel!,
                  style: const TextStyle(color: _textSec, fontSize: 9, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 4),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Text(widget.title,
                      style: const TextStyle(color: _textSec, fontSize: 12, fontWeight: FontWeight.w500))),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.arrow_forward_ios_rounded, color: widget.accent, size: 10),
                  ),
                ]),
          ]),
        ),
      ),
    );
  }
}

// ── Styled Dialog ──────────────────────────────────────────────────
class _StyledDialog extends StatelessWidget {
  final String       title;
  final Color        titleColor;
  final IconData     icon;
  final Color        iconColor;
  final String       content;
  final String       confirmLabel;
  final Color        confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  static const Color _card       = Color(0xFF151E30);
  static const Color _cardBorder = Color(0xFF1E2D47);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  const _StyledDialog({
    required this.title,        required this.titleColor,
    required this.icon,         required this.iconColor,
    required this.content,      required this.confirmLabel,
    required this.confirmColor, required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.3))),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(color: _textSec, fontSize: 13, height: 1.6), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: _textSec,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _cardBorder))),
              child: const Text("Cancel"),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ]),
      ),
    );
  }
}