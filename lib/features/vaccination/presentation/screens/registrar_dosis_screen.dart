import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Registrar dosis" (VAC-01, VAC-02). Cuerpo completo en la Tarea 2.
class RegistrarDosisScreen extends ConsumerStatefulWidget {
  const RegistrarDosisScreen({
    super.key,
    required this.mascotaId,
    this.codigoInicial,
    this.citaId,
    this.categoria,
  });

  final String mascotaId;
  final String? codigoInicial;
  final String? citaId;
  final String? categoria;

  @override
  ConsumerState<RegistrarDosisScreen> createState() =>
      _RegistrarDosisScreenState();
}

class _RegistrarDosisScreenState extends ConsumerState<RegistrarDosisScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}
