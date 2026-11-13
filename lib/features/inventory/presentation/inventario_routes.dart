import 'package:go_router/go_router.dart';

import 'screens/inventario_screen.dart';
import 'screens/producto_form_screen.dart';

/// Ruta del alta de producto.
const String kRutaNuevoProducto = '/inventario/nuevo';

/// Rutas de inventario de primer nivel (fuera del shell de la barra inferior)
/// para que cualquier punto de entrada empuje la misma pantalla. Desde estas
/// pantallas solo se empujan rutas de primer nivel: empujar una ruta de una
/// rama del shell duplica la página del shell en el Navigator raíz (G5).
final List<GoRoute> inventarioRoutes = [
  GoRoute(path: '/inventario', builder: (_, _) => const InventarioScreen()),
  GoRoute(
    path: kRutaNuevoProducto,
    builder: (_, _) => const ProductoFormScreen(),
  ),
];

/// Lista de inventario; con [bajos] abre con el filtro "Bajos" (lo lee 06-07).
String rutaInventario({bool bajos = false}) => Uri(
  path: '/inventario',
  queryParameters: bajos ? {'filtro': 'bajos'} : null,
).toString();
