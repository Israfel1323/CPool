import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/utils/password_validator.dart';
import '../../core/utils/auth_error_helper.dart';
import 'signup_success_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      
    });
    try {
      await context.read<AuthProvider>().signUpWithEmail(
            _email.text,
            _password.text,
          );
      if (!mounted) return;

Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => SignupSuccessScreen(
      email: _email.text.trim(),
    ),
  ),
);
    } catch (e) {
  setState(() {
    _error = AuthErrorHelper.getMessage(e);
  });
}finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
  controller: _password,
  obscureText: _obscurePassword,
  decoration: InputDecoration(
    labelText: 'Password',
    hintText: 'Create a strong password',
    helperText:
        'Use at least 8 characters with uppercase, lowercase, number and special character.',
    prefixIcon: const Icon(Icons.lock_outline),
    suffixIcon: IconButton(
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
      ),
      onPressed: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
    ),
  ),
  onChanged: (_) => setState(() {}),
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (!PasswordValidator.isValid(value)) {
      return 'Please create a stronger password';
    }

    return null;
  },
),
const SizedBox(height: 10),

TweenAnimationBuilder<double>(
  duration: const Duration(milliseconds: 250),
  tween: Tween(
    begin: 0,
    end: PasswordValidator.strengthPercent(_password.text),
  ),
  builder: (context, value, _) {
    Color color;

    if (value < 0.4) {
      color = Colors.red;
    } else if (value < 0.7) {
      color = Colors.orange;
    } else if (value < 1) {
      color = Colors.blue;
    } else {
      color = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          PasswordValidator.strengthText(_password.text),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  },
),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  } 
}