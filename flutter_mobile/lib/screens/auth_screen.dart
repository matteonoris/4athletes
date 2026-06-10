import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../core/dev_flags.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'coach_dashboard_screen.dart';
import 'health_permission_screen.dart';
import 'home_screen.dart';

enum _SignupStep { role, personal, physical, photo }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = !kOnboardingPreviewMode;
  bool _isSocialSignup = kOnboardingPreviewMode;
  _SignupStep _signupStep = _SignupStep.role;
  String _role = 'athlete';
  String _gender = 'M';
  File? _pickedAvatarFile;

  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<_SignupStep> get _activeSteps => _role == 'coach'
      ? [_SignupStep.role, _SignupStep.personal, _SignupStep.photo]
      : [
          _SignupStep.role,
          _SignupStep.personal,
          _SignupStep.physical,
          _SignupStep.photo,
        ];

  int get _currentStepIndex => _activeSteps.indexOf(_signupStep) + 1;
  int get _totalSteps => _activeSteps.length;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (kOnboardingPreviewMode) {
      _emailCtrl.text = 'preview@4athletes.local';
      _firstNameCtrl.text = 'Mario';
      _lastNameCtrl.text = 'Rossi';
      _dobCtrl.text = '1998-05-06';
      _weightCtrl.text = '72';
      _heightCtrl.text = '178';
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (kOnboardingPreviewMode) {
      _startSocialSignup();
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final response = await appState.signInWithGoogle();
      if (response != null && response.user != null) {
        if (appState.isNewGoogleUser) {
          _startSocialSignup();
        } else {
          _navigateToNext();
        }
      }
    } catch (e) {
      _showError('Errore durante il login con Google: $e');
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (kOnboardingPreviewMode) {
      _startSocialSignup();
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final response = await appState.signInWithApple();
      if (response != null && response.user != null) {
        if (appState.isNewAppleUser) {
          _startSocialSignup();
        } else {
          _navigateToNext();
        }
      }
    } catch (e) {
      _showError('Errore durante il login con Apple: $e');
    }
  }

  void _startSocialSignup() {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() {
      _isLogin = false;
      _isSocialSignup = true;
      _signupStep = _SignupStep.role;
      _firstNameCtrl.text = appState.userProfile?.firstName.isNotEmpty == true
          ? appState.userProfile!.firstName
          : _firstNameCtrl.text;
      _lastNameCtrl.text = appState.userProfile?.lastName.isNotEmpty == true
          ? appState.userProfile!.lastName
          : _lastNameCtrl.text;
      _emailCtrl.text = appState.userProfile?.email.isNotEmpty == true
          ? appState.userProfile!.email
          : _emailCtrl.text;
      _animationController.forward(from: 0);
    });
  }

  void _goBack() {
    HapticFeedback.lightImpact();
    final currentIndex = _activeSteps.indexOf(_signupStep);
    if (currentIndex > 0) {
      setState(() {
        _signupStep = _activeSteps[currentIndex - 1];
        _animationController.forward(from: 0);
      });
      return;
    }

    setState(() {
      _isLogin = true;
      _animationController.forward(from: 0);
    });
  }

  void _goNext() {
    HapticFeedback.lightImpact();
    final currentIndex = _activeSteps.indexOf(_signupStep);
    if (currentIndex < _activeSteps.length - 1) {
      setState(() {
        _signupStep = _activeSteps[currentIndex + 1];
        _animationController.forward(from: 0);
      });
      return;
    }

    _submitSignup();
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showError('Permesso fotocamera negato.');
        return;
      }
    } else {
      await Permission.photos.request();
    }

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null) return;
      setState(() => _pickedAvatarFile = File(image.path));
    } catch (e) {
      _showError('Errore durante la selezione della foto: $e');
    }
  }

  Future<void> _selectBirthDate() async {
    final initial = DateTime.tryParse(_dobCtrl.text) ?? DateTime(2000, 1, 1);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Data di nascita',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primary,
                surface: AppTheme.surface,
                onSurface: AppTheme.textHighEmphasis,
              ),
        ),
        child: child!,
      ),
    );

    if (selected == null) return;
    _dobCtrl.text = selected.toIso8601String().split('T')[0];
  }

  Future<void> _submitSignup() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final weight = double.tryParse(_weightCtrl.text) ?? 0.0;
    final height = double.tryParse(_heightCtrl.text) ?? 0.0;

    String avatarUrl = appState.userProfile?.avatarUrl ?? '';
    if (!kOnboardingPreviewMode && _pickedAvatarFile != null) {
      final uploadedUrl = await appState.uploadProfileImage(_pickedAvatarFile!);
      if (uploadedUrl != null) avatarUrl = uploadedUrl;
    }

    final profile = UserProfile(
      firstName:
          _firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text : 'Utente',
      lastName: _lastNameCtrl.text.isNotEmpty ? _lastNameCtrl.text : 'Nuovo',
      email: _emailCtrl.text,
      birthDate: _dobCtrl.text.isNotEmpty ? _dobCtrl.text : '2000-01-01',
      role: _role,
      skiClub: '',
      gender: _gender,
      weight: _role == 'athlete' ? weight : 0,
      height: _role == 'athlete' ? height : 0,
      maxHr: 190,
      unitSystem: 'metric',
      language: 'it',
      avatarUrl: avatarUrl,
      notificationsEnabled: false,
      connectedDevices: [],
      oneRepMax: {},
    );

    if (kOnboardingPreviewMode) {
      _showMessage('Preview completata: nessun profilo reale e stato creato.');
      return;
    }

    try {
      if (_isSocialSignup) {
        appState.login(profile);
      }

      final date = DateTime.now().toIso8601String().split('T')[0];
      if (_role == 'athlete' && weight > 0) {
        appState.addBodyLog(
          BodyMetricLog(id: '', date: date, type: 'weight', value: weight),
        );
      }
      if (_role == 'athlete' && height > 0) {
        appState.addBodyLog(
          BodyMetricLog(id: '', date: date, type: 'height', value: height),
        );
      }

      if (mounted) _navigateToNext(isNewAthleteSignUp: _role == 'athlete');
    } catch (e) {
      _showError('Errore di registrazione: $e');
    }
  }

  void _navigateToNext({bool isNewAthleteSignUp = false}) {
    final appState = Provider.of<AppState>(context, listen: false);
    Widget nextScreen = const HomeScreen();
    if (appState.userProfile?.role == 'coach') {
      nextScreen = const CoachDashboardScreen();
    } else if (isNewAthleteSignUp) {
      nextScreen = const HealthPermissionScreen();
    }
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.card),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  Widget _buildLogin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          '4ATHLETES',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.textHighEmphasis,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Track, Analyze, and Dominate.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppTheme.textMediumEmphasis),
        ),
        const SizedBox(height: 64),
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _handleGoogleSignIn();
          },
          icon: Icon(PhosphorIcons.googleLogo(), color: Colors.blue, size: 24),
          label: const Text(
            'Continua con Google',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
        if (Provider.of<AppState>(context, listen: false)
            .isAppleSignInAvailable) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _handleAppleSignIn();
            },
            icon: Icon(
              PhosphorIcons.appleLogo(PhosphorIconsStyle.fill),
              color: AppTheme.textHighEmphasis,
              size: 24,
            ),
            label: Text(
              'Continua con Apple',
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.card,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.textLowEmphasis.withValues(alpha: 0.2),
                ),
              ),
              elevation: 0,
            ),
          ),
        ],
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildSignupHeader(String titleText, String subtitleText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _goBack,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: AppTheme.textHighEmphasis,
                  size: 18,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Passo $_currentStepIndex di $_totalSteps',
                style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(_totalSteps, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: index < _currentStepIndex
                      ? AppTheme.primary
                      : AppTheme.card,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Text(
          titleText.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitleText,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textHighEmphasis,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildRoleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'Chi sei?'),
        _buildRoleCard(
          role: 'athlete',
          icon: PhosphorIconsRegular.user,
          title: 'Atleta',
          description:
              'Traccia i tuoi allenamenti, monitora i progressi e competi con la squadra.',
          accent: AppTheme.primary,
          iconBackground: const Color(0xFF1B2E3D),
        ),
        const SizedBox(height: 20),
        _buildRoleCard(
          role: 'coach',
          icon: PhosphorIconsRegular.users,
          title: 'Allenatore',
          description:
              'Gestisci i tuoi team, analizza le performance e pianifica le sessioni.',
          accent: AppTheme.secondary,
          iconBackground: const Color(0xFF16322A),
        ),
        const Spacer(),
        _buildFlowButton('Avanti', _goNext),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String description,
    required Color accent,
    required Color iconBackground,
  }) {
    final isSelected = _role == role;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _role = role);
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.55)
                : AppTheme.textLowEmphasis.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'I tuoi dati'),
        Row(
          children: [
            Expanded(child: _buildLabeledField('NOME', _firstNameCtrl, 'Nome')),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLabeledField('COGNOME', _lastNameCtrl, 'Cognome'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildLabeledField(
          'DATA DI NASCITA',
          _dobCtrl,
          'Seleziona giorno, mese e anno',
          preIcon: Icons.calendar_today_outlined,
          readOnly: true,
          onTap: _selectBirthDate,
        ),
        const SizedBox(height: 24),
        Text(
          'SESSO',
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildGenderButton('M')),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderButton('F')),
          ],
        ),
        const SizedBox(height: 48),
        _buildFlowButton('Avanti', _goNext),
        const Spacer(),
      ],
    );
  }

  Widget _buildGenderButton(String value) {
    final isSelected = _gender == value;
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        setState(() => _gender = value);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primary : AppTheme.card,
        foregroundColor: isSelected ? Colors.white : AppTheme.textHighEmphasis,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.textLowEmphasis.withValues(alpha: 0.2),
          ),
        ),
        elevation: 0,
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPhysicalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'Fisico'),
        Text(
          'Questi dati ci aiutano a personalizzare la tua esperienza. Puoi saltarli e inserirli in un secondo momento dal tuo profilo.',
          style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 14),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildLabeledField(
                'PESO (KG)',
                _weightCtrl,
                '70',
                preIcon: Icons.monitor_weight_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLabeledField(
                'ALTEZZA (CM)',
                _heightCtrl,
                '175',
                preIcon: Icons.height_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _buildFlowButton('Avanti', _goNext),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _weightCtrl.clear();
            _heightCtrl.clear();
            _goNext();
          },
          child: Text(
            'Salta per ora',
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'Foto profilo'),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => _pickProfileImage(ImageSource.gallery),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: AppTheme.textLowEmphasis.withValues(alpha: 0.2),
                      width: 4,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedAvatarFile != null
                      ? Image.file(_pickedAvatarFile!, fit: BoxFit.cover)
                      : Icon(
                          PhosphorIconsRegular.user,
                          size: 76,
                          color: AppTheme.textMediumEmphasis,
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.background, width: 4),
                  ),
                  child: const Icon(Icons.photo, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        _buildFlowButton('Scatta foto', () {
          HapticFeedback.lightImpact();
          _pickProfileImage(ImageSource.camera);
        }, icon: Icons.camera_alt_outlined),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _pickProfileImage(ImageSource.gallery);
          },
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Scegli dalla galleria'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textHighEmphasis,
            side: BorderSide(
              color: AppTheme.textLowEmphasis.withValues(alpha: 0.24),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const Spacer(),
        _buildFlowButton(_role == 'coach' ? 'Completa' : 'Avanti', _goNext),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _goNext,
          child: Text(
            'Salta per ora',
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField(
    String label,
    TextEditingController controller,
    String hint, {
    IconData? preIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          style: TextStyle(color: AppTheme.textHighEmphasis),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppTheme.textMediumEmphasis.withValues(alpha: 0.6),
            ),
            prefixIcon: preIcon != null
                ? Icon(
                    preIcon,
                    color: AppTheme.textMediumEmphasis.withValues(alpha: 0.6),
                  )
                : null,
            filled: true,
            fillColor: AppTheme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppTheme.textLowEmphasis.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowButton(
    String text,
    VoidCallback onPressed, {
    IconData icon = Icons.arrow_forward,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: AppTheme.primary.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget activeContent = const SizedBox();
    if (_isLogin) {
      activeContent = _buildLogin();
    } else {
      switch (_signupStep) {
        case _SignupStep.role:
          activeContent = _buildRoleStep();
          break;
        case _SignupStep.personal:
          activeContent = _buildPersonalStep();
          break;
        case _SignupStep.physical:
          activeContent = _buildPhysicalStep();
          break;
        case _SignupStep.photo:
          activeContent = _buildPhotoStep();
          break;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondary.withValues(alpha: 0.1),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: activeContent,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
