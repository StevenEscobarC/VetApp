/// Días hacia adelante en que un producto cuenta como "vence pronto".
const int kDiasVencePronto = 30;

/// Cambio de stock (en unidades) a partir del cual la UI pide confirmar.
const int kAjusteGrande = 10;

/// Mínimo sugerido al crear un producto.
const int kMinimoPorDefecto = 2;

/// Tope de cantidad aceptado por el formulario (y por el CHECK de la tabla).
const int kCantidadMaxima = 1000000;

/// Tope de un solo movimiento: `mover_stock` rechaza `abs(delta) > 100000`.
const int kAjusteMaximo = 100000;

/// Cuántos movimientos recientes muestra el historial de un producto.
const int kMovimientosHistorial = 50;
