import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _draftProfile;

  // UI Expansion States
  bool _showUnits = false;
  bool _showLang = false;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<AppState>(context, listen: false).userProfile;
    if (profile != null) {
      _draftProfile = profile.copyWith(); // Create a draft copy
    }
  }

  void _logout(BuildContext context) {
    Provider.of<AppState>(context, listen: false).logout();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _saveProfile() {
    if (_draftProfile != null) {
      Provider.of<AppState>(context, listen: false)
          .updateProfile(_draftProfile!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profilo salvato con successo!'),
            backgroundColor: AppTheme.success),
      );
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

  @override
  Widget build(BuildContext context) {
    if (_draftProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final p = _draftProfile!;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Impostazioni Profilo', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('SALVA',
                style: TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          const SizedBox(width: 8),
        ],
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
                    // Profile image click simulation
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Simulazione cambio foto profilo...')));
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
                                  image: NetworkImage(p.avatarUrl),
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
                    // Weight (Read-only since it's tracked in logs)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.card.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.monitor,
                                    size: 14,
                                    color: AppTheme.textMediumEmphasis),
                                SizedBox(width: 4),
                                Text('PESO',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('${p.weight}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 2),
                                Text(p.unitSystem == 'metric' ? 'kg' : 'lbs',
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
                                    onChanged: (val) => setState(() =>
                                        p.height =
                                            double.tryParse(val) ?? p.height),
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
                                    onChanged: (val) => setState(() =>
                                        p.maxHr = int.tryParse(val) ?? p.maxHr),
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
                            onChanged: (val) =>
                                setState(() => p.firstName = val),
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
                            onChanged: (val) =>
                                setState(() => p.lastName = val),
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
                      onChanged: (val) => setState(() => p.email = val),
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
                      onChanged: (val) => setState(() => p.birthDate = val),
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
                        onTap: () => setState(() =>
                            p.notificationsEnabled = !p.notificationsEnabled),
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
                          onChanged: (val) =>
                              setState(() => p.notificationsEnabled = val),
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
                                  (val) => setState(() => p.unitSystem = val!)),
                              _buildRadioItem(
                                  'imperial',
                                  'Imperial (lbs, ft)',
                                  p.unitSystem,
                                  (val) => setState(() => p.unitSystem = val!)),
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
                                  (val) => setState(() => p.language = val!)),
                              _buildRadioItem('it', 'Italiano', p.language,
                                  (val) => setState(() => p.language = val!)),
                            ],
                          ),
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
      BuildContext context, String provider, String name, String type) {
    // Simulate Connect
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
        'id': 'garmin',
        'name': 'Garmin Connect',
        'type': 'api',
        'color': const Color(0xFF007cc3),
        'icon': Icons.show_chart
      },
      {
        'id': 'whoop',
        'name': 'Whoop',
        'type': 'api',
        'color': const Color(0xFFFF3B30),
        'icon': Icons.show_chart
      },
      {
        'id': 'polar',
        'name': 'Polar Flow / BLE',
        'type': 'ble',
        'color': const Color(0xFFE60012),
        'icon': Icons.favorite
      },
      {
        'id': 'apple',
        'name': 'Apple Health',
        'type': 'api',
        'color': const Color(0xFFFFFFFF),
        'icon': Icons.favorite
      },
      {
        'id': 'amazfit',
        'name': 'Amazfit / Zepp',
        'type': 'api',
        'color': const Color(0xFF2ECC71),
        'icon': Icons.watch
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
