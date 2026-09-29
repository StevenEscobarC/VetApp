import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/captura_foto.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../clinical_history/data/services/historia_clinica_pdf_service.dart';
import '../../../clinical_history/domain/consulta_failure.dart';
import '../../../clinical_history/presentation/providers/consultas_providers.dart';
import '../../../clinical_history/presentation/providers/historia_clinica_pdf_providers.dart';
import '../../../clinical_history/presentation/widgets/historia_clinica_timeline.dart';
import '../../domain/entities/mascota.dart';
import '../../domain/entities/peso_registro.dart';
import '../../domain/mascota_failure.dart';
import '../providers/mascota_foto_providers.dart';
import '../providers/mascotas_providers.dart';
import '../widgets/mascota_foto_avatar.dart';

/// Ficha de mascota (PAT-02 ver, PAT-03 cambiar foto, PAT-05 historial de
/// peso, HIST-01 historia clínica, HIST-03 exportar a PDF). Alcanzable
/// desde `PacientesListScreen` (`/pacientes/:id`) y desde la ficha de un
/// cliente (`/clientes/:id/mascotas/:mascotaId`) — [rutaBase] guarda la
/// ubicación donde se abrió esta ficha (`state.uri.path` en la ruta que la
/// construyó) para que las rutas hijas (`editar`, `consultas/nueva`)
/// puedan empujar `'$rutaBase/...'` sin importar desde cuál lista se
/// llegó. La sección "Historia clínica" es el único CTA de acento de esta
/// pantalla ("Editar" quedó demotado a `outline`, UI-SPEC Fase 3) — Plan
/// 03-04 inserta la línea de tiempo entre el encabezado y el botón "Nueva
/// consulta"; Plan 03-05 agrega la acción "Exportar PDF" en la barra
/// superior (D-04: siempre exporta TODA la historia, nunca deshabilitada;
/// D-05: solo share sheet nativo, sin previsualización ni diálogo).
class MascotaDetailScreen extends ConsumerStatefulWidget {
  const MascotaDetailScreen({
    super.key,
    required this.mascotaId,
    required this.rutaBase,
  });

  final String mascotaId;
  final String rutaBase;

  @override
  ConsumerState<MascotaDetailScreen> createState() =>
      _MascotaDetailScreenState();
}

class _MascotaDetailScreenState extends ConsumerState<MascotaDetailScreen> {
  bool _subiendoFoto = false;
  bool _exportando = false;

  /// Exporta TODA la historia clínica del paciente a PDF y la entrega al
  /// share sheet nativo del sistema operativo (HIST-03, D-04, D-05) — sin
  /// pantalla de previsualización ni diálogo de confirmación. Nunca
  /// deshabilitada, ni siquiera sin consultas (D-04: un historial vacío
  /// también se exporta). Mientras `_exportando` es `true` el ícono se
  /// reemplaza por un spinner, así que un segundo toque no es posible.
  Future<void> _exportarPdf() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final mascota = await ref.read(
        mascotaProvider(widget.mascotaId).future,
      );
      final consultas = await ref.read(
        consultasProvider(widget.mascotaId).future,
      );
      final bytes = await ref
          .read(historiaClinicaPdfServiceProvider)
          .generar(mascota: mascota, consultas: consultas);
      await ref.read(compartirPdfProvider)(
        bytes: bytes,
        filename: HistoriaClinicaPdfService.nombreArchivo(mascota.nombre),
      );
    } on ConsultaFailure {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos generar el PDF. Intenta de nuevo.'),
          ),
        );
      }
    } on MascotaFailure {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos generar el PDF. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  /// Reemplaza la foto (D-05, camera-first): sube la nueva, actualiza
  /// `foto_path`, y solo entonces intenta borrar la anterior en su propio
  /// try/catch que ignora fallos (T-02-32) — perder el objeto viejo nunca
  /// es una pérdida de datos, así que nunca bloquea ni reporta error al
  /// vet. Sin diálogo de confirmación: reemplazar no es destructivo
  /// (UI-SPEC).
  Future<void> _cambiarFoto(Mascota mascota, FuenteFoto fuente) async {
    final capturador = ref.read(capturadorFotoProvider);
    final bytes = await capturador(context, fuente);
    if (bytes == null || !mounted) return;

    setState(() => _subiendoFoto = true);
    try {
      final path = await ref
          .read(mascotaFotoDatasourceProvider)
          .upload(
            clinicaId: mascota.clinicaId,
            mascotaId: widget.mascotaId,
            bytes: bytes,
          );
      await ref
          .read(mascotaRepositoryProvider)
          .actualizarFotoPath(widget.mascotaId, path);

      final fotoAnterior = mascota.fotoPath;
      if (fotoAnterior != null) {
        try {
          await ref.read(mascotaFotoDatasourceProvider).eliminar(fotoAnterior);
        } catch (_) {
          // Best-effort (T-02-32): el objeto anterior puede quedar
          // huérfano, pero nunca bloquea el flujo ni se le reporta al vet.
        }
      }

      ref.invalidate(mascotaProvider(widget.mascotaId));
      ref.read(mascotasProvider.notifier).refrescar();
    } on MascotaFailure {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos subir la foto. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  void _abrirRegistrarPeso() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RegistrarPesoSheet(mascotaId: widget.mascotaId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mascotaAsync = ref.watch(mascotaProvider(widget.mascotaId));
    return Scaffold(
      appBar: AppTopBar(
        title: 'Paciente',
        actions: [
          if (_exportando)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exportar historia clínica a PDF',
              onPressed: mascotaAsync.hasValue ? _exportarPdf : null,
            ),
        ],
      ),
      body: mascotaAsync.when(
        data: (mascota) => _buildBody(context, mascota),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('No pudimos cargar la mascota. Intenta de nuevo.'),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Mascota mascota) {
    final textTheme = Theme.of(context).textTheme;
    final fechaNacimiento = mascota.fechaNacimiento;
    final raza = mascota.raza;
    final rutaBase = widget.rutaBase;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: MascotaFotoAvatar(
              fotoPath: mascota.fotoPath,
              size: 96,
              isUploading: _subiendoFoto,
              onTomarFoto: () => _cambiarFoto(mascota, FuenteFoto.camara),
              onElegirGaleria: () => _cambiarFoto(mascota, FuenteFoto.galeria),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              mascota.nombre,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Editar',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.outline,
            onPressed: () => context.push('$rutaBase/editar'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FichaRow(label: 'Especie', valor: mascota.especie.etiqueta),
          _FichaRow(
            label: 'Raza',
            valor: (raza == null || raza.isEmpty) ? 'Sin registrar' : raza,
          ),
          _FichaRow(
            label: 'Fecha de nacimiento',
            valor: fechaNacimiento == null
                ? 'Sin registrar'
                : '${formatearFecha(fechaNacimiento)} · '
                      '${formatearEdad(mascota.edadEnAnios)}',
          ),
          _FichaRow(
            label: 'Dueño',
            valor: mascota.duenoNombre ?? 'Sin registrar',
            onTapValor: mascota.duenoNombre == null
                ? null
                : () => context.push('/clientes/${mascota.duenoId}'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Historial de peso', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _HistorialPeso(mascotaId: widget.mascotaId),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Registrar peso',
            icon: Icons.add,
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: _abrirRegistrarPeso,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Historia clínica', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          HistoriaClinicaTimeline(mascotaId: widget.mascotaId),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Nueva consulta',
            icon: Icons.add,
            onPressed: () => context.push('$rutaBase/consultas/nueva'),
          ),
        ],
      ),
    );
  }
}

/// Fila de ficha de solo lectura: etiqueta a la izquierda, valor a la
/// derecha. Si [onTapValor] no es null, el valor se muestra con estilo de
/// enlace (color de acento) y es tocable — usado por la fila "Dueño".
class _FichaRow extends StatelessWidget {
  const _FichaRow({required this.label, required this.valor, this.onTapValor});

  final String label;
  final String valor;
  final VoidCallback? onTapValor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valorWidget = Text(
      valor,
      style: onTapValor == null
          ? textTheme.bodyLarge
          : textTheme.bodyLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: onTapValor == null
                ? valorWidget
                : GestureDetector(onTap: onTapValor, child: valorWidget),
          ),
        ],
      ),
    );
  }
}

/// Historial de peso (PAT-05): ordena de forma defensiva por
/// `registradoEn` descendente — nunca confía ciegamente en el orden que
/// entrega la fuente de datos. Filas simples separadas por [Divider], sin
/// ningún ícono/acción de editar o borrar (append-only).
class _HistorialPeso extends ConsumerWidget {
  const _HistorialPeso({required this.mascotaId});

  final String mascotaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pesosAsync = ref.watch(pesosProvider(mascotaId));
    final textTheme = Theme.of(context).textTheme;

    return pesosAsync.when(
      data: (pesos) {
        if (pesos.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aún no hay pesos registrados', style: textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Usa “Registrar peso” para agregar el primero.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        }

        final ordenados = List<PesoRegistro>.of(pesos)
          ..sort((a, b) => b.registradoEn.compareTo(a.registradoEn));

        return Column(
          children: [
            for (var i = 0; i < ordenados.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatearPeso(ordenados[i].pesoKg),
                      style: textTheme.bodyLarge,
                    ),
                    Text(
                      formatearFecha(ordenados[i].registradoEn),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text(
        'No pudimos cargar el historial de peso. Intenta de nuevo.',
      ),
    );
  }
}

/// Hoja "Registrar peso" (PAT-05): un solo campo numérico — nunca edita ni
/// borra un registro existente (T-02-PESO). `parsearPeso` valida antes de
/// llamar al repositorio.
class _RegistrarPesoSheet extends ConsumerStatefulWidget {
  const _RegistrarPesoSheet({required this.mascotaId});

  final String mascotaId;

  @override
  ConsumerState<_RegistrarPesoSheet> createState() =>
      _RegistrarPesoSheetState();
}

class _RegistrarPesoSheetState extends ConsumerState<_RegistrarPesoSheet> {
  final _pesoCtrl = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _pesoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final peso = parsearPeso(_pesoCtrl.text);
    if (peso.error != null || peso.valor == null) {
      setState(() => _error = peso.error ?? 'Ingresa un peso válido en kg');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref
          .read(mascotaRepositoryProvider)
          .registrarPeso(widget.mascotaId, peso.valor!);
      ref.invalidate(pesosProvider(widget.mascotaId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Peso registrado')));
    } on MascotaFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar peso',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Peso (kg)',
              controller: _pesoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              errorText: _error,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Guardar',
              onPressed: _guardar,
              isLoading: _guardando,
            ),
          ],
        ),
      ),
    );
  }
}
