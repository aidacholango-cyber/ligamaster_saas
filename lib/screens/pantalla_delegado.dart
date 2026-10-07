import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_login.dart';
import 'ajustar_foto.dart';

const _azul = Color(0xFF4351BF);
const _categorias = ['Fútbol Senior', 'Femenino', 'Sub 40', 'Sub 12'];
const _posiciones = [
  'ARQUERO',
  'DEFENSA CENTRAL',
  'DER LATERAL',
  'IZQ LATERAL',
  'VOLANTE CONTENCIÓN',
  'VOLANTE IZQ',
  'VOLANTE DE',
  'ENGANCHE',
  'DELANTERO',
  'CENTRO DELANTERO',
];

class _Mayusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final texto = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: texto,
      selection: TextSelection(
        baseOffset: newValue.selection.baseOffset < 0
            ? texto.length
            : newValue.text
                  .substring(0, newValue.selection.baseOffset)
                  .toUpperCase()
                  .length,
        extentOffset: newValue.selection.extentOffset < 0
            ? texto.length
            : newValue.text
                  .substring(0, newValue.selection.extentOffset)
                  .toUpperCase()
                  .length,
      ),
      composing: TextRange.empty,
    );
  }
}

String _error(Object e) {
  if (e is PostgrestException) {
    if (e.code == '23505')
      return 'Este jugador ya está inscrito en una categoría incompatible de la misma liga.';
    if (e.code == '23503')
      return 'El jugador ya tiene inscripciones en campeonatos. Solicita al administrador el cambio de categoría.';
    return e.message;
  }
  if (e is StateError) return e.message.toString();
  return 'No se pudo completar la operación. Comprueba tu conexión e inténtalo de nuevo.';
}

String _nombre(Map<String, dynamic> j) =>
    '${j['nombres'] ?? ''} ${j['apellidos'] ?? ''}'.trim();
String _fecha(dynamic valor) {
  final d = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();
  if (d == null) return 'Sin registrar';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

DateTime? _nacimiento(String valor) {
  final partes = valor.split('/');
  if (partes.length == 3) {
    final d = int.tryParse(partes[0]),
        m = int.tryParse(partes[1]),
        a = int.tryParse(partes[2]);
    if (d == null || m == null || a == null) return null;
    final fecha = DateTime(a, m, d);
    return fecha.day == d && fecha.month == m && fecha.year == a ? fecha : null;
  }
  return DateTime.tryParse(valor);
}

String _edad(String valor) {
  final n = _nacimiento(valor);
  if (n == null) return 'Sin registrar';
  final hoy = DateTime.now();
  var a = hoy.year - n.year;
  if (hoy.month < n.month || (hoy.month == n.month && hoy.day < n.day)) a--;
  return a < 0 ? 'Fecha no válida' : '$a años';
}

Widget _foto(String? url, {double lado = 60}) => ClipOval(
  child: SizedBox(
    width: lado,
    height: lado,
    child: (url?.trim().isNotEmpty ?? false)
        ? Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.person_outline, color: _azul),
          )
        : const ColoredBox(
            color: Color(0xFFE5E5F5),
            child: Icon(Icons.person_outline, color: _azul),
          ),
  ),
);
Widget _seguimiento(Map<String, dynamic> j) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        const Chip(
          avatar: Icon(Icons.check_circle, color: Colors.green, size: 18),
          label: Text('Inscrito'),
        ),
        Chip(
          avatar: Icon(
            Icons.check_circle,
            size: 18,
            color: j['fecha_revision'] != null ? Colors.orange : Colors.grey,
          ),
          label: Text(
            j['fecha_revision'] != null ? 'Revisado' : 'Pendiente de revisión',
          ),
        ),
        Chip(
          avatar: Icon(
            Icons.check_circle,
            size: 18,
            color: j['estado'] == 'Calificado' && j['calificado_por_id'] != null
                ? _azul
                : Colors.grey,
          ),
          label: Text(
            j['estado'] == 'Calificado' && j['calificado_por_id'] != null
                ? 'Calificado'
                : 'Sin calificar',
          ),
        ),
      ],
    ),
    Text(
      'Observaciones: ${j['observaciones'] ?? 'Sin observaciones registradas'}',
    ),
    if (j['fecha_revision'] != null)
      Text(
        'Revisado por ${j['revisado_por'] ?? ''} · ${_fecha(j['fecha_revision'])}',
      ),
    if (j['fecha_calificacion'] != null)
      Text(
        'Calificado por ${j['calificado_por'] ?? ''} · ${_fecha(j['fecha_calificacion'])}',
      ),
  ],
);

class PantallaDelegado extends StatelessWidget {
  const PantallaDelegado({super.key});
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(seedColor: _azul),
      scaffoldBackgroundColor: const Color(0xFFF2F2F5),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFFF8F6FB)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _azul,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),
    child: const _PanelDelegado(),
  );
}

class _PanelDelegado extends StatefulWidget {
  const _PanelDelegado();
  @override
  State<_PanelDelegado> createState() => _PanelDelegadoState();
}

class _PanelDelegadoState extends State<_PanelDelegado> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _equipos = [], _jugadores = [];
  Map<String, dynamic>? _equipo;
  String _categoria = _categorias.first, _busqueda = '';
  String _filtroEstado = 'Todos';
  List<Map<String, dynamic>> _campeonatos = [];
  String? _campeonatoId;
  String? _nombrePerfil;
  bool _cargando = true, _ocupado = false;
  String? _fallo;
  @override
  void initState() {
    super.initState();
    _leer();
  }

  Map<String, dynamic>? get _campeonato {
    final lista = _campeonatos
        .where((c) => c['categoria'] == _categoria)
        .toList();
    return lista.where((c) => c['id'] == _campeonatoId).firstOrNull ??
        lista.firstOrNull;
  }

  bool get _inscripcionAbierta {
    final c = _campeonato;
    if (c == null || c['abierta'] != true) return false;
    final inicio = DateTime.tryParse(c['inicio']?.toString() ?? '');
    final fin = DateTime.tryParse(c['fin']?.toString() ?? '');
    final ahora = DateTime.now();
    return inicio != null &&
        fin != null &&
        !ahora.isBefore(inicio) &&
        ahora.isBefore(fin);
  }

  Future<void> _limpiarFotos() async {
    final tareas = await _db.rpc('lm_fotos_pendientes_delegado');
    for (final t in tareas as List) {
      await _db.storage.from(t['bucket'].toString()).remove([
        Uri.decodeComponent(t['ruta'].toString()),
      ]);
      await _db.rpc('lm_confirmar_foto_borrada', params: {'p_id': t['id']});
    }
  }

  Future<void> _borrarJugador(Map<String, dynamic> j) async {
    if (!_inscripcionAbierta || _ocupado) return;
    final campeonato = _campeonato!['id'];
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar jugador definitivamente'),
        content: Text(
          'Se eliminará la ficha de ${_nombre(j)} y sus fotos no compartidas. Esta acción no se puede deshacer. Si tiene historial, se bloqueará el borrado. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Borrar definitivamente',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await _db.rpc(
        'lm_borrar_jugador_en_periodo',
        params: {'p_campeonato_id': campeonato, 'p_jugador_id': j['id']},
      );
      try {
        await _limpiarFotos();
        _aviso(
          'Ficha borrada. Se eliminaron las fotos no compartidas compatibles con el almacenamiento de la aplicación.',
        );
      } catch (_) {
        _aviso(
          'Ficha borrada. Quedaron fotos pendientes: pulsa Actualizar para reintentar su eliminación.',
        );
      }
      if (mounted) await _leer();
    } catch (e) {
      _aviso(_error(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _leer() async {
    setState(() {
      _cargando = true;
      _fallo = null;
    });
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null)
        throw StateError('Inicia sesión con tu cuenta de delegado.');
      final perfil = await _db
          .from('perfiles')
          .select('rol,nombre')
          .eq('id', uid)
          .maybeSingle();
      if (perfil?['rol'] != 'club')
        throw StateError('Esta pantalla corresponde al delegado de un equipo.');
      final equipos = List<Map<String, dynamic>>.from(
        await _db
            .from('equipos')
            .select()
            .eq('delegado_id', uid)
            .order('nombre'),
      );
      // El administrador registra estos datos como presidente del equipo.
      for (final e in equipos) {
        for (final campo in ['nombre', 'cedula', 'telefono']) {
          final delegado = e['delegado_$campo']?.toString().trim() ?? '';
          if (delegado.isEmpty) e['delegado_$campo'] = e['presidente_$campo'];
        }
      }
      final id = _equipo?['id'];
      final equipo =
          equipos.where((e) => e['id'] == id).firstOrNull ??
          equipos.firstOrNull;
      final jugadores = equipo == null
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await _db
                  .from('jugadores')
                  .select()
                  .eq('equipo_id', equipo['id'])
                  .order('apellidos'),
            );
      final campeonatos = equipo == null
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await _db.rpc(
                'lm_campeonatos_delegado',
                params: {'p_equipo_id': equipo['id']},
              ),
            );
      try {
        await _limpiarFotos();
      } catch (_) {}
      if (mounted)
        setState(() {
          _campeonatos = campeonatos;
          _nombrePerfil = perfil?['nombre']?.toString().trim();
          _equipos = equipos;
          _equipo = equipo;
          _jugadores = jugadores;
        });
    } catch (e) {
      if (mounted) setState(() => _fallo = _error(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _salir() async {
    try {
      await _db.auth.signOut(scope: SignOutScope.local);
      if (mounted)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaLogin()),
          (_) => false,
        );
    } catch (e) {
      _aviso(_error(e));
    }
  }

  void _aviso(String texto) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _datos({bool editar = false}) async {
    if (_equipo == null) return;
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DatosDelegado(equipo: _equipo!, editar: editar),
    );
    if (guardado == true && mounted) _leer();
  }

  Future<void> _retirar() async {
    if (_equipo == null) return;
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar mi asignación'),
        content: Text(
          'Dejarás de tener acceso a ${_equipo!['nombre']}. El equipo, sus jugadores y el historial se conservarán. Tu sesión se cerrará. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Quitar asignación',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await _db.rpc(
        'lm_retirar_mi_asignacion_delegado',
        params: {'p_equipo_id': _equipo!['id']},
      );
      await _salir();
      if (mounted) await _leer();
    } catch (e) {
      _aviso(_error(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _formulario([Map<String, dynamic>? jugador]) async {
    if (_equipo == null || !_inscripcionAbierta) {
      _aviso('La inscripción está cerrada.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      Map<String, dynamic>? actual;
      if (jugador != null)
        actual = await _db
            .from('jugadores')
            .select()
            .eq('id', jugador['id'])
            .eq('equipo_id', _equipo!['id'])
            .single();
      if (!mounted) return;
      final guardado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _FormularioJugador(
          campeonatoId: _campeonato!['id'].toString(),
          equipoId: _equipo!['id'],
          categoria: _categoria,
          jugador: actual,
        ),
      );
      if (guardado == true && mounted) await _leer();
    } catch (e) {
      _aviso(_error(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _ficha(Map<String, dynamic> j) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(_nombre(j)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ImagenFormulario(
                      titulo: 'Foto del jugador',
                      url: j['foto_url'] ?? j['foto_perfil_url'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImagenFormulario(
                      titulo: 'Cédula (frente)',
                      url: j['foto_cedula_url'],
                    ),
                  ),
                ],
              ),
              for (final c in {
                'cedula': 'Cédula',
                'num_camiseta': 'Camiseta',
                'categoria': 'Categoría',
                'fecha_nacimiento': 'Nacimiento',
                'tipo_jugador': 'Tipo de jugador',
                'posicion': 'Posición',
                'email': 'Correo',
                'direccion': 'Dirección',
                'telefono': 'Teléfono',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                    '${c.value}: ${j[c.key] ?? 'Sin registrar'}',
                  ),
                ),
              const Divider(),
              _seguimiento(j),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
  String _estadoLista(Map<String, dynamic> j) {
    if (j['estado'] == 'Calificado' &&
        j['calificado_por_id'] != null &&
        j['fecha_calificacion'] != null)
      return 'Calificados';
    if ((j['estado'] == 'Revisado' || j['estado'] == 'Calificado') &&
        j['fecha_revision'] != null)
      return 'Revisados';
    return 'Inscritos';
  }

  @override
  Widget build(BuildContext context) {
    final deCategoria = _jugadores
        .where((j) => j['categoria'] == _categoria)
        .toList();
    final filtrados = _jugadores
        .where(
          (j) =>
              j['categoria'] == _categoria &&
              (_filtroEstado == 'Todos' || _estadoLista(j) == _filtroEstado) &&
              ('${_nombre(j)} ${j['cedula'] ?? ''}').toLowerCase().contains(
                _busqueda.toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del delegado del equipo'),
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargando || _ocupado ? null : _leer,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _ocupado ? null : _salir,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _fallo != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_fallo!),
                  TextButton(onPressed: _leer, child: const Text('Reintentar')),
                ],
              ),
            )
          : _equipo == null
          ? const Center(child: Text('Tu cuenta no tiene un equipo asignado.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6FB),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: _foto(
                              _equipo!['escudo_url'] ?? _equipo!['logo_url'],
                              lado: 72,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'LigaMaster SaaS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              color: _azul,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _equipo!['nombre'].toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _equipo!['delegado_nombre']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true
                                ? _equipo!['delegado_nombre'].toString()
                                : (_nombrePerfil?.isNotEmpty == true
                                      ? _nombrePerfil!
                                      : 'Registra tu nombre en Editar'),
                            textAlign: TextAlign.center,
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: _ocupado ? null : () => _datos(),
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text('Ver datos'),
                              ),
                              TextButton.icon(
                                onPressed: _ocupado
                                    ? null
                                    : () => _datos(editar: true),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.orange,
                                ),
                                label: const Text('Editar'),
                              ),
                              TextButton.icon(
                                onPressed: _ocupado ? null : _retirar,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                label: const Text('Borrar asignación'),
                              ),
                            ],
                          ),
                          if (_equipos.length > 1)
                            DropdownButtonFormField<int>(
                              initialValue: (_equipo!['id'] as num).toInt(),
                              decoration: const InputDecoration(
                                labelText: 'Equipo',
                              ),
                              items: [
                                for (final e in _equipos)
                                  DropdownMenuItem(
                                    value: (e['id'] as num).toInt(),
                                    child: Text(e['nombre'].toString()),
                                  ),
                              ],
                              onChanged: _ocupado
                                  ? null
                                  : (id) {
                                      _equipo = _equipos.firstWhere(
                                        (e) => e['id'] == id,
                                      );
                                      _leer();
                                    },
                            ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _categoria,
                                  decoration: const InputDecoration(
                                    labelText: 'Categoría',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    for (final c in _categorias)
                                      DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                  ],
                                  onChanged: _ocupado
                                      ? null
                                      : (v) => setState(() => _categoria = v!),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _ocupado || !_inscripcionAbierta
                                    ? null
                                    : () => _formulario(),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Ingresar jugador'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_campeonatos.any(
                            (c) => c['categoria'] == _categoria,
                          )) ...[
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                '${_equipo!['id']}:$_categoria:${_campeonato?['id']}',
                              ),
                              initialValue: _campeonato?['id']?.toString(),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Campeonato para inscripción',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final c in _campeonatos.where(
                                  (c) => c['categoria'] == _categoria,
                                ))
                                  DropdownMenuItem(
                                    value: c['id'].toString(),
                                    child: Text(c['nombre'].toString()),
                                  ),
                              ],
                              onChanged: _ocupado
                                  ? null
                                  : (v) => setState(() => _campeonatoId = v),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            _inscripcionAbierta
                                ? 'Inscripción abierta hasta ${_fecha(_campeonato?['fin'])}'
                                : 'Inscripción cerrada o sin configurar para esta categoría. Solo puedes consultar las fichas.',
                            style: TextStyle(
                              color: _inscripcionAbierta
                                  ? Colors.green
                                  : Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Buscar por nombre o cédula',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(() => _busqueda = v),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final estado in [
                                'Todos',
                                'Inscritos',
                                'Revisados',
                                'Calificados',
                              ])
                                ChoiceChip(
                                  label: Text(
                                    '$estado: ${estado == 'Todos' ? deCategoria.length : deCategoria.where((j) => _estadoLista(j) == estado).length}',
                                  ),
                                  selected: _filtroEstado == estado,
                                  onSelected: (_) =>
                                      setState(() => _filtroEstado = estado),
                                  avatar: Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: estado == 'Calificados'
                                        ? _azul
                                        : estado == 'Revisados'
                                        ? Colors.orange
                                        : estado == 'Inscritos'
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Jugadores en esta categoría: ${_jugadores.where((j) => j['categoria'] == _categoria).length} · Coincidencias: ${filtrados.length}',
                          ),
                          if (filtrados.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No hay jugadores para esta selección.',
                              ),
                            ),
                          for (final j in filtrados)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _foto(
                                          j['foto_url'] ?? j['foto_perfil_url'],
                                          lado: 48,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _nombre(j),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Cédula: ${j['cedula']} · ${j['posicion'] ?? ''}',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    _seguimiento(j),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        TextButton(
                                          onPressed: _ocupado
                                              ? null
                                              : () => _ficha(j),
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.visibility_outlined,
                                                color: _azul,
                                              ),
                                              SizedBox(height: 4),
                                              Text('Ver ficha'),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed:
                                              _ocupado || !_inscripcionAbierta
                                              ? null
                                              : () => _formulario(j),
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.edit_outlined,
                                                color: Colors.orange,
                                              ),
                                              SizedBox(height: 4),
                                              Text('Editar'),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed:
                                              _ocupado || !_inscripcionAbierta
                                              ? null
                                              : () => _borrarJugador(j),
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              SizedBox(height: 4),
                                              Text('Borrar'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DatosDelegado extends StatefulWidget {
  final Map<String, dynamic> equipo;
  final bool editar;
  const _DatosDelegado({required this.equipo, required this.editar});
  @override
  State<_DatosDelegado> createState() => _DatosDelegadoState();
}

class _DatosDelegadoState extends State<_DatosDelegado> {
  final _ctrl = <String, TextEditingController>{};
  Uint8List? _logoBytes;
  String _extension = 'png';
  Future<void> _elegirLogo() async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (archivo == null) return;
      final extension = archivo.name.split('.').last.toLowerCase();
      if (!['png', 'jpg', 'jpeg', 'webp'].contains(extension))
        throw StateError('Selecciona una imagen PNG, JPG o WEBP.');
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 5242880)
        throw StateError('El logo debe pesar como máximo 5 MB.');
      if (mounted)
        setState(() {
          _logoBytes = bytes;
          _extension = extension == 'jpeg' ? 'jpg' : extension;
          _fallo = null;
        });
    } catch (e) {
      if (mounted) setState(() => _fallo = _error(e));
    }
  }

  bool _guardando = false;
  String? _fallo;
  final _campos = {
    'nombre': 'Nombre',
    'cedula': 'Cédula',
    'telefono': 'Teléfono',
  };
  @override
  void initState() {
    super.initState();
    for (final k in _campos.keys) {
      _ctrl[k] = TextEditingController(
        text: widget.equipo['delegado_$k']?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      if (_ctrl['nombre']!.text.trim().isEmpty)
        throw StateError('Ingresa el nombre del delegado.');
      String? ruta;
      if (_logoBytes != null) {
        ruta =
            '${widget.equipo['id']}/logo_${DateTime.now().microsecondsSinceEpoch}.$_extension';
        await Supabase.instance.client.storage
            .from('logos_equipos')
            .uploadBinary(
              ruta,
              _logoBytes!,
              fileOptions: FileOptions(
                contentType:
                    'image/${_extension == 'jpg' ? 'jpeg' : _extension}',
              ),
            );
      }
      await Supabase.instance.client.rpc(
        'lm_actualizar_datos_delegado',
        params: {
          'p_equipo_id': widget.equipo['id'],
          'p_ruta_logo': ruta,
          for (final c in _ctrl.entries) 'p_${c.key}': c.value.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _fallo = _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      title: Text(widget.editar ? 'Editar delegado' : 'Datos del delegado'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ImagenFormulario(
                titulo: 'Logo del equipo',
                url: widget.equipo['escudo_url'] ?? widget.equipo['logo_url'],
                bytes: _logoBytes,
                seleccionar: widget.editar && !_guardando ? _elegirLogo : null,
              ),
              const SizedBox(height: 16),
              for (final c in _campos.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _ctrl[c.key],
                    inputFormatters: c.key == 'nombre' ? [_Mayusculas()] : null,
                    readOnly: !widget.editar,
                    enabled: !_guardando,
                    decoration: InputDecoration(
                      labelText: c.value,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              SelectableText(
                'Correo de acceso: ${Supabase.instance.client.auth.currentUser?.email ?? ''}',
              ),
              if (_fallo != null)
                Text(_fallo!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        if (widget.editar)
          ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
      ],
    ),
  );
}

class _ImagenFormulario extends StatelessWidget {
  final String titulo;
  final String? url;
  final Uint8List? bytes;
  final VoidCallback? seleccionar;
  final bool llenar;
  const _ImagenFormulario({
    required this.titulo,
    this.url,
    this.bytes,
    this.seleccionar,
    this.llenar = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(titulo, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Container(
        height: llenar ? null : 160,
        clipBehavior: Clip.antiAlias,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: llenar ? EdgeInsets.zero : const EdgeInsets.all(6),
        child: AspectRatio(
          aspectRatio: 1.8,
          child: bytes != null
              ? Image.memory(
                  bytes!,
                  fit: llenar ? BoxFit.cover : BoxFit.contain,
                )
              : (url?.isNotEmpty ?? false)
              ? Image.network(
                  url!,
                  fit: llenar ? BoxFit.cover : BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Text('No se pudo cargar la imagen')),
                )
              : const Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: _azul,
                  ),
                ),
        ),
      ),
      if (seleccionar != null)
        TextButton(
          onPressed: seleccionar,
          child: const Text('Seleccionar foto'),
        ),
    ],
  );
}

class _FormularioJugador extends StatefulWidget {
  final dynamic equipoId;
  final String campeonatoId;
  final String categoria;
  final Map<String, dynamic>? jugador;
  const _FormularioJugador({
    required this.equipoId,
    required this.campeonatoId,
    required this.categoria,
    this.jugador,
  });
  @override
  State<_FormularioJugador> createState() => _FormularioJugadorState();
}

class _FormularioJugadorState extends State<_FormularioJugador> {
  final _form = GlobalKey<FormState>();
  final _ctrl = <String, TextEditingController>{};
  final _campos = {
    'cedula': 'Cédula',
    'num_camiseta': 'Número de camiseta',
    'nombres': 'Nombres',
    'apellidos': 'Apellidos',
    'fecha_nacimiento': 'Fecha de nacimiento (DD/MM/AAAA)',
    'tipo_jugador': 'Tipo de jugador',
    'posicion': 'Posición',
    'email': 'Correo (opcional)',
    'direccion': 'Dirección (opcional)',
    'telefono': 'Teléfono (opcional)',
  };
  late String _categoria;
  Uint8List? _foto, _cedula;
  String? _fotoMime, _cedulaMime;
  bool _guardando = false;
  String? _fallo;
  @override
  void initState() {
    super.initState();
    final j = widget.jugador ?? {};
    _categoria = j['categoria']?.toString() ?? widget.categoria;
    for (final k in _campos.keys) {
      _ctrl[k] = TextEditingController(
        text:
            (k == 'num_camiseta'
                    ? (j[k] ?? j['dorsal'] ?? j['numero_camiseta'])
                    : j[k])
                ?.toString() ??
            '',
      );
    }
    final n = _nacimiento(_ctrl['fecha_nacimiento']!.text);
    if (n != null)
      _ctrl['fecha_nacimiento']!.text =
          '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegir(bool documento) async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f == null) return;
      final b = await f.readAsBytes();
      if (b.length > 5 * 1024 * 1024)
        throw StateError('La imagen debe pesar como máximo 5 MB.');

      final png =
          b.length >= 8 &&
          b[0] == 137 &&
          b[1] == 80 &&
          b[2] == 78 &&
          b[3] == 71;
      final jpeg = b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255;
      final webp =
          b.length >= 12 &&
          String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(b.sublist(8, 12)) == 'WEBP';
      if (!png && !jpeg && !webp) {
        throw StateError('Selecciona una imagen PNG, JPG o WebP.');
      }
      if (!mounted) return;
      final ajustada = await ajustarFoto(
        context,
        b,
        documento ? 'Cédula (parte delantera)' : 'Foto del jugador',
      );
      if (ajustada == null || !mounted) return;
      if (mounted)
        setState(() {
          if (documento) {
            _cedula = ajustada;
            _cedulaMime = 'image/png';
          } else {
            _foto = ajustada;
            _fotoMime = 'image/png';
          }
        });
    } catch (e) {
      debugPrint('Error al preparar la foto: $e');
      if (mounted) {
        setState(
          () => _fallo = e is StateError
              ? e.message.toString()
              : 'No se pudo abrir o ajustar esta imagen. Intenta con otra foto JPG o PNG.',
        );
      }
    }
  }

  Future<String> _subir(Uint8List bytes, String mime, String bucket) async {
    final db = Supabase.instance.client;
    final ext = mime == 'image/png'
        ? 'png'
        : mime == 'image/webp'
        ? 'webp'
        : 'jpg';
    final ruta =
        '${widget.equipoId}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await db.storage
        .from(bucket)
        .uploadBinary(ruta, bytes, fileOptions: FileOptions(contentType: mime));
    return db.storage.from(bucket).getPublicUrl(ruta);
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    final fotoActual =
        widget.jugador?['foto_url'] ?? widget.jugador?['foto_perfil_url'];
    final cedulaActual = widget.jugador?['foto_cedula_url'];
    if (_foto == null && (fotoActual?.toString().isEmpty ?? true) ||
        _cedula == null && (cedulaActual?.toString().isEmpty ?? true)) {
      setState(
        () =>
            _fallo = 'Selecciona la foto del jugador y el frente de la cédula.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _fallo = null;
    });
    try {
      final datos = <String, dynamic>{
        for (final c in _ctrl.entries) c.key: c.value.text.trim(),
        'categoria': _categoria,
      };
      datos['nombres'] = _ctrl['nombres']!.text.trim().toUpperCase();
      datos['apellidos'] = _ctrl['apellidos']!.text.trim().toUpperCase();
      datos['num_camiseta'] = int.tryParse(_ctrl['num_camiseta']!.text.trim());
      if (_foto != null)
        datos['foto_url'] = await _subir(_foto!, _fotoMime!, 'fotos_jugadores');
      if (_cedula != null)
        datos['foto_cedula_url'] = await _subir(
          _cedula!,
          _cedulaMime!,
          'cedulas_jugadores',
        );
      // En edición, enviar solo los campos que cambiaron.
      if (widget.jugador != null) {
        datos.removeWhere(
          (k, v) =>
              v == widget.jugador![k] ||
              (v == '' && widget.jugador![k] == null),
        );
      }
      if (datos.isNotEmpty)
        await Supabase.instance.client.rpc(
          'lm_guardar_jugador_en_periodo',
          params: {
            'p_campeonato_id': widget.campeonatoId,
            'p_equipo_id': widget.equipoId,
            'p_jugador_id': widget.jugador?['id'],
            'p_datos': datos,
          },
        );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _fallo = _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        widget.jugador == null ? 'Ingresar jugador' : 'Editar jugador',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ImagenFormulario(
                        titulo: 'Foto del jugador',
                        llenar: true,
                        url:
                            widget.jugador?['foto_url'] ??
                            widget.jugador?['foto_perfil_url'],
                        bytes: _foto,
                        seleccionar: _guardando ? null : () => _elegir(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImagenFormulario(
                        titulo: 'Cédula (parte delantera)',
                        llenar: true,
                        url: widget.jugador?['foto_cedula_url'],
                        bytes: _cedula,
                        seleccionar: _guardando ? null : () => _elegir(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in _categorias)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: null,
                ),
                for (final c in _campos.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.key == 'posicion')
                          DropdownButtonFormField<String>(
                            initialValue:
                                _posiciones.contains(_ctrl['posicion']!.text)
                                ? _ctrl['posicion']!.text
                                : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Posición',
                              border: const OutlineInputBorder(),
                              helperText:
                                  _ctrl['posicion']!.text.isNotEmpty &&
                                      !_posiciones.contains(
                                        _ctrl['posicion']!.text,
                                      )
                                  ? 'Posición guardada: ${_ctrl['posicion']!.text}'
                                  : null,
                            ),
                            items: [
                              for (final p in _posiciones)
                                DropdownMenuItem(value: p, child: Text(p)),
                            ],
                            onChanged: _guardando
                                ? null
                                : (v) => setState(
                                    () => _ctrl['posicion']!.text = v ?? '',
                                  ),
                            validator: (_) =>
                                _ctrl['posicion']!.text.trim().isEmpty
                                ? 'Selecciona la posición.'
                                : null,
                          )
                        else
                          TextFormField(
                            controller: _ctrl[c.key],
                            textCapitalization:
                                ['nombres', 'apellidos'].contains(c.key)
                                ? TextCapitalization.characters
                                : TextCapitalization.none,
                            inputFormatters:
                                ['nombres', 'apellidos'].contains(c.key)
                                ? [_Mayusculas()]
                                : null,
                            enabled: !_guardando,
                            decoration: InputDecoration(
                              labelText: c.value,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: c.key == 'fecha_nacimiento'
                                ? (_) => setState(() {})
                                : null,
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              if ([
                                    'nombres',
                                    'apellidos',
                                    'cedula',
                                    'fecha_nacimiento',
                                  ].contains(c.key) &&
                                  t.isEmpty)
                                return 'Completa este dato.';
                              if (c.key == 'cedula' &&
                                  !RegExp(r'^\d{10}$').hasMatch(t))
                                return 'La cédula debe tener 10 dígitos.';
                              if (c.key == 'num_camiseta' &&
                                  t.isNotEmpty &&
                                  (int.tryParse(t) == null || int.parse(t) < 0))
                                return 'Escribe un número válido.';
                              if (c.key == 'fecha_nacimiento') {
                                final n = _nacimiento(t);
                                if (n == null ||
                                    n.isAfter(DateTime.now()) ||
                                    n.year < 1900)
                                  return 'Escribe una fecha de nacimiento válida.';
                              }
                              return null;
                            },
                          ),
                        if (c.key == 'fecha_nacimiento')
                          Text('Edad: ${_edad(_ctrl[c.key]!.text)}'),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (widget.jugador != null) ...[
                  _seguimiento(widget.jugador!),
                  const SizedBox(height: 8),
                  const Text(
                    'Al modificar la ficha, el jugador volverá a Inscrito para una nueva revisión.',
                  ),
                ] else
                  const Text(
                    'El jugador ingresará como Inscrito. El administrador realizará la revisión y calificación.',
                  ),
                if (_fallo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _fallo!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
