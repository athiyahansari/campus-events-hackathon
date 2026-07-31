import 'package:flutter/material.dart';

class PublicFeedScreen extends StatelessWidget {
  const PublicFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Events')),
      body: const Center(child: Text('Public event feed — coming in Phase 2')),
    );
  }
}
