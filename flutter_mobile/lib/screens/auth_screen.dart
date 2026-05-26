import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'home_screen.dart';
import 'coach_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  int _signupStep = 1; // 1 to 5
  bool _isSocialSignup = false; // true while completing signup after Google/Apple auth
  String _role = 'athlete';

  // Controllers
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _skiClubCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _skiClubCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _genderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (_emailCtrl.text.isNotEmpty && _passCtrl.text.isNotEmpty) {
      try {
        await appState.signInWithEmailAndPassword(_emailCtrl.text, _passCtrl.text);
        if (mounted) _navigateToNext();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore di login: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitSignup() async {
    final appState = Provider.of<AppState>(context, listen: false);

    String dobStr = _dobCtrl.text;
    if (dobStr.isEmpty) dobStr = '2000-01-01'; // Fallback
    else {
      final parts = dobStr.split('/');
      if (parts.length == 3) {
        dobStr = '${parts[2]}-${parts[1]}-${parts[0]}';
      } else if (parts.length == 1) { // If they just typed the year or age
        int? age = int.tryParse(dobStr);
        if (age != null && age < 100) { // It's an age
           int year = DateTime.now().year - age;
           dobStr = '$year-01-01';
        } else if (age != null && age > 1900) { // It's a year
           dobStr = '$age-01-01';
        }
      }
    }

    final weight = double.tryParse(_weightCtrl.text) ?? 0.0;
    final height = double.tryParse(_heightCtrl.text) ?? 0.0;
    
    final profile = UserProfile(
      firstName: _firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text : 'Utente',
      lastName: _lastNameCtrl.text.isNotEmpty ? _lastNameCtrl.text : 'Nuovo',
      email: _emailCtrl.text,
      birthDate: dobStr,
      role: _role,
      skiClub: '',
      gender: _genderCtrl.text.isNotEmpty ? _genderCtrl.text : 'M',
      weight: weight,
      height: height,
      maxHr: 190,
      unitSystem: 'metric',
      language: 'it',
      avatarUrl: appState.userProfile?.avatarUrl ?? '',
      notificationsEnabled: true,
      connectedDevices: [],
      oneRepMax: {},
    );

    try {
      if (_isSocialSignup) {
        // Google/Apple user is already authenticated with Supabase; just
        // persist the profile they just completed and mark the session as
        // logged in.
        appState.login(profile);
      } else {
        await appState.signUpWithEmailAndPassword(_emailCtrl.text, _passCtrl.text, profile);
      }

      final date = DateTime.now().toIso8601String().split('T')[0];
      if (weight > 0) {
        appState.addBodyLog(BodyMetricLog(id: '', date: date, type: 'weight', value: weight));
      }
      if (height > 0) {
        appState.addBodyLog(BodyMetricLog(id: '', date: date, type: 'height', value: height));
      }

      if (mounted) _navigateToNext();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore di registrazione: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final response = await appState.signInWithGoogle();
      if (response != null && response.user != null) {
        if (appState.isNewGoogleUser) {
          setState(() {
            _isLogin = false;
            _isSocialSignup = true;
            _signupStep = 1;
            _firstNameCtrl.text = appState.userProfile?.firstName ?? '';
            _lastNameCtrl.text = appState.userProfile?.lastName ?? '';
            _emailCtrl.text = appState.userProfile?.email ?? '';
            _animationController.forward(from: 0);
          });
        } else {
          _navigateToNext();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante il login con Google: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleAppleSignIn() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final response = await appState.signInWithApple();
      if (response != null && response.user != null) {
        if (appState.isNewAppleUser) {
          setState(() {
            _isLogin = false;
            _isSocialSignup = true;
            _signupStep = 1;
            _firstNameCtrl.text = appState.userProfile?.firstName ?? '';
            _lastNameCtrl.text = appState.userProfile?.lastName ?? '';
            _emailCtrl.text = appState.userProfile?.email ?? '';
            _animationController.forward(from: 0);
          });
        } else {
          _navigateToNext();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante il login con Apple: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToNext() {
    final appState = Provider.of<AppState>(context, listen: false);
    Widget nextScreen = const HomeScreen();
    if (appState.userProfile?.role == 'coach') {
      nextScreen = const CoachDashboardScreen();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, [bool obscureText = false]) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textMediumEmphasis.withValues(alpha: 0.8)),
        prefixIcon: Icon(icon, color: AppTheme.textMediumEmphasis.withValues(alpha: 0.6)),
        filled: true,
        fillColor: AppTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildLabeledField(
    String label, 
    TextEditingController controller, 
    String hint, 
    {IconData? preIcon, IconData? sufIcon, bool readOnly = false, VoidCallback? onTap, TextInputType? keyboardType}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textMediumEmphasis.withValues(alpha: 0.6)),
            prefixIcon: preIcon != null ? Icon(preIcon, color: AppTheme.textMediumEmphasis.withValues(alpha: 0.6)) : null,
            suffixIcon: sufIcon != null ? Icon(sufIcon, color: AppTheme.textMediumEmphasis.withValues(alpha: 0.6)) : null,
            filled: true,
            fillColor: AppTheme.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildLogin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
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
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Track, Analyze, and Dominate.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMediumEmphasis),
        ),
        const SizedBox(height: 48),

        _buildTextField(_emailCtrl, 'Email', Icons.email_outlined),
        const SizedBox(height: 16),
        _buildTextField(_passCtrl, 'Password', Icons.lock_outline, true),
        
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _submitLogin();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: AppTheme.primary.withValues(alpha: 0.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Accedi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OPPURE', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          ],
        ),
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _handleGoogleSignIn();
                },
                icon: Icon(PhosphorIcons.googleLogo(), color: Colors.blue, size: 20),
                label: const Text('Google', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            if (Provider.of<AppState>(context, listen: false).isAppleSignInAvailable) ...[
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _handleAppleSignIn();
                  },
                  icon: Icon(PhosphorIcons.appleLogo(PhosphorIconsStyle.fill), color: Colors.white, size: 20),
                  label: const Text('Apple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.card,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),

        const Spacer(),
        Center(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isLogin = false;
                _signupStep = 1;
                _animationController.forward(from: 0);
              });
            },
            child: RichText(
              text: const TextSpan(
                text: 'Non hai un account? ',
                style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 14),
                children: [
                  TextSpan(text: 'Iscriviti', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  int _getTotalSteps() {
    return _isSocialSignup ? (_role == 'coach' ? 2 : 3) : (_role == 'coach' ? 4 : 5);
  }

  int _getCurrentStepIndex() {
    if (_isSocialSignup) {
      if (_signupStep == 1) return 1;
      if (_signupStep == 4) return 2;
      if (_signupStep == 5) return 3;
    }
    return _signupStep;
  }

  Widget _buildSignupHeader(String titleText, String subtitleText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (_isSocialSignup && _signupStep == 4) {
                  // Skip steps 2 and 3 (irrelevant for Google/Apple sign-up).
                  setState(() { _signupStep = 1; _animationController.forward(from: 0); });
                } else if (_signupStep > 1) {
                  int prevStep = _signupStep - 1;
                  if (_isSocialSignup && prevStep == 3) {
                    prevStep = 1; // skip 2 and 3
                  }
                  setState(() { _signupStep = prevStep; _animationController.forward(from: 0); });
                } else {
                  setState(() { _isLogin = true; _animationController.forward(from: 0); });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: AppTheme.card, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20)),
              child: Text(
                'Passo ${_getCurrentStepIndex()} di ${_getTotalSteps()}',
                style: const TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        // Progress bar visuale
        Row(
          children: List.generate(_getTotalSteps(), (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: index < _getCurrentStepIndex() ? AppTheme.primary : AppTheme.card,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Text(titleText.toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(subtitleText, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSignupStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'Chi sei?'),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _role = 'athlete');
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _role == 'athlete' ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFF1B2E3D), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(PhosphorIconsRegular.user, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                const Text('Atleta', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Traccia i tuoi allenamenti, monitora i progressi e competi con la squadra.', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _role = 'coach');
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _role == 'coach' ? AppTheme.secondary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFF16322A), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(PhosphorIconsRegular.users, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                const Text('Allenatore', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Gestisci i tuoi team, analizza le performance e pianifica le sessioni.', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 14)),
              ],
            ),
          ),
        ),
        const Spacer(),
        _buildFlowButton('Avanti', () {
          if (_isSocialSignup) {
            setState(() { _signupStep = 4; _animationController.forward(from: 0); });
          } else {
            setState(() { _signupStep = 2; _animationController.forward(from: 0); });
          }
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSignupStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'Iscriviti con'),
        GestureDetector(
          onTap: () => setState(() { _signupStep = 3; _animationController.forward(from: 0); }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.mail_outline, color: AppTheme.primary),
                ),
                const SizedBox(width: 16),
                const Text('Email e Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('O SOCIAL', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          ],
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _handleGoogleSignIn,
          icon: Icon(PhosphorIcons.googleLogo(), color: Colors.blue, size: 24),
          label: const Text('Google', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
        if (Provider.of<AppState>(context, listen: false).isAppleSignInAvailable) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _handleAppleSignIn,
            icon: Icon(PhosphorIcons.appleLogo(PhosphorIconsStyle.fill), color: Colors.white, size: 24),
            label: const Text('Apple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.card,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              elevation: 0,
            ),
          ),
        ],
        const Spacer(),
        _buildAlreadyAccount()
      ],
    );
  }

  Widget _buildSignupStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'Account'),
        _buildLabeledField('EMAIL', _emailCtrl, 'Email', preIcon: Icons.mail_outline),
        const SizedBox(height: 24),
        _buildLabeledField('PASSWORD', _passCtrl, 'Password', preIcon: Icons.lock_outline),
        const SizedBox(height: 48),
        _buildFlowButton('Avanti', () => setState(() { _signupStep = 4; _animationController.forward(from: 0); })),
        const Spacer(),
        _buildAlreadyAccount()
      ],
    );
  }

  Widget _buildSignupStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'I tuoi dati'),
        Row(
          children: [
            Expanded(child: _buildLabeledField('NOME', _firstNameCtrl, 'Nome')),
            const SizedBox(width: 16),
            Expanded(child: _buildLabeledField('COGNOME', _lastNameCtrl, 'Cognome')),
          ],
        ),
        const SizedBox(height: 24),
        _buildLabeledField(
          'ANNO DI NASCITA O ETÀ',
          _dobCtrl,
          'Es. 1995 o 28',
          preIcon: Icons.calendar_today_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 48),
        _buildFlowButton(_role == 'coach' ? 'Completa' : 'Avanti', () {
          if (_role == 'coach') {
            _submitSignup();
          } else {
            setState(() { _signupStep = 5; _animationController.forward(from: 0); });
          }
        }),
        const Spacer(),
      ],
    );
  }

  Widget _buildSignupStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'Fisico'),
        const Text(
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
              )
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLabeledField(
                'ALTEZZA (CM)', 
                _heightCtrl, 
                '175', 
                preIcon: Icons.height_outlined,
                keyboardType: TextInputType.number,
              )
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildLabeledField('SESSO (M/F)', _genderCtrl, 'M', preIcon: Icons.people_outline),
        const SizedBox(height: 48),
        _buildFlowButton('Completa', _submitSignup),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            // Salta per ora: Pulisci i campi non obbligatori
            _weightCtrl.clear();
            _heightCtrl.clear();
            _submitSignup();
          },
          child: const Text('Salta per ora', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildFlowButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
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
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 20),
        ],
      ),
    );
  }

  Widget _buildAlreadyAccount() {
    return Center(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _isLogin = true;
            _animationController.forward(from: 0);
          });
        },
        child: RichText(
          text: const TextSpan(
            text: 'Hai già un account? ',
            style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 14),
            children: [
              TextSpan(text: 'Accedi', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
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
        case 1: activeContent = _buildSignupStep1(); break;
        case 2: activeContent = _buildSignupStep2(); break;
        case 3: activeContent = _buildSignupStep3(); break;
        case 4: activeContent = _buildSignupStep4(); break;
        case 5: activeContent = _buildSignupStep5(); break;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Gradient / Blur Effect
          Positioned(
            top: -100,
            left: -100,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary.withValues(alpha: 0.15))),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.secondary.withValues(alpha: 0.1))),
          ),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(color: Colors.transparent)),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: activeContent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
