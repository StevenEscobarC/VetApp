import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../data/repositories/supabase_cliente_repository.dart';
import '../../domain/cliente_failure.dart';
import '../providers/clientes_providers.dart';

/// Mensaje de vigencia del código de vinculación (CLI-05), calculado sobre
/// [expiraEn] respecto a [ahora] (inyectable para pruebas, nunca
/// `DateTime.now()` directo dentro de esta función).
String textoVigencia(DateTime expiraEn, DateTime ahora) {
  final restante = expiraEn.difference(ahora);
  if (restante >= const Duration(hours: 23, minutes: 30)) {
    return 'Válido por 24 horas';
  }
  if (restante <= const Duration(hours: 1)) {
    return 'Válido por menos de 1 hora';
  }
  final horas = (restante.inMinutes / 60).ceil();
  return 'Válido por $horas horas más';
}

/// Hoja de vinculación de cuenta (CLI-05, D-07 — solo el lado veterinario
/// esta fase): la generación ocurre automáticamente al abrir la hoja, sin
/// ningún botón adicional que el vet deba tocar antes de ver el código
/// (per UI-SPEC). "Copiar código" es el único mecanismo para compartirlo
/// esta fase — ningún canal de mensajería externo está integrado aquí
/// (ese patrón queda reservado para AGND-05). Cerrar la hoja no invalida
/// el código — sigue vigente hasta `codigo_expira_en`.
class VinculacionSheet extends ConsumerStatefulWidget {
  const VinculacionSheet({
    super.key,
    required this.clienteId,
    required this.clienteNombre,
  });

  final String clienteId;
  final String clienteNombre;

  @override
  ConsumerState<VinculacionSheet> createState() => _VinculacionSheetState();
}

class _VinculacionSheetState extends ConsumerState<VinculacionSheet> {
  CodigoVinculacion? _codigo;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generar();
  }

  Future<void> _generar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final codigo = await ref
          .read(clienteRepositoryProvider)
          .generarCodigoVinculacion(widget.clienteId);
      if (!mounted) return;
      setState(() {
        _codigo = codigo;
        _loading = false;
      });
    } on ClienteFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos generar el código. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  Future<void> _copiar() async {
    final codigo = _codigo;
    if (codigo == null) return;
    await Clipboard.setData(ClipboardData(text: codigo.codigo));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _buildContent(Theme.of(context).textTheme),
      ),
    );
  }

  Widget _buildContent(TextTheme textTheme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Intentar de nuevo',
            variant: AppButtonVariant.text,
            onPressed: _generar,
          ),
        ],
      );
    }

    final codigo = _codigo!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Comparte este código con ${widget.clienteNombre} para que '
          'vincule sus mascotas desde su cuenta',
          style: textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          codigo.codigo,
          style: textTheme.headlineMedium?.copyWith(
            letterSpacing: 6,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (codigo.reemplazoExpirado) ...[
          Text(
            'El código anterior expiró. Se generó uno nuevo.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          textoVigencia(codigo.expiraEn, DateTime.now()),
          style: textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Copiar código',
          variant: AppButtonVariant.outline,
          icon: Icons.copy,
          onPressed: _copiar,
        ),
      ],
    );
  }
}
