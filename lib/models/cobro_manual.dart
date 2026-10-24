const conceptosCobro = <String, String>{
  'arbitraje': 'Arbitraje',
  'ta': 'T.A.',
  'tr': 'T.R.',
  'mantenimiento': 'Mantenimiento de cancha',
  'otro': 'Otro cobro',
};

bool monedaCobroValida(String valor) =>
    RegExp(r'^(?:[A-Za-z]{3}|\$|€|£)$').hasMatch(valor.trim());

// Trabaja con centavos enteros para no redondear importes con doubles.
int? leerCentavos(String texto) {
  final valor = texto.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(valor)) return null;
  final partes = valor.split('.');
  return int.parse(partes.first) * 100 +
      (partes.length == 1 ? 0 : int.parse(partes[1].padRight(2, '0')));
}

String importeCentavos(int centavos) =>
    '${centavos ~/ 100}.${(centavos % 100).toString().padLeft(2, '0')}';

int totalCobro(List<Map<String, dynamic>> items) =>
    items.fold(0, (total, item) => total + (item['centavos'] as num).toInt());

String detalleCobro(Map<String, dynamic> item) {
  final tipo = item['tipo'];
  if (tipo == 'ta' || tipo == 'tr') {
    return '${conceptosCobro[tipo]} · jugador n.º ${item['camiseta']}';
  }
  return tipo == 'otro'
      ? item['concepto'].toString()
      : conceptosCobro[tipo] ?? '';
}
