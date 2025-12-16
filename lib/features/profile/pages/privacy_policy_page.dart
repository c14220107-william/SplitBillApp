import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Hitung lebar card sesuai lebar layar
    final double cardWidth = MediaQuery.of(context).size.width - 32; // 16 padding kiri & kanan

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop(); // Kembali ke halaman sebelumnya (ProfilePage)
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Judul utama
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Last updated: December 2025',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Intro
            _buildFixedSizeCard(
              width: cardWidth,
              child: const Text(
                'SplitBill respects your privacy. This Privacy Policy explains how we collect, use, and protect your personal information when you use our application.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            // Gabungkan Section 1, 2, 3, dan 4 ke dalam satu card
            _buildFixedSizeCard(
              width: cardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  // Section 1
                  Text(
                    '1. Information We Collect',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Full name and email address\n'
                    '• Profile photo (avatar)\n'
                    '• Account-related application usage data',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  SizedBox(height: 16),

                  // Section 2
                  Text(
                    '2. How We Use Your Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• To manage your account\n'
                    '• To display your profile information\n'
                    '• To improve application performance',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  SizedBox(height: 16),

                  // Section 3
                  Text(
                    '3. Data Storage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your data is securely stored using third-party services such as Supabase.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  SizedBox(height: 16),

                  // Section 4
                  Text(
                    '4. Changes to This Policy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This Privacy Policy may be updated from time to time. Any changes will be shown in the application.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Helper: card dengan lebar sesuai layar
  Widget _buildFixedSizeCard({required double width, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
