import 'dart:convert';
import '../widgets/refresco_deportivo.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaPosiciones extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  const PantallaPosiciones({super.key, required this.campeonato});

  @override
  State<PantallaPosiciones> createState() => _PantallaPosicionesState();
}

class _PantallaPosicionesState extends State<PantallaPosiciones>
    with RefrescoDeportivo<PantallaPosiciones> {
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
      setState(() {
        _datos = Future.value(nuevos);
      });
    }
  }

  late Future<List<Map<String, dynamic>>> _datos;
  String? _faseId;

  @override
  void initState() {
    super.initState();
    _datos = _leer();
  }

  Future<List<Map<String, dynamic>>> _leer() async {
    final filas = <Map<String, dynamic>>[];
    // Paginar evita omitir equipos al superar el límite de Supabase.
    for (var desde = 0; ; desde += 500) {
      final pagina = await Supabase.instance.client
          .from('lm_tabla_posiciones')
          .select()
          .eq('campeonato_id', widget.campeonato['id'].toString())
          .order('orden_fase')
          .order('fase_id')
          .order('grupo_id')
          .order('equipo_id')
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

  int _numero(Map<String, dynamic> fila, String campo) =>
      (fila[campo] as num?)?.toInt() ?? 0;

  Widget _tabla(List<Map<String, dynamic>> equipos) {
    equipos.sort((a, b) {
      final puntos = _numero(b, 'puntos').compareTo(_numero(a, 'puntos'));
      // El nombre solo organiza la visualización; no resuelve desempates.
      return puntos != 0
          ? puntos
          : a['equipo'].toString().compareTo(b['equipo'].toString());
    });
    const campos = {
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBDEC9)),
        ),
        clipBehavior: Clip.antiAlias,
        child: DataTable(
        columnSpacing: 22,
        horizontalMargin: 20,
        headingRowHeight: 52,
        dataRowMinHeight: 58,
        dataRowMaxHeight: 58,
        headingRowColor: const WidgetStatePropertyAll(Color(0xFF166534)),
        headingTextStyle: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFDCE8E0))),
        columns: [
          const DataColumn(label: Text('Equipo')),
          for (final campo in campos.keys)
            DataColumn(label: Text(campo), numeric: true),
        ],
        rows: [
          for (var indice = 0; indice < equipos.length; indice++)
            DataRow(
              color: WidgetStatePropertyAll(indice.isEven
                  ? const Color(0xFFF0FDF4) : Colors.white),
              cells: [
                DataCell(Text(equipos[indice]['equipo'].toString(),
                  style: const TextStyle(color: Color(0xFF1D4DE2),
                    fontWeight: FontWeight.w600))),
                for (final campo in campos.values)
                  DataCell(
                    campo == 'puntos'
                      ? Container(
                          constraints: const BoxConstraints(minWidth: 36),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBE1176),
                            borderRadius: BorderRadius.circular(10)),
                          child: Text(_numero(equipos[indice], campo).toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold)),
                        )
                      : Text(_numero(equipos[indice], campo).toString(),
                          style: TextStyle(
                            color: campo == 'ganados' || campo == 'goles_favor'
                              ? const Color(0xFF166534)
                              : campo == 'perdidos' || campo == 'goles_contra'
                              ? const Color(0xFFB82018)
                              : campo == 'empatados'
                              ? const Color(0xFF925900) : const Color(0xFF334155),
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
        ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tabla de posiciones'),
      actions: [
        IconButton(
          tooltip: 'Actualizar posiciones',
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
              : 'No se pudieron cargar las posiciones. Intenta nuevamente.';
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
        final filas = snapshot.data!;
        final fases = <String, String>{
          for (final fila in filas)
            fila['fase_id'].toString(): fila['fase'].toString(),
        };
        final fase = fases.containsKey(_faseId)
            ? _faseId
            : (fases.isEmpty ? null : fases.keys.first);
        final grupos = <String, List<Map<String, dynamic>>>{};
        for (final fila in filas.where((f) => f['fase_id'] == fase)) {
          grupos
              .putIfAbsent(fila['grupo_id']?.toString() ?? '', () => [])
              .add(fila);
        }
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
                        '${widget.campeonato['nombre']} · ${widget.campeonato['categoria']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      if (fase == null)
                        const Text(
                          'Todavía no hay equipos inscritos en fases regulares para mostrar posiciones.',
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(fase),
                          initialValue: fase,
                          decoration: const InputDecoration(labelText: 'Fase'),
                          items: [
                            for (final entrada in fases.entries)
                              DropdownMenuItem(
                                value: entrada.key,
                                child: Text(entrada.value),
                              ),
                          ],
                          onChanged: (valor) {
                            setState(() {
                              _faseId = valor;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        for (final grupo in grupos.entries) ...[
                          if (grupo.key.isNotEmpty)
                            Text(
                              grupo.value.first['grupo'].toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          _tabla(grupo.value),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'Solo resultados confirmados. Los equipos con igual puntaje permanecen empatados.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'PJ: jugados · PG: ganados · PE: empatados · PP: perdidos\nGF: goles a favor · GC: goles en contra · DG: diferencia · Pts: puntos',
                        ),
                      ],
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
