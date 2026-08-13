import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../state/app_controller.dart';
import 'profiles_screen.dart';

/// Écran de connexion / inscription (obligatoire quand le cloud est activé).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignup = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  bool get _validEmail => _email.text.contains('@') && _email.text.contains('.');
  bool get _validPassword => _password.text.trim().length >= 6;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_validEmail) {
      setState(() => _error = 'Adresse email invalide.');
      return;
    }
    if (!_validPassword) {
      setState(() => _error = 'Le mot de passe doit faire au moins 6 caractères.');
      return;
    }

    setState(() => _loading = true);
    final c = context.read<AppController>();
    try {
      if (_isSignup) {
        final immediate = await c.signUp(_email.text.trim(), _password.text.trim());
        if (!immediate) {
          setState(() {
            _loading = false;
            _isSignup = false;
            _info =
                'Compte créé ! Vérifie ta boîte mail pour confirmer, puis connecte-toi. '
                '(Astuce : tu peux désactiver la confirmation email dans Supabase.)';
          });
          return;
        }
      } else {
        await c.signIn(_email.text.trim(), _password.text.trim());
      }
      if (mounted) _goNext();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('invalid login') || s.contains('credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (s.contains('already registered') || s.contains('already exists')) {
      return 'Ce compte existe déjà. Connecte-toi.';
    }
    if (s.contains('email not confirmed')) {
      return 'Email pas encore confirmé. Vérifie ta boîte mail.';
    }
    if (s.contains('network') || s.contains('socket') || s.contains('failed host')) {
      return 'Pas de connexion internet.';
    }
    return 'Une erreur est survenue. Réessaie.';
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfilesScreen()),
    );
  }

  Future<void> _forgot() async {
    if (!_validEmail) {
      setState(() => _error = 'Entre ton email d\'abord.');
      return;
    }
    try {
      await context.read<AppController>().cloud.resetPassword(_email.text.trim());
      setState(() => _info = 'Email de réinitialisation envoyé.');
    } catch (_) {
      setState(() => _error = 'Impossible d\'envoyer l\'email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.instance;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    cfg.appName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      color: cfg.accentColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignup ? 'Crée ton compte' : 'Connecte-toi pour continuer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _Banner(text: _error!, color: Colors.red.shade400, icon: Icons.error_outline),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 14),
                    _Banner(text: _info!, color: Colors.green.shade400, icon: Icons.check_circle_outline),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Text(_isSignup ? 'Créer le compte' : 'Se connecter'),
                    ),
                  ),
                  if (!_isSignup)
                    TextButton(
                      onPressed: _loading ? null : _forgot,
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignup ? 'Déjà un compte ?' : 'Nouveau ici ?',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _isSignup = !_isSignup;
                                  _error = null;
                                  _info = null;
                                }),
                        child: Text(_isSignup ? 'Se connecter' : 'Créer un compte'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}
