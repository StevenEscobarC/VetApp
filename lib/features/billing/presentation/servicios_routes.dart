import 'package:go_router/go_router.dart';

import 'cobros_rutas.dart';
import 'screens/servicios_screen.dart';

/// Ruta de servicios de primer nivel (fuera del shell de la barra inferior),
/// empujada desde la acción "Servicios y precios" de Cobros y desde "Agregar
/// servicios" del formulario de cobro. Vive en su propio archivo para no
/// chocar con `cobros_routes.dart`. Desde aquí solo se empujan rutas de
/// primer nivel: empujar una ruta de una rama del shell duplica la página del
/// shell en el Navigator raíz (G5).
final List<GoRoute> serviciosRoutes = [
  GoRoute(path: kRutaServicios, builder: (_, _) => const ServiciosScreen()),
];
