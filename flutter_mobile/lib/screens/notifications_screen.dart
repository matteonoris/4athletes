import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';
import 'athlete_event_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final notifications = appState.notifications;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Notifiche',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: notifications.isEmpty
          ? Center(
              child: Text(
                'Nessuna notifica',
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];

                return CustomCard(
                  padding: EdgeInsets.zero,
                  borderColor: notif.isRead ? null : AppTheme.primary,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.background,
                      child: Icon(
                        Icons.event,
                        color: notif.isRead
                            ? AppTheme.textMediumEmphasis
                            : AppTheme.primary,
                      ),
                    ),
                    title: Text(
                      notif.title,
                      style: TextStyle(
                        fontWeight:
                            notif.isRead ? FontWeight.normal : FontWeight.bold,
                        color: AppTheme.textHighEmphasis,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        notif.message,
                        style: TextStyle(color: AppTheme.textMediumEmphasis),
                      ),
                    ),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      // Extract event id if possible. The notification ID is generated as "timestamp_eventid".
                      final parts = notif.id.split('_');
                      if (parts.length > 1) {
                        final eventId = parts.sublist(1).join('_');
                        final event =
                            appState.coachEvents.cast<dynamic>().firstWhere(
                                  (e) => e.id == eventId,
                                  orElse: () => null,
                                );
                        if (event != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AthleteEventScreen(event: event),
                            ),
                          );
                        }
                      }

                      // Also mark as read in DB if supported, for now we just rely on Supabase
                    },
                  ),
                );
              },
            ),
    );
  }
}
