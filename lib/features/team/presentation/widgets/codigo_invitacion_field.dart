import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/codigo_invitacion.dart';

/// Da formato `XXXX-XXXX` mientras se escribe: mayúsculas, descarta símbolos
/// fuera del alfabeto (0/O, 1/I/L, espacios, guiones) y limita a 8 símbolos.
class CodigoInvitacionFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final simbolos = newValue.text
        .toUpperCase()
        .split('')
        .where(alfabetoCodigoInvitacion.contains)
        .take(8)
        .join();
    final texto = formatearCodigoInvitacion(simbolos);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Campo de código de invitación, compartido por el registro y por "Unirme a
/// otra clínica".
class CodigoInvitacionField extends StatelessWidget {
  const CodigoInvitacionField({
    super.key,
    required this.controller,
    this.errorText,
    this.label = 'Código de invitación',
  });

  final TextEditingController controller;
  final String? errorText;
  final String label;

  @override
  Widget build(BuildContext context) => AppTextField(
    label: label,
    controller: controller,
    hintText: 'K7MQ-4P2X',
    helperText: 'Te lo envió el administrador de tu clínica.',
    errorText: errorText,
    prefixIcon: Icons.vpn_key_outlined,
    textCapitalization: TextCapitalization.characters,
    inputFormatters: [CodigoInvitacionFormatter()],
  );
}
