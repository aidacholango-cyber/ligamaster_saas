import 'dart:convert';
import '../widgets/refresco_deportivo.dart';
import 'package:flutter/material.dart';
import 'lista_goleadores.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaConsultaDeportiva extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  final String seccion, titulo;
  const PantallaConsultaDeportiva({
    super.key,
    required this.campeonato,
    required this.seccion,
    required this.titulo,
  });
  @override
  State<PantallaConsultaDeportiva> createState() =>
      _PantallaConsultaDeportivaState();
}

class _PantallaConsultaDeportivaState extends State<PantallaConsultaDeportiva>
    with RefrescoDeportivo<PantallaConsultaDeportiva> {
  @override
  Future<void> refrescarDeporte() async {
    List<Map<String, dynamic>>? anteriores;
    try {
      anteriores = await _datos;
    } catch (_) {
      /* Reintentar una lectura inicial fallida. */
    }
    final nuevos = await _leer();
    if (mounted &&
        (anteriores == null || jsonEncode(anteriores) != jsonEncode(nuevos))) {
      setState(() => _datos = Future.value(nuevos));
    }
  }

  late Future<List<Map<String, dynamic>>> _datos;
  @override
  void initState() {
    super.initState();
    _datos = _leer();
  }

  Future<List<Map<String, dynamic>>> _leer() async {
    final filas = <Map<String, dynamic>>[];
    for (var desde = 0; ; desde += 500) {
      final respuesta = await Supabase.instance.client.rpc(
        widget.seccion == 'goleadores'
            ? 'lm_goleadores_con_foto'
            : 'lm_consulta_deportiva',
        params: {
          'p_campeonato_id': widget.campeonato['id'].toString(),
          if (widget.seccion != 'goleadores') 'p_seccion': widget.seccion,
          'p_desde': desde,
        },
      );
      final pagina = List<Map<String, dynamic>>.from(respuesta as List);
      filas.addAll(pagina);
      if (pagina.length < 500) break;
    }
    return filas;
  }

  void _recargar() {
    final carga = _leer();
    setState(() {
      _datos = carga;
    });
  }

  String _fecha(dynamic texto) {
    final fecha = DateTime.tryParse(texto?.toString() ?? '')?.toLocal();
    if (fecha == null) return 'Fecha y hora por definir';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} · '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Widget _partido(Map<String, dynamic> p) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p['fase']} · Jornada ${p['jornada']} · Partido ${p['numero_partido']}',
          ),
          if (p['grupo'] != null) Text('Grupo: ${p['grupo']}'),
          const SizedBox(height: 8),
          Text(
            '${p['local']} vs. ${p['visitante']}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_fecha(p['fecha_hora'])),
          Text('Cancha: ${p['cancha'] ?? 'Por definir'}'),
          Text('Estado: ${p['estado']}'),
          if (p['goles_local'] != null) ...[
            Text(
              'Resultado confirmado: ${p['goles_local']} – ${p['goles_visitante']}',
            ),
            if (p['prorroga_local'] != null)
              Text(
                'Goles en prórroga: ${p['prorroga_local']} – ${p['prorroga_visitante']}',
              ),
            if (p['penales_local'] != null)
              Text(
                'Tanda de penales: ${p['penales_local']} – ${p['penales_visitante']}',
              ),
          ],
        ],
      ),
    ),
  );

  Widget _tabla(List<Map<String, dynamic>> filas) {
    final campos = <String, String>{
      'Equipo': 'equipo',
      'PJ': 'partidos_jugados',
      'PG': 'ganados',
      'PE': 'empatados',
      'PP': 'perdidos',
      'GF': 'goles_favor',
      'GC': 'goles_contra',
      'DG': 'diferencia_goles',
      'Pts': 'puntos',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: [
          for (final entrada in campos.entries)
            DataColumn(
              label: Text(entrada.key),
              numeric: !['equipo', 'jugador'].contains(entrada.value),
            ),
        ],
        rows: [
          for (final fila in filas)
            DataRow(
              cells: [
                for (final campo in campos.values)
                  DataCell(
                    Text(
                      campo == 'jugador'
                          ? '${fila['nombres'] ?? ''} ${fila['apellidos'] ?? ''}'
                          : '${fila[campo] ?? ''}',
                      style: ['puntos', 'goles'].contains(campo)
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _contenido(List<Map<String, dynamic>> filas) {
    if (filas.isEmpty) {
      return [
        Text(
          widget.seccion == 'fixture'
              ? 'Todavía no hay partidos programados.'
              : widget.seccion == 'goleadores'
              ? 'Todavía no hay goles en resultados confirmados.'
              : 'Todavía no hay posiciones disponibles en fases regulares.',
        ),
      ];
    }
    if (widget.seccion == 'fixture')
      return [for (final p in filas) _partido(p)];
    if (widget.seccion == 'goleadores') {
      return [ListaGoleadores(jugadores: filas)];
    }
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final fila in filas) {
      grupos
          .putIfAbsent('${fila['fase_id']}:${fila['grupo_id']}', () => [])
          .add(fila);
    }
    return [
      for (final grupo in grupos.values) ...[
        Text(
          '${grupo.first['fase']}'
          '${grupo.first['grupo'] == null ? '' : ' · ${grupo.first['grupo']}'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _tabla(grupo),
        const SizedBox(height: 20),
      ],
      const Text(
        'Solo resultados confirmados. Igual puntaje mantiene el empate.\n'
        'PJ: jugados · PG: ganados · PE: empatados · PP: perdidos\n'
        'GF: goles a favor · GC: goles en contra · DG: diferencia · Pts: puntos',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.titulo),
      actions: [
        IconButton(
          onPressed: _recargar,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _datos,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is PostgrestException
                        ? error.message
                        : 'No se pudo cargar la información.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _recargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LigaMaster SaaS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4351BF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${widget.campeonato['nombre']} · ${widget.campeonato['categoria']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      ..._contenido(snapshot.data!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
