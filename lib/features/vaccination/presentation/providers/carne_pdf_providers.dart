import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../clinic/presentation/providers/clinica_providers.dart';
import '../../data/services/carne_pdf_service.dart';

final carnePdfServiceProvider = Provider<CarnePdfService>(
  (ref) => CarnePdfService(
    cargarFuenteDisplay: () => PdfGoogleFonts.caprasimoRegular(),
    cargarLogo: (path) =>
        ref.read(clinicaLogoDatasourceProvider).descargar(path),
  ),
);
