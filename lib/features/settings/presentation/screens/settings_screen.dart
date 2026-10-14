import 'package:flutter/material.dart';
import '../widgets/account_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/bookmarks_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: const [
          AccountSection(),
          BookmarksSection(),
          AppearanceSection(),
        ],
      ),
    );
  }
}
