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
  int _signupStep = 1; // 1 to 3
  String _role = 'athlete';

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
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
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _genderCtrl.dispose();
    super.dispose();
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
    
    // We update the existing profile that was created by Google Login
    if (appState.userProfile != null) {
      appState.userProfile!.role = _role;
      appState.userProfile!.firstName = _firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text : appState.userProfile!.firstName;
      appState.userProfile!.lastName = _lastNameCtrl.text.isNotEmpty ? _lastNameCtrl.text : appState.userProfile!.lastName;
      appState.userProfile!.birthDate = dobStr;
      appState.userProfile!.weight = weight;
      appState.userProfile!.height = height;
      appState.userProfile!.gender = _genderCtrl.text.isNotEmpty ? _genderCtrl.text : 'M';

      appState.updateProfile(appState.userProfile!);

      final date = DateTime.now().toIso8601String().split('T')[0];
      if (weight > 0) {
        appState.addBodyLog(BodyMetricLog(id: '', date: date, type: 'weight', value: weight));
      }
      if (height > 0) {
        appState.addBodyLog(BodyMetricLog(id: '', date: date, type: 'height', value: height));
      }
    }

    // Now navigate to next screen based on role
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
            _signupStep = 1;
            _firstNameCtrl.text = appState.userProfile?.firstName ?? '';
            _lastNameCtrl.text = appState.userProfile?.lastName ?? '';
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

  void _navigateToNext() {
    final appState = Provider.of<AppState>(context, listen: false);
    Widget nextScreen = const HomeScreen();
    if (appState.userProfile?.role == 'coach') {
      nextScreen = const CoachDashboardScreen();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
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
        const SizedBox(height: 64),
        
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _handleGoogleSignIn();
          },
          icon: Icon(PhosphorIcons.googleLogo(), color: Colors.blue, size: 24),
          label: const Text('Accedi con Google', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _handleGoogleSignIn();
          },
          icon: Icon(PhosphorIcons.appleLogo(PhosphorIconsStyle.fill), color: Colors.white, size: 24),
          label: const Text('Accedi con Apple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
              child: Text('Passo $_signupStep di 3', style: const TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
        const SizedBox(height: 16),
        // Progress bar visuale
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: index < _signupStep ? AppTheme.primary : AppTheme.card,
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
        _buildFlowButton('Avanti', () {
          setState(() { _signupStep = 2; _animationController.forward(from: 0); });
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSignupStep2() {
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
          keyboardType: TextInputType.number, // Tastierino numerico come richiesto
        ),
        const SizedBox(height: 48),
        _buildFlowButton('Avanti', () {
          setState(() { _signupStep = 3; _animationController.forward(from: 0); });
        }),
        const Spacer(),
      ],
    );
  }
  
  Widget _buildSignupStep3() {
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
                keyboardType: TextInputType.number, // Tastierino numerico
              )
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLabeledField(
                'ALTEZZA (CM)', 
                _heightCtrl, 
                '175', 
                preIcon: Icons.height_outlined,
                keyboardType: TextInputType.number, // Tastierino numerico
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
