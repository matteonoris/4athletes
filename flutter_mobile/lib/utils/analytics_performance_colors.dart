import 'package:flutter/material.dart';

import 'analytics_performance_benchmarks.dart';

Color? analyticsPerformanceCardColor(
  Brightness brightness,
  AnalyticsPerformanceBand band,
) {
  final isDark = brightness == Brightness.dark;
  return switch (band) {
    AnalyticsPerformanceBand.neutral => null,
    AnalyticsPerformanceBand.negative =>
      isDark ? const Color(0xFF52252B) : const Color(0xFFFFD9DC),
    AnalyticsPerformanceBand.discrete =>
      isDark ? const Color(0xFF514316) : const Color(0xFFFFEFB3),
    AnalyticsPerformanceBand.positive =>
      isDark ? const Color(0xFF174333) : const Color(0xFFD7F4E3),
  };
}
