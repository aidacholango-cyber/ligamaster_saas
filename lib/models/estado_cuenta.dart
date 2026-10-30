import 'dart:convert';
import 'cobro_manual.dart';

String dineroTesoreria(int centavos) =>
    '${centavos < 0 ? '-' : ''}${importeCentavos(centavos.abs())}';

String fechaTesoreria(Object? valor) {
  final fecha = DateTime.tryParse('$valor')?.toLocal();
  if (fecha == null) return 'Sin fecha';
  return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

class BalanceTesoreria {
  int cobrado = 0, recibido = 0, arbitros = 0;
  int get saldo => cobrado - recibido;
}

Map<String, BalanceTesoreria> balancesTesoreria(
  List<Map<String, dynamic>> partidos,
) {
  final balances = <String, BalanceTesoreria>{};
  for (final partido in partidos) {
    final cobro = partido['cobro'] as Map?;
    if (cobro != null) {
      final moneda = '${cobro['moneda']}';
      final balance = balances.putIfAbsent(moneda, BalanceTesoreria.new);
      balance.cobrado += totalCobro(
        List<Map<String, dynamic>>.from(cobro['items'] as List),
      );
    }
    for (final m in partido['movimientos'] as List? ?? []) {
      if (m['anulado_en'] != null) continue;
      final b = balances.putIfAbsent('${m['moneda']}', BalanceTesoreria.new);
      final monto = (m['centavos'] as num).toInt();
      if (m['tipo'] == 'aporte_equipo') b.recibido += monto;
      if (m['tipo'] == 'pago_arbitro') b.arbitros += monto;
    }
  }
  return balances;
}

List<Map<String, dynamic>> partidosEnPeriodo(
  List<Map<String, dynamic>> partidos,
  DateTime? desde,
  DateTime? hasta,
) => partidos.where((p) {
  final fecha = DateTime.tryParse('${p['fecha']}')?.toLocal();
  if (fecha == null) return desde == null && hasta == null;
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  return (desde == null || !dia.isBefore(desde)) &&
      (hasta == null || !dia.isAfter(hasta));
}).toList();

/// Genera solo datos visibles; escapa nombres, referencias y observaciones.
String htmlEstadoCuenta(
  Map<String, dynamic> datos,
  List<Map<String, dynamic>> partidos, {
  DateTime? desde,
  DateTime? hasta,
}) {
  String e(Object? v) => const HtmlEscape().convert(v?.toString() ?? '');
  final filas = StringBuffer();
  for (final p in partidos) {
    final cobro = p['cobro'] as Map?;
    filas.write(
      '<tr class="partido"><td colspan="4">${e(fechaTesoreria(p['fecha']))} · '
      'Jornada ${e(p['jornada'])} · Partido ${e(p['numero_partido'])} · ${e(p['local'])} vs ${e(p['visitante'])}</td></tr>',
    );
    if (cobro == null)
      filas.write(
        '<tr><td colspan="4">Cobro de este equipo pendiente de publicar. No suma al total.</td></tr>',
      );
    for (final item in List<Map<String, dynamic>>.from(
      cobro?['items'] as List? ?? [],
    )) {
      filas.write(
        '<tr><td>Cobro</td><td colspan="2">${e(detalleCobro(item))}</td>'
        '<td>${e(cobro?['moneda'])} ${dineroTesoreria((item['centavos'] as num).toInt())}</td></tr>',
      );
    }
    for (final m in p['movimientos'] as List? ?? []) {
      final anulado = m['anulado_en'] != null;
      filas.write(
        '<tr><td>${e(fechaTesoreria(m['fecha']))}</td><td>'
        '${m['tipo'] == 'aporte_equipo' ? 'Pago del equipo' : 'Entrega al árbitro'}'
        '${anulado ? ' (ANULADO)' : ''}</td><td>${e(m['referencia'])} '
        '${e(m['beneficiario'])}${anulado ? ' · Motivo: ${e(m['motivo_anulacion'])}' : ''}'
        '${m['comprobante'] == null ? '' : ' · Comprobante archivado'}</td>'
        '<td>${e(m['moneda'])} ${dineroTesoreria((m['centavos'] as num).toInt())}</td></tr>',
      );
    }
  }
  final resumen = balancesTesoreria(partidos).entries.map((entrada) {
    final b = entrada.value;
    return '<tr><td>${e(entrada.key)}</td><td>${dineroTesoreria(b.cobrado)}</td>'
        '<td>${dineroTesoreria(b.recibido)}</td><td>${dineroTesoreria(b.saldo)}</td>'
        '<td>${dineroTesoreria(b.arbitros)}</td></tr>';
  }).join();
  return '<!doctype html><html lang="es"><head><meta charset="utf-8">'
      '<title>Estado de cuenta · ${e(datos['equipo'])}</title><style>'
      'body{font:13px Arial,sans-serif;color:#172033;margin:28px}h1{color:#166534;font-size:22px}'
      'table{width:100%;border-collapse:collapse;margin:16px 0}th,td{border:1px solid #ccd8cf;padding:9px;text-align:left}'
      'th,.partido{background:#e9f5ed}tr{break-inside:avoid}thead{display:table-header-group}'
      '@page{size:A4;margin:14mm}@media print{body{margin:0}}'
      '</style></head><body><h1>Tesorería · Estado de cuenta</h1>'
      '<p>${e(datos['liga'])} · ${e(datos['campeonato'])} · ${e(datos['categoria'])}</p>'
      '<h2>${e(datos['equipo'])}</h2><p>Partidos: '
      '${desde == null ? 'Desde el inicio' : fechaTesoreria(desde.toIso8601String())} — '
      '${hasta == null ? 'Hasta la fecha' : fechaTesoreria(hasta.toIso8601String())}</p>'
      '<table><thead><tr><th>Moneda</th><th>Cobros publicados</th><th>Recibido</th><th>Saldo pendiente</th>'
      '<th>Entregado al árbitro</th></tr></thead><tbody>$resumen</tbody></table>'
      '<p>El saldo corresponde a los partidos seleccionados e incluye todos sus pagos registrados. '
      'Un saldo negativo es crédito a favor. Las entregas al árbitro son egresos de la liga '
      'y no se descuentan nuevamente de la deuda del equipo.</p>'
      '<table><thead><tr><th>Fecha / tipo</th><th>Concepto</th><th>Referencia / beneficiario</th><th>Importe</th></tr></thead>'
      '<tbody>$filas</tbody></table><p>Emitido: ${fechaTesoreria(DateTime.now().toIso8601String())}. '
      'Los movimientos anulados se conservan como respaldo y no suman a los totales.</p></body></html>';
}
