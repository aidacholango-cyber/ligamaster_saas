import 'dart:convert';
import '../widgets/refresco_deportivo.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaSanciones extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  const PantallaSanciones({super.key, required this.campeonato});

  @override
  State<PantallaSanciones> createState() => _PantallaSancionesState();
}

class _PantallaSancionesState extends State<PantallaSanciones>
    with RefrescoDeportivo<PantallaSanciones> {
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
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _datos = _leer();
  }

  Future<List<Map<String, dynamic>>> _leer() async {
    final respuesta = await Supabase.instance.client.rpc(
      'lm_leer_sanciones',
      params: {'p_campeonato_id': widget.campeonato['id'].toString()},
    );
    return List<Map<String, dynamic>>.from(respuesta as List);
  }

  void _recargar() {
    final carga = _leer();
    setState(() {
      _datos = carga;
    });
  }

  int _numero(Map<String, dynamic> fila, String campo) =>
      (fila[campo] as num?)?.toInt() ?? 0;

  Widget _jugador(Map<String, dynamic> fila) {
    final fechas = fila['fechas_por_revisar'] == true;
    final incumplimiento = _numero(fila, 'participaciones_suspendido') > 0;
    final pendientes = _numero(fila, 'partidos_pendientes');
    final generados = _numero(fila, 'partidos_suspension_generados');
    final motivos = <String>[
      if (_numero(fila, 'expulsiones_doble_amarilla') > 0)
        'Doble amarilla: ${fila['expulsiones_doble_amarilla']}',
      if (_numero(fila, 'rojas_directas') > 0)
        'Roja directa: ${fila['rojas_directas']}',
      if (_numero(fila, 'sanciones_acumulacion') > 0)
        'Acumulación de cinco amarillas: ${fila['sanciones_acumulacion']}',
    ];
    final estado = fechas
        ? 'Revisar fechas'
        : incumplimiento
        ? 'Revisar participación'
        : pendientes > 0
        ? 'Suspendido'
        : generados > 0
        ? 'Suspensión cumplida'
        : 'Sin suspensión';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${fila['nombres'] ?? ''} ${fila['apellidos'] ?? ''}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(fila['equipo'].toString()),
            const SizedBox(height: 8),
            Text(
              estado,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: fechas || incumplimiento
                    ? Colors.orange.shade900
                    : pendientes > 0
                    ? Colors.red.shade700
                    : Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Amarillas totales: ${fila['amarillas_total']} · '
              'Ciclo actual: ${fila['amarillas_ciclo_actual']}/5',
            ),
            if (motivos.isNotEmpty) Text(motivos.join(' · ')),
            Text('Partidos de suspensión generados: $generados'),
            if (fechas)
              const Text(
                'El administrador debe revisar las fechas de los partidos '
                'confirmados. No se puede determinar el cumplimiento todavía.',
              )
            else ...[
              Text(
                'Cumplidos: ${fila['partidos_cumplidos']} · Pendientes: $pendientes',
              ),
              if (incumplimiento)
                const Text(
                  'Se registró participación durante una suspensión. '
                  'El administrador debe revisar las planillas.',
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sanciones'),
      actions: [
        IconButton(
          onPressed: _recargar,
          tooltip: 'Actualizar sanciones',
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
                        : 'No se pudieron cargar las sanciones. Intenta nuevamente.',
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
        final filas = snapshot.data!;
        final filtro = _busqueda.trim().toLowerCase();
        final visibles = filas
            .where(
              (f) => '${f['nombres']} ${f['apellidos']} ${f['equipo']}'
                  .toLowerCase()
                  .contains(filtro),
            )
            .toList();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(24),
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
                  '${widget.campeonato['nombre']} · ${widget.campeonato['categoria']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar jugador o equipo',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (valor) {
                    setState(() {
                      _busqueda = valor;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (filas.isEmpty)
                  const Text(
                    'No hay tarjetas registradas en partidos confirmados '
                    'de este campeonato y categoría.',
                  )
                else if (visibles.isEmpty)
                  const Text('No hay coincidencias con la búsqueda.')
                else
                  for (final fila in visibles) _jugador(fila),
                const SizedBox(height: 16),
                const Text(
                  'Las sanciones corresponden a este campeonato y categoría. '
                  'Solo descuentan los partidos confirmados del equipo '
                  'en los que el jugador no participó.',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
