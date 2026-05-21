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
  int _signupStep = 1; // 1 to 6
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

  void _submitLogin() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (_emailCtrl.text.isNotEmpty && _passCtrl.text.isNotEmpty) {
      final role = _emailCtrl.text.toLowerCase().contains('coach') ? 'coach' : 'athlete';
      appState.login(appState.userProfile ?? _createMockProfile(role));
      _navigateToNext();
    }
  }

  void _submitSignup() {
    final appState = Provider.of<AppState>(context, listen: false);
    final profile = _createMockProfile(_role);
    appState.login(profile);
    
    final date = DateTime.now().toIso8601String().split('T')[0];
    if (profile.weight > 0) {
      appState.addBodyLog(BodyMetricLog(id: DateTime.now().millisecondsSinceEpoch.toString() + '_w', date: date, type: 'weight', value: profile.weight));
    }
    if (profile.height > 0) {
      appState.addBodyLog(BodyMetricLog(id: DateTime.now().millisecondsSinceEpoch.toString() + '_h', date: date, type: 'height', value: profile.height));
    }
    _navigateToNext();
  }

  Future<void> _handleGoogleSignIn() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final response = await appState.signInWithGoogle();
      if (response != null && response.user != null) {
        if (appState.isNewGoogleUser) {
          setState(() {
            _isLogin = false;
            _signupStep = 4;
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

  UserProfile _createMockProfile(String role) {
    String dobStr = _dobCtrl.text;
    if (dobStr.isEmpty) dobStr = '2000-01-01'; // Fallback
    else {
      // Very basic parsing assuming dd/mm/yyyy
      final parts = dobStr.split('/');
      if (parts.length == 3) {
        dobStr = '${parts[2]}-${parts[1]}-${parts[0]}';
      } else {
        dobStr = '2000-01-01';
      }
    }

    return UserProfile(
      firstName: _isLogin ? 'Alex' : _firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text : 'Nuovo',
      lastName: _isLogin ? 'Skier' : _lastNameCtrl.text.isNotEmpty ? _lastNameCtrl.text : 'Utente',
      email: _isLogin ? _emailCtrl.text : _emailCtrl.text.isNotEmpty ? _emailCtrl.text : 'user@example.com',
      birthDate: dobStr,
      role: role,
      skiClub: _isLogin ? 'Club 4A' : '',
      gender: _isLogin ? 'M' : _genderCtrl.text.isNotEmpty ? _genderCtrl.text : 'M',
      weight: _isLogin ? 70.0 : double.tryParse(_weightCtrl.text) ?? 70.0,
      height: _isLogin ? 175.0 : double.tryParse(_heightCtrl.text) ?? 175.0,
      maxHr: 190,
      unitSystem: 'metric',
      language: 'it',
      avatarUrl: '',
      notificationsEnabled: true,
      connectedDevices: [],
      oneRepMax: {},
    );
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

  Widget _buildLabeledField(String label, TextEditingController controller, String hint, {IconData? preIcon, IconData? sufIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
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
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00C6FF).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)
              ]
            ),
            child: const Center(
              child: Text('4A', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '4ATHLETES',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          'Track, Analyze, and Dominate.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMediumEmphasis),
        ),
        const SizedBox(height: 48),

        _buildTextField(_emailCtrl, 'Email', Icons.email_outlined),
        const SizedBox(height: 16),
        _buildTextField(_passCtrl, 'Password', Icons.lock_outline, true),
        
        const SizedBox(height: 32),
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
        
        const SizedBox(height: 32),
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
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _handleGoogleSignIn();
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
                if (_signupStep > 1) {
                  setState(() { _signupStep--; _animationController.forward(from: 0); });
                } else {
                  setState(() { _isLogin = true; _animationController.forward(from: 0); });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.card, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20)),
              child: Text('$_signupStep/${_role == 'coach' ? 4 : 5}', style: const TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
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
                  decoration: BoxDecoration(color: const Color(0xFF1B2E3D), borderRadius: BorderRadius.circular(16)),
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
                  decoration: BoxDecoration(color: const Color(0xFF16322A), borderRadius: BorderRadius.circular(16)),
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
        _buildBottomNextButton(),
        const SizedBox(height: 20),
        _buildAlreadyAccount()
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
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _handleGoogleSignIn,
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
        _buildSignupHeader('Iscrizione', 'Chi sei?'),
        Row(
          children: [
            Expanded(child: _buildLabeledField('NOME', _firstNameCtrl, 'Nome')),
            const SizedBox(width: 16),
            Expanded(child: _buildLabeledField('COGNOME', _lastNameCtrl, 'Cognome')),
          ],
        ),
        const SizedBox(height: 24),
        _buildLabeledField('DATA DI NASCITA', _dobCtrl, 'gg/mm/aaaa', preIcon: Icons.calendar_today_outlined, sufIcon: Icons.calendar_today),
        const SizedBox(height: 48),
        _buildFlowButton(_role == 'coach' ? 'Completa' : 'Avanti', () {
          if (_role == 'coach') {
            _submitSignup();
          } else {
            setState(() { _signupStep = 5; _animationController.forward(from: 0); });
          }
        }),
        const Spacer(),
        _buildAlreadyAccount()
      ],
    );
  }
  
  Widget _buildSignupStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignupHeader('Iscrizione', 'Fisico'),
        Row(
          children: [
            Expanded(child: _buildLabeledField('PESO (KG)', _weightCtrl, '70', preIcon: Icons.monitor_weight_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _buildLabeledField('ALTEZZA (CM)', _heightCtrl, '175', preIcon: Icons.height_outlined)),
          ],
        ),
        const SizedBox(height: 24),
        _buildLabeledField('SESSO (M/F)', _genderCtrl, 'M', preIcon: Icons.people_outline),
        const SizedBox(height: 48),
        _buildFlowButton('Completa', _submitSignup),
        const Spacer(),
        _buildAlreadyAccount()
      ],
    );
  }
  

  Widget _buildBottomNextButton() {
    return _buildFlowButton('Avanti', () {
      if (_signupStep < (_role == 'coach' ? 4 : 5)) {
         setState(() { _signupStep++; _animationController.forward(from: 0); });
      }
    });
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
