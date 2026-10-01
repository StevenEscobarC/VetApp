import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../patients/domain/entities/mascota.dart';
import '../../../patients/presentation/widgets/mascota_foto_avatar.dart';

/// Lista de mascotas del cliente con casillas (una cita puede incluir varias).
class MascotaMultiSelect extends StatelessWidget {
  const MascotaMultiSelect({
    super.key,
    required this.mascotas,
    required this.seleccionadas,
    required this.onCambio,
    required this.onAgregarMascota,
    this.mostrarError = false,
    this.bloqueadas = const {},
  });

  final List<Mascota> mascotas;
  final Set<String> seleccionadas;
  final void Function(String id, bool marcada) onCambio;
  final VoidCallback onAgregarMascota;

  /// `true` cuando el usuario desmarcó la última mascota.
  final bool mostrarError;

  /// Mascotas que ya tienen consulta registrada en la cita (modo edición):
  /// el servidor rechaza quitarlas, así que su casilla queda fija.
  final Set<String> bloqueadas;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in mascotas)
          InkWell(
            onTap: bloqueadas.contains(m.id)
                ? null
                : () => onCambio(m.id, !seleccionadas.contains(m.id)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Checkbox(
                    value: seleccionadas.contains(m.id),
                    onChanged: bloqueadas.contains(m.id)
                        ? null
                        : (v) => onCambio(m.id, v ?? false),
                  ),
                  MascotaFotoAvatar(fotoPath: m.fotoPath, size: 40),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.nombre,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          bloqueadas.contains(m.id)
                              ? '${m.especie.etiqueta} · Consulta registrada'
                              : m.especie.etiqueta,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (mostrarError && seleccionadas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'Elige al menos una mascota.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: '+ Agregar mascota',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: onAgregarMascota,
          ),
        ),
      ],
    );
  }
}
