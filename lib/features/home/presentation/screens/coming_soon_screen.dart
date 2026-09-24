import 'package:flutter/material.dart';

import '../../../../core/widgets/app_bar/app_top_bar.dart';

/// Placeholder for sections whose real screens arrive in Phases 2-7
/// (Pacientes, Agenda, Clientes). Not for Más, which has its own screen.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(title: title),
    body: Center(
      child: Text(
        'Próximamente',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );
}
