import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/carne_pdf_service.dart';

final carnePdfServiceProvider = Provider<CarnePdfService>(
  (_) => CarnePdfService(),
);
