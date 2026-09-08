// lib/widgets/dialogo_agregar_jugador.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DialogoAgregarJugador extends StatefulWidget {
  final dynamic equipoId;
  final Function(Map<String, dynamic>)? onGuardar;

  const DialogoAgregarJugador({
    super.key,
    required this.equipoId,
    this.onGuardar,
  });

  @override
  State<DialogoAgregarJugador> createState() => _DialogoAgregarJugadorState();
}

class _DialogoAgregarJugadorState extends State<DialogoAgregarJugador> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final _cedulaController = TextEditingController();
  final _dorsalController = TextEditingController();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _fechaNacController = TextEditingController();
  final _edadController = TextEditingController();
  final _apodoController = TextEditingController();
  final _observacionesController = TextEditingController();

  String _posicionSeleccionada = 'ARQUERO';
  String _estadoJugador = 'Inscrito';
  bool _guardando = false;
  bool _esNovato = true;

  XFile? _fotoJugador;
  XFile? _fotoCedula;
  Uint8List? _bytesFotoJugador;
  Uint8List? _bytesFotoCedula;

  final List<String> _posiciones = [
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

  @override
  void initState() {
    super.initState();
    _fechaNacController.addListener(_calcularEdadCompleta);
  }

  @override
  void dispose() {
    _fechaNacController.removeListener(_calcularEdadCompleta);
    _fechaNacController.dispose();
    _cedulaController.dispose();
    _dorsalController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _edadController.dispose();
    _apodoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _calcularEdadCompleta() {
    final texto = _fechaNacController.text.trim().replaceAll('-', '/');
    if (texto.length == 10) {
      try {
        final partes = texto.split('/');
        if (partes.length == 3) {
          final dia = int.parse(partes[0]);
          final mes = int.parse(partes[1]);
          final anio = int.parse(partes[2]);

          final fechaNac = DateTime(anio, mes, dia);
          final hoy = DateTime.now();

          if (fechaNac.isAfter(hoy)) return;

          int anios = hoy.year - fechaNac.year;
          int meses = hoy.month - fechaNac.month;
          int dias = hoy.day - fechaNac.day;

          if (dias < 0) {
            meses--;
            final ultimoDiaMesAnterior = DateTime(hoy.year, hoy.month, 0).day;
            dias += ultimoDiaMesAnterior;
          }

          if (meses < 0) {
            anios--;
            meses += 12;
          }

          if (anios >= 0 && anios < 100) {
            setState(() {
              _edadController.text = '$anios Años, $meses Meses, $dias Días';
              _esNovato = anios <= 18;
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (seleccionado != null) {
      final dia = seleccionado.day.toString().padLeft(2, '0');
      final mes = seleccionado.month.toString().padLeft(2, '0');
      final anio = seleccionado.year;
      _fechaNacController.text = '$dia/$mes/$anio';
      _calcularEdadCompleta();
    }
  }

  Future<void> _seleccionarImagen(bool esFotoJugador) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        if (esFotoJugador) {
          _fotoJugador = picked;
          _bytesFotoJugador = bytes;
        } else {
          _fotoCedula = picked;
          _bytesFotoCedula = bytes;
        }
      });
    }
  }

  Future<String?> _subirImagenASupabase(
    Uint8List bytes,
    String fileName,
    String bucket,
  ) async {
    try {
      final path = '${widget.equipoId}/$fileName';
      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('Error al subir imagen a $bucket: $e');
      return null;
    }
  }

  Future<void> _guardarJugador() async {
    final cedula = _cedulaController.text.trim();
    final nombres = _nombresController.text.trim().toUpperCase();
    final apellidos = _apellidosController.text.trim().toUpperCase();

    if (cedula.isEmpty || nombres.isEmpty || apellidos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cédula, Nombres y Apellidos son obligatorios'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      String? urlFoto;
      String? urlCedula;

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (_bytesFotoJugador != null && _fotoJugador != null) {
        final ext = _fotoJugador!.name.split('.').last;
        urlFoto = await _subirImagenASupabase(
          _bytesFotoJugador!,
          'foto_$timestamp.$ext',
          'fotos_jugadores',
        );
      }

      if (_bytesFotoCedula != null && _fotoCedula != null) {
        final ext = _fotoCedula!.name.split('.').last;
        urlCedula = await _subirImagenASupabase(
          _bytesFotoCedula!,
          'cedula_$timestamp.$ext',
          'cedulas_jugadores',
        );
      }

      final datosJugador = {
        'equipo_id': widget.equipoId,
        'cedula': cedula,
        'dorsal': int.tryParse(_dorsalController.text.trim()) ?? 0,
        'nombres': nombres,
        'apellidos': apellidos,
        'posicion': _posicionSeleccionada,
        'fecha_nacimiento': _fechaNacController.text.trim(),
        'edad': _edadController.text.trim(),
        'apodo': _apodoController.text.trim().toUpperCase(),
        'estado': _estadoJugador,
        'observaciones': _observacionesController.text.trim(),
        'foto_url': urlFoto,
        'foto_cedula_url': urlCedula,
      };

      final response = await _supabase
          .from('jugadores')
          .insert(datosJugador)
          .select()
          .single();

      if (widget.onGuardar != null) {
        widget.onGuardar!(response);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar jugador: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _estiloCampo(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFEFEFF4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF1A3160), width: 1.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFEBEBF0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _guardando
            ? const SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF1A3160)),
                      SizedBox(height: 16),
                      Text('Guardando datos y subiendo archivos...'),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => _seleccionarImagen(true),
                          icon: Icon(
                            _bytesFotoJugador != null
                                ? Icons.check_circle
                                : Icons.add_a_photo,
                            size: 18,
                            color: const Color(0xFF1A3160),
                          ),
                          label: Text(
                            _bytesFotoJugador != null
                                ? 'Foto cargada'
                                : 'Foto Jugador',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A3160),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => _seleccionarImagen(false),
                          icon: Icon(
                            _bytesFotoCedula != null
                                ? Icons.check_circle
                                : Icons.badge,
                            size: 18,
                            color: const Color(0xFF1A3160),
                          ),
                          label: Text(
                            _bytesFotoCedula != null
                                ? 'Cédula cargada'
                                : 'Foto Cédula',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A3160),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _cedulaController,
                            keyboardType: TextInputType.number,
                            decoration: _estiloCampo('Cédula / NUI'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _dorsalController,
                            keyboardType: TextInputType.number,
                            decoration: _estiloCampo('N° Camiseta'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _nombresController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _estiloCampo('Nombres'),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _apellidosController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _estiloCampo('Apellidos'),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: _posicionSeleccionada,
                      decoration: _estiloCampo('Posición'),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        color: Color(0xFF1A3160),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      items: _posiciones.map((String pos) {
                        return DropdownMenuItem<String>(
                          value: pos,
                          child: Text(pos),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _posicionSeleccionada = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _fechaNacController,
                      onChanged: (_) => _calcularEdadCompleta(),
                      decoration: _estiloCampo(
                        'Fecha de Nacimiento (DD/MM/AAAA)',
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                          ),
                          onPressed: () => _seleccionarFecha(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _edadController,
                            readOnly: true,
                            style: const TextStyle(fontSize: 12),
                            decoration: _estiloCampo('Edad'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFEFF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFC7C7CC),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _esNovato ? 'NOVATO' : 'SENIOR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _esNovato ? Colors.black : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _apodoController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _estiloCampo('Apodo / Clasificación'),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF1A3160)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          _buildOpcionEstado('Inscrito'),
                          _buildOpcionEstado('Revisado'),
                          _buildOpcionEstado('Calificado'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _observacionesController,
                      decoration: _estiloCampo('Observaciones'),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF8E8E93)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A3160),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _guardarJugador,
                          child: const Text(
                            'Guardar Jugador',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOpcionEstado(String valor) {
    final seleccionado = _estadoJugador == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _estadoJugador = valor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado ? const Color(0xFF4A5568) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: seleccionado ? Colors.white : const Color(0xFF2D3748),
            ),
          ),
        ),
      ),
    );
  }
}
