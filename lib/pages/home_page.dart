import 'package:flutter/material.dart';
import 'admin_login.dart';
import 'admin_register.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {

  // ── Design tokens ───────────────────────────────────────────────
  static const Color _bg         = Color(0xFF050810);
  static const Color _card       = Color(0xFF0F1624);
  static const Color _cardBorder = Color(0xFF1A2740);
  static const Color _teal       = Color(0xFF00E5CC);
  static const Color _indigo     = Color(0xFF7C6FFF);
  static const Color _rose       = Color(0xFFFF4D8D);
  static const Color _gold       = Color(0xFFFFB547);
  static const Color _textPri    = Color(0xFFEEF2FF);
  static const Color _textSec    = Color(0xFF7A8DB0);

  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late AnimationController _orb3Ctrl;
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;
  late Animation<double> _orb3Anim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _orb1Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _orb2Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _orb3Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _orb1Anim = Tween<double>(begin: 0, end: 30)
        .animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2Anim = Tween<double>(begin: 0, end: 24)
        .animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    _orb3Anim = Tween<double>(begin: 0, end: 20)
        .animate(CurvedAnimation(parent: _orb3Ctrl, curve: Curves.easeInOut));

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack));
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _orb3Ctrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Animated background orbs ──────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_orb1Ctrl, _orb2Ctrl, _orb3Ctrl]),
            builder: (_, __) {
              return Stack(children: [
                // Orb 1 — teal top-right
                Positioned(
                  top: -80 + _orb1Anim.value,
                  right: -60,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _teal.withOpacity(0.18),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Orb 2 — indigo center-left
                Positioned(
                  top: size.height * 0.3 - _orb2Anim.value,
                  left: -80,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _indigo.withOpacity(0.2),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Orb 3 — rose bottom-right
                Positioned(
                  bottom: 80 + _orb3Anim.value,
                  right: -50,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _rose.withOpacity(0.15),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Faint star grid overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StarGridPainter(color: _teal.withOpacity(0.04)),
                  ),
                ),
              ]);
            },
          ),

          // ── Content ───────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // ── Logo ──────────────────────────────────
                        ScaleTransition(
                          scale: _scaleAnim,
                          child: AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, child) {
                              return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer glow ring (pulsing)
                                    Container(
                                      width: 148 * _pulseAnim.value,
                                      height: 148 * _pulseAnim.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _teal.withOpacity(
                                              0.15 * _pulseAnim.value),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    // Mid ring
                                    Container(
                                      width: 126,
                                      height: 126,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _teal.withOpacity(0.3),
                                            width: 1.5),
                                        gradient: RadialGradient(colors: [
                                          _teal.withOpacity(0.05),
                                          Colors.transparent,
                                        ]),
                                      ),
                                    ),
                                    // Logo container
                                    Container(
                                      width: 104,
                                      height: 104,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            _teal.withOpacity(0.6),
                                            _indigo.withOpacity(0.6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _teal.withOpacity(0.35),
                                            blurRadius: 30,
                                            spreadRadius: 2,
                                          ),
                                          BoxShadow(
                                            color: _indigo.withOpacity(0.2),
                                            blurRadius: 50,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF0F1624),
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            'assets/logo.jpeg',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]);
                            },
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Brand name ────────────────────────────
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [_teal, _indigo],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'CASC',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 6,
                              height: 1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Admin portal label
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                width: 30,
                                height: 1,
                                color: _teal.withOpacity(0.4)),
                            const SizedBox(width: 10),
                            const Text(
                              'Admin Portal',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textPri,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                                width: 30,
                                height: 1,
                                color: _teal.withOpacity(0.4)),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'College Administration System',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSec.withOpacity(0.8),
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Quote card ────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: _teal.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _gold.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _gold.withOpacity(0.25)),
                                ),
                                child: const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: _gold,
                                    size: 22),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  '"Manage your college efficiently\nwith real-time data"',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: _textSec,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Feature pills row ─────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FeaturePill(
                                icon: Icons.people_alt_outlined,
                                label: "Students",
                                color: _teal),
                            const SizedBox(width: 10),
                            _FeaturePill(
                                icon: Icons.school_outlined,
                                label: "Staff",
                                color: _indigo),
                            const SizedBox(width: 10),
                            _FeaturePill(
                                icon: Icons.bar_chart_rounded,
                                label: "Analytics",
                                color: _rose),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ── ACCESS CONTROL card ───────────────────
                        Container(
                          constraints: const BoxConstraints(maxWidth: 380),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: _teal.withOpacity(0.2), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: _teal.withOpacity(0.08),
                                blurRadius: 40,
                                spreadRadius: 2,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: _indigo.withOpacity(0.06),
                                blurRadius: 60,
                                spreadRadius: 5,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Card header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _teal.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: _teal.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: _teal.withOpacity(0.15),
                                        borderRadius:
                                        BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.admin_panel_settings_rounded,
                                          color: _teal,
                                          size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'ACCESS CONTROL',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _teal,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // LOGIN button — full width, glowing
                              _GlowButton(
                                label: 'LOGIN',
                                icon: Icons.login_rounded,
                                accentColor: _teal,
                                filled: true,
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const AdminLoginPage()),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // REGISTER button — outlined
                              _GlowButton(
                                label: 'REGISTER',
                                icon: Icons.person_add_alt_1_rounded,
                                accentColor: _indigo,
                                filled: false,
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const AdminRegisterPage()),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Divider
                              Row(children: [
                                Expanded(
                                    child: Divider(
                                        color: _cardBorder, thickness: 0.8)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _teal.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: _cardBorder, thickness: 0.8)),
                              ]),

                              const SizedBox(height: 16),

                              // Support link (logic unchanged — onTap is empty)
                              InkWell(
                                onTap: () {
                                  // Add support contact action
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.help_outline_rounded,
                                          size: 14, color: _textSec),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Need help? Contact support',
                                        style: TextStyle(
                                          color: _textSec,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Footer ────────────────────────────────
                        Column(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _dot(_teal),
                              const SizedBox(width: 6),
                              _dot(_indigo),
                              const SizedBox(width: 6),
                              _dot(_rose),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '© 2024 CASC Admin Panel v2.0',
                            style: TextStyle(
                              color: _textSec.withOpacity(0.6),
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    decoration:
    BoxDecoration(color: color.withOpacity(0.5), shape: BoxShape.circle),
  );
}

// ── Feature Pill ─────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeaturePill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

// ── Glow Button ──────────────────────────────────────────────────────
class _GlowButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final bool filled;
  final VoidCallback onPressed;

  const _GlowButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.filled,
    required this.onPressed,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const Color _bg    = Color(0xFF050810);
  static const Color _textPri = Color(0xFFEEF2FF);

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _ctrl,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onPressed();
        },
        onTapCancel: () => _ctrl.forward(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: widget.filled
                ? widget.accentColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.accentColor
                  .withOpacity(widget.filled ? 0 : 0.5),
              width: 1.5,
            ),
            boxShadow: widget.filled
                ? [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: widget.accentColor.withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
            ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.filled
                    ? _bg
                    : widget.accentColor,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: widget.filled ? _bg : widget.accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Star Grid Painter ────────────────────────────────────────────────
class _StarGridPainter extends CustomPainter {
  final Color color;
  _StarGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 28.0;
    const r = 1.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StarGridPainter old) => old.color != color;
}