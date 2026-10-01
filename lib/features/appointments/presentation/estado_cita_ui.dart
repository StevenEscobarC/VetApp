import '../../../core/widgets/status/app_status_chip.dart';
import '../domain/entities/cita.dart';

/// Mapea el estado de dominio de una cita al estado visual del chip.
AppStatus estadoAStatus(EstadoCita e) => switch (e) {
      EstadoCita.pendiente => AppStatus.pending,
      EstadoCita.confirmada => AppStatus.confirmed,
      EstadoCita.completada => AppStatus.completed,
      EstadoCita.cancelada => AppStatus.cancelled,
      EstadoCita.noAsistio => AppStatus.noShow,
    };
