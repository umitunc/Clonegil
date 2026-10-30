import 'package:flutter/material.dart';

/// 1:1 Apple HIG Tasarımında Disk İkonu / Logo
class AppleDiskLogo extends StatelessWidget {
  final double size;

  const AppleDiskLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF0284C7),
                  Color(0xFF0369A1),
                  Color(0xFF091224),
                ]
              : const [
                  Color(0xFF0EA5E9),
                  Color(0xFF0284C7),
                  Color(0xFF1E3A8A),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF0284C7) : const Color(0xFF0369A1))
                .withValues(alpha: 0.38),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.30 : 0.45),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.225),
        child: Stack(
          children: [
            // Apple HIG tarzı üst ışık yansıması (specular highlight)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size * 0.45,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.35 : 0.45),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Disk custom vector çizimi
            Center(
              child: CustomPaint(
                size: Size(size * 0.74, size * 0.74),
                painter: const _AppleDiskPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleDiskPainter extends CustomPainter {
  const _AppleDiskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Metalik sürücü kasası (beveled hard drive chassis)
    final chassisRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.16),
    );
    final chassisPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1E293B),
          Color(0xFF0A0F1D),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(chassisRect, chassisPaint);

    final chassisBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.08),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(chassisRect, chassisBorder);

    // 2. Manyetik Plaka (Disk Platter)
    final center = Offset(w * 0.52, h * 0.48);
    final platterRadius = w * 0.36;

    final platterPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFFE2E8F0),
          Color(0xFF94A3B8),
          Color(0xFF475569),
          Color(0xFF1E293B),
        ],
        stops: const [0.0, 0.40, 0.80, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: platterRadius));
    canvas.drawCircle(center, platterRadius, platterPaint);

    // Yansıma halkası
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawCircle(center, platterRadius * 0.65, groovePaint);

    // Mil Göbeği (Spindle Hub)
    final hubPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Colors.white,
          Color(0xFF64748B),
          Color(0xFF0F172A),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: platterRadius * 0.28),
      );
    canvas.drawCircle(center, platterRadius * 0.28, hubPaint);
    canvas.drawCircle(
      center,
      platterRadius * 0.10,
      Paint()..color = const Color(0xFF0B0F19),
    );

    // 3. Okuma / Yazma Kolu (Actuator Arm)
    final pivot = Offset(w * 0.20, h * 0.80);
    canvas.drawCircle(
      pivot,
      w * 0.08,
      Paint()..color = const Color(0xFF64748B),
    );
    canvas.drawCircle(pivot, w * 0.04, Paint()..color = Colors.white);

    final armPath = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(center.dx - w * 0.09, center.dy + h * 0.08)
      ..lineTo(center.dx - w * 0.02, center.dy + h * 0.05)
      ..close();
    final armPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFCBD5E1), Color(0xFFF1F5F9)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(armPath, armPaint);

    // Kol başlığı (head tip)
    canvas.drawCircle(
      Offset(center.dx - w * 0.03, center.dy + h * 0.06),
      w * 0.03,
      Paint()..color = const Color(0xFF38BDF8),
    );

    // 4. Durum LED'leri: Mavi (CLONE) ve Turuncu (GİL)
    final blueLed = Offset(w * 0.84, h * 0.20);
    final orangeLed = Offset(w * 0.84, h * 0.36);

    // Mavi LED (CLONE)
    canvas.drawCircle(
      blueLed,
      w * 0.06,
      Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      blueLed,
      w * 0.03,
      Paint()..color = const Color(0xFF38BDF8),
    );

    // Turuncu LED (GİL)
    canvas.drawCircle(
      orangeLed,
      w * 0.06,
      Paint()..color = const Color(0xFFFB923C).withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      orangeLed,
      w * 0.03,
      Paint()..color = const Color(0xFFFB923C),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CLONE (Mavi) & GİL (Turuncu) tipografi bileşeni
class ClonegilBrandText extends StatelessWidget {
  final double fontSize;
  final double letterSpacing;

  const ClonegilBrandText({
    super.key,
    this.fontSize = 20,
    this.letterSpacing = 1.3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'CLONE',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              shadows: isDark
                  ? [
                      Shadow(
                        color:
                            const Color(0xFF38BDF8).withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
          ),
          TextSpan(
            text: 'GİL',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
              color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
              shadows: isDark
                  ? [
                      Shadow(
                        color:
                            const Color(0xFFFB923C).withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

