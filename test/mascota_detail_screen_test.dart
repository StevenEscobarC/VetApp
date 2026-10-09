import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/core/utils/captura_foto.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/media/app_photo_picker.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clinical_history/data/services/historia_clinica_pdf_service.dart';
import 'package:vetapp/features/clinical_history/domain/consulta_failure.dart';
import 'package:vetapp/features/clinical_history/presentation/providers/consultas_providers.dart';
import 'package:vetapp/features/clinical_history/presentation/providers/historia_clinica_pdf_providers.dart';
import 'package:vetapp/features/clinical_history/presentation/screens/consulta_form_screen.dart';
import 'package:vetapp/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart';
import 'package:vetapp/features/patients/domain/entities/peso_registro.dart';
import 'package:vetapp/features/patients/domain/mascota_failure.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/patients/presentation/screens/mascota_detail_screen.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_consultas.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_pdf.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

/// Historial de peso de Rocky (m-1), seedeado deliberadamente fuera de
/// orden (enero, junio, marzo) — la pantalla es la que debe ordenar de
/// forma defensiva, no el fake.
final _pesosRocky = [
  PesoRegistro(
    id: 'p-1',
    mascotaId: 'm-1',
    pesoKg: 10,
    registradoEn: DateTime(2026, 1, 10),
  ),
  PesoRegistro(
    id: 'p-2',
    mascotaId: 'm-1',
    pesoKg: 12.5,
    registradoEn: DateTime(2026, 6, 1),
  ),
  PesoRegistro(
    id: 'p-3',
    mascotaId: 'm-1',
    pesoKg: 11,
    registradoEn: DateTime(2026, 3, 15),
  ),
];

Carne _carneVacia(String id) => Carne(
  hoy: DateTime.utc(2026, 10, 2),
  mascotaId: id,
  mascotaNombre: 'Rocky',
  especie: 'perro',
  raza: '',
  duenoNombre: '',
  duenoTelefono: '',
  clinicaNombre: '',
  clinicaCiudad: '',
  biologicos: const [],
  dosis: const [],
);

/// Carné con una dosis de polivalente en el estado dado.
Carne _carneConEstado(String id, EstadoCarne estado) => Carne(
  hoy: DateTime.utc(2026, 10, 2),
  mascotaId: id,
  mascotaNombre: 'Rocky',
  especie: 'perro',
  raza: '',
  duenoNombre: '',
  duenoTelefono: '',
  clinicaNombre: '',
  clinicaCiudad: '',
  biologicos: [
    BiologicoCarne(
      codigoProtocolo: 'polivalente',
      biologicoNombre: 'Polivalente',
      tipo: TipoDosis.vacuna,
      ultimaDosisId: 'd-1',
      ultimaFecha: DateTime.utc(2026, 8, 30),
      posicion: 1,
      dosisSerie: 3,
      proximaFecha: DateTime.utc(2026, 9, 20),
      etiquetaProxima: '',
      estado: estado,
      diasVencida: estado == EstadoCarne.vencida ? 12 : 0,
      ventanaDias: 30,
      sugerirReiniciar: false,
    ),
  ],
  dosis: [
    DosisCarne(
      id: 'd-1',
      codigoProtocolo: 'polivalente',
      biologicoNombre: 'Polivalente',
      tipo: TipoDosis.vacuna,
      fechaAplicacion: DateTime.utc(2026, 8, 30),
      esUltima: true,
      externa: false,
      esRefuerzo: false,
      anulada: false,
    ),
  ],
);

Widget _appUnderTest({
  FakeVacunaRepository? vacunas,
  required FakeMascotaRepository repo,
  FakeMascotaFotoDatasource? fotos,
  CapturadorFoto? capturador,
  FakeConsultaRepository? consultaRepo,
  HistoriaClinicaPdfService? pdf,
  CompartirPdfFalso? compartir,
  String initialLocation = '/pacientes/m-1',
  bool formularioReal = false,
  MiPlan? plan,
}) {
  return routerHarness(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/pacientes',
        builder: (_, _) => const Text('LISTA PACIENTES'),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => MascotaDetailScreen(
              mascotaId: state.pathParameters['id']!,
              rutaBase: state.uri.path,
            ),
            routes: [
              GoRoute(
                path: 'carne',
                builder: (_, state) =>
                    Text('CARNE ${state.pathParameters['id']}'),
              ),
              GoRoute(
                path: 'consultas/nueva',
                builder: (_, state) => formularioReal
                    ? ConsultaFormScreen(
                        mascotaId: state.pathParameters['id']!,
                      )
                    : Text('FORM CONSULTA ${state.pathParameters['id']}'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/clientes/:id',
        builder: (_, state) =>
            Text('FICHA CLIENTE ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/agenda/nueva',
        builder: (_, state) => Text('nueva-cita ${state.uri.query}'),
      ),
    ],
    overrides: [
      ...planOverrides(plan: plan),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      mascotaRepositoryProvider.overrideWithValue(repo),
      vacunaRepositoryProvider.overrideWithValue(
        vacunas ??
            FakeVacunaRepository(
              carnes: {
                'm-1': _carneVacia('m-1'),
                'm-2': _carneVacia('m-2'),
              },
            ),
      ),
      mascotaFotoDatasourceProvider.overrideWithValue(
        fotos ?? FakeMascotaFotoDatasource(),
      ),
      capturadorFotoProvider.overrideWithValue(
        capturador ?? capturadorFalso(null),
      ),
      consultaRepositoryProvider.overrideWithValue(
        consultaRepo ?? FakeConsultaRepository(),
      ),
      historiaClinicaPdfServiceProvider.overrideWithValue(
        pdf ?? HistoriaClinicaPdfService(cargarFuentes: fuentesDePrueba),
      ),
      compartirPdfProvider.overrideWithValue(
        (compartir ?? CompartirPdfFalso()).call,
      ),
    ],
  );
}

void main() {
  testWidgets('sin dosis: sección Carné vacía y sin insignia', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Carné de vacunación'), findsOneWidget);
    expect(find.text('Sin vacunas registradas'), findsOneWidget);
    expect(find.text('Vacunas al día'), findsNothing);
    expect(find.text('Vencida'), findsNothing);
  });

  testWidgets('con vencidas: insignia Vencida y sección con pendientes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
    final vacunas = FakeVacunaRepository(
      carnes: {'m-1': _carneConEstado('m-1', EstadoCarne.vencida)},
    );
    await tester.pumpWidget(_appUnderTest(repo: repo, vacunas: vacunas));
    await tester.pumpAndSettle();

    // Insignia bajo el nombre + chip de la sección.
    expect(find.text('Vencida'), findsNWidgets(2));
    expect(find.text('1 pendientes'), findsOneWidget);
    expect(find.text('1 dosis'), findsOneWidget);
  });

  testWidgets('con dosis y sin pendientes: Vacunas al día', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
    final vacunas = FakeVacunaRepository(
      carnes: {'m-1': _carneConEstado('m-1', EstadoCarne.alDia)},
    );
    await tester.pumpWidget(_appUnderTest(repo: repo, vacunas: vacunas));
    await tester.pumpAndSettle();

    expect(find.text('Vacunas al día'), findsOneWidget);
  });

  testWidgets('tocar la sección navega a /pacientes/<id>/carne', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
    final vacunas = FakeVacunaRepository(
      carnes: {'m-1': _carneConEstado('m-1', EstadoCarne.proxima)},
    );
    await tester.pumpWidget(_appUnderTest(repo: repo, vacunas: vacunas));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('1 pendientes'));
    await tester.tap(find.text('1 pendientes'));
    await tester.pumpAndSettle();

    expect(find.text('CARNE m-1'), findsOneWidget);
  });

  testWidgets(
    '"Agendar cita" es un botón outline que navega a /agenda/nueva con '
    'clienteId y mascotaId',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      final boton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Agendar cita'),
      );
      expect(boton.variant, AppButtonVariant.outline);
      final primarios = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .where((b) => b.variant == AppButtonVariant.primary);
      expect(primarios, hasLength(1));

      await tester.ensureVisible(find.text('Agendar cita'));
      await tester.tap(find.text('Agendar cita'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'nueva-cita clienteId=${mascotaRocky.duenoId}&mascotaId=m-1',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('muestra los datos de la mascota y el nombre del dueño', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Rocky'), findsOneWidget);
    expect(find.textContaining('Perro'), findsOneWidget);
    expect(find.textContaining('Labrador'), findsOneWidget);
    expect(find.text('Rita Gómez'), findsOneWidget);
  });

  testWidgets(
    'el historial de peso se muestra del más reciente al más antiguo',
    (tester) async {
      final repo = FakeMascotaRepository(
        mascotas: [mascotaRocky],
        pesosPorMascota: {'m-1': _pesosRocky},
      );
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('01/06/2026'), findsOneWidget);
      expect(find.text('12,5 kg'), findsOneWidget);
      expect(find.text('11 kg'), findsOneWidget);
      expect(find.text('10 kg'), findsOneWidget);

      final y125 = tester.getTopLeft(find.text('12,5 kg')).dy;
      final y11 = tester.getTopLeft(find.text('11 kg')).dy;
      final y10 = tester.getTopLeft(find.text('10 kg')).dy;
      expect(y125, lessThan(y11));
      expect(y11, lessThan(y10));
    },
  );

  testWidgets('mascota sin pesos registrados muestra el estado vacío', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(mascotas: [mascotaLuna]);
    await tester.pumpWidget(
      _appUnderTest(repo: repo, initialLocation: '/pacientes/m-2'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay pesos registrados'), findsOneWidget);
    expect(
      find.text('Usa “Registrar peso” para agregar el primero.'),
      findsOneWidget,
    );
  });

  testWidgets('no hay acciones de editar o borrar en el historial de peso', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(
      mascotas: [mascotaRocky],
      pesosPorMascota: {'m-1': _pesosRocky},
    );
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets(
    'Registrar peso valida un peso inválido sin llamar al repositorio, y '
    'guarda uno válido mostrándolo arriba del historial',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Registrar peso'));
      await tester.tap(find.text('Registrar peso'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un peso válido en kg'), findsOneWidget);
      expect(repo.pesosRegistrados, isEmpty);

      await tester.enterText(find.byType(TextFormField), '13,2');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.pesosRegistrados, [(mascotaId: 'm-1', pesoKg: 13.2)]);
      expect(find.text('13,2 kg'), findsOneWidget);
    },
  );

  testWidgets(
    'el AppPhotoPicker de la ficha recibe fotoPath y cacheKey coincidentes',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      final img = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(img.cacheKey, 'cli-1/m-1/1.jpg');
    },
  );

  testWidgets(
    'tocar el avatar sube la nueva foto, actualiza foto_path y borra la '
    'anterior en segundo plano',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final fotos = FakeMascotaFotoDatasource();
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          fotos: fotos,
          capturador: capturadorFalso(kFotoPrueba),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pumpAndSettle();

      expect(fotos.uploads, [('cli-1', 'm-1')]);
      expect(repo.fotoPathsActualizados['m-1'], 'cli-1/m-1/fake.jpg');
      expect(fotos.eliminados, ['cli-1/m-1/1.jpg']);
    },
  );

  testWidgets('tocar el nombre del dueño navega a su ficha de cliente', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rita Gómez'));
    await tester.pumpAndSettle();

    expect(find.text('FICHA CLIENTE c-1'), findsOneWidget);
  });

  testWidgets(
    "muestra 'Historia clínica', demota 'Editar' a outline, y 'Nueva "
    "consulta' es el único botón primario de la ficha",
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Historia clínica'), findsOneWidget);

      final editar = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Editar'),
      );
      expect(editar.variant, AppButtonVariant.outline);

      final botonesPrimarios = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .where((b) => b.variant == AppButtonVariant.primary);
      expect(botonesPrimarios, hasLength(1));
      expect(botonesPrimarios.single.label, 'Nueva consulta');

      expect(find.text('Grabar nota de voz'), findsNothing);
    },
  );

  testWidgets(
    "tocar 'Nueva consulta' navega al formulario de consulta para esa "
    'mascota',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Nueva consulta'));
      await tester.tap(find.text('Nueva consulta'));
      await tester.pumpAndSettle();

      expect(find.text('FORM CONSULTA m-1'), findsOneWidget);
    },
  );

  testWidgets(
    'la historia clínica se muestra del más reciente al más antiguo, sin '
    'importar el orden en que la fuente de datos entrega las consultas',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, consultaRepo: consultaRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('05/08/2026'), findsOneWidget);
      expect(find.text('12/04/2026'), findsOneWidget);
      expect(find.text('20/02/2026'), findsOneWidget);

      final yGastro = tester.getTopLeft(find.text('Gastroenteritis leve')).dy;
      final yControl = tester.getTopLeft(find.text('Control general')).dy;
      final yOtitis = tester.getTopLeft(find.text('Otitis externa')).dy;
      expect(yGastro, lessThan(yControl));
      expect(yControl, lessThan(yOtitis));
    },
  );

  testWidgets(
    "el orden de secciones es 'Historial de peso' -> 'Historia clínica' -> "
    "la primera tarjeta de consulta -> el botón 'Nueva consulta'",
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, consultaRepo: consultaRepo),
      );
      await tester.pumpAndSettle();

      final yPeso = tester.getTopLeft(find.text('Historial de peso')).dy;
      final yHistoria = tester.getTopLeft(find.text('Historia clínica')).dy;
      final yPrimeraConsulta = tester
          .getTopLeft(find.text('Gastroenteritis leve'))
          .dy;
      final yBoton = tester
          .getTopLeft(find.widgetWithText(AppButton, 'Nueva consulta'))
          .dy;

      expect(yPeso, lessThan(yHistoria));
      expect(yHistoria, lessThan(yPrimeraConsulta));
      expect(yPrimeraConsulta, lessThan(yBoton));
    },
  );

  testWidgets(
    'mascota sin consultas registradas muestra el estado vacío de historia '
    'clínica',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaLuna]);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, initialLocation: '/pacientes/m-2'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aún no hay consultas registradas'), findsOneWidget);
      expect(
        find.text('Usa “Nueva consulta” para agregar la primera.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'si falla la carga de la historia clínica se muestra el error y el '
    'resto de la ficha sigue renderizando',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(
        error: const ConsultaFailure('boom'),
      );
      await tester.pumpWidget(
        _appUnderTest(repo: repo, consultaRepo: consultaRepo),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar la historia clínica. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Rocky'), findsOneWidget);
    },
  );

  testWidgets(
    'las tarjetas de consulta empiezan colapsadas: sin Anamnesis ni '
    'Tratamiento visibles, con el chevron hacia abajo',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, consultaRepo: consultaRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anamnesis'), findsNothing);
      expect(find.text('Tratamiento'), findsNothing);
      expect(
        find.byIcon(Icons.keyboard_arrow_down),
        findsNWidgets(consultasRocky.length),
      );
    },
  );

  testWidgets(
    'expandir la tarjeta de Otitis muestra el registro completo con signos '
    'vitales, y tocarla otra vez la colapsa de nuevo',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, consultaRepo: consultaRepo),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Otitis externa'));
      await tester.tap(find.text('Otitis externa'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('Se rasca la oreja derecha'), findsOneWidget);
      expect(find.text('Peso: 4,2 kg'), findsOneWidget);
      expect(find.text('Temperatura: 38,5 °C'), findsOneWidget);
      expect(find.text('Frecuencia cardíaca: 90 lpm'), findsOneWidget);
      expect(find.text('Frecuencia respiratoria: 24 rpm'), findsOneWidget);
      expect(find.text('Mucosas: rosadas'), findsOneWidget);
      expect(find.text('Gotas óticas cada 12 horas'), findsOneWidget);
      expect(find.text('Mejoría a los 5 días'), findsOneWidget);

      await tester.tap(find.text('Otitis externa').first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
      expect(
        find.byIcon(Icons.keyboard_arrow_down),
        findsNWidgets(consultasRocky.length),
      );
    },
  );

  testWidgets(
    "expandir la tarjeta de Control general muestra 'Examen físico: Sin "
    "registrar' una sola vez y 'Sin registrar' para Anamnesis y Evolución",
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, consultaRepo: consultaRepo),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Control general'));
      await tester.tap(find.text('Control general'));
      await tester.pumpAndSettle();

      final timeline = find.byType(HistoriaClinicaTimeline);
      expect(
        find.descendant(
          of: timeline,
          matching: find.text('Examen físico: Sin registrar'),
        ),
        findsOneWidget,
      );
      // Scoped to the timeline: the ficha itself also uses "Sin registrar"
      // for its own blank fields (e.g. "Fecha de nacimiento"), which is
      // unrelated to this card.
      expect(
        find.descendant(
          of: timeline,
          matching: find.text('Sin registrar'),
        ),
        findsNWidgets(2),
      );
      expect(find.textContaining('Peso:'), findsNothing);
    },
  );

  testWidgets(
    'la línea de tiempo de historia clínica no ofrece ningún ícono de '
    'editar o borrar (HIST-04)',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, consultaRepo: consultaRepo),
      );
      await tester.pumpAndSettle();

      final timeline = find.byType(HistoriaClinicaTimeline);
      expect(
        find.descendant(of: timeline, matching: find.byIcon(Icons.edit)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: timeline,
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: timeline, matching: find.byIcon(Icons.delete)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: timeline,
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'al registrar una consulta desde la ficha, el vet vuelve y la ve arriba '
    'de la historia clínica y del historial de peso, sin refrescar a mano',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(mascotas: repo);
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          consultaRepo: consultaRepo,
          formularioReal: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Nueva consulta'));
      await tester.tap(find.text('Nueva consulta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Dermatitis');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Champú medicado',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Agregar más detalles'));
      await tester.tap(find.text('Agregar más detalles'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(3), '13,4');
      await tester.pump();

      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Guardar consulta'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Guardar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Consulta guardada'), findsOneWidget);
      expect(find.text('Dermatitis'), findsOneWidget);
      expect(find.text('13,4 kg'), findsOneWidget);
    },
  );

  testWidgets(
    "la ficha tiene un botón 'Exportar historia clínica a PDF' en la barra "
    'superior (HIST-03)',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Exportar historia clínica a PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'tocar el botón de exportar genera el PDF y lo comparte con el nombre '
    'de archivo correcto',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      final compartir = CompartirPdfFalso();
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          consultaRepo: consultaRepo,
          compartir: compartir,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Exportar historia clínica a PDF'));
      await tester.pumpAndSettle();

      expect(compartir.llamadas, hasLength(1));
      expect(compartir.llamadas.single.filename, 'historia_clinica_Rocky.pdf');
      expect(
        String.fromCharCodes(compartir.llamadas.single.bytes.take(4)),
        '%PDF',
      );
    },
  );

  testWidgets(
    'para una mascota sin consultas el botón de exportar sigue habilitado '
    'y comparte igual (D-04)',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaLuna]);
      final compartir = CompartirPdfFalso();
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          compartir: compartir,
          initialLocation: '/pacientes/m-2',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Exportar historia clínica a PDF'), findsOneWidget);

      await tester.tap(find.byTooltip('Exportar historia clínica a PDF'));
      await tester.pumpAndSettle();

      expect(compartir.llamadas, hasLength(1));
    },
  );

  testWidgets(
    'mientras se genera el PDF el ícono se convierte en un spinner y no se '
    'puede volver a tocar; al completar la carga de fuentes se comparte '
    'exactamente una vez',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final compartir = CompartirPdfFalso();
      final completer = Completer<({pw.Font regular, pw.Font bold})>();
      final pdf = HistoriaClinicaPdfService(
        cargarFuentes: () => completer.future,
      );
      await tester.pumpWidget(
        _appUnderTest(repo: repo, pdf: pdf, compartir: compartir),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Exportar historia clínica a PDF'));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsNothing);
      expect(find.byTooltip('Exportar historia clínica a PDF'), findsNothing);

      completer.complete((
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ));
      await tester.pumpAndSettle();

      expect(compartir.llamadas, hasLength(1));
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'si falla la generación del PDF se muestra el error, no se comparte '
    'nada y el ícono vuelve a aparecer',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final compartir = CompartirPdfFalso();
      final pdf = HistoriaClinicaPdfService(cargarFuentes: fuentesQueFallan);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, pdf: pdf, compartir: compartir),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Exportar historia clínica a PDF'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos generar el PDF. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(compartir.llamadas, isEmpty);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    },
  );

  group('solo lectura (colega sin plan vigente)', () {
    const hoja = 'Tu cuenta está en solo lectura';

    void pantallaAlta(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Finder candadoEn(String etiqueta) => find.descendant(
      of: find.widgetWithText(AppButton, etiqueta),
      matching: find.byIcon(Icons.lock_outline),
    );

    for (final etiqueta in [
      'Editar',
      'Registrar peso',
      'Nueva consulta',
      'Agendar cita',
    ]) {
      testWidgets(
        '"$etiqueta" muestra candado, semántica bloqueada y abre la hoja '
        'sin navegar',
        (tester) async {
          final semantics = tester.ensureSemantics();
          pantallaAlta(tester);
          final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
          await tester.pumpWidget(
            _appUnderTest(repo: repo, plan: planSoloLectura),
          );
          await tester.pumpAndSettle();

          final boton = find.widgetWithText(AppButton, etiqueta);
          final original = tester.widget<AppButton>(boton);
          expect(candadoEn(etiqueta), findsOneWidget);
          expect(
            tester.getSemantics(boton).label,
            contains('bloqueado, solo lectura'),
          );

          await tester.ensureVisible(boton);
          await tester.tap(boton);
          await tester.pumpAndSettle();

          expect(find.text(hoja), findsOneWidget);
          expect(find.text('FORM CONSULTA m-1'), findsNothing);
          expect(find.textContaining('nueva-cita'), findsNothing);
          expect(find.text('Paciente'), findsOneWidget);
          // Conserva variante y tamaño: solo cambia el ícono.
          expect(tester.widget<AppButton>(boton).variant, original.variant);
          expect(tester.widget<AppButton>(boton).expand, original.expand);
          semantics.dispose();
        },
      );
    }

    testWidgets('"Registrar peso" en solo lectura no abre la hoja de peso', (
      tester,
    ) async {
      pantallaAlta(tester);
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo, plan: planSoloLectura));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Registrar peso'));
      await tester.tap(find.text('Registrar peso'));
      await tester.pumpAndSettle();

      expect(find.text(hoja), findsOneWidget);
      expect(find.text('Peso (kg)'), findsNothing);
    });

    testWidgets(
      'con plan Beta ningún control lleva candado y todo funciona como antes',
      (tester) async {
        pantallaAlta(tester);
        final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
        await tester.pumpWidget(_appUnderTest(repo: repo, plan: planBeta));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock_outline), findsNothing);
        expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

        await tester.ensureVisible(find.text('Nueva consulta'));
        await tester.tap(find.text('Nueva consulta'));
        await tester.pumpAndSettle();
        expect(find.text('FORM CONSULTA m-1'), findsOneWidget);
        expect(find.text(hoja), findsNothing);
      },
    );

    testWidgets('tocar la foto abre la hoja en vez de la captura', (
      tester,
    ) async {
      pantallaAlta(tester);
      var capturas = 0;
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final fotos = FakeMascotaFotoDatasource();
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          fotos: fotos,
          plan: planSoloLectura,
          capturador: (context, fuente) async {
            capturas++;
            return kFotoPrueba;
          },
        ),
      );
      await tester.pumpAndSettle();

      // El badge de cámara pasa a candado (conserva su lugar).
      expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppPhotoPicker),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsWidgets,
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text(hoja), findsOneWidget);
      expect(capturas, 0);
      expect(fotos.uploads, isEmpty);
    });

    testWidgets('"Elegir de galería" en solo lectura abre la hoja y no captura', (
      tester,
    ) async {
      pantallaAlta(tester);
      var capturas = 0;
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          plan: planSoloLectura,
          capturador: (context, fuente) async {
            capturas++;
            return kFotoPrueba;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Elegir de galería'));
      await tester.pumpAndSettle();

      expect(find.text(hoja), findsOneWidget);
      expect(capturas, 0);
    });

    testWidgets('Exportar historia clínica a PDF sigue funcionando', (
      tester,
    ) async {
      pantallaAlta(tester);
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      final compartir = CompartirPdfFalso();
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          consultaRepo: consultaRepo,
          compartir: compartir,
          plan: planSoloLectura,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      await tester.tap(find.byTooltip('Exportar historia clínica a PDF'));
      await tester.pumpAndSettle();

      expect(compartir.llamadas, hasLength(1));
      expect(find.text(hoja), findsNothing);
    });

    testWidgets('la historia clínica se puede leer y expandir', (tester) async {
      pantallaAlta(tester);
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final consultaRepo = FakeConsultaRepository(consultas: consultasRocky);
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          consultaRepo: consultaRepo,
          plan: planSoloLectura,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Otitis externa'));
      await tester.tap(find.text('Otitis externa'));
      await tester.pumpAndSettle();
      expect(find.text('Se rasca la oreja derecha'), findsOneWidget);
      expect(find.text(hoja), findsNothing);
    });

    testWidgets(
      'LP004 al guardar el peso (bandera vencida) abre la hoja de solo '
      'lectura',
      (tester) async {
        pantallaAlta(tester);
        final repo = FakeMascotaRepository(
          mascotas: [mascotaRocky],
          errorRegistrarPeso: const MascotaFailure(
            'Tu cuenta está en solo lectura. Pide al administrador que '
            'active el plan.',
            limite: LimitePlan.soloLectura,
          ),
        );
        await tester.pumpWidget(_appUnderTest(repo: repo, plan: planBeta));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Registrar peso'));
        await tester.tap(find.text('Registrar peso'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '13,2');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        expect(find.text(hoja), findsOneWidget);
        expect(find.textContaining('Pide al administrador'), findsNothing);
        expect(repo.pesosRegistrados, hasLength(1));
      },
    );

    testWidgets(
      'LP004 al cambiar la foto (bandera vencida) abre la hoja y no muestra '
      'el snackbar de error',
      (tester) async {
        pantallaAlta(tester);
        final repo = FakeMascotaRepository(
          mascotas: [mascotaRocky],
          errorActualizarFoto: const MascotaFailure(
            'Tu cuenta está en solo lectura. Pide al administrador que '
            'active el plan.',
            limite: LimitePlan.soloLectura,
          ),
        );
        await tester.pumpWidget(
          _appUnderTest(
            repo: repo,
            plan: planBeta,
            capturador: capturadorFalso(kFotoPrueba),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.camera_alt_outlined));
        await tester.pumpAndSettle();

        expect(find.text(hoja), findsOneWidget);
        expect(
          find.text('No pudimos subir la foto. Intenta de nuevo.'),
          findsNothing,
        );
      },
    );
  });
}
