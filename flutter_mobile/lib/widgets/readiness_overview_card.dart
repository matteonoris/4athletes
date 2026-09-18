import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

class ReadinessMetricData {
  final IconData icon;
  final String title;
  final String label;
  final String caption;
  final double value;
  final Color color;
  final Color secondaryColor;
  final VoidCallback? onTap;

  const ReadinessMetricData({
    required this.icon,
    required this.title,
    required this.label,
    required this.caption,
    required this.value,
    required this.color,
    required this.secondaryColor,
    this.onTap,
  });

  static const placeholders = [
    ReadinessMetricData(
        icon: Icons.nightlight_round,
        title: 'Sonno',
        label: '--',
        caption: '',
        value: 0,
        color: AppTheme.sleep,
        secondaryColor: Color(0xFFA59AFF)),
    ReadinessMetricData(
        icon: Icons.local_fire_department_rounded,
        title: 'Sforzo',
        label: '--',
        caption: '',
        value: 0,
        color: AppTheme.strain,
        secondaryColor: Color(0xFFFFBE81)),
    ReadinessMetricData(
        icon: Icons.favorite_rounded,
        title: 'Recupero',
        label: '--',
        caption: '',
        value: 0,
        color: AppTheme.recovery,
        secondaryColor: Color(0xFF73D8C2)),
  ];
}

/// A stable three-score layout, including while the first snapshot is loading.
/// The breathing effect conveys activity without suggesting measured progress.
class ReadinessOverviewCard extends StatelessWidget {
  final List<ReadinessMetricData> metrics;
  final String readinessLabel;
  final String insight;
  final bool isLoading;
  final bool isRefreshing;
  final String? progressLabel;

  const ReadinessOverviewCard({
    super.key,
    required this.metrics,
    required this.readinessLabel,
    required this.insight,
    this.isLoading = false,
    this.isRefreshing = false,
    this.progressLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final busy = isLoading || isRefreshing;
    return _BreathingLight(
      active: busy,
      builder: (context, pulse) => Container(
        decoration: AppTheme.panelDecoration(context: context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < metrics.length; i++)
                    Expanded(
                        child: _MetricTile(
                            data: metrics[i],
                            loading: isLoading ||
                                (isRefreshing && metrics[i].label == '--'),
                            pulse: pulse,
                            index: i)),
                ],
              ),
            ),
            Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: ink.withValues(alpha: .07)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 16, 17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8275F4).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12)),
                    child: busy
                        ? SizedBox.square(
                            dimension: 17,
                            child: Center(
                                child: ReadinessSyncPulse(
                                    color: dark
                                        ? const Color(0xFFB8AEFF)
                                        : const Color(0xFF6754C5))))
                        : Icon(Icons.insights_rounded,
                            size: 17,
                            color: dark
                                ? const Color(0xFFB8AEFF)
                                : const Color(0xFF6754C5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            isLoading
                                ? 'Prepariamo i tuoi punteggi'
                                : isRefreshing
                                    ? 'Aggiorniamo i tuoi punteggi'
                                    : readinessLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ink,
                                fontSize: 13)),
                        const SizedBox(height: 5),
                        Text(
                            busy
                                ? '${progressLabel ?? 'Sincronizzazione dei dati salute'}. Puoi esplorare l’app, ti avvisiamo qui.'
                                : insight,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: ink.withValues(alpha: .64),
                                height: 1.5,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final ReadinessMetricData data;
  final bool loading;
  final double pulse;
  final int index;

  const _MetricTile(
      {required this.data,
      required this.loading,
      required this.pulse,
      required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final dark = theme.brightness == Brightness.dark;
    final pending = loading && index < ReadinessMetricData.placeholders.length
        ? ReadinessMetricData.placeholders[index]
        : data;
    final color = pending.color;
    final secondaryColor = pending.secondaryColor;
    final accent = dark ? secondaryColor : color;
    final missing = data.label == '--';
    return Semantics(
      label: loading
          ? '${data.title}: calcolo in corso'
          : '${data.title}: ${data.label}${missing ? '' : ' su 100'}. ${data.caption}',
      button: !loading && data.onTap != null,
      onTap: loading ? null : data.onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : data.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                children: [
                  Text(data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: ink.withValues(alpha: .72),
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: loading ? 84 : 102),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CustomPaint(
                        painter: _ReadinessRingPainter(
                            value: missing ? 0 : data.value,
                            color: color,
                            secondaryColor: secondaryColor,
                            track: ink.withValues(alpha: .07),
                            loading: loading,
                            pulse: pulse),
                        child: Center(
                          child: loading
                              ? Icon(data.icon,
                                  size: 26,
                                  color: accent.withValues(
                                      alpha: .55 + .35 * pulse))
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(data.label,
                                            style: theme
                                                .textTheme.headlineMedium
                                                ?.copyWith(
                                                    color: ink,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 29,
                                                    letterSpacing: -1.2)),
                                        if (!missing)
                                          Text('/ 100',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                      color: ink.withValues(
                                                          alpha: .42),
                                                      fontSize: 9)),
                                      ]),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (loading)
                    Container(
                        width: 38.0 + index * 6,
                        height: 7,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: .12 + .12 * pulse),
                            borderRadius: BorderRadius.circular(6)))
                  else
                    Text(data.caption,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: ink.withValues(alpha: .62),
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadinessRingPainter extends CustomPainter {
  final double value, pulse;
  final Color color, secondaryColor, track;
  final bool loading;

  const _ReadinessRingPainter(
      {required this.value,
      required this.color,
      required this.secondaryColor,
      required this.track,
      required this.loading,
      required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 14) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
        center,
        radius - 5,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: loading ? .03 + .06 * pulse : .07),
            color.withValues(alpha: 0)
          ]).createShader(rect));
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color =
              loading ? color.withValues(alpha: .13 + .14 * pulse) : track);
    if (loading || value <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
              transform: const GradientRotation(-math.pi / 2),
              colors: [secondaryColor, color]).createShader(rect));
  }

  @override
  bool shouldRepaint(_ReadinessRingPainter old) =>
      value != old.value ||
      pulse != old.pulse ||
      loading != old.loading ||
      color != old.color ||
      secondaryColor != old.secondaryColor ||
      track != old.track;
}

class ReadinessSyncPulse extends StatelessWidget {
  final Color color;
  const ReadinessSyncPulse({super.key, required this.color});

  @override
  Widget build(BuildContext context) => _BreathingLight(
      active: true,
      builder: (_, pulse) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .45 + .55 * pulse))));
}

class _BreathingLight extends StatefulWidget {
  final bool active;
  final Widget Function(BuildContext, double) builder;
  const _BreathingLight({required this.active, required this.builder});

  @override
  State<_BreathingLight> createState() => _BreathingLightState();
}

class _BreathingLightState extends State<_BreathingLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  void _updateAnimation() {
    if (widget.active &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = .5;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant _BreathingLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(
          context, Curves.easeInOut.transform(_controller.value)));
}
