import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/health_service.dart';
import '../services/training_reminder_notification_service.dart';
import 'auth_screen.dart';
import 'hr_zones_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // UI Expansion States
  bool _showTheme = false;
  bool _showUnits = false;
  bool _showLang = false;

  @override
  void initState() {
    super.initState();
  }

  void _logout(BuildContext context) {
    Provider.of<AppState>(context, listen: false).logout();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _triggerAutoSave() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.userProfile != null) {
        appState.updateProfile(appState.userProfile!);
      }
    });
  }

  Future<void> _setNotificationsEnabled(
      UserProfile profile, bool enabled) async {
    final appState = Provider.of<AppState>(context, listen: false);

    if (!enabled) {
      await TrainingReminderNotificationService.instance
          .cancelDailyTrainingReminder();
      if (!mounted) return;
      setState(() => profile.notificationsEnabled = false);
      appState.updateProfile(profile);
      return;
    }

    final granted = await TrainingReminderNotificationService.instance
        .requestPermissionAndSchedule();
    if (!mounted) return;

    setState(() => profile.notificationsEnabled = granted);
    appState.updateProfile(profile);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(granted
            ? 'Reminder serale attivato alle 21:00.'
            : 'Permesso notifiche non concesso. Controlla le impostazioni del telefono.'),
        backgroundColor: granted ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  Future<void> _setThemeMode(UserProfile profile, String themeMode) async {
    setState(() => profile.themeMode = themeMode);
    await Provider.of<AppState>(context, listen: false).setThemeMode(themeMode);
  }

  Future<void> _clearHealthCacheAndResync(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Attenzione',
            style: TextStyle(color: AppTheme.textHighEmphasis)),
        content: Text(
          'Questa azione svuota la cache locale degli score salute e forza una nuova sincronizzazione da Apple Health / Health Connect. Non elimina allenamenti o metriche salvate, ma gli score potrebbero cambiare se i dati importati sono diversi. Vuoi continuare?',
          style: TextStyle(color: AppTheme.textMediumEmphasis),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annulla',
                style: TextStyle(color: AppTheme.textMediumEmphasis)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Svuota e risincronizza',
                style: TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pulizia cache e sincronizzazione in corso...')));

    try {
      final removedCount = await Provider.of<AppState>(context, listen: false)
          .clearHealthScoreCacheAndResync(DateTime.now());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Cache salute svuotata ($removedCount elementi). Sincronizzazione completata.'),
          backgroundColor: AppTheme.success));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante la risincronizzazione: $e'),
          backgroundColor: AppTheme.error));
    }
  }

  void _showDeviceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _DeviceManagementModal(),
    );
  }

  Future<void> _showImagePickerOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: Text('Scatta Foto',
                    style: TextStyle(color: AppTheme.textHighEmphasis)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: Text('Scegli da Galleria',
                    style: TextStyle(color: AppTheme.textHighEmphasis)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!kIsWeb) {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Permesso fotocamera negato.',
                      style: TextStyle(color: AppTheme.textHighEmphasis)),
                  backgroundColor: AppTheme.error),
            );
          }
          return;
        }
      } else {
        await Permission.photos.request();
      }
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Caricamento in corso...'),
                backgroundColor: AppTheme.primary),
          );
        }
        final appState = Provider.of<AppState>(context, listen: false);
        final publicUrl = await appState.uploadProfileImage(File(image.path));

        if (publicUrl != null) {
          setState(() {
            appState.userProfile?.avatarUrl = publicUrl;
          });
          _triggerAutoSave();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Immagine profilo aggiornata!'),
                  backgroundColor: AppTheme.success),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Errore di caricamento.'),
                  backgroundColor: AppTheme.error),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore: $e',
                  style: TextStyle(color: AppTheme.textHighEmphasis)),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  ImageProvider? _getAvatarImage(String url) {
    if (url.isEmpty) return null;
    if (kIsWeb) {
      return NetworkImage(url);
    } else {
      if (url.startsWith('http') || url.startsWith('https')) {
        return NetworkImage(url);
      } else {
        return FileImage(File(url));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final p = appState.userProfile;
    if (p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isCoach = p.role == 'coach';
    final themeMode = appState.themeMode;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Impostazioni Profilo', style: TextStyle(fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Container(color: Colors.white.withValues(alpha: 0.05), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // Avatar Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    _showImagePickerOptions(context);
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.card,
                          border: Border.all(color: AppTheme.card, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10))
                          ],
                          image: p.avatarUrl.isNotEmpty
                              ? DecorationImage(
                                  image: _getAvatarImage(p.avatarUrl)!,
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: p.avatarUrl.isEmpty
                            ? Icon(Icons.person,
                                size: 50, color: AppTheme.textMediumEmphasis)
                            : null,
                      ),
                      // Camera overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 28),
                        ),
                      ),
                      // Edit badge
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.background, width: 2),
                          ),
                          child: const Icon(Icons.edit,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${p.firstName} ${p.lastName}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle,
                        color: AppTheme.secondary, size: 16),
                    SizedBox(width: 4),
                    Text('PRO MEMBER',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMediumEmphasis,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Personal Details Form
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dati Personali',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NOME',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMediumEmphasis)),
                          const SizedBox(height: 6),
                          TextFormField(
                            initialValue: p.firstName,
                            onChanged: (val) {
                              setState(() => p.firstName = val);
                              _triggerAutoSave();
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppTheme.card,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COGNOME',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMediumEmphasis)),
                          const SizedBox(height: 6),
                          TextFormField(
                            initialValue: p.lastName,
                            onChanged: (val) {
                              setState(() => p.lastName = val);
                              _triggerAutoSave();
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppTheme.card,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EMAIL',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMediumEmphasis)),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: p.email,
                      onChanged: (val) {
                        setState(() => p.email = val);
                        _triggerAutoSave();
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.card,
                        prefixIcon: Icon(Icons.mail,
                            color: AppTheme.textMediumEmphasis),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DATA DI NASCITA',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMediumEmphasis)),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: p.birthDate,
                      onChanged: (val) {
                        setState(() => p.birthDate = val);
                        _triggerAutoSave();
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.card,
                        prefixIcon: Icon(Icons.calendar_today,
                            color: AppTheme.textMediumEmphasis),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // App Preferences
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preferenze App',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Theme Selector
                      ListTile(
                        onTap: () => setState(() => _showTheme = !_showTheme),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: Icon(
                              themeMode == AppTheme.darkMode
                                  ? Icons.dark_mode
                                  : Icons.light_mode,
                              color: AppTheme.secondary,
                              size: 16),
                        ),
                        title: const Text('Tema',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                themeMode == AppTheme.darkMode
                                    ? 'Scuro'
                                    : 'Chiaro',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMediumEmphasis)),
                            const SizedBox(width: 8),
                            Icon(
                                _showTheme
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppTheme.textMediumEmphasis),
                          ],
                        ),
                      ),
                      if (_showTheme)
                        Container(
                          color: AppTheme.surface,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              _buildRadioItem(
                                  AppTheme.lightMode, 'Chiaro', themeMode,
                                  (val) {
                                if (val != null) {
                                  _setThemeMode(p, val);
                                }
                              }),
                              _buildRadioItem(
                                  AppTheme.darkMode, 'Scuro', themeMode, (val) {
                                if (val != null) {
                                  _setThemeMode(p, val);
                                }
                              }),
                            ],
                          ),
                        ),
                      Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                          height: 1),

                      // Notifications
                      ListTile(
                        onTap: () => _setNotificationsEnabled(
                            p, !p.notificationsEnabled),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.notifications,
                              color: AppTheme.secondary, size: 16),
                        ),
                        title: const Text('Notifiche',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        subtitle: Text(
                          'Reminder allenamenti alle 21:00',
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis, fontSize: 12),
                        ),
                        trailing: Switch(
                          value: p.notificationsEnabled,
                          onChanged: (val) => _setNotificationsEnabled(p, val),
                          activeThumbColor: AppTheme.secondary,
                        ),
                      ),
                      Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                          height: 1),

                      // Units Selector
                      ListTile(
                        onTap: () => setState(() => _showUnits = !_showUnits),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.straighten,
                              color: AppTheme.secondary, size: 16),
                        ),
                        title: const Text('Unità di Misura',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                p.unitSystem == 'metric'
                                    ? 'Metric'
                                    : 'Imperial',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMediumEmphasis)),
                            const SizedBox(width: 8),
                            Icon(
                                _showUnits
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppTheme.textMediumEmphasis),
                          ],
                        ),
                      ),
                      if (_showUnits)
                        Container(
                          color: AppTheme.surface,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              _buildRadioItem(
                                  'metric', 'Metric (kg, cm)', p.unitSystem,
                                  (val) {
                                setState(() => p.unitSystem = val!);
                                _triggerAutoSave();
                              }),
                              _buildRadioItem('imperial', 'Imperial (lbs, ft)',
                                  p.unitSystem, (val) {
                                setState(() => p.unitSystem = val!);
                                _triggerAutoSave();
                              }),
                            ],
                          ),
                        ),
                      Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                          height: 1),

                      // Language Selector
                      ListTile(
                        onTap: () => setState(() => _showLang = !_showLang),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.language,
                              color: AppTheme.secondary, size: 16),
                        ),
                        title: const Text('Lingua',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.language == 'en' ? 'English' : 'Italiano',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMediumEmphasis)),
                            const SizedBox(width: 8),
                            Icon(
                                _showLang
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppTheme.textMediumEmphasis),
                          ],
                        ),
                      ),
                      if (_showLang)
                        Container(
                          color: AppTheme.surface,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              _buildRadioItem('en', 'English', p.language,
                                  (val) {
                                setState(() => p.language = val!);
                                _triggerAutoSave();
                              }),
                              _buildRadioItem('it', 'Italiano', p.language,
                                  (val) {
                                setState(() => p.language = val!);
                                _triggerAutoSave();
                              }),
                            ],
                          ),
                        ),
                      Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                          height: 1),

                      if (!isCoach) ...[
                        // Heart Rate Zones
                        ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HrZonesScreen()),
                            );
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color:
                                    AppTheme.secondary.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.favorite_outline,
                                color: AppTheme.secondary, size: 16),
                          ),
                          title: const Text('Zone Cardiache',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          trailing: Icon(Icons.keyboard_arrow_right,
                              size: 16, color: AppTheme.textMediumEmphasis),
                        ),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05),
                            height: 1),

                        // Health Permissions (Apple Health / Google Health Connect)
                        ListTile(
                          onTap: () async {
                            // Ask for permissions which will also initialize the service
                            await HealthService().requestPermissions();
                            // Open app settings since OS-level permissions usually need manual toggling after first time
                            openAppSettings();
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color:
                                    AppTheme.secondary.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.health_and_safety_outlined,
                                color: AppTheme.secondary, size: 16),
                          ),
                          title: const Text('Consensi Salute',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: Text(
                              Platform.isIOS
                                  ? 'Apple Health'
                                  : 'Health Connect',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMediumEmphasis)),
                          trailing: Icon(Icons.open_in_new,
                              size: 16, color: AppTheme.textMediumEmphasis),
                        ),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05),
                            height: 1),

                        ListTile(
                          onTap: () => _clearHealthCacheAndResync(context),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.delete_sweep_outlined,
                                color: AppTheme.error, size: 16),
                          ),
                          title: const Text('Svuota cache salute',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: Text(
                              'Risincronizza Apple Health / Health Connect',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMediumEmphasis)),
                          trailing: Icon(Icons.keyboard_arrow_right,
                              size: 16, color: AppTheme.textMediumEmphasis),
                        ),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05),
                            height: 1),

                        // Connected Devices
                        ListTile(
                          onTap: _showDeviceModal,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color:
                                    AppTheme.secondary.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.watch,
                                color: AppTheme.secondary, size: 16),
                          ),
                          title: const Text('Dispositivi Connessi',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (p.connectedDevices.isNotEmpty)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: AppTheme.success,
                                      shape: BoxShape.circle),
                                ),
                              const SizedBox(width: 8),
                              Text('${p.connectedDevices.length} attivi',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMediumEmphasis)),
                              const SizedBox(width: 8),
                              Icon(Icons.keyboard_arrow_right,
                                  size: 16, color: AppTheme.textMediumEmphasis),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // Logout Button
          Center(
            child: TextButton(
              onPressed: () => _logout(context),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'LOG OUT',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioItem(String value, String label, String groupValue,
      ValueChanged<String?> onChanged) {
    bool isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.textMediumEmphasis)),
            if (isSelected)
              const Icon(Icons.check, color: AppTheme.secondary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// DEVICE MANAGEMENT MODAL
// ---------------------------------------------------------

class _DeviceManagementModal extends StatelessWidget {
  const _DeviceManagementModal();

  void _disconnectDevice(BuildContext context, String id) {
    final state = Provider.of<AppState>(context, listen: false);
    final p = state.userProfile!;
    p.connectedDevices.removeWhere((d) => d.id == id);
    state.updateProfile(p);
  }

  void _connectDevice(
      BuildContext context, String provider, String name, String type) async {
    if (provider == 'health_connect') {
      bool success = await HealthService().requestPermissions();

      if (!context.mounted) return;

      if (success) {
        final state = Provider.of<AppState>(context, listen: false);
        final p = state.userProfile!;
        p.connectedDevices.add(ConnectedDevice(
          id: '${provider}_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          provider: provider,
          type: type,
          status: 'connected',
          lastSync: 'Adesso',
        ));
        state.updateProfile(p);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Connesso con successo!'),
            backgroundColor: AppTheme.success));

        // Prompt for immediate sync
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text('Sincronizza Dati',
                style: TextStyle(color: AppTheme.textHighEmphasis)),
            content: Text(
                'Vuoi importare ora gli allenamenti degli ultimi 7 giorni?',
                style: TextStyle(color: AppTheme.textMediumEmphasis)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Non ora',
                    style: TextStyle(color: AppTheme.textMediumEmphasis)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sincronizza',
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sincronizzazione in corso...')));
          await state.syncHealthWorkouts();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Sincronizzazione completata!'),
              backgroundColor: AppTheme.success));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permessi negati o errore di connessione.'),
            backgroundColor: AppTheme.error));
      }
      return;
    }

    // Simulate Connect for other devices
    final state = Provider.of<AppState>(context, listen: false);
    final p = state.userProfile!;
    p.connectedDevices.add(ConnectedDevice(
      id: '${provider}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      provider: provider,
      type: type,
      status: 'connected',
      batteryLevel: type == 'ble' ? 88 : null,
      lastSync: 'Adesso',
    ));
    state.updateProfile(p);
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<AppState>(context).userProfile!;
    final connected = p.connectedDevices;

    // Providers standard definition
    final integrators = [
      {
        'id': 'health_connect',
        'name': Platform.isIOS ? 'Apple Health' : 'Google Health Connect',
        'type': 'api',
        'color':
            Platform.isIOS ? const Color(0xFFFFFFFF) : const Color(0xFF4285F4),
        'icon': Icons.favorite
      },
      {
        'id': 'polar',
        'name': 'Polar Flow / BLE',
        'type': 'ble',
        'color': const Color(0xFFE60012),
        'icon': Icons.favorite
      },
      {
        'id': 'generic',
        'name': 'Standard BLE Monitor',
        'type': 'ble',
        'color': const Color(0xFF0070F3),
        'icon': Icons.bluetooth
      },
    ];

    final available = integrators
        .where((i) => !connected.any((d) => d.provider == i['id']))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        children: [
          // Drag Handle & Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05)))),
            child: Column(
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dispositivi Connessi',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon:
                          Icon(Icons.close, color: AppTheme.textMediumEmphasis),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (connected.isNotEmpty) ...[
                  Text('I TUOI DISPOSITIVI',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMediumEmphasis,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  ...connected.map((d) {
                    final meta = integrators.firstWhere(
                        (i) => i['id'] == d.provider,
                        orElse: () => integrators.last);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: (meta['color'] as Color)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: Icon(meta['icon'] as IconData,
                                color: meta['color'] as Color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.circle,
                                        color: AppTheme.success, size: 8),
                                    const SizedBox(width: 4),
                                    const Text('Connesso',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.success)),
                                    if (d.batteryLevel != null) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.battery_full,
                                          size: 12,
                                          color: AppTheme.textMediumEmphasis),
                                      const SizedBox(width: 2),
                                      Text('${d.batteryLevel}%',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  AppTheme.textMediumEmphasis)),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (d.provider == 'health_connect') ...[
                            IconButton(
                              icon: const Icon(Icons.sync,
                                  color: AppTheme.primary),
                              tooltip: 'Sincronizza Allenamenti',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.surface,
                                    title: Text('Sincronizza Dati',
                                        style: TextStyle(
                                            color: AppTheme.textHighEmphasis)),
                                    content: Text(
                                        'Vuoi importare gli allenamenti degli ultimi 7 giorni?',
                                        style: TextStyle(
                                            color:
                                                AppTheme.textMediumEmphasis)),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: Text('Annulla',
                                            style: TextStyle(
                                                color: AppTheme
                                                    .textMediumEmphasis)),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Sincronizza',
                                            style: TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Sincronizzazione in corso...')));
                                  await Provider.of<AppState>(context,
                                          listen: false)
                                      .syncHealthWorkouts();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Sincronizzazione completata!'),
                                          backgroundColor: AppTheme.success));
                                }
                              },
                            ),
                          ],
                          IconButton(
                            icon: Icon(Icons.power_off,
                                color: AppTheme.textMediumEmphasis),
                            onPressed: () => _disconnectDevice(context, d.id),
                            tooltip: 'Disconnetti',
                          )
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
                Text('DISPONIBILI',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMediumEmphasis,
                        letterSpacing: 1)),
                const SizedBox(height: 12),
                ...available.map((i) {
                  return InkWell(
                    onTap: () => _connectDevice(context, i['id'] as String,
                        i['name'] as String, i['type'] as String),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(16),
                        color: AppTheme.card,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: (i['color'] as Color)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: Icon(i['icon'] as IconData,
                                color: i['color'] as Color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i['name'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                    i['type'] == 'ble'
                                        ? 'Connessione Diretta Bluetooth'
                                        : 'Sincronizzazione Cloud API',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                          ),
                          Icon(Icons.link,
                              size: 16, color: AppTheme.textMediumEmphasis),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
