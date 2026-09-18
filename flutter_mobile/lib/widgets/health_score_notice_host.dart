import 'dart:async';

import 'package:flutter/material.dart';

import '../models/health_score_update.dart';
import '../providers/app_state.dart';
import '../services/training_reminder_notification_service.dart';
import '../services/daily_strain_persistence_service.dart';

/// Lives above the Navigator so a calculation can finish on any screen.
class HealthScoreNoticeHost extends StatefulWidget {
  final AppState state;
  final Widget child;
  final VoidCallback onOpenScores;
  const HealthScoreNoticeHost(
      {super.key,
      required this.state,
      required this.child,
      required this.onOpenScores});

  @override
  State<HealthScoreNoticeHost> createState() => _HealthScoreNoticeHostState();
}

class _HealthScoreNoticeHostState extends State<HealthScoreNoticeHost>
    with WidgetsBindingObserver {
  HealthScoreUpdate? _notice;
  int? _handledRevision;
  Timer? _timer;
  bool _foreground = true;
  final _notifications = TrainingReminderNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _handledRevision = widget.state.lastHealthScoreUpdate?.revision;
    widget.state.addListener(_onStateChanged);
    _notifications.healthScoreNotificationTap
        .addListener(_openFromNotification);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _openFromNotification());
  }

  @override
  void didUpdateWidget(covariant HealthScoreNoticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_onStateChanged);
      widget.state.addListener(_onStateChanged);
      _handledRevision = widget.state.lastHealthScoreUpdate?.revision;
      _notice = null;
    }
  }

  void _openFromNotification() {
    if (!mounted || _notifications.healthScoreNotificationTap.value == null) {
      return;
    }
    _notifications.healthScoreNotificationTap.value = null;
    if (widget.state.isLoggedIn &&
        widget.state.userProfile?.role == 'athlete') {
      widget.onOpenScores();
    }
  }

  void _onStateChanged() {
    final update = widget.state.lastHealthScoreUpdate;
    if (!widget.state.isLoggedIn || update == null) {
      if (_notice != null) _scheduleNotice(null);
      return;
    }
    if (update.revision == _handledRevision) return;
    _handledRevision = update.revision;
    if (update.dateKey != localDateKey(DateTime.now())) return;
    _scheduleNotice(update.systemNotificationShown ? null : update);
  }

  void _scheduleNotice(HealthScoreUpdate? update) {
    final owner = widget.state.userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _notice =
          widget.state.isLoggedIn && widget.state.userId == owner
              ? update
              : null);
      _startDismissTimer();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _startDismissTimer() {
    _timer?.cancel();
    if (_foreground &&
        _notice != null &&
        !MediaQuery.accessibleNavigationOf(context)) {
      _timer = Timer(const Duration(seconds: 7), _dismiss);
    }
  }

  void _dismiss() {
    _timer?.cancel();
    if (mounted) setState(() => _notice = null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    _startDismissTimer();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    _notifications.healthScoreNotificationTap
        .removeListener(_openFromNotification);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                        position:
                            Tween(begin: const Offset(0, -.2), end: Offset.zero)
                                .animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic)),
                        child: child)),
                child: _notice == null || !_foreground
                    ? const SizedBox.shrink()
                    : HealthScoreReadyNotice(
                        key: ValueKey(_notice!.revision),
                        update: _notice!,
                        onDismiss: _dismiss,
                        onOpen: () {
                          _dismiss();
                          widget.onOpenScores();
                        }),
              ),
            ),
          ),
        ],
      );
}

class HealthScoreReadyNotice extends StatelessWidget {
  final HealthScoreUpdate update;
  final VoidCallback onOpen, onDismiss;
  const HealthScoreReadyNotice(
      {super.key,
      required this.update,
      required this.onOpen,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: dark ? const Color(0xFF26342F) : const Color(0xFFF3FCF8),
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 4, 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: const Color(0xFF38BA92)
                                  .withValues(alpha: .16),
                              shape: BoxShape.circle),
                          child: Icon(Icons.done_rounded,
                              size: 22,
                              color: dark
                                  ? const Color(0xFF78E1B9)
                                  : const Color(0xFF18775B))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(update.title,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(update.message,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(height: 1.4)),
                            TextButton(
                                onPressed: onOpen,
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft),
                                child: const Text('Vedi i punteggi')),
                          ])),
                      IconButton(
                          key: const ValueKey('dismiss_health_score_notice'),
                          onPressed: onDismiss,
                          icon: const Icon(Icons.close_rounded,
                              size: 18, semanticLabel: 'Chiudi avviso')),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
