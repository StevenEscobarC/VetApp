import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/inicio_revision.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../auth/data/repositories/supabase_auth_repository.dart'
    show AuthProfile;
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../inventory/data/repositories/supabase_inventario_repository.dart'
    show esErrorDeRed;
import '../../../inventory/presentation/providers/inventario_providers.dart';
import '../../../inventory/presentation/widgets/stock_bajo_card.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/aviso_plan_visible_provider.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../../../plan/presentation/widgets/plan_banner.dart';
import '../../../vaccination/presentation/providers/alertas_providers.dart';
import '../../../vaccination/presentation/widgets/mascota_search_sheet.dart';
import '../../../vaccination/presentation/widgets/vacunas_pendientes_card.dart';
import '../../data/supabase_inicio_repository.dart'
    show kMensajeSinConexionLectura;
import '../providers/inicio_providers.dart';
import '../widgets/inicio_colores.dart';
import '../widgets/inicio_encabezado.dart';
import '../widgets/metricas_mes.dart';

/// Inicio de la Fase 8 (D-12): saludo, aviso de plan, cifras reales del mes,
/// Vacunar y alertas. Cada bloque falla solo (D-14) y todo se recarga al
/// deslizar hacia abajo o al volver la app a primer plano (D-13).
class InicioScreen extends ConsumerStatefulWidget {
  const InicioScreen({super.key});

  @override
  ConsumerState<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends ConsumerState<InicioScreen> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    // Resumen y próximas citas ya se releen solos al volver (sus providers
    // escuchan el ciclo de vida); aquí van el perfil, el plan y las alertas.
    _ciclo = AppLifecycleListener(onResume: _invalidarAlertas);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  void _invalidarAlertas() {
    if (!mounted) return;
    ref.invalidate(authProfileProvider);
    ref.invalidate(miPlanProvider);
    ref.invalidate(resumenVacunasProvider);
    ref.invalidate(vacunasPendientesProvider);
    ref.invalidate(resumenInventarioProvider);
  }

  Future<void> _refrescar() async {
    ref.read(inicioRevisionProvider.notifier).incrementar();
    _invalidarAlertas();
    // Los errores salen en su bloque: el indicador siempre se detiene.
    try {
      await Future.wait([
        ref.read(inicioResumenProvider.future),
        ref.read(proximasCitasProvider.future),
      ]);
    } catch (_) {}
  }

  Future<void> _vacunar() async {
    if (!await asegurarEscritura(
      context,
      ref,
      plan: ref.read(miPlanProvider).value,
    )) {
      return;
    }
    if (!mounted) return;
    unawaited(showMascotaSearchSheet(context));
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(authProfileProvider);
    final textTheme = Theme.of(context).textTheme;

    final Widget cuerpo;
    if (profileAsync.hasError && !profileAsync.hasValue) {
      cuerpo = _ErrorPerfil(
        sinConexion: esErrorDeRed(profileAsync.error!),
        cargando: profileAsync.isLoading,
        onReintentar: () => ref.invalidate(authProfileProvider),
      );
    } else if (profileAsync.hasValue && profileAsync.value == null) {
      cuerpo = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sin sesión activa', style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Vuelve a iniciar sesión para ver tu información.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      cuerpo = _contenido(profileAsync.value);
    }

    return Scaffold(body: SafeArea(bottom: false, child: cuerpo));
  }

  Widget _contenido(AuthProfile? profile) {
    final colorScheme = Theme.of(context).colorScheme;
    final puedeEscribir = ref.watch(puedeEscribirProvider);
    final hayAviso = ref.watch(avisoPlanVisibleProvider) != null;

    // Mismas condiciones de visibilidad que las tarjetas, para no dejar
    // huecos de más cuando una está oculta (UI-SPEC §0).
    final vacunasAsync = ref.watch(resumenVacunasProvider);
    final vacunas = vacunasAsync.hasError ? null : vacunasAsync.value;
    final verVacunas =
        vacunas == null || vacunas.vencidas + vacunas.proximas > 0;
    final verStock =
        (ref.watch(resumenInventarioProvider).value?.bajos ?? 0) > 0;

    return RefreshIndicator(
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      onRefresh: _refrescar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          InicioEncabezado(
            nombre: profile?.nombre,
            clinica: profile?.clinicaNombre,
          ),
          if (hayAviso) ...[
            const SizedBox(height: AppSpacing.lg),
            const PlanBanner(),
            // PlanBanner ya trae md abajo: md + sm = lg hasta las cifras.
            const SizedBox(height: AppSpacing.sm),
          ] else
            const SizedBox(height: AppSpacing.lg),
          const MetricasMes(),
          const SizedBox(height: AppSpacing.lg),
          // Solo lectura: conserva lugar, acento y tamaño; el ícono pasa a
          // candado y el toque abre la hoja explicativa en vez del
          // buscador (D-12). Registrar una dosis es una escritura.
          ControlEscritura(
            puedeEscribir: puedeEscribir,
            label: 'Vacunar',
            onTap: _vacunar,
            child: AppButton(
              label: 'Vacunar',
              icon: iconoEscritura(puedeEscribir, Icons.vaccines_outlined),
              onPressed: _vacunar,
            ),
          ),
          if (verVacunas) ...[
            const SizedBox(height: AppSpacing.lg),
            const VacunasPendientesCard(mostrarSiVacia: false),
          ],
          if (verStock) ...[
            // StockBajoCard trae md arriba: sola necesita sm más para lg;
            // detrás de vacunas, su md es el hueco entre alertas.
            if (!verVacunas) const SizedBox(height: AppSpacing.sm),
            const StockBajoCard(),
          ],
        ],
      ),
    );
  }
}

class _ErrorPerfil extends StatelessWidget {
  const _ErrorPerfil({
    required this.sinConexion,
    required this.cargando,
    required this.onReintentar,
  });

  final bool sinConexion;
  final bool cargando;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                sinConexion
                    ? kMensajeSinConexionLectura
                    : 'No pudimos cargar tu perfil.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: InicioColores.secundario(context),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Reintentar',
              variant: AppButtonVariant.text,
              expand: false,
              isLoading: cargando,
              onPressed: onReintentar,
            ),
          ],
        ),
      ),
    );
  }
}
