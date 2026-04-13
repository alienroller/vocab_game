import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vocab_game/theme/app_theme.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Available')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'A new version of the app is available!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please update to the latest version to enjoy new features and improvements.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppTheme.borderRadiusMd,
                  boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                ),
                child: FilledButton(
                  onPressed: () {
                    final url = 'https://play.google.com/store/apps/details?id=com.vocabgame.vocab_game';

                    launchUrlString(url, mode: LaunchMode.externalApplication);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMd,
                    ),
                  ),
                  child: const Text('Update now'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
