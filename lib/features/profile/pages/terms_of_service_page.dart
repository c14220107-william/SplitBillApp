import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Hitung lebar card sesuai lebar layar
    final double cardWidth = MediaQuery.of(context).size.width - 32; // padding kiri & kanan

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // Judul utama
          const Text(
            'Terms of Service',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last updated: December 2025',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),

          // Intro
          _buildCard(
            width: cardWidth,
            child: const Text(
              'Welcome to SplitBill! By using our application, you agree to the following terms and conditions.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),

          // Gabungkan Section 1, 2, 3, dan 4 menjadi satu card
          _buildCard(
            width: cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                // Section 1
                Text(
                  '1. Account Usage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• You must provide accurate information when registering.\n'
                  '• You are responsible for keeping your account credentials secure.\n'
                  '• Any activity under your account is your responsibility.',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                SizedBox(height: 16),

                // Section 2
                Text(
                  '2. Data Privacy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• We respect your privacy and handle your personal information according to our Privacy Policy.\n'
                  '• Your data will not be shared with third parties without your consent, except as required by law.',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                SizedBox(height: 16),

                // Section 3
                Text(
                  '3. User Conduct',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• You agree not to misuse the application in any way.\n'
                  '• Prohibited actions include spamming, harassment, or unauthorized access.',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                SizedBox(height: 16),

                // Section 4
                Text(
                  '4. Changes to Terms',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• We may update these terms from time to time.\n'
                  '• Any changes will be posted in the application and will take effect immediately.',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Helper untuk membuat card
  Widget _buildCard({required double width, required Widget child}) {
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
