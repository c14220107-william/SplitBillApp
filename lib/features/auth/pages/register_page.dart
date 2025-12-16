import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    print('🚀 _handleRegister called!');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    print('✅ Form validation passed');
    setState(() => _isLoading = true);
    
    // Simpan reference sebelum async operation
    final authNotifier = ref.read(authStateProvider.notifier);

    try {
      print('📝 Starting registration...');
      
      // Step 1: Register user (sign out sudah otomatis dilakukan di provider)
      await authNotifier.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      print('✅ Register success and user already signed out!');

      if (!mounted) {
        print('❌ Widget not mounted after registration');
        return;
      }

      // Step 2: Stop loading
      setState(() => _isLoading = false);
      print('🛑 Loading stopped');

      // Step 3: Show success dialog
      print('💬 Showing success dialog...');
      
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          print('🎨 Dialog builder called!');
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Registrasi Berhasil!',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akun Anda telah berhasil dibuat! 🎉',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mark_email_unread, size: 20, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Konfirmasi Email Diperlukan',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sebelum login, silakan:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1. Cek email Anda (${_emailController.text})',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      Text(
                        '2. Klik link konfirmasi dari Supabase',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      Text(
                        '3. Kembali ke halaman login',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '💡 Cek folder Spam jika tidak menemukannya',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(
                  'Nanti Saja',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    // Untuk Android: coba buka Gmail app dengan package name
                    final Uri gmailAppUri = Uri.parse(
                      'android-app://com.google.android.gm'
                    );
                    
                    bool opened = false;
                    
                    // Try method 1: Android app link
                    try {
                      if (await canLaunchUrl(gmailAppUri)) {
                        await launchUrl(gmailAppUri);
                        opened = true;
                        print('✅ Gmail app opened via android-app');
                      }
                    } catch (e) {
                      print('⚠️ Method 1 failed: $e');
                    }
                    
                    // Try method 2: Custom Gmail scheme untuk iOS
                    if (!opened) {
                      try {
                        final Uri gmailIosUri = Uri.parse('googlegmail://');
                        if (await canLaunchUrl(gmailIosUri)) {
                          await launchUrl(gmailIosUri, mode: LaunchMode.externalApplication);
                          opened = true;
                          print('✅ Gmail app opened via iOS scheme');
                        }
                      } catch (e) {
                        print('⚠️ Method 2 failed: $e');
                      }
                    }
                    
                    // Try method 3: Mailto scheme (akan buka app selector atau default email)
                    if (!opened) {
                      try {
                        final Uri mailtoUri = Uri.parse('mailto:');
                        if (await canLaunchUrl(mailtoUri)) {
                          await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
                          opened = true;
                          print('✅ Email app opened via mailto');
                        }
                      } catch (e) {
                        print('⚠️ Method 3 failed: $e');
                      }
                    }
                    
                    // Fallback: Buka Gmail web
                    if (!opened) {
                      final Uri gmailWebUri = Uri.parse('https://mail.google.com');
                      await launchUrl(gmailWebUri, mode: LaunchMode.externalApplication);
                      print('✅ Gmail web opened');
                    }
                    
                    // Tutup dialog dan navigate ke login
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  } catch (e) {
                    print('Error opening Gmail: $e');
                    // Tetap navigate meskipun error
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  }
                },
                icon: const Icon(Icons.email_outlined, size: 18),
                label: Text(
                  'Buka Email',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          );
        },
      );

      print('✅ Dialog closed with result: $shouldProceed');

      // Step 4: Navigate to login page
      if (mounted && shouldProceed == true) {
        print('🔄 Navigating to login...');
        context.go('/login');
      }
    } catch (e) {
      print('Register error: $e');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        
        // Clean up error message
        if (errorMessage.isEmpty || errorMessage == 'null') {
          errorMessage = 'Registrasi gagal. Silakan coba lagi.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ $errorMessage',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: Text(
          'Daftar Akun',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                Icon(
                  Icons.person_add_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                Text(
                  'Buat akun baru',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    labelStyle: GoogleFonts.poppins(),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  style: GoogleFonts.poppins(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    if (value.length < 3) {
                      return 'Nama minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: GoogleFonts.poppins(),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  style: GoogleFonts.poppins(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!value.contains('@')) {
                      return 'Email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: GoogleFonts.poppins(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password',
                    labelStyle: GoogleFonts.poppins(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Konfirmasi password tidak boleh kosong';
                    }
                    if (value != _passwordController.text) {
                      return 'Password tidak sama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Daftar',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sudah punya akun? ',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Masuk',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
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
    );
  }
}
