import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/entities/protocolo.dart';
import '../providers/vacuna_providers.dart';

/// Resultado del selector: [protocolo] null significa "Otro...". Se envuelve
/// para distinguir "Otro..." de cerrar la hoja sin elegir.
class BiologicoElegido {
  const BiologicoElegido(this.protocolo);

  final Protocolo? protocolo;
}

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

IconData _icono(TipoDosis t) => switch (t) {
  TipoDosis.vacuna => Icons.vaccines_outlined,
  TipoDosis.desparasitacionInterna => Icons.medication_outlined,
  TipoDosis.desparasitacionExterna => Icons.bug_report_outlined,
};

/// Hoja completa "Biológico": búsqueda instantánea sin distinguir acentos,
/// catálogo filtrado por especie con pista de historial (D-02) y "Otro...".
class BiologicoPickerSheet extends ConsumerStatefulWidget {
  const BiologicoPickerSheet({
    super.key,
    required this.mascotaId,
    required this.especie,
  });

  final String mascotaId;

  /// Valor de `Especie.name` para filtrar el catálogo.
  final String especie;

  @override
  ConsumerState<BiologicoPickerSheet> createState() =>
      _BiologicoPickerSheetState();
}

class _BiologicoPickerSheetState extends ConsumerState<BiologicoPickerSheet> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  String _pista(Protocolo p) {
    final carne = ref.watch(carneProvider(widget.mascotaId)).asData?.value;
    if (carne == null) return 'Primera dosis';
    for (final b in carne.biologicos) {
      if (b.codigoProtocolo != p.codigo) continue;
      return b.posicion < b.dosisSerie
          ? 'Dosis ${b.posicion + 1} de ${b.dosisSerie}'
          : 'Refuerzo';
    }
    return 'Primera dosis';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final protocolos = ref.watch(protocolosProvider(widget.especie));
    final q = _sinAcentos(_busquedaCtrl.text.trim());
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Biológico', style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Buscar biológico',
                hideLabel: true,
                hintText: 'Buscar biológico',
                autofocus: true,
                prefixIcon: Icons.search,
                controller: _busquedaCtrl,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: protocolos.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Text(
                      'No pudimos cargar el catálogo. Intenta de nuevo.',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (lista) {
                    final filtrada = lista
                        .where((p) => _sinAcentos(p.nombre).contains(q))
                        .toList();
                    return ListView(
                      children: [
                        for (final p in filtrada)
                          _Fila(
                            icono: _icono(p.tipo),
                            titulo: p.nombre,
                            pista: _pista(p),
                            onTap: () =>
                                Navigator.of(context).pop(BiologicoElegido(p)),
                          ),
                        _Fila(
                          icono: Icons.add,
                          titulo: 'Otro...',
                          onTap: () => Navigator.of(
                            context,
                          ).pop(const BiologicoElegido(null)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    this.pista,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String? pista;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icono, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(titulo, style: textTheme.bodyLarge)),
            if (pista != null)
              Text(
                pista!,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
