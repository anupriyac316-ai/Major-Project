import 'package:flutter/material.dart';
import 'admin_login.dart';
import 'admin_register.dart';

class AdminAuthPage extends StatefulWidget {
  const AdminAuthPage({super.key});

  @override
  State<AdminAuthPage> createState() => _AdminAuthPageState();
}

class _AdminAuthPageState extends State<AdminAuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 700,
          height: 500,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, spreadRadius: 2)
            ],
          ),
          child: Row(
            children: [
              // LEFT PANEL
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2196F3),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'WELCOME BACK\nAdmin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // RIGHT PANEL
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.black54,
                        tabs: const [
                          Tab(text: 'Login'),
                          Tab(text: 'Register'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: const [
                            AdminLoginPage(),
                            AdminRegisterPage(),
                          ],
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
    );
  }
}
