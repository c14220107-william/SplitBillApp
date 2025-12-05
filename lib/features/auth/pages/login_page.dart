import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../../../main.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    // Simpan ScaffoldMessenger sebelum async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      print('🔐 Starting login...');
      
      await ref.read(authStateProvider.notifier).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('✅ Login success!');

      if (!mounted) {
        print('❌ Widget not mounted after login');
        return;
      }

      // Stop loading
      setState(() => _isLoading = false);

      // Show success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            '✅ Login berhasil! Selamat datang.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );

      // Navigate akan otomatis dilakukan oleh router karena state sudah berubah
      print('🔄 Router will redirect to /home automatically');
    } catch (e) {
      print('❌ Login error: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('🔍 Widget mounted status: $mounted');
      
      // Process error message SEBELUM check mounted
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      print('🔍 Processed error message: $errorMessage');
      print('🔍 Lower case: ${errorMessage.toLowerCase()}');
      
      // Stop loading jika masih mounted
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      // Handle specific error messages menggunakan root navigator
      if (errorMessage.contains('Invalid login credentials') ||
          (errorMessage.contains('invalid') && errorMessage.contains('credentials'))) {
        print('📍 Showing invalid credentials snackbar');
        
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '❌ Email atau password salah. Silakan coba lagi.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      } else if (errorMessage.toLowerCase().contains('email not confirmed') || 
                 (errorMessage.toLowerCase().contains('email') && errorMessage.toLowerCase().contains('confirmed'))) {
        print('📍 Showing email not confirmed dialog');
        
        // Gunakan WidgetsBinding untuk schedule dialog di frame berikutnya
        // Gunakan global navigator key dari MaterialApp
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigatorContext = globalNavigatorKey.currentContext;
          
          if (navigatorContext != null) {
            print('🎨 Showing dialog via global navigator');
            showDialog(
              context: navigatorContext,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                print('🎨 Dialog builder executed!');
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      const Icon(Icons.mark_email_unread, color: Colors.orange, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Email Belum Dikonfirmasi',
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
                        'Akun Anda belum dikonfirmasi. Silakan cek email Anda untuk link konfirmasi.',
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Langkah-langkah:',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. Buka aplikasi email Anda',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            Text(
                              '2. Cari email dari Supabase',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            Text(
                              '3. Klik link "Confirm Email"',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            Text(
                              '4. Kembali dan login lagi',
                              style: GoogleFonts.poppins(fontSize: 13),
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
                        Navigator.of(dialogContext).pop();
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
                          
                          // Tutup dialog setelah membuka
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (e) {
                          print('Error opening Gmail: $e');
                          // Tetap tutup dialog meskipun error
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
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
          } else {
            print('❌ Global navigator context is null');
          }
        });
      } else {
        if (errorMessage.isEmpty || errorMessage == 'null') {
          errorMessage = 'Login gagal. Silakan coba lagi.';
        }
        print('📍 Showing generic error snackbar: $errorMessage');
        
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '❌ $errorMessage',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
      key: _scaffoldKey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon
                  Icon(
                    Icons.receipt_long,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Splitbillers',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Split bills with friends easily',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),

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
                  const SizedBox(height: 32),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
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
                            'Masuk',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Belum punya akun? ',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: Text(
                          'Daftar',
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
      ),
    );
  }
}
