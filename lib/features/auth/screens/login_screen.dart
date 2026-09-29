import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _isDemoLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _rawErrorDetails;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rawErrorDetails = null;
    });

    try {
      debugPrint('🔵 [Auth] Attempting signInWithPassword for ${_emailController.text.trim()}');
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final banStatus = await DBService().checkUserBanStatus(user.id);
        if (banStatus.isBanned) {
          await _authService.signOut();
          setState(() {
            _errorMessage = '🚫 This account (${_emailController.text.trim()}) has been permanently restricted due to repeated submission of fake/AI images (4/4 warnings reached).';
            _rawErrorDetails = banStatus.reason != null ? 'Ban Reason: ${banStatus.reason}' : null;
          });
          return;
        }
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        context.go('/home');
      }
    } on AuthException catch (e) {
      debugPrint('🔴 [Auth] AuthException caught: statusCode=${e.statusCode}, message=${e.message}');
      setState(() {
        _errorMessage = AppUtils.getFriendlyErrorMessage(e.message);
        _rawErrorDetails = 'Raw AuthException [${e.statusCode}]: ${e.message}';
      });
    } catch (e, st) {
      debugPrint('🔴 [Auth] Generic Exception caught: $e\n$st');
      setState(() {
        _errorMessage = AppUtils.getFriendlyErrorMessage(e);
        _rawErrorDetails = 'Raw Exception [${e.runtimeType}]: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _demoLogin() async {
    setState(() {
      _isDemoLoading = true;
      _errorMessage = null;
    });

    const demoEmail = 'citizen.bangalore@roadsense.ai';
    const demoPassword = 'RoadSense@123';

    try {
      try {
        await _authService.signInWithEmail(
          email: demoEmail,
          password: demoPassword,
        );
      } catch (_) {
        await _authService.signUpWithEmail(
          name: 'Rahul Sharma (HSR Layout)',
          email: demoEmail,
          password: demoPassword,
        );
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        context.go('/home');
      }
    } catch (e, st) {
      debugPrint('🔴 [Auth] Demo login error: $e\n$st');
      setState(() {
        _errorMessage = AppUtils.getFriendlyErrorMessage(e);
        _rawErrorDetails = 'Raw Demo Login Exception: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDemoLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email above to reset password';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent to your email!'),
            backgroundColor: AppTheme.primaryTeal,
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = AppUtils.getFriendlyErrorMessage(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppUtils.getFriendlyErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo Emblem
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/roadsense_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.traffic,
                              size: 48,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title
                    const Text(
                      'RoadSense AI',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Civic Road Safety & Hazard Detection',
                      style: TextStyle(fontSize: 13, color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerousRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.dangerousRed.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppTheme.dangerousRed, fontSize: 13, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            if (_rawErrorDetails != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SelectableText(
                                  _rawErrorDetails!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Email Input
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(PhosphorIconsRegular.envelope, color: AppTheme.primaryTeal),
                        filled: true,
                        fillColor: AppTheme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(PhosphorIconsRegular.lock, color: AppTheme.primaryTeal),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? PhosphorIconsRegular.eyeClosed : PhosphorIconsRegular.eye,
                            color: Colors.white60,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    
                    // Forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: AppTheme.primaryTeal, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sign In Button
                    ElevatedButton(
                      onPressed: (_isLoading || _isDemoLoading) ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'SIGN IN',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                    ),
                    const SizedBox(height: 14),

                    // Quick Demo Citizen Login Button
                    OutlinedButton.icon(
                      onPressed: (_isLoading || _isDemoLoading) ? null : _demoLogin,
                      icon: _isDemoLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(color: AppTheme.secondaryAmber, strokeWidth: 2),
                            )
                          : const Icon(PhosphorIconsBold.lightning, size: 18, color: AppTheme.secondaryAmber),
                      label: Text(
                        _isDemoLoading ? 'SIGNING IN...' : 'QUICK DEMO CITIZEN SIGN IN',
                        style: const TextStyle(
                          color: AppTheme.secondaryAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.secondaryAmber),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              color: AppTheme.primaryTeal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
