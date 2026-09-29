import '../../../core/utils/formato.dart';
import 'entities/consulta.dart';

/// Formatea una temperatura en grados Celsius con una posición decimal y
/// coma como separador decimal (formato colombiano, mismo criterio que
/// [formatearPeso]) — reutilizada por la línea de tiempo de historia
/// clínica y por el PDF (Plan 03-05) para que ambos lean exactamente igual.
String formatearTemperatura(double celsius) {
  final texto = celsius.toStringAsFixed(1).replaceAll('.', ',');
  return '$texto °C';
}

/// Una línea `Etiqueta: valor` por cada signo vital presente en [examen],
/// en orden fijo (peso, temperatura, frecuencia cardíaca, frecuencia
/// respiratoria, mucosas) — nunca incluye un signo vital que no fue
/// registrado. Compartida por la línea de tiempo y el PDF (mismo criterio
/// que [formatearTemperatura]) para que ambos muestren exactamente las
/// mismas líneas; si [examen.estaVacio] es `true` la lista vuelve vacía y
/// el llamador debe mostrar en su lugar una única línea
/// "Examen físico: Sin registrar".
List<String> lineasExamenFisico(ExamenFisico examen) {
  final lineas = <String>[];

  final pesoKg = examen.pesoKg;
  if (pesoKg != null) lineas.add('Peso: ${formatearPeso(pesoKg)}');

  final temperaturaC = examen.temperaturaC;
  if (temperaturaC != null) {
    lineas.add('Temperatura: ${formatearTemperatura(temperaturaC)}');
  }

  final frecuenciaCardiaca = examen.frecuenciaCardiaca;
  if (frecuenciaCardiaca != null) {
    lineas.add('Frecuencia cardíaca: $frecuenciaCardiaca lpm');
  }

  final frecuenciaRespiratoria = examen.frecuenciaRespiratoria;
  if (frecuenciaRespiratoria != null) {
    lineas.add('Frecuencia respiratoria: $frecuenciaRespiratoria rpm');
  }

  final mucosas = examen.mucosas;
  if (mucosas != null && mucosas.isNotEmpty) {
    lineas.add('Mucosas: $mucosas');
  }

  return lineas;
}
