import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_login.dart';
import 'pantalla_vocal.dart';
import 'pantalla_tecnica.dart' show fechaProgramacion;
import 'pantalla_revision_sanciones.dart';

class PantallaComisionSanciones extends StatefulWidget {
  const PantallaComisionSanciones({super.key});
  @override
  State<PantallaComisionSanciones> createState() =>
      _PantallaComisionSancionesState();
}

class _PantallaComisionSancionesState extends State<PantallaComisionSanciones> {
  List<Map<String, dynamic>> _hojas = [];
  String? _error;
  String _busqueda = '';
  bool _cargando = true;
  @override
  void initState() {
    super.initState();
    _leer();
  }

  Future<void> _leer() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final respuesta = await Supabase.instance.client.rpc('lm_penas_hojas');
      if (mounted)
        setState(() => _hojas = List<Map<String, dynamic>>.from(respuesta));
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No se pudieron cargar las hojas de vocalía.',
        );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Comisión de penas y sanciones'),
      actions: [
        IconButton(
          onPressed: _cargando ? null : _leer,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const PantallaLogin()),
                (_) => false,
              );
          },
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    const Text(
                      'LigaMaster SaaS',
                      style: TextStyle(
                        color: Color(0xFF4351BF),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Revisión de hojas de vocalía',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar liga, campeonato o equipo',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          setState(() => _busqueda = v.trim().toLowerCase()),
                    ),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    for (final h in _hojas.where(
                      (h) =>
                          '${h['liga']} ${h['campeonato']} ${h['categoria']} ${h['local']} ${h['visitante']}'
                              .toLowerCase()
                              .contains(_busqueda),
                    ))
                      Card(
                        color: const Color(0xFFFFF2F8),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${h['local']} vs ${h['visitante']}',
                                style: const TextStyle(
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${h['liga']} · ${h['campeonato']} · ${h['categoria']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                '${fechaProgramacion(h['fecha_hora'])} · Jornada ${h['jornada']} · Partido ${h['numero_partido']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFBC1676),
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PlanillaVocal(
                                          partidoId: '${h['id']}',
                                          soloLectura: true,
                                          consultaSanciones: true,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.description_outlined,
                                    ),
                                    label: const Text('Hoja de vocalía'),
                                  ),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF925900),
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PantallaRevisionSanciones(
                                              partidoId: '${h['id']}',
                                            ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.gavel),
                                    label: const Text('Revisar sanciones'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_hojas.isEmpty && _error == null)
                      const Text(
                        'No hay hojas de vocalía confirmadas para revisar.',
                      ),
                  ],
                ),
              ),
            ),
          ),
  );
}
