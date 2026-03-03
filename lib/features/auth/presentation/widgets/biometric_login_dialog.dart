import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';

/// Full-screen Face ID / biometric scan overlay.
///
/// Shows a sleek scanning animation, then calls [onAuthenticated] on success.
/// On web preview this is purely visual; on real devices it would pair with
/// local_auth for actual biometric authentication.
class BiometricLoginDialog extends StatefulWidget {
  final String email;
  final VoidCallback onAuthenticated;
  final VoidCallback onCancel;

  const BiometricLoginDialog({
    super.key,
    required this.email,
    required this.onAuthenticated,
    required this.onCancel,
  });

  @override
  State<BiometricLoginDialog> createState() => _BiometricLoginDialogState();
}

class _BiometricLoginDialogState extends State<BiometricLoginDialog>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _scanLine;
  late Animation<double> _pulseScale;
  late Animation<double> _successScale;

  bool _success = false;
  bool _callbackFired = false;

  @override
  void initState() {
    super.initState();

    // Scan line moves up and down
    _scanController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scanController, curve: Curves.easeInOut));

    // Pulsing ring
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // Success checkmark
    _successController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut));

    // Auto-complete scan after delay
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() {
        _success = true;
      });
      _scanController.stop();
      _pulseController.stop();
      _successController.forward();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        // Only fire callback once
        if (!_callbackFired) {
          _callbackFired = true;
          widget.onAuthenticated();
        }
      });
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BmbColors.deepNavy.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: BmbColors.textTertiary),
                    onPressed: widget.onCancel,
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BmbColors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.face,
                            color: BmbColors.blue, size: 14),
                        const SizedBox(width: 4),
                        Text('Face ID',
                            style: TextStyle(
                                color: BmbColors.blue,
                                fontSize: 12,
                                fontWeight: BmbFontWeights.semiBold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            // Face scan area
            _buildScanArea(),
            const SizedBox(height: 24),
            // Status text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _success
                  ? Column(
                      key: const ValueKey('success'),
                      children: [
                        Text('Welcome Back!',
                            style: TextStyle(
                                color: BmbColors.successGreen,
                                fontSize: 20,
                                fontWeight: BmbFontWeights.bold,
                                fontFamily: 'ClashDisplay')),
                        const SizedBox(height: 4),
                        Text(widget.email,
                            style: TextStyle(
                                color: BmbColors.textSecondary, fontSize: 13)),
                      ],
                    )
                  : Column(
                      key: const ValueKey('scanning'),
                      children: [
                        Text('Look at the screen',
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 20,
                                fontWeight: BmbFontWeights.bold,
                                fontFamily: 'ClashDisplay')),
                        const SizedBox(height: 4),
                        Text('Verifying your identity...',
                            style: TextStyle(
                                color: BmbColors.textSecondary, fontSize: 13)),
                      ],
                    ),
            ),
            const Spacer(flex: 1),
            // Bottom hint
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: TextButton(
                onPressed: widget.onCancel,
                child: Text('Use password instead',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanArea() {
    const size = 180.0;
    return SizedBox(
      width: size + 40,
      height: size + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring
          AnimatedBuilder(
            animation: _pulseScale,
            builder: (_, child) => Transform.scale(
              scale: _success ? 1.0 : _pulseScale.value,
              child: child,
            ),
            child: Container(
              width: size + 30,
              height: size + 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _success
                      ? BmbColors.successGreen.withValues(alpha: 0.6)
                      : BmbColors.blue.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
          ),
          // Main circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _success
                      ? BmbColors.successGreen.withValues(alpha: 0.15)
                      : BmbColors.blue.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: _success
                    ? BmbColors.successGreen
                    : BmbColors.blue.withValues(alpha: 0.6),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: _success
                  ? ScaleTransition(
                      scale: _successScale,
                      child: Icon(Icons.check_circle,
                          color: BmbColors.successGreen, size: 72),
                    )
                  : Stack(
                      children: [
                        // Face icon
                        Center(
                          child: Icon(Icons.face,
                              color: BmbColors.blue.withValues(alpha: 0.3),
                              size: 80),
                        ),
                        // Scan line
                        AnimatedBuilder(
                          animation: _scanLine,
                          builder: (_, __) => Positioned(
                            top: _scanLine.value * (size - 4),
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    BmbColors.blue.withValues(alpha: 0.8),
                                    BmbColors.blue,
                                    BmbColors.blue.withValues(alpha: 0.8),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: BmbColors.blue.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          // Corner brackets (like a real scanner)
          ..._buildCornerBrackets(size),
        ],
      ),
    );
  }

  List<Widget> _buildCornerBrackets(double size) {
    final color = _success ? BmbColors.successGreen : BmbColors.blue;
    const len = 24.0;
    const thick = 3.0;
    return [
      // Top-left
      Positioned(
        top: 20 - 4,
        left: 20 - 4,
        child: _cornerBracket(color, len, thick, topLeft: true),
      ),
      // Top-right
      Positioned(
        top: 20 - 4,
        right: 20 - 4,
        child: _cornerBracket(color, len, thick, topRight: true),
      ),
      // Bottom-left
      Positioned(
        bottom: 20 - 4,
        left: 20 - 4,
        child: _cornerBracket(color, len, thick, bottomLeft: true),
      ),
      // Bottom-right
      Positioned(
        bottom: 20 - 4,
        right: 20 - 4,
        child: _cornerBracket(color, len, thick, bottomRight: true),
      ),
    ];
  }

  Widget _cornerBracket(Color color, double len, double thick,
      {bool topLeft = false,
      bool topRight = false,
      bool bottomLeft = false,
      bool bottomRight = false}) {
    return SizedBox(
      width: len,
      height: len,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          thickness: thick,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter({
    required this.color,
    required this.thickness,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (topLeft) {
      canvas.drawLine(Offset(0, size.height * 0.4), Offset.zero, paint);
      canvas.drawLine(Offset.zero, Offset(size.width * 0.4, 0), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(size.width, size.height * 0.4),
          Offset(size.width, 0), paint);
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width * 0.6, 0), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(
          Offset(0, size.height * 0.6), Offset(0, size.height), paint);
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width * 0.4, size.height), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(size.width, size.height * 0.6),
          Offset(size.width, size.height), paint);
      canvas.drawLine(Offset(size.width, size.height),
          Offset(size.width * 0.6, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
