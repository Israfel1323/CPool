import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/password_validator.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  bool _success = false;

  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().updatePassword(
            _password.text,
          );

      if (!mounted) return;

      setState(() {
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to update your password. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter a password';
    }

    if (!PasswordValidator.isValid(value)) {
      return 'Password does not meet all requirements';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }

    if (value != _password.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  Widget _requirement({
    required String label,
    required bool satisfied,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            satisfied
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: satisfied
                ? Colors.green
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: satisfied
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordStrength() {
    final password = _password.text;
    final strength = PasswordValidator.strength(password);
    final percent = PasswordValidator.strengthPercent(password);
    final text = PasswordValidator.strengthText(password);

    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Password strength',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: strength >= 4
                    ? Colors.green
                    : strength >= 3
                        ? Colors.orange
                        : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
          ),
        ),

        const SizedBox(height: 14),

        _requirement(
          label: 'At least 8 characters',
          satisfied: PasswordValidator.hasMinLength(password),
        ),
        _requirement(
          label: 'One uppercase letter',
          satisfied: PasswordValidator.hasUppercase(password),
        ),
        _requirement(
          label: 'One lowercase letter',
          satisfied: PasswordValidator.hasLowercase(password),
        ),
        _requirement(
          label: 'One number',
          satisfied: PasswordValidator.hasNumber(password),
        ),
        _requirement(
          label: 'One special character',
          satisfied: PasswordValidator.hasSpecialCharacter(password),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _success
            ? _buildSuccess(context)
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    Icon(
                      Icons.lock_reset_rounded,
                      size: 72,
                      color: theme.accent,
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Create a new password',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Choose a strong password for your CPool account.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                    ),

                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),

                    _passwordStrength(),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: _obscureConfirmPassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validateConfirmPassword,
                    ),

                    if (_confirmPassword.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _confirmPassword.text == _password.text
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 18,
                            color: _confirmPassword.text == _password.text
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _confirmPassword.text == _password.text
                                ? 'Passwords match'
                                : 'Passwords do not match',
                            style: TextStyle(
                              color: _confirmPassword.text == _password.text
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    FilledButton(
                      onPressed: _loading || !auth.isConfigured
                          ? null
                          : _resetPassword,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Reset Password'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),

        const CircleAvatar(
          radius: 52,
          child: Icon(
            Icons.check_rounded,
            size: 58,
          ),
        ),

        const SizedBox(height: 28),

        Text(
          'Password Updated',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 12),

        Text(
          'Your password has been changed successfully. '
          'You can now sign in using your new password.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              await context.read<AuthProvider>().signOut();

              if (!context.mounted) return;

              Navigator.of(context).popUntil(
                (route) => route.isFirst,
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Continue to Sign In'),
            ),
          ),
        ),
      ],
    );
  }
}