import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../clients/domain/entities/cliente.dart';
import '../providers/citas_providers.dart';

/// Búsqueda de cliente por nombre o teléfono con debounce de 350 ms. La
/// última fila siempre ofrece crear cliente y mascota juntos (D-04).
class ClienteSearchField extends ConsumerStatefulWidget {
  const ClienteSearchField({
    super.key,
    required this.onSeleccionar,
    required this.onNuevoClienteYMascota,
  });

  final ValueChanged<Cliente> onSeleccionar;
  final VoidCallback onNuevoClienteYMascota;

  @override
  ConsumerState<ClienteSearchField> createState() => _ClienteSearchFieldState();
}

class _ClienteSearchFieldState extends ConsumerState<ClienteSearchField> {
  static const _debounce = Duration(milliseconds: 350);
  final _ctrl = TextEditingController();
  Timer? _timer;
  String _query = '';

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resultados = _query.isEmpty
        ? null
        : ref.watch(busquedaClientesCitaProvider(_query));

    Widget? estado;
    if (resultados != null) {
      estado = resultados.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
        error: (_, _) => Text(
          'No pudimos buscar clientes. Intenta de nuevo.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.destructive),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return Text(
              'No encontramos a nadie con ese nombre.',
              style: textTheme.bodyMedium,
            );
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 5 * 72),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in lista)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: AppCard(
                      onTap: () => widget.onSeleccionar(c),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c.nombre,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              normalizarTelefono(c.telefono).formateado,
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Buscar cliente por nombre o teléfono',
          hintText: 'Buscar cliente por nombre o teléfono',
          hideLabel: true,
          controller: _ctrl,
          onChanged: _onChanged,
        ),
        if (estado != null) ...[
          const SizedBox(height: AppSpacing.sm),
          estado,
        ],
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: '+ Nuevo cliente y mascota',
          icon: Icons.person_add_alt_outlined,
          variant: AppButtonVariant.text,
          onPressed: widget.onNuevoClienteYMascota,
        ),
      ],
    );
  }
}
