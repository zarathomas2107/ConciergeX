import 'package:flutter/material.dart';

class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Check your email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We\'ve sent you an email with a verification link and code. Please verify your account to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/verify-email'),
              child: const Text('Enter Verification Code'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
              child: const Text('Return to Login'),
            ),
          ],
        ),
      ),
    );
  }
}