import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaGoleadores extends StatefulWidget {
  final Map<String, dynamic> campeonato;

  const PantallaGoleadores({
    super.key,
    required this.campeonato,
  });

  @override
  State<PantallaGoleadores> createState() => _PantallaGoleadoresState();
}

class _PantallaGoleadoresState extends State<PantallaGoleadores> {
  late Future<List<Map<String, dynamic>>> _datos;

  @override
  void initState() {
    super.initState();
    _datos = _leer();
  }

  Future<List<Map<String, dynamic>>> _leer() async {
    final filas = <Map<String, dynamic>>[];

    for (var desde = 0; ; desde += 500) {
      final pagina = await Supabase.instance.client
          .from('lm_goleadores')
          .select()
          .eq('campeonato_id', widget.campeonato['id'].toString())
          .order('posicion')
          .order('apellidos')
          .order('nombres')
          .order('inscripcion_jugador_id')
          .range(desde, desde + 499);

      filas.addAll(List<Map<String, dynamic>>.from(pagina));

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

  String _nombre(Map<String, dynamic> jugador) {
    return [
      jugador['nombres']?.toString() ?? '',
      jugador['apellidos']?.toString() ?? '',
    ].where((parte) => parte.trim().isNotEmpty).join(' ');
  }

  Widget _tabla(List<Map<String, dynamic>> jugadores) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Posición'), numeric: true),
          DataColumn(label: Text('Jugador')),
          DataColumn(label: Text('Equipo')),
          DataColumn(label: Text('PJ'), numeric: true),
          DataColumn(label: Text('Goles'), numeric: true),
        ],
        rows: [
          for (final jugador in jugadores)
            DataRow(
              cells: [
                DataCell(Text('${jugador['posicion']}')),
                DataCell(Text(_nombre(jugador))),
                DataCell(Text('${jugador['equipo']}')),
                DataCell(Text('${jugador['partidos_jugados']}')),
                DataCell(
                  Text(
                    '${jugador['goles']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4351BF),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goleadores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar goleadores',
            onPressed: _recargar,
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
            final mensaje = error is PostgrestException
                ? error.message
                : 'No se pudieron cargar los goleadores. Intenta nuevamente.';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mensaje, textAlign: TextAlign.center),
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

          final jugadores = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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
                        const SizedBox(height: 16),
                        Text(
                          '${widget.campeonato['nombre']} · '
                          '${widget.campeonato['categoria']}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        if (jugadores.isEmpty)
                          const Text(
                            'Todavía no hay goleadores con '
                            'resultados confirmados en esta categoría.',
                          )
                        else
                          _tabla(jugadores),
                        const SizedBox(height: 20),
                        const Text(
                          'Solo se cuentan goles de partidos confirmados. '
                          'Los autogoles y los penales de la tanda '
                          'no suman a los goleadores.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'PJ: partidos en los que participó el jugador. '
                          'Los jugadores con igual cantidad de goles '
                          'comparten posición.',
                        ),
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
}