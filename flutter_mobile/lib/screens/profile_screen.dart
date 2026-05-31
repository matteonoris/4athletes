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
import 'auth_screen.dart';
import 'hr_zones_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // UI Expansion States
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
                title: const Text('Scatta Foto', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Scegli da Galleria', style: TextStyle(color: Colors.white)),
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
              const SnackBar(content: Text('Permesso fotocamera negato.', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.error),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caricamento in corso...'), backgroundColor: AppTheme.primary),
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
              const SnackBar(content: Text('Immagine profilo aggiornata!'), backgroundColor: AppTheme.success),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Errore di caricamento.'), backgroundColor: AppTheme.error),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.error),
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
    final p = Provider.of<AppState>(context).userProfile;
    if (p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Impostazioni Profilo', style: TextStyle(fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withValues(alpha: 0.05), height: 1),
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
                            ? const Icon(Icons.person,
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
                const Row(
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

          // Vitals Grid
          if (p.role != 'coach')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dati Fisiologici',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [

                    // Height (Editable)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.straighten,
                                    size: 14,
                                    color: AppTheme.textMediumEmphasis),
                                SizedBox(width: 4),
                                Text('ALTEZZA',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: p.height.toString(),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      fillColor: Colors.transparent,
                                      filled: false,
                                    ),
                                    onChanged: (val) {
                                      setState(() => p.height = double.tryParse(val) ?? p.height);
                                      _triggerAutoSave();
                                    },
                                  ),
                                ),
                                Text(p.unitSystem == 'metric' ? 'cm' : 'ft',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Max HR (Editable)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.favorite,
                                    size: 14,
                                    color: AppTheme.textMediumEmphasis),
                                SizedBox(width: 4),
                                Text('MAX HR',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: p.maxHr.toString(),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      fillColor: Colors.transparent,
                                      filled: false,
                                    ),
                                    onChanged: (val) {
                                      setState(() => p.maxHr = int.tryParse(val) ?? p.maxHr);
                                      _triggerAutoSave();
                                    },
                                  ),
                                ),
                                const Text('bpm',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
                          const Text('NOME',
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
                          const Text('COGNOME',
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
                    const Text('EMAIL',
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
                        prefixIcon: const Icon(Icons.mail,
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
                    const Text('DATA DI NASCITA',
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
                        prefixIcon: const Icon(Icons.calendar_today,
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Notifications
                      ListTile(
                        onTap: () {
                          setState(() => p.notificationsEnabled = !p.notificationsEnabled);
                          _triggerAutoSave();
                        },
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
                        trailing: Switch(
                          value: p.notificationsEnabled,
                          onChanged: (val) {
                            setState(() => p.notificationsEnabled = val);
                            _triggerAutoSave();
                          },
                          activeThumbColor: AppTheme.secondary,
                        ),
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),

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
                                style: const TextStyle(
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
                                  'metric',
                                  'Metric (kg, cm)',
                                  p.unitSystem,
                                  (val) {
                                    setState(() => p.unitSystem = val!);
                                    _triggerAutoSave();
                                  }),
                              _buildRadioItem(
                                  'imperial',
                                  'Imperial (lbs, ft)',
                                  p.unitSystem,
                                  (val) {
                                    setState(() => p.unitSystem = val!);
                                    _triggerAutoSave();
                                  }),
                            ],
                          ),
                        ),
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),

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
                                style: const TextStyle(
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
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),

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
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.favorite_outline,
                              color: AppTheme.secondary, size: 16),
                        ),
                        title: const Text('Zone Cardiache',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        trailing: const Icon(Icons.keyboard_arrow_right,
                            size: 16, color: AppTheme.textMediumEmphasis),
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),

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
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.health_and_safety_outlined,
                              color: AppTheme.secondary, size: 16),
                        ),
                        title: const Text('Consensi Salute',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        subtitle: Text(Platform.isIOS ? 'Apple Health' : 'Health Connect', 
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMediumEmphasis)),
                        trailing: const Icon(Icons.open_in_new,
                            size: 16, color: AppTheme.textMediumEmphasis),
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),

                      // Connected Devices
                      ListTile(
                        onTap: _showDeviceModal,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.1),
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
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMediumEmphasis)),
                            const SizedBox(width: 8),
                            const Icon(Icons.keyboard_arrow_right,
                                size: 16, color: AppTheme.textMediumEmphasis),
                          ],
                        ),
                      ),
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
          color:
              isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
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
            title: const Text('Sincronizza Dati', style: TextStyle(color: Colors.white)),
            content: const Text('Vuoi importare ora gli allenamenti degli ultimi 7 giorni?', style: TextStyle(color: AppTheme.textMediumEmphasis)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Non ora', style: TextStyle(color: AppTheme.textMediumEmphasis)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sincronizza', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizzazione in corso...')));
          await state.syncHealthWorkouts();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizzazione completata!'), backgroundColor: AppTheme.success));
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
        'color': Platform.isIOS ? const Color(0xFFFFFFFF) : const Color(0xFF4285F4),
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
      decoration: const BoxDecoration(
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
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
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
                      icon: const Icon(Icons.close,
                          color: AppTheme.textMediumEmphasis),
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
                  const Text('I TUOI DISPOSITIVI',
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
                                color:
                                    (meta['color'] as Color).withValues(alpha: 0.1),
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
                                      const Icon(Icons.battery_full,
                                          size: 12,
                                          color: AppTheme.textMediumEmphasis),
                                      const SizedBox(width: 2),
                                      Text('${d.batteryLevel}%',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color:
                                                  AppTheme.textMediumEmphasis)),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (d.provider == 'health_connect')
                            IconButton(
                              icon: const Icon(Icons.sync, color: AppTheme.primary),
                              tooltip: 'Sincronizza Allenamenti',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.surface,
                                    title: const Text('Sincronizza Dati', style: TextStyle(color: Colors.white)),
                                    content: const Text('Vuoi importare gli allenamenti degli ultimi 7 giorni?', style: TextStyle(color: AppTheme.textMediumEmphasis)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Annulla', style: TextStyle(color: AppTheme.textMediumEmphasis)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('Sincronizza', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizzazione in corso...')));
                                  await Provider.of<AppState>(context, listen: false).syncHealthWorkouts();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizzazione completata!'), backgroundColor: AppTheme.success));
                                }
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.power_off,
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
                const Text('DISPONIBILI',
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
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(16),
                        color: AppTheme.card,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: (i['color'] as Color).withValues(alpha: 0.1),
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
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                          ),
                          const Icon(Icons.link,
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
