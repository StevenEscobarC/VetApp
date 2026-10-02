/// Alfabeto de los códigos de invitación: sin 0/O, 1/I/L para que un código
/// dictado por teléfono o leído en pantalla no se confunda.
const alfabetoCodigoInvitacion = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Pasa a mayúsculas y descarta todo lo que no sea alfanumérico, de modo que
/// el usuario pueda pegar o escribir el código con guion o espacios.
String normalizarCodigoInvitacion(String entrada) =>
    entrada.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Presenta el código como `XXXX-XXXX`; si aún está incompleto (4 o menos
/// caracteres) lo devuelve normalizado y sin guion.
String formatearCodigoInvitacion(String entrada) {
  final n = normalizarCodigoInvitacion(entrada);
  if (n.length <= 4) return n;
  return '${n.substring(0, 4)}-${n.substring(4)}';
}

/// `true` cuando [entrada] normalizada tiene 8 caracteres, todos del
/// [alfabetoCodigoInvitacion].
bool esCodigoInvitacionCompleto(String entrada) {
  final n = normalizarCodigoInvitacion(entrada);
  if (n.length != 8) return false;
  return n.split('').every(alfabetoCodigoInvitacion.contains);
}
