import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/dialogo_nuevo_responsable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaSuperAdmin extends StatefulWidget {
  const PantallaSuperAdmin({super.key});

  @override
  State<PantallaSuperAdmin> createState() => _PantallaSuperAdminState();
}

class _PantallaSuperAdminState extends State<PantallaSuperAdmin> {
  // Etiqueta reutilizable para los encabezados de estado de los jugadores.
  Widget _encabezadoEstado({
    required String texto,
    required Color fondo,
    required Color textoColor,
  }) {
    return SizedBox(
      width: 70,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textoColor.withOpacity(0.22)),
        ),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textoColor,
          ),
        ),
      ),
    );
  }

  // Función para mostrar alertas claras en la parte delantera (primer plano)
  void _mostrarAlertaFrontal(
    BuildContext context,
    String titulo,
    String mensaje,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return _LigaDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(mensaje, style: const TextStyle(fontSize: 14)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4351BF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Aceptar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Función para validar cédula ecuatoriana (Soporta cédulas de menores de edad)
  bool _validarCedulaEcuatoriana(String cedula) {
    if (cedula.length != 10) return false;
    if (int.tryParse(cedula) == null) return false;

    int provincia = int.parse(cedula.substring(0, 2));
    if ((provincia < 1 || provincia > 24) && provincia != 30) return false;

    return true;
  }

  // Función para calcular edad desde 'DD/MM/YYYY'
  String _calcularEdadDetallada(String fechaStr) {
    final partes = fechaStr.split('/');
    if (partes.length != 3) return '';

    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final anio = int.tryParse(partes[2]);

    if (dia == null || mes == null || anio == null) return '';

    try {
      final fechaNac = DateTime(anio, mes, dia);
      final hoy = DateTime.now();

      if (fechaNac.isAfter(hoy)) return '';

      int anios = hoy.year - fechaNac.year;
      int meses = hoy.month - fechaNac.month;
      int dias = hoy.day - fechaNac.day;

      if (dias < 0) {
        meses--;
        final ultimoMesAnterior = DateTime(hoy.year, hoy.month, 0);
        dias += ultimoMesAnterior.day;
      }

      if (meses < 0) {
        anios--;
        meses += 12;
      }

      return '$anios años $meses meses $dias días';
    } catch (_) {
      return '';
    }
  }

  // Validar límites de fecha de nacimiento por categoría
  String? _validarFechaPorCategoria(String fechaStr, String categoria) {
    final partes = fechaStr.split('/');
    if (partes.length != 3) {
      return 'Formato de fecha inválido. Use DD/MM/YYYY.';
    }

    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final anio = int.tryParse(partes[2]);

    if (dia == null || mes == null || anio == null) {
      return 'Fecha de nacimiento no válida.';
    }

    try {
      final fechaNac = DateTime(anio, mes, dia);

      if (categoria == 'Fútbol Senior' || categoria == 'Femenino') {
        final limiteMax = DateTime(2013, 12, 31);
        if (fechaNac.isAfter(limiteMax)) {
          return 'Para la categoría $categoria, el jugador debe haber nacido hasta el 31 de diciembre de 2013.';
        }
      } else if (categoria == 'Sub 12') {
        final limiteMin = DateTime(2014, 1, 1);
        if (fechaNac.isBefore(limiteMin)) {
          return 'Para la categoría Sub 12, el jugador debe haber nacido a partir del 1 de enero de 2014.';
        }
      } else if (categoria == 'Sub 40') {
        final limiteMax = DateTime(1986, 12, 31);
        if (fechaNac.isAfter(limiteMax)) {
          return 'Para la categoría Sub 40, el jugador debe haber nacido hasta el 31 de diciembre de 1986.';
        }
      }
    } catch (_) {
      return 'Fecha de nacimiento inválida.';
    }

    return null;
  }

  // VER JUGADORES DEL EQUIPO FILTRADOS POR CATEGORÍA CON OPCIÓN DE INGRESAR JUGADOR
  void _verJugadoresDeEquipo(Map<String, dynamic> equipo) {
    final equipoId = equipo['id'];
    final nombreEquipo = equipo['nombre'] ?? 'Equipo';
    final ligaId = equipo['liga_id'];

    final categoriasDisponibles = [
      'Fútbol Senior',
      'Femenino',
      'Sub 12',
      'Sub 40',
    ];
    String categoriaFiltro = categoriasDisponibles.contains(equipo['categoria'])
        ? equipo['categoria']
        : 'Fútbol Senior';

    // Los estados comienzan en gris y se activan únicamente al pulsarlos.
    // Se mantienen mientras esta ventana de jugadores permanezca abierta.
    final estadosInscritosActivos = <String>{};
    final estadosRevisadosActivos = <String>{};
    final estadosCalificadosActivos = <String>{};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setJugadoresState) {
            void eliminarJugador(Map<String, dynamic> jugador) {
              showDialog(
                context: context,
                builder: (ctx) => _LigaDialog(
                  title: const Text('Confirmar Eliminación'),
                  content: Text(
                    '¿Deseas eliminar al jugador "${jugador['nombres']} ${jugador['apellidos']}"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await Supabase.instance.client
                            .from('jugadores')
                            .delete()
                            .eq('id', jugador['id']);
                        if (ctx.mounted) Navigator.pop(ctx);
                        setJugadoresState(() {});
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
            }

            Future<void> agregarNuevoJugador([
              Map<String, dynamic>? jugadorInicial,
            ]) async {
              Map<String, dynamic>? jugadorActual = jugadorInicial;
              // Load the complete, current record before opening the same form.
              if (jugadorInicial != null) {
                try {
                  final actual = await Supabase.instance.client
                      .from('jugadores')
                      .select('*')
                      .eq('id', jugadorInicial['id'])
                      .maybeSingle();
                  if (!context.mounted) return;
                  if (actual == null) {
                    _mostrarAlertaFrontal(
                      context,
                      'Jugador no disponible',
                      'Este jugador ya no existe. Cierra y vuelve a abrir la lista.',
                    );
                    return;
                  }
                  jugadorActual = actual;
                } catch (e) {
                  if (context.mounted) {
                    _mostrarAlertaFrontal(
                      context,
                      'No se pudo cargar el jugador',
                      'No se pudieron recuperar sus datos. Inténtalo nuevamente.\n$e',
                    );
                  }
                  return;
                }
              }
              final jugadorEditar = jugadorActual;
              String dato(String campo) =>
                  jugadorEditar?[campo]?.toString() ?? '';
              final cedulaCtrl = TextEditingController(text: dato('cedula'));
              final numCamisetaCtrl = TextEditingController(
                text: dato('num_camiseta'),
              );
              final nombresCtrl = TextEditingController(text: dato('nombres'));
              final apellidosCtrl = TextEditingController(
                text: dato('apellidos'),
              );
              final fechaNacCtrl = TextEditingController(
                text: dato('fecha_nacimiento'),
              );
              final edadCtrl = TextEditingController(text: dato('edad'));
              final tipoJugadorCtrl = TextEditingController(
                text: dato('tipo_jugador').isEmpty
                    ? 'NOVATO'
                    : dato('tipo_jugador'),
              );
              // Age follows the birth date instead of keeping an outdated value.
              final fechaGuardada = DateTime.tryParse(fechaNacCtrl.text);
              if (fechaGuardada != null && !fechaNacCtrl.text.contains('/')) {
                fechaNacCtrl.text =
                    '${fechaGuardada.day.toString().padLeft(2, '0')}/${fechaGuardada.month.toString().padLeft(2, '0')}/${fechaGuardada.year}';
              }
              edadCtrl.text = _calcularEdadDetallada(fechaNacCtrl.text.trim());
              final emailCtrl = TextEditingController(text: dato('email'));
              final direccionCtrl = TextEditingController(
                text: dato('direccion'),
              );
              final telefonoCtrl = TextEditingController(
                text: dato('telefono'),
              );

              String categoriaSeleccionadaModal =
                  jugadorEditar?['categoria'] ?? categoriaFiltro;

              final posicionesDisponibles = [
                'ARQUERO',
                'DEFENSA',
                'VOLANTE IZQUIERDO',
                'VOLANTE DERECHO',
                'DELANTERO',
              ];
              String posicionSeleccionada =
                  posicionesDisponibles.contains(jugadorEditar?['posicion'])
                  ? jugadorEditar!['posicion']
                  : posicionesDisponibles.first;

              String estadoSeleccionado =
                  jugadorEditar?['estado'] ?? 'Calificado';

              Uint8List? fotoJugadorBytes;
              Uint8List? cedulaFotoBytes;
              bool guardandoJugador = false;

              showDialog(
                context: context,
                builder: (dialogContext) => StatefulBuilder(
                  builder: (context, setFormState) {
                    Future<void> seleccionarFotoJugador() async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setFormState(() {
                          fotoJugadorBytes = bytes;
                        });
                      }
                    }

                    Future<void> seleccionarFotoCedula() async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setFormState(() {
                          cedulaFotoBytes = bytes;
                        });
                      }
                    }

                    return _LigaDialog(
                      titlePadding: const EdgeInsets.all(16),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            jugadorEditar != null
                                ? 'Editar Jugador'
                                : 'Agregar Jugador',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4351BF),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: 500,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Fotos (Jugador y Cédula)
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: seleccionarFotoJugador,
                                      child: Container(
                                        height: 140,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: fotoJugadorBytes != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  fotoJugadorBytes!,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : (jugadorEditar?['foto_url'] !=
                                                          null &&
                                                      jugadorEditar!['foto_url']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: Image.network(
                                                        jugadorEditar['foto_url'],
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  : const Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.person,
                                                          size: 40,
                                                          color: Colors.grey,
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'Foto Jugador',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    )),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: seleccionarFotoCedula,
                                      child: Container(
                                        height: 140,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: cedulaFotoBytes != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  cedulaFotoBytes!,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.credit_card,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Cédula Foto',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // DESPLEGABLE DE CATEGORÍA
                              const Text(
                                'Categoría *',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              DropdownButtonFormField<String>(
                                initialValue: categoriaSeleccionadaModal,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: categoriasDisponibles.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setFormState(() {
                                      categoriaSeleccionadaModal = val;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),

                              // 2. Cédula y N Camiseta
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: cedulaCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Cédula',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        fillColor: const Color(0xFFF2F2F2),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: numCamisetaCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'N Camiseta',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 3. Nombres
                              const Text(
                                'Nombres',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              TextField(
                                controller: nombresCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                onChanged: (value) {
                                  final upper = value.toUpperCase();
                                  if (value != upper) {
                                    nombresCtrl.value = nombresCtrl.value
                                        .copyWith(
                                          text: upper,
                                          selection: TextSelection.collapsed(
                                            offset: upper.length,
                                          ),
                                        );
                                  }
                                },
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  fillColor: const Color(0xFFF2F2F2),
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 4. Apellidos
                              const Text(
                                'Apellidos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              TextField(
                                controller: apellidosCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                onChanged: (value) {
                                  final upper = value.toUpperCase();
                                  if (value != upper) {
                                    apellidosCtrl.value = apellidosCtrl.value
                                        .copyWith(
                                          text: upper,
                                          selection: TextSelection.collapsed(
                                            offset: upper.length,
                                          ),
                                        );
                                  }
                                },
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  fillColor: const Color(0xFFF2F2F2),
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 5. Fecha de nacimiento
                              const Text(
                                'Fecha de nacimiento *',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: fechaNacCtrl,
                                      keyboardType: TextInputType.datetime,
                                      onChanged: (val) {
                                        final edadCalculada =
                                            _calcularEdadDetallada(val.trim());
                                        setFormState(() {
                                          edadCtrl.text = edadCalculada;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'DD/MM/YYYY',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        fillColor: const Color(0xFFF2F2F2),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.info_outline,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 6. Edad y Tipo de Jugador
                              const Text(
                                'Edad',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: edadCtrl,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        hintText: 'Calculado automáticamente',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        fillColor: const Color(0xFFF2F2F2),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: tipoJugadorCtrl,
                                      readOnly:
                                          !(jugadorEditar?.containsKey(
                                                'tipo_jugador',
                                              ) ??
                                              false),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        fillColor: const Color(0xFFF2F2F2),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 7. Definidor de pecado / Posición
                              const Text(
                                'Definidor de pecado',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              DropdownButtonFormField<String>(
                                initialValue: posicionSeleccionada,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: posicionesDisponibles.map((pos) {
                                  return DropdownMenuItem(
                                    value: pos,
                                    child: Text(pos),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setFormState(() {
                                      posicionSeleccionada = val;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),

                              // 8. Email
                              TextField(
                                controller: emailCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Ingrese Email (Opc)',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 9. Dirección
                              TextField(
                                controller: direccionCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Ingrese Dirección (Opc)',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 10. Teléfono
                              TextField(
                                controller: telefonoCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Ingrese teléfono (Opc)',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 11. Selector de Estado
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF4351BF),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setFormState(
                                          () => estadoSeleccionado = 'Inscrito',
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          color:
                                              estadoSeleccionado == 'Inscrito'
                                              ? const Color(0xFFD6DBE9)
                                              : Colors.transparent,
                                          child: const Text(
                                            'Inscrito',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFF4351BF),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 35,
                                      color: const Color(0xFF4351BF),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setFormState(
                                          () => estadoSeleccionado = 'Revisado',
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          color:
                                              estadoSeleccionado == 'Revisado'
                                              ? const Color(0xFFD6DBE9)
                                              : Colors.transparent,
                                          child: const Text(
                                            'Revisado',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFF4351BF),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 35,
                                      color: const Color(0xFF4351BF),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setFormState(
                                          () =>
                                              estadoSeleccionado = 'Calificado',
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          color:
                                              estadoSeleccionado == 'Calificado'
                                              ? const Color(0xFFD6DBE9)
                                              : Colors.transparent,
                                          child: const Text(
                                            'Calificado',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFF4351BF),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF4351BF)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: guardandoJugador
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Color(0xFF4351BF)),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4351BF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: guardandoJugador
                              ? null
                              : () async {
                                  final cedulaTexto = cedulaCtrl.text.trim();
                                  if (!_validarCedulaEcuatoriana(cedulaTexto)) {
                                    _mostrarAlertaFrontal(
                                      dialogContext,
                                      'Cédula Inválida',
                                      'Por favor ingrese un número de cédula.',
                                    );
                                    return;
                                  }

                                  final nom = nombresCtrl.text.trim();
                                  final ape = apellidosCtrl.text.trim();
                                  final nombreCompleto = '$nom $ape'.trim();

                                  if (nombreCompleto.isEmpty) {
                                    _mostrarAlertaFrontal(
                                      dialogContext,
                                      'Campo Requerido',
                                      'Por favor ingrese los nombres y apellidos del jugador.',
                                    );
                                    return;
                                  }

                                  // Validar restricción de límites de edad por categoría
                                  final errorFecha = _validarFechaPorCategoria(
                                    fechaNacCtrl.text.trim(),
                                    categoriaSeleccionadaModal,
                                  );
                                  if (errorFecha != null) {
                                    _mostrarAlertaFrontal(
                                      dialogContext,
                                      'Límite de Edad',
                                      errorFecha,
                                    );
                                    return;
                                  }

                                  setFormState(() => guardandoJugador = true);

                                  try {
                                    final dynamic parsedLigaId =
                                        int.tryParse(ligaId.toString()) ??
                                        ligaId;
                                    final dynamic parsedEquipoId =
                                        int.tryParse(equipoId.toString()) ??
                                        equipoId;

                                    {
                                      final equiposRes = await Supabase
                                          .instance
                                          .client
                                          .from('equipos')
                                          .select('id')
                                          .eq('liga_id', parsedLigaId);

                                      final List<dynamic> equiposLiga =
                                          equiposRes as List<dynamic>;
                                      final List<dynamic> idsEquipos =
                                          equiposLiga
                                              .map((e) => e['id'])
                                              .toList();

                                      if (idsEquipos.isNotEmpty) {
                                        final existeJugadorRes = await Supabase
                                            .instance
                                            .client
                                            .from('jugadores')
                                            .select('id, equipo_id, categoria')
                                            .eq('cedula', cedulaTexto)
                                            .filter(
                                              'equipo_id',
                                              'in',
                                              idsEquipos,
                                            );

                                        final List<dynamic>
                                        registrosExistentes =
                                            existeJugadorRes as List<dynamic>;

                                        bool duplicadoProhibido = false;

                                        for (var reg in registrosExistentes) {
                                          if (jugadorEditar != null &&
                                              reg['id'].toString() ==
                                                  jugadorEditar['id']
                                                      .toString())
                                            continue;
                                          final regEquipoId = reg['equipo_id'];
                                          final regCat = reg['categoria'];

                                          if (regEquipoId.toString() !=
                                              parsedEquipoId.toString()) {
                                            duplicadoProhibido = true;
                                            break;
                                          }

                                          bool esCombPermitida =
                                              (regCat == 'Sub 40' &&
                                                  categoriaSeleccionadaModal ==
                                                      'Fútbol Senior') ||
                                              (regCat == 'Fútbol Senior' &&
                                                  categoriaSeleccionadaModal ==
                                                      'Sub 40');

                                          if (!esCombPermitida) {
                                            duplicadoProhibido = true;
                                            break;
                                          }
                                        }

                                        if (duplicadoProhibido) {
                                          setFormState(
                                            () => guardandoJugador = false,
                                          );
                                          if (dialogContext.mounted) {
                                            _mostrarAlertaFrontal(
                                              dialogContext,
                                              'Jugador Ya Registrado',
                                              'Este jugador con la cédula $cedulaTexto ya se encuentra inscrito en esta liga.',
                                            );
                                          }
                                          return;
                                        }
                                      }
                                    }

                                    String? fotoUrl =
                                        jugadorEditar?['foto_url'];
                                    if (fotoJugadorBytes != null) {
                                      final path =
                                          'jugador_${DateTime.now().millisecondsSinceEpoch}.png';
                                      await Supabase.instance.client.storage
                                          .from('fotos_jugadores')
                                          .uploadBinary(
                                            path,
                                            fotoJugadorBytes!,
                                          );

                                      fotoUrl = Supabase.instance.client.storage
                                          .from('fotos_jugadores')
                                          .getPublicUrl(path);
                                    }

                                    final Map<String, dynamic> datosInsertar = {
                                      'equipo_id': parsedEquipoId,
                                      'nombres': nom,
                                      'apellidos': ape,
                                      'cedula': cedulaTexto,
                                      'num_camiseta': numCamisetaCtrl.text
                                          .trim(),
                                      'fecha_nacimiento': fechaNacCtrl.text
                                          .trim(),
                                      'edad': edadCtrl.text.trim(),
                                      'posicion': posicionSeleccionada,
                                      'email': emailCtrl.text.trim(),
                                      'direccion': direccionCtrl.text.trim(),
                                      'telefono': telefonoCtrl.text.trim(),
                                      'estado': estadoSeleccionado,
                                      'categoria': categoriaSeleccionadaModal,
                                    };

                                    if (jugadorEditar?.containsKey(
                                          'tipo_jugador',
                                        ) ??
                                        false) {
                                      datosInsertar['tipo_jugador'] =
                                          tipoJugadorCtrl.text.trim();
                                    }
                                    if (fotoUrl != null) {
                                      datosInsertar['foto_url'] = fotoUrl;
                                    }

                                    if (jugadorEditar != null) {
                                      await Supabase.instance.client
                                          .from('jugadores')
                                          .update(datosInsertar)
                                          .eq('id', jugadorEditar['id']);
                                    } else {
                                      await Supabase.instance.client
                                          .from('jugadores')
                                          .insert(datosInsertar);
                                    }

                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                    setJugadoresState(() {
                                      categoriaFiltro =
                                          categoriaSeleccionadaModal;
                                    });
                                  } catch (e) {
                                    setFormState(
                                      () => guardandoJugador = false,
                                    );
                                    if (dialogContext.mounted) {
                                      _mostrarAlertaFrontal(
                                        dialogContext,
                                        'Error al Guardar',
                                        'Ocurrió un inconveniente en la base de datos:\n\n$e',
                                      );
                                    }
                                  }
                                },
                          child: guardandoJugador
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  jugadorEditar != null
                                      ? 'Guardar cambios'
                                      : 'Guardar jugador',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              );
            }

            return _LigaDialog(
              wide: true,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          'Jugadores: $nombreEquipo',
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.indigo.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: categoriaFiltro,
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                              ),
                              items: categoriasDisponibles.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setJugadoresState(
                                    () => categoriaFiltro = val,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => agregarNuevoJugador(),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Ingresar Jugador'),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ENCABEZADO DE ESTADOS: usa los mismos anchos que cada fila
                    // para que los títulos queden centrados sobre sus iconos.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 326,
                            child: Row(
                              children: [
                                _encabezadoEstado(
                                  texto: 'Inscrito',
                                  fondo: const Color(0xFFE8F5E9),
                                  textoColor: const Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 4),
                                _encabezadoEstado(
                                  texto: 'Revisado',
                                  fondo: const Color(0xFFFFF3E0),
                                  textoColor: const Color(0xFFEF6C00),
                                ),
                                const SizedBox(width: 4),
                                _encabezadoEstado(
                                  texto: 'Calificado',
                                  fondo: const Color(0xFFE8EAF6),
                                  textoColor: const Color(0xFF3949AB),
                                ),
                                const SizedBox(width: 12),
                                const SizedBox(width: 48),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: Supabase.instance.client
                            .from('jugadores')
                            .select('*')
                            .eq(
                              'equipo_id',
                              int.tryParse(equipoId.toString()) ?? equipoId,
                            )
                            .eq('categoria', categoriaFiltro),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Error al cargar jugadores: ${snapshot.error}',
                            );
                          }
                          final jugadores = snapshot.data ?? [];
                          if (jugadores.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Este equipo no tiene jugadores registrados en la categoría $categoriaFiltro.',
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: jugadores.length,
                            itemBuilder: (context, index) {
                              final jugador = jugadores[index];
                              final fotoUrl = jugador['foto_url'];
                              final nombreJugador =
                                  jugador['nombre'] ??
                                  '${jugador['nombres'] ?? ''} ${jugador['apellidos'] ?? ''}'
                                      .trim();
                              final cedulaJugador = jugador['cedula'] ?? 'N/A';
                              final posicion = jugador['posicion'] ?? 'N/A';
                              final jugadorId = jugador['id'].toString();

                              final fechaInscrito =
                                  jugador['created_at'] != null
                                  ? jugador['created_at']
                                        .toString()
                                        .split('T')
                                        .first
                                  : '20/09/2026';
                              final comentarioRevisado =
                                  jugador['comentario_revision'] ??
                                  'Sin observaciones por el administrador.';
                              final calificadoPor =
                                  jugador['calificado_por'] ??
                                  'admin@ligamaster.com';

                              // Todos aparecen grises al abrir la ventana.
                              final esInscrito = estadosInscritosActivos
                                  .contains(jugadorId);
                              final esRevisado = estadosRevisadosActivos
                                  .contains(jugadorId);
                              final esCalificado = estadosCalificadosActivos
                                  .contains(jugadorId);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      (fotoUrl != null &&
                                          fotoUrl.toString().isNotEmpty)
                                      ? NetworkImage(fotoUrl)
                                      : null,
                                  child:
                                      (fotoUrl == null ||
                                          fotoUrl.toString().isEmpty)
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                  nombreJugador.isNotEmpty
                                      ? nombreJugador
                                      : 'Sin Nombre',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Cédula: $cedulaJugador | Posición: $posicion',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. VISTO INSCRITO
                                    SizedBox(
                                      width: 70,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.check_circle,
                                          color: esInscrito
                                              ? Colors.green
                                              : Colors.grey.shade400,
                                          size: 24,
                                        ),
                                        tooltip: 'Ver Fecha de Inscripción',
                                        onPressed: () {
                                          setJugadoresState(() {
                                            esInscrito
                                                ? estadosInscritosActivos
                                                      .remove(jugadorId)
                                                : estadosInscritosActivos.add(
                                                    jugadorId,
                                                  );
                                          });
                                          _mostrarAlertaFrontal(
                                            context,
                                            'Fecha de Inscripción',
                                            'El jugador fue inscrito el: $fechaInscrito',
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    // 2. VISTO REVISADO
                                    SizedBox(
                                      width: 70,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.check_circle,
                                          color: esRevisado
                                              ? Colors.amber.shade700
                                              : Colors.grey.shade400,
                                          size: 24,
                                        ),
                                        tooltip: 'Ver Comentario de Revisión',
                                        onPressed: () {
                                          setJugadoresState(() {
                                            esRevisado
                                                ? estadosRevisadosActivos
                                                      .remove(jugadorId)
                                                : estadosRevisadosActivos.add(
                                                    jugadorId,
                                                  );
                                          });
                                          _mostrarAlertaFrontal(
                                            context,
                                            'Comentario del Administrador',
                                            comentarioRevisado,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    // 3. VISTO CALIFICADO
                                    SizedBox(
                                      width: 70,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.check_circle,
                                          color: esCalificado
                                              ? const Color(0xFF3949AB)
                                              : Colors.grey.shade400,
                                          size: 24,
                                        ),
                                        tooltip: 'Ver Nombre de Quien Calificó',
                                        onPressed: () {
                                          setJugadoresState(() {
                                            esCalificado
                                                ? estadosCalificadosActivos
                                                      .remove(jugadorId)
                                                : estadosCalificadosActivos.add(
                                                    jugadorId,
                                                  );
                                          });
                                          _mostrarAlertaFrontal(
                                            context,
                                            'Calificado Por',
                                            'Calificado por: $calificadoPor',
                                          );
                                        },
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // EDITAR
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.orange,
                                      ),
                                      tooltip: 'Editar Jugador',
                                      onPressed: () =>
                                          agregarNuevoJugador(jugador),
                                    ),

                                    // ELIMINAR
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Eliminar Jugador',
                                      onPressed: () => eliminarJugador(jugador),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ABRIR EQUIPOS DE LA LIGA
  Future<void> _verEquiposDeLiga(String ligaId, String nombreLiga) async {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void verDetallesPresidente(Map<String, dynamic> equipo) {
              final presiNombre =
                  (equipo['delegado_nombre'] ??
                          equipo['presidente_nombre'] ??
                          '')
                      .toString()
                      .toUpperCase();
              final presiCedula =
                  equipo['delegado_cedula'] ??
                  equipo['presidente_cedula'] ??
                  'N/A';
              final presiCorreo = equipo['presidente_correo'] ?? 'N/A';
              final presiTel =
                  equipo['delegado_telefono'] ??
                  equipo['presidente_telefono'] ??
                  'N/A';

              showDialog(
                context: context,
                builder: (context) => _LigaDialog(
                  title: const Text('Detalles del Presidente'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre: ${presiNombre.isNotEmpty ? presiNombre : "SIN ASIGNAR"}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Cédula: $presiCedula'),
                      const SizedBox(height: 8),
                      Text('Correo: $presiCorreo'),
                      const SizedBox(height: 8),
                      Text('Teléfono: $presiTel'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            }

            void editarEquipo(Map<String, dynamic> equipo) {
              final nombreEquipoCtrl = TextEditingController(
                text: equipo['nombre'] ?? '',
              );
              final presiNombreCtrl = TextEditingController(
                text:
                    equipo['delegado_nombre'] ??
                    equipo['presidente_nombre'] ??
                    '',
              );
              final presiCedulaCtrl = TextEditingController(
                text:
                    equipo['delegado_cedula'] ??
                    equipo['presidente_cedula'] ??
                    '',
              );
              final presiTelCtrl = TextEditingController(
                text:
                    equipo['delegado_telefono'] ??
                    equipo['presidente_telefono'] ??
                    '',
              );
              final presiCorreoCtrl = TextEditingController(
                text: equipo['presidente_correo'] ?? '',
              );

              final categoriasDisponibles = [
                'Fútbol Senior',
                'Femenino',
                'Sub 12',
                'Sub 40',
              ];
              String categoriaSeleccionada =
                  equipo['categoria'] ?? 'Fútbol Senior';

              showDialog(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setEditarState) {
                    return _LigaDialog(
                      title: const Text('Editar Equipo'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nombreEquipoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del Equipo',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  categoriasDisponibles.contains(
                                    categoriaSeleccionada,
                                  )
                                  ? categoriaSeleccionada
                                  : categoriasDisponibles.first,
                              decoration: const InputDecoration(
                                labelText: 'Categoría',
                                border: OutlineInputBorder(),
                              ),
                              items: categoriasDisponibles.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setEditarState(
                                    () => categoriaSeleccionada = val,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: presiNombreCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: presiCedulaCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cédula',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: presiTelCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: presiCorreoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Correo',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await Supabase.instance.client
                                .from('equipos')
                                .update({
                                  'nombre': nombreEquipoCtrl.text
                                      .trim()
                                      .toUpperCase(),
                                  'presidente_nombre': presiNombreCtrl.text
                                      .trim()
                                      .toUpperCase(),
                                  'presidente_cedula': presiCedulaCtrl.text
                                      .trim(),
                                  'presidente_telefono': presiTelCtrl.text
                                      .trim(),
                                  'presidente_correo': presiCorreoCtrl.text
                                      .trim()
                                      .toLowerCase(),
                                })
                                .eq('id', equipo['id']);

                            if (context.mounted) Navigator.pop(context);
                            setModalState(() {});
                          },
                          child: const Text('Guardar'),
                        ),
                      ],
                    );
                  },
                ),
              );
            }

            void eliminarEquipo(Map<String, dynamic> equipo) {
              showDialog(
                context: context,
                builder: (context) => _LigaDialog(
                  title: const Text('Confirmar Eliminación'),
                  content: Text(
                    '¿Deseas eliminar el equipo "${equipo['nombre']}"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await Supabase.instance.client
                            .from('equipos')
                            .delete()
                            .eq('id', equipo['id']);
                        if (context.mounted) Navigator.pop(context);
                        setModalState(() {});
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
            }

            Future<void> crearNuevoEquipo() async {
              final creado = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    DialogoNuevoResponsable(tipo: 'equipo', ligaId: ligaId),
              );
              if (creado == true && context.mounted) setModalState(() {});
            }

            return _LigaDialog(
              wide: true,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Equipos de: $nombreLiga',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: crearNuevoEquipo,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo Equipo'),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: Supabase.instance.client
                      .from('equipos')
                      .select('*')
                      .eq('liga_id', int.tryParse(ligaId) ?? ligaId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Error al cargar equipos: ${snapshot.error}');
                    }
                    final equipos = snapshot.data ?? [];
                    if (equipos.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Esta liga aún no tiene equipos registrados.',
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: equipos.length,
                      itemBuilder: (context, index) {
                        final equipo = equipos[index];
                        final logoUrl =
                            equipo['escudo_url'] ?? equipo['logo_url'];
                        return Card(
                          child: ListTile(
                            onTap: () => _verJugadoresDeEquipo(equipo),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child:
                                  logoUrl != null &&
                                      logoUrl.toString().isNotEmpty
                                  ? Image.network(
                                      logoUrl,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.shield,
                                                color: Colors.indigo,
                                              ),
                                    )
                                  : const Icon(
                                      Icons.shield,
                                      color: Colors.indigo,
                                    ),
                            ),
                            title: Text(
                              equipo['nombre'] ?? 'Sin nombre',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            subtitle: const Text('Categoría: Todas'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      verDetallesPresidente(equipo),
                                  icon: const Icon(Icons.person, size: 16),
                                  label: const Text('Admin'),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.orange,
                                  ),
                                  tooltip: 'Editar Equipo',
                                  onPressed: () => editarEquipo(equipo),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Eliminar Equipo',
                                  onPressed: () => eliminarEquipo(equipo),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // REGISTRAR NUEVA LIGA
  Future<void> _crearNuevaLiga() async {
    final creado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DialogoNuevoResponsable(tipo: 'liga'),
    );
    if (creado == true && mounted) setState(() {});
  }

  // DETALLES DEL ADMINISTRADOR DE LIGA
  void _verDetallesAdmin(Map<String, dynamic> liga) {
    final adminNombre = liga['admin_nombre'] ?? 'N/A';
    final adminCedula = liga['admin_cedula'] ?? 'N/A';
    final adminCorreo = liga['admin_correo'] ?? 'N/A';
    final adminTel = liga['admin_telefono'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) {
        return _LigaDialog(
          title: const Text('Detalles del Administrador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nombre: $adminNombre',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Cédula: $adminCedula'),
              const SizedBox(height: 8),
              Text('Correo Institucional: $adminCorreo'),
              const SizedBox(height: 8),
              Text('Teléfono: $adminTel'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  // ELIMINAR LIGA CON CONFIRMACIÓN
  Future<void> _eliminarLiga(Map<String, dynamic> liga) async {
    showDialog(
      context: context,
      builder: (context) {
        return _LigaDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
            '¿Estás seguro de que deseas eliminar la liga "${liga['nombre']}"? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('ligas')
                      .delete()
                      .eq('id', liga['id']);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  if (mounted) {
                    setState(() {});
                  }
                } catch (_) {}
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  // EDITAR LIGA Y GUARDAR CAMBIOS
  Future<void> _editarLiga(Map<String, dynamic> liga) async {
    final nombreLigaCtrl = TextEditingController(
      text: (liga['nombre'] ?? '').toString().toUpperCase(),
    );
    final adminNombreCtrl = TextEditingController(
      text: (liga['admin_nombre'] ?? '').toString().toUpperCase(),
    );
    final adminCedulaCtrl = TextEditingController(
      text: liga['admin_cedula'] ?? '',
    );
    final adminCorreoCtrl = TextEditingController(
      text: liga['admin_correo'] ?? '',
    );
    final adminTelCtrl = TextEditingController(
      text: liga['admin_telefono'] ?? '',
    );

    String? logoUrlExistente = liga['logo_url'] ?? liga['escudo_url'];
    Uint8List? imagenBytes;
    bool subiendo = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> seleccionarLogo() async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
              );

              if (image != null) {
                final bytes = await image.readAsBytes();
                setDialogState(() {
                  imagenBytes = bytes;
                });
              }
            }

            return _LigaDialog(
              title: const Text('Editar Liga y Administrador'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreLigaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Liga',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Logo:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: imagenBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      imagenBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : (logoUrlExistente != null &&
                                          logoUrlExistente.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.network(
                                            logoUrlExistente,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.emoji_events,
                                                      size: 40,
                                                      color: Colors.indigo,
                                                    ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.emoji_events,
                                          size: 40,
                                          color: Colors.indigo,
                                        )),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: subiendo ? null : seleccionarLogo,
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              imagenBytes != null
                                  ? 'Cambiar Imagen'
                                  : 'Cargar del Dispositivo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Datos del Administrador:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: adminNombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Encargado',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: adminCedulaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cédula',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: adminCorreoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Institucional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: adminTelCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: subiendo
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: subiendo
                      ? null
                      : () async {
                          setDialogState(() {
                            subiendo = true;
                          });

                          String? finalUrl = logoUrlExistente;

                          try {
                            if (imagenBytes != null) {
                              final path =
                                  'liga_${liga['id']}_${DateTime.now().millisecondsSinceEpoch}.png';
                              await Supabase.instance.client.storage
                                  .from('escudos_ligas')
                                  .uploadBinary(path, imagenBytes!);

                              finalUrl = Supabase.instance.client.storage
                                  .from('escudos_ligas')
                                  .getPublicUrl(path);
                            }

                            final Map<String, dynamic> datosActualizar = {
                              'nombre': nombreLigaCtrl.text
                                  .trim()
                                  .toUpperCase(),
                              'admin_nombre': adminNombreCtrl.text
                                  .trim()
                                  .toUpperCase(),
                              'admin_cedula': adminCedulaCtrl.text.trim(),
                              'admin_correo': adminCorreoCtrl.text
                                  .trim()
                                  .toLowerCase(),
                              'admin_telefono': adminTelCtrl.text.trim(),
                            };

                            if (finalUrl != null) {
                              datosActualizar['logo_url'] = finalUrl;
                            }

                            await Supabase.instance.client
                                .from('ligas')
                                .update(datosActualizar)
                                .eq('id', liga['id']);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              setState(() {});
                            }
                          } catch (_) {
                            setDialogState(() {
                              subiendo = false;
                            });
                          }
                        },
                  child: subiendo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _ligaTheme(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F5),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 820),
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6FB),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE5E3EA)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: _LigaBrand(subtitle: 'Panel Superadministrador'),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Ligas Registradas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _crearNuevaLiga,
                          icon: const Icon(Icons.add),
                          label: const Text('Nueva Liga'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: Supabase.instance.client
                            .from('ligas')
                            .select('*'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }
                          final ligas = snapshot.data ?? [];
                          if (ligas.isEmpty) {
                            return const Center(
                              child: Text('No hay ligas registradas.'),
                            );
                          }

                          return ListView.builder(
                            itemCount: ligas.length,
                            itemBuilder: (context, index) {
                              final liga = ligas[index];
                              final logoUrl =
                                  liga['logo_url'] ?? liga['escudo_url'];

                              final adminNombre = liga['admin_nombre'] ?? 'N/A';
                              final adminCorreo = liga['admin_correo'] ?? 'N/A';
                              final adminTel = liga['admin_telefono'] ?? 'N/A';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child:
                                        logoUrl != null &&
                                            logoUrl.toString().isNotEmpty
                                        ? Image.network(
                                            logoUrl,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.emoji_events,
                                                      color: Colors.indigo,
                                                    ),
                                          )
                                        : const Icon(
                                            Icons.emoji_events,
                                            color: Colors.indigo,
                                          ),
                                  ),
                                  title: GestureDetector(
                                    onTap: () => _verEquiposDeLiga(
                                      liga['id'].toString(),
                                      liga['nombre'] ?? 'Liga',
                                    ),
                                    child: Text(
                                      liga['nombre'] ?? 'Sin nombre',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Admin: $adminNombre | Correo: $adminCorreo | Tel: $adminTel',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _verDetallesAdmin(liga),
                                        icon: const Icon(
                                          Icons.person,
                                          size: 16,
                                        ),
                                        label: const Text('Admin'),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.orange,
                                        ),
                                        tooltip: 'Editar Liga',
                                        onPressed: () => _editarLiga(liga),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Eliminar Liga',
                                        onPressed: () => _eliminarLiga(liga),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Shared visual style for the panel and every modal route.
ThemeData _ligaTheme(BuildContext context) {
  const primary = Color(0xFF4351BF);
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(primary: primary, surface: const Color(0xFFF8F6FB)),
    scaffoldBackgroundColor: const Color(0xFFF2F2F5),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F6FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Color(0xFF898692)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(100, 46),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
  );
}

class _LigaBrand extends StatelessWidget {
  const _LigaBrand({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircleAvatar(
        radius: 30,
        backgroundColor: Color(0xFF4351BF),
        child: Icon(Icons.sports_soccer, color: Colors.white, size: 36),
      ),
      const SizedBox(height: 12),
      const Text(
        'LigaMaster SaaS',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4351BF),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF96939B)),
      ),
    ],
  );
}

class _LigaDialog extends StatelessWidget {
  const _LigaDialog({
    this.title,
    this.content,
    this.actions,
    this.shape,
    this.titlePadding,
    this.contentPadding,
    this.wide = false,
  });
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height - media.viewInsets.bottom - 40)
        .clamp(100.0, 900.0)
        .toDouble();
    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SizedBox(
        width: wide ? 940 : 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF4351BF),
                    child: Icon(Icons.sports_soccer, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'LigaMaster SaaS',
                      style: TextStyle(
                        color: Color(0xFF4351BF),
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            if (title != null)
              Padding(
                padding:
                    titlePadding ?? const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Color(0xFF4351BF),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  child: title!,
                ),
              ),
            if (content != null)
              Flexible(
                child: Padding(
                  padding:
                      contentPadding ??
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: wide
                      ? content!
                      : SingleChildScrollView(child: content!),
                ),
              ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: actions!,
                  ),
                ),
              )
            else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
    return Theme(
      data: _ligaTheme(context),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        backgroundColor: const Color(0xFFF8F6FB),
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE5E3EA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: wide
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: panel,
              )
            : panel,
      ),
    );
  }
}
