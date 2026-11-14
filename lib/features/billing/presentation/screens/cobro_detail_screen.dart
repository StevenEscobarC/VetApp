import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/entities/cobro_item.dart';
import '../../domain/numeracion.dart';
import '../cobros_rutas.dart';
import '../providers/cobros_providers.dart';
import '../widgets/anular_cobro_sheet.dart';
import '../widgets/cobro_fila.dart';
import '../widgets/enviar_cobro_sheet.dart';
import '../widgets/estado_cobro_chip.dart';
import '../widgets/marcar_pagada_sheet.dart';

/// Detalle de lectura de una cotización o cuenta de cobro (UI-SPEC §4).
/// Muestra lo que guardó el servidor: número, estado, total y las líneas
/// copiadas al emitir (D-14). Una cuenta de cobro nunca se edita (D-10); el
/// bloque de acciones llega en planes posteriores por [_acciones].
class CobroDetailScreen extends ConsumerWidget {
  const CobroDetailScreen({super.key, required this.cobroId});

  final String cobroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cobroProvider(cobroId));
    final cobro = async.value;

    final Widget cuerpo;
    if (cobro != null) {
      cuerpo = _Contenido(cobro: cobro, acciones: _acciones(cobro));
    } else if (async.hasError && !async.hasValue) {
      cuerpo = _Mensaje(
        texto: 'No pudimos cargar el cobro. Intenta de nuevo.',
        boton: 'Reintentar',
        onPressed: () => ref.invalidate(cobroProvider(cobroId)),
      );
    } else if (async.hasValue) {
      cuerpo = _Mensaje(
        texto: 'Este cobro ya no está disponible.',
        boton: 'Volver a Cobros',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(kRutaCobros),
      );
    } else {
      cuerpo = const _Esqueleto();
    }

    return Scaffold(
      appBar: AppTopBar(title: cobro?.tipo.etiqueta ?? 'Cobro'),
      body: cuerpo,
    );
  }

  /// Bloque de acciones del estado actual (UI-SPEC §4): a lo sumo un
  /// primario por estado (CC pendiente, CC pagada y cotización abierta tienen
  /// uno; convertida y anuladas, ninguno). Una cotización anulada no tiene
  /// acciones.
  Widget _acciones(Cobro c) => switch ((c.tipo, c.estado)) {
    (TipoCobro.cuentaCobro, EstadoCobro.pendiente) => _AccionesCcPendiente(
      cobro: c,
    ),
    (TipoCobro.cuentaCobro, EstadoCobro.pagada) => _AccionesCcPagada(cobro: c),
    (TipoCobro.cuentaCobro, EstadoCobro.anulada) => _AccionesCcAnulada(
      cobro: c,
    ),
    (TipoCobro.cotizacion, EstadoCobro.abierta) => _AccionesCotAbierta(
      cobro: c,
    ),
    (TipoCobro.cotizacion, EstadoCobro.convertida) => _AccionesCotConvertida(
      cobro: c,
    ),
    _ => const SizedBox.shrink(),
  };
}

/// Acción que escribe (UI-SPEC §8): en solo lectura conserva su lugar y
/// variante, muestra el candado y abre `LimitePlanSheet`; el servidor es la
/// autoridad (LP004).
class _BotonEscritura extends ConsumerWidget {
  const _BotonEscritura({
    required this.label,
    required this.icono,
    required this.alTocar,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final IconData? icono;
  final AppButtonVariant variant;
  final Future<void> Function(BuildContext context) alTocar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puede = ref.watch(puedeEscribirProvider);
    final icono = this.icono;

    Future<void> tocar() async {
      if (!await asegurarEscritura(
        context,
        ref,
        plan: ref.read(miPlanProvider).value,
      )) {
        return;
      }
      if (!context.mounted) return;
      await alTocar(context);
    }

    return ControlEscritura(
      puedeEscribir: puede,
      label: label,
      onTap: tocar,
      child: AppButton(
        label: label,
        icon: icono == null
            ? (puede ? null : Icons.lock_outline)
            : iconoEscritura(puede, icono),
        variant: variant,
        onPressed: tocar,
      ),
    );
  }
}

/// Cotización abierta (D-09, D-10): convertirla es la acción principal;
/// enviarla nunca se bloquea porque compartir no escribe.
class _AccionesCotAbierta extends StatelessWidget {
  const _AccionesCotAbierta({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BotonEscritura(
          label: 'Convertir en cuenta de cobro',
          icono: Icons.swap_horiz,
          alTocar: (ctx) => ctx.push(rutaConvertirCotizacion(cobro.id)),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Enviar al cliente',
          icon: Icons.ios_share,
          variant: AppButtonVariant.outline,
          onPressed: () => showEnviarCobroSheet(context, cobro),
        ),
        const SizedBox(height: AppSpacing.sm),
        _BotonEscritura(
          label: 'Editar cotización',
          icono: Icons.edit_outlined,
          variant: AppButtonVariant.outline,
          alTocar: (ctx) => ctx.push(rutaEditarCotizacion(cobro.id)),
        ),
        _AccionAnular(cobro: cobro),
      ],
    ),
  );
}

/// Cotización convertida: solo lectura, lleva a su CC y se puede reenviar.
class _AccionesCotConvertida extends StatelessWidget {
  const _AccionesCotConvertida({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context) {
    final ccId = cobro.convertidaEnId;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ccId != null) ...[
            AppButton(
              label:
                  'Ver '
                  '${formatearNumeroCobro(TipoCobro.cuentaCobro, cobro.convertidaEnNumero ?? 0)}',
              variant: AppButtonVariant.outline,
              onPressed: () => context.push(rutaCobro(ccId)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'Enviar al cliente',
            icon: Icons.ios_share,
            variant: AppButtonVariant.outline,
            onPressed: () => showEnviarCobroSheet(context, cobro),
          ),
        ],
      ),
    );
  }
}

/// CC anulada (D-10): se reemite como un borrador nuevo (otra clave) con el
/// mismo cliente, mascota, visita y líneas. No se envía ni se cobra.
class _AccionesCcAnulada extends StatelessWidget {
  const _AccionesCcAnulada({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: _BotonEscritura(
      label: 'Emitir una nueva',
      icono: null,
      variant: AppButtonVariant.outline,
      alTocar: (ctx) => ctx.push(
        rutaNuevoCobro(
          clienteId: cobro.clienteId,
          mascotaId: cobro.mascotaId,
          citaId: cobro.citaId,
          consultaId: cobro.consultaId,
          desdeCobroId: cobro.id,
        ),
      ),
    ),
  );
}

/// CC pendiente: primario "Marcar como pagada" (candado en solo lectura) y
/// outline "Enviar al cliente", que sigue usable porque compartir no escribe.
class _AccionesCcPendiente extends ConsumerWidget {
  const _AccionesCcPendiente({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puede = ref.watch(puedeEscribirProvider);

    Future<void> marcar() async {
      if (!await asegurarEscritura(
        context,
        ref,
        plan: ref.read(miPlanProvider).value,
      )) {
        return;
      }
      if (!context.mounted) return;
      await showMarcarPagadaSheet(context, cobro);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ControlEscritura(
            puedeEscribir: puede,
            label: 'Marcar como pagada',
            onTap: marcar,
            child: AppButton(
              label: 'Marcar como pagada',
              icon: iconoEscritura(puede, Icons.payments_outlined),
              onPressed: marcar,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Enviar al cliente',
            icon: Icons.ios_share,
            variant: AppButtonVariant.outline,
            onPressed: () => showEnviarCobroSheet(context, cobro),
          ),
          _AccionAnular(cobro: cobro),
        ],
      ),
    );
  }
}

/// CC pagada: el envío pasa a ser la acción principal.
class _AccionesCcPagada extends StatelessWidget {
  const _AccionesCcPagada({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'Enviar al cliente',
          icon: Icons.ios_share,
          onPressed: () => showEnviarCobroSheet(context, cobro),
        ),
        _AccionAnular(cobro: cobro),
      ],
    ),
  );
}

/// "Anular cuenta de cobro" / "Anular cotización" (D-10, D-19): última
/// acción, destructiva. Límite de rol: oculta (sin candado ni explicación)
/// para quien no es el administrador ni quien la emitió; el servidor es la
/// autoridad (42501). En solo lectura conserva su lugar con candado y abre
/// `LimitePlanSheet`.
class _AccionAnular extends ConsumerWidget {
  const _AccionAnular({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(puedeAnularCobroProvider(cobro.creadoPor))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: _BotonEscritura(
        label: cobro.esCotizacion
            ? 'Anular cotización'
            : 'Anular cuenta de cobro',
        icono: null,
        variant: AppButtonVariant.destructive,
        alTocar: (ctx) => showAnularCobroSheet(ctx, cobro),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.cobro, required this.acciones});

  final Cobro cobro;
  final Widget acciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = diaBogota(ref.watch(clockProvider)());
    final abajo = MediaQuery.paddingOf(context).bottom + AppSpacing.xl;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        abajo,
      ),
      children: [
        _Encabezado(cobro: cobro, hoy: hoy),
        const SizedBox(height: AppSpacing.lg),
        _ClienteCard(cobro: cobro),
        const SizedBox(height: AppSpacing.lg),
        _DetalleCard(cobro: cobro),
        acciones,
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.cobro, required this.hoy});

  final Cobro cobro;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final c = cobro;
    final t = Theme.of(context).textTheme;
    final muted = t.labelLarge?.copyWith(color: AppColors.textMuted);
    final chip = EstadoCobroChip.para(c.estado);

    final autor = c.autorNombre;
    final verbo = c.esCotizacion ? 'Creada' : 'Emitida';
    final lineas = <Widget>[
      Text(
        autor == null
            ? '$verbo el ${formatearFecha(c.fecha)}'
            : '$verbo el ${formatearFecha(c.fecha)} por Dr(a). $autor',
        style: muted,
      ),
      if (c.pagada && c.pagadaEl != null)
        Text(
          [
            'Pagada el ${formatearFecha(c.pagadaEl!)}',
            ?c.metodoPago?.etiqueta,
          ].join(' · '),
          style: muted,
        ),
      if (c.esCotizacion && c.abierta && c.validaHasta != null)
        Text(
          c.vencida(hoy)
              ? 'Venció el ${formatearFecha(c.validaHasta!)}'
              : 'Válida por $kDiasValidezCotizacion días, hasta el '
                    '${formatearFecha(c.validaHasta!)}',
          style: muted,
        ),
      // El documento no guarda la fecha de la visita: se muestra la del cobro.
      if (c.citaId != null)
        Text('De la cita del ${formatearFecha(c.fecha)}', style: muted),
      if (c.consultaId != null)
        Text('De la consulta del ${formatearFecha(c.fecha)}', style: muted),
      if (c.cotizacionOrigenId != null)
        _FilaEnlace(
          texto:
              'Viene de la cotización '
              '${formatearNumeroCobro(TipoCobro.cotizacion, c.cotizacionOrigenNumero ?? 0)}',
          onTap: () => context.push(rutaCobro(c.cotizacionOrigenId!)),
        ),
      if (c.convertidaEnId != null)
        _FilaEnlace(
          texto:
              'Convertida en '
              '${formatearNumeroCobro(TipoCobro.cuentaCobro, c.convertidaEnNumero ?? 0)}',
          onTap: () => context.push(rutaCobro(c.convertidaEnId!)),
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(c.numeroTexto, style: t.headlineSmall)),
              ?chip,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label:
                'Total ${pesosSemantica(c.totalCop)}'
                '${c.anulada ? ', anulada' : ''}',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatearCop(c.totalCop),
                style: t.displaySmall?.copyWith(
                  color: c.anulada
                      ? AppColors.textMuted
                      : AppColors.primaryText,
                  decoration: c.anulada ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
          if (c.anulada) ...[
            const SizedBox(height: AppSpacing.sm),
            _BloqueAnulada(cobro: c),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < lineas.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            lineas[i],
          ],
        ],
      ),
    );
  }
}

class _BloqueAnulada extends StatelessWidget {
  const _BloqueAnulada({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cuando = cobro.anuladaAt;
    final quien = cobro.anuladaPorNombre;
    final motivo = cobro.motivoAnulacion;
    final frase = StringBuffer('Anulada');
    if (cuando != null) frase.write(' el ${formatearFecha(diaBogota(cuando))}');
    if (quien != null) frase.write(' por Dr(a). $quien');
    frase.write('.');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(frase.toString(), style: t.bodyLarge),
                if (motivo != null && motivo.isNotEmpty)
                  Text('Motivo: $motivo', style: t.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaEnlace extends StatelessWidget {
  const _FilaEnlace({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: texto,
    excludeSemantics: true,
    onTap: onTap,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        child: Row(
          children: [
            Expanded(
              child: Text(texto, style: Theme.of(context).textTheme.labelLarge),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class _ClienteCard extends StatelessWidget {
  const _ClienteCard({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context) {
    final c = cobro;
    final t = Theme.of(context).textTheme;
    final clienteId = c.clienteId;
    final nombre = Text(c.clienteNombre, style: t.bodyLarge);
    final cedula = c.clienteCedula;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cliente', style: t.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          if (clienteId == null)
            nombre
          else
            // El detalle del cliente vive en una rama del shell: desde una
            // ruta de primer nivel se navega con `go`, no `push`, para no
            // duplicar la página del shell (G5).
            Semantics(
              button: true,
              label: '${c.clienteNombre}. Abrir cliente.',
              excludeSemantics: true,
              onTap: () => context.go('/clientes/$clienteId'),
              child: InkWell(
                onTap: () => context.go('/clientes/$clienteId'),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.touchTarget,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: nombre),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          if (cedula != null && cedula.isNotEmpty)
            Text(
              'C.C. ${formatearCedula(cedula)}',
              style: t.labelLarge?.copyWith(color: AppColors.textMuted),
            ),
          if (c.mascotaNombre != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Mascota: ${c.mascotaNombre}', style: t.labelLarge),
          ],
        ],
      ),
    );
  }
}

class _DetalleCard extends StatelessWidget {
  const _DetalleCard({required this.cobro});

  final Cobro cobro;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Detalle', style: t.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final item in cobro.items) ...[
            _LineaDetalle(item: item),
            const Divider(
              height: AppSpacing.md,
              thickness: 1,
              color: AppColors.border,
            ),
          ],
          Semantics(
            label: 'Total ${pesosSemantica(cobro.totalCop)}',
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(child: Text('Total', style: t.labelLarge)),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatearCop(cobro.totalCop),
                      style: t.headlineSmall?.copyWith(
                        decoration: cobro.anulada
                            ? TextDecoration.lineThrough
                            : null,
                        color: cobro.anulada ? AppColors.textMuted : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineaDetalle extends StatelessWidget {
  const _LineaDetalle({required this.item});

  final CobroItem item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label:
          '${item.descripcion}, ${item.cantidad} por '
          '${pesosSemantica(item.precioUnitarioCop)}, subtotal '
          '${pesosSemantica(item.subtotalCop)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.descripcion, style: t.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.cantidad} × ${formatearCop(item.precioUnitarioCop)}',
                  style: t.labelLarge?.copyWith(color: AppColors.textMuted),
                ),
              ),
              Text(formatearCop(item.subtotalCop), style: t.labelLarge),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.texto,
    required this.boton,
    required this.onPressed,
  });

  final String texto;
  final String boton;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: boton,
              variant: AppButtonVariant.outline,
              expand: false,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) {
    Widget bloque(double alto) => Container(
      height: alto,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(child: bloque(96)),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < 3; i++) ...[
          AppCard(child: bloque(40)),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
