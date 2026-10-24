import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_admin_liga.dart';
import 'pantalla_login.dart';

/// Acceso auxiliar a los equipos participantes de todas las ligas y campeonatos.
class PantallaCalificaciones extends StatefulWidget {
  const PantallaCalificaciones({super.key});

  @override
  State<PantallaCalificaciones> createState() => _PantallaCalificacionesState();
}

class _PantallaCalificacionesState extends State<PantallaCalificaciones> {
  late Future<List<Map<String, dynamic>>> _datos;

  @override
  void initState() {
    super.initState();
    _datos = _leer();
  }

  Future<List<Map<String, dynamic>>> _leer() async =>
      List<Map<String, dynamic>>.from(await Supabase.instance.client
          .rpc('lm_comision_equipos'));

  void _recargar() {
    setState(() { _datos = _leer(); });
  }

  Future<void> _salir() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PantallaLogin()), (_) => false);
  }

  Color _colorCategoria(String categoria) {
    final nombre = categoria.toLowerCase();
    if (nombre.contains('femenino')) return const Color(0xFFBE1176);
    if (nombre.contains('12')) return const Color(0xFF925900);
    if (nombre.contains('40')) return const Color(0xFF1D4DE2);
    return const Color(0xFF166534);
  }

  Widget _escudo(Map<String, dynamic> equipo) {
    final escudo = equipo['escudo_url']?.toString().trim() ?? '';
    final url = escudo.isNotEmpty ? escudo
      : equipo['logo_url']?.toString().trim() ?? '';
    const respaldo = Icon(Icons.shield_outlined, color: Color(0xFF166534), size: 36);
    return Container(width: 58, height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12)),
      child: url.isEmpty ? respaldo : Image.network(url, fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, error, stack) => respaldo));
  }

  Widget _equipo(List<Map<String, dynamic>> categorias) {
    final equipo = categorias.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFB6DCC7))),
      child: ExpansionTile(
        key: PageStorageKey('comision-equipo-${equipo['equipo_id']}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(), collapsedShape: const Border(),
        leading: const SizedBox(width: 24),
        title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _escudo(equipo),
          const SizedBox(width: 12),
          Flexible(child: Text('${equipo['equipo']}', textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold,
              color: Color(0xFF166534)))),
        ]),
        subtitle: Text('${equipo['liga']}', textAlign: TextAlign.center),
        children: [
          Align(alignment: Alignment.center, child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12, runSpacing: 12,
            children: [for (final categoria in categorias)
              SizedBox(width: 230, child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _colorCategoria('${categoria['categoria']}'),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PantallaRevisionJugadoresAdmin(
                    equipoId: '${categoria['equipo_id']}',
                    nombreEquipo: '${categoria['equipo']} · ${categoria['categoria']}',
                    campeonatoCalificaciones: '${categoria['campeonato_id']}',
                    campeonatosCalificaciones: [for (final c in categorias)
                      '${c['campeonato_id']}'],
                    categoriaInicial: '${categoria['categoria']}',
                  ))),
                child: Column(children: [
                  Text('${categoria['categoria']}', textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${categoria['campeonato']}', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12)),
                ]),
              )),
            ],
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Comisión de calificaciones'),
      actions: [
        IconButton(onPressed: _recargar, tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh)),
        IconButton(onPressed: _salir, tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout)),
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
          return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(error is PostgrestException ? error.message
                : 'No se pudieron cargar los equipos participantes.'),
              TextButton(onPressed: _recargar, child: const Text('Reintentar')),
            ])));
        }
        final equipos = snapshot.data ?? [];
        final agrupados = <String, List<Map<String, dynamic>>>{};
        for (final equipo in equipos) {
          agrupados.putIfAbsent('${equipo['equipo_id']}', () => []).add(equipo);
        }
        return Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('LigaMaster SaaS', textAlign: TextAlign.center, style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.bold, color: Color(0xFF4351BF))),
            const SizedBox(height: 12),
            const Text('Selecciona un equipo para revisar y calificar a sus jugadores.',
              textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (equipos.isEmpty)
              const Text('No hay equipos inscritos en los campeonatos.'),
            for (final categorias in agrupados.values) _equipo(categorias),
          ]),
        ));
      },
    ),
  );
}
