import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/kreavana_ai_floating_widget.dart';

class KreavanaAiScreen extends StatelessWidget {
  final UserModel user;
  const KreavanaAiScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      body: SafeArea(
        child: KreavanaAiPanel(
          isDesktop: isDesktop,
        ),
      ),
    );
  }
}
