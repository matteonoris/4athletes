import 'package:flutter/material.dart';
import '../core/theme.dart';

class CoachAthleteDetailScreen extends StatelessWidget {
  final String athleteName;
  final String initial;

  const CoachAthleteDetailScreen({
    super.key,
    required this.athleteName,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: AppTheme.card, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(initial,
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(athleteName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const Text('Alpine Elite Squad',
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top 3 Stat Cards
            Row(
              children: [
                Expanded(
                    child: _buildStatCard('PRESENZA', '100%', Colors.green)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard(
                        'EXTRA SCI', '1h', const Color(0xFFFF7A00))),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        _buildStatCard('TOT. CAMBI', '237', AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 24),

            // Volume per Specialità
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Volume per Specialità (Cambi)',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('SL',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.85,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('237',
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Charts (Peso, Altezza)
            Row(
              children: [
                Expanded(
                    child: _buildChartCard('Peso', '15', 'kg',
                        [14, 15, 14.5, 15.2, 14.8, 15], Colors.cyan)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildChartCard(
                        'Altezza',
                        '175',
                        'cm',
                        [175, 175, 175, 176, 176, 176],
                        Colors.deepPurpleAccent)),
              ],
            ),
            const SizedBox(height: 32),

            // Profilo Salto
            const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Profilo Salto',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildJumpCard('SQUAT JUMP', '42')),
                const SizedBox(width: 12),
                Expanded(child: _buildJumpCard('CM JUMP', '49')),
                const SizedBox(width: 12),
                Expanded(child: _buildJumpCard('DROP JUMP', '31')),
              ],
            ),
            const SizedBox(height: 32),

            // Massimali (1RM)
            const Row(
              children: [
                Icon(Icons.fitness_center, color: Color(0xFFFF7A00), size: 20),
                SizedBox(width: 8),
                Text('Massimali (1RM)',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _build1RMCard('Back Squat', '154')),
                const SizedBox(width: 16),
                Expanded(child: _build1RMCard('Bench Press', '100')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _build1RMCard('Deadlift', '146')),
                const SizedBox(width: 16),
                Expanded(child: _build1RMCard('Clean', '89')),
              ],
            ),
            const SizedBox(height: 32),

            // Storico Attività
            const Text('Storico Attività',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 16),
            _buildActivityItem('Alpine Skiing', '2026-04-18', '3h',
                Icons.ac_unit, AppTheme.primary),
            _buildActivityItem('Weightlifting', '2023-11-01', '1h 30m',
                Icons.fitness_center, const Color(0xFFFF7A00)),
            _buildActivityItem('Running Road', '2023-10-28', '1h • 10.5km',
                Icons.directions_run, const Color(0xFFFF7A00)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 22)),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, String currentValue, String unit,
      List<double> dataPoints, Color lineColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_weight_outlined,
                  color: AppTheme.textMediumEmphasis, size: 14),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 60,
            child: Stack(
              children: [
                // Axis lines mock
                Align(
                  alignment: Alignment.center,
                  child: Container(
                      height: 1, color: Colors.white.withOpacity(0.05)),
                ),
                // Data points mock using CustomPaint or just simple representation
                CustomPaint(
                  size: const Size(double.infinity, 60),
                  painter: _MiniChartPainter(dataPoints, lineColor),
                ),
                // Current Value Overlay
                Positioned(
                  right: 0,
                  top: 0,
                  child: Text(currentValue,
                      style: TextStyle(
                          color: lineColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('2026-03-31',
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildJumpCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24)),
              const SizedBox(width: 2),
              const Text('cm',
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build1RMCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(width: 4),
              const Text('kg',
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String date, String subtitle,
      IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('$date  •  $subtitle',
              style: const TextStyle(
                  color: AppTheme.textMediumEmphasis, fontSize: 13)),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppTheme.textMediumEmphasis),
        onTap: () {
          // Open details
        },
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _MiniChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final min = data.reduce((a, b) => a < b ? a : b) * 0.95;
    final max = data.reduce((a, b) => a > b ? a : b) * 1.05;
    final range = max - min;

    final path = Path();
    final stepX = size.width / (data.length > 1 ? data.length - 1 : 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = range == 0 ? 0.5 : (data[i] - min) / range;
      final y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Shadow/glow under line
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
    );

    final fillPaint = Paint()
      ..shader =
          gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = range == 0 ? 0.5 : (data[i] - min) / range;
      final y = size.height - (normalizedY * size.height);
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
