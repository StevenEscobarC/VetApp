import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../clients/domain/entities/cliente.dart';
import '../../../clients/presentation/providers/clientes_providers.dart';

/// Abre la hoja "Elegir cliente" y devuelve el cliente tocado (o `null` si
/// se cierra). Crear un cliente desde aquí está fuera de alcance.
Future<Cliente?> mostrarElegirClienteSheet(BuildContext context) =>
    showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ElegirClienteSheet(),
    );

String _sinAcentos(String s) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : a[i]);
  }
  return b.toString();
}

/// Hoja con búsqueda local (sin tildes ni mayúsculas) sobre la lista de
/// clientes ya cargada por [clientesProvider].
class ElegirClienteSheet extends ConsumerStatefulWidget {
  const ElegirClienteSheet({super.key});

  @override
  ConsumerState<ElegirClienteSheet> createState() => _ElegirClienteSheetState();
}

class _ElegirClienteSheetState extends ConsumerState<ElegirClienteSheet> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final clientes = ref.watch(clientesProvider);
    final q = _busquedaCtrl.text.trim();
    final qn = _sinAcentos(q);
    final lista = (clientes.value ?? const <Cliente>[])
        .where(
          (c) =>
              qn.isEmpty ||
              _sinAcentos(c.nombre).contains(qn) ||
              c.telefono.contains(qn),
        )
        .toList();

    Widget cuerpo;
    if (clientes.isLoading && !clientes.hasValue) {
      cuerpo = const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (clientes.hasError && !clientes.hasValue) {
      cuerpo = Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'No pudimos cargar los clientes. Intenta de nuevo.',
          style: t.bodyLarge,
        ),
      );
    } else if (lista.isEmpty) {
      cuerpo = Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          q.isEmpty
              ? 'Aún no tienes clientes.'
              : 'No encontramos clientes con «$q»',
          style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
        ),
      );
    } else {
      cuerpo = ListView.builder(
        shrinkWrap: true,
        itemCount: lista.length,
        itemBuilder: (context, i) {
          final c = lista[i];
          return InkWell(
            onTap: () => Navigator.of(context).pop(c),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(c.nombre, style: t.bodyLarge),
                  if (c.telefono.isNotEmpty)
                    Text(
                      c.telefono,
                      style: t.labelLarge?.copyWith(color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Semantics(
              header: true,
              child: Text('Elegir cliente', style: t.headlineSmall),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppTextField(
              label: 'Buscar cliente',
              hideLabel: true,
              hintText: 'Buscar cliente',
              prefixIcon: Icons.search,
              autofocus: true,
              controller: _busquedaCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(child: cuerpo),
        ],
      ),
    );
  }
}
