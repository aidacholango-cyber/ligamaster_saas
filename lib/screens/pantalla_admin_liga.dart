import '../widgets/estilo_panel.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/dialogo_nuevo_responsable.dart';
import '../widgets/imagen_cedula.dart';
import 'pantalla_campeonatos.dart';
import 'pantalla_tesoreria.dart';

class PantallaAdminLiga extends StatelessWidget {
  const PantallaAdminLiga({super.key});
  @override
  Widget build(BuildContext context) =>
      Theme(data: _temaAdmin(), child: const _ContenidoAdminLiga());
}

class _ContenidoAdminLiga extends StatefulWidget {
  const _ContenidoAdminLiga({super.key});

  @override
  State<_ContenidoAdminLiga> createState() => __ContenidoAdminLigaState();
}

class __ContenidoAdminLigaState extends State<_ContenidoAdminLiga> {
  String? _ligaId;
  String _nombreLiga = '';
  String _adminNombre = '';
  String? _logoLigaUrl;
  bool _subiendoLogo = false;
  bool _accionAdmin = false;
  String? _errorCarga;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
      _ligaId = null;
    });
    try {
      final cliente = Supabase.instance.client;
      final usuario = cliente.auth.currentUser;
      if (usuario == null)
        throw StateError('Inicia sesión con tu cuenta de administrador.');
      final perfil = await cliente
          .from('perfiles')
          .select('rol, nombre')
          .eq('id', usuario.id)
          .maybeSingle();
      if (perfil?['rol'] != 'admin') {
        throw StateError('Esta pantalla corresponde al administrador de liga.');
      }
      final liga = await cliente
          .from('ligas')
          .select('*')
          .eq('admin_id', usuario.id)
          .maybeSingle();
      if (liga == null)
        throw StateError('Tu cuenta no tiene una liga asignada.');
      if (!mounted) return;
      _ligaId = liga['id'].toString();
      _nombreLiga = liga['nombre']?.toString() ?? '';
      _logoLigaUrl = liga['logo_url']?.toString();
      _adminNombre =
          liga['admin_nombre']?.toString() ??
          perfil?['nombre']?.toString() ??
          '';
    } catch (e) {
      _ligaId = null;
      _errorCarga = e is PostgrestException ? e.message : e.toString();
    } finally {
      if (mounted)
        setState(() {
          _cargando = false;
        });
    }
  }

  Future<void> _subirLogoLiga() async {
    if (_subiendoLogo || _ligaId == null) return;
    setState(() => _subiendoLogo = true);
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024)
        throw StateError('El logo debe pesar como máximo 5 MB.');
      String extension;
      String mime;
      if (bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        extension = 'png';
        mime = 'image/png';
      } else if (bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255) {
        extension = 'jpg';
        mime = 'image/jpeg';
      } else if (bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        extension = 'webp';
        mime = 'image/webp';
      } else {
        throw StateError('Selecciona una imagen PNG, JPG o WebP.');
      }
      final ruta =
          '$_ligaId/logo_${DateTime.now().microsecondsSinceEpoch}.$extension';
      final db = Supabase.instance.client;
      await db.storage
          .from('logos_ligas')
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(contentType: mime),
          );
      final url = await db.rpc(
        'lm_guardar_logo_liga',
        params: {'p_liga_id': _ligaId!, 'p_ruta': ruta},
      );
      if (!mounted) return;
      setState(() => _logoLigaUrl = url.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo de la liga guardado.')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : e is PostgrestException
                  ? e.message
                  : 'No se pudo guardar el logo. Comprueba tu conexión y los permisos.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _datosAdministrador({bool editar = false}) async {
    if (_accionAdmin || _ligaId == null) return;
    setState(() => _accionAdmin = true);
    try {
      final datos = await Supabase.instance.client
          .from('ligas')
          .select('admin_nombre,admin_cedula,admin_telefono,admin_correo')
          .eq('id', _ligaId!)
          .single();
      if (!mounted) return;
      if (!editar) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => _AdminDialog(
            logoUrl: _logoLigaUrl,
            title: const Text('Datos del administrador'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final campo in {
                  'admin_nombre': 'Nombre',
                  'admin_cedula': 'Cédula',
                  'admin_telefono': 'Teléfono',
                  'admin_correo': 'Correo',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextFormField(
                      initialValue: datos[campo.key]?.toString() ?? '',
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: campo.value,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      } else {
        final guardado = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _EditarDatosAdmin(
            ligaId: _ligaId!,
            datos: datos,
            logoUrl: _logoLigaUrl,
          ),
        );
        if (guardado == true && mounted) await _cargarDatosIniciales();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PostgrestException
                  ? e.message
                  : 'No se pudieron cargar los datos. Inténtalo de nuevo.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _accionAdmin = false);
    }
  }

  Future<void> _quitarAdministrador() async {
    if (_accionAdmin || _ligaId == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AdminDialog(
        title: const Text('Eliminar asignación del administrador'),
        content: const Text(
          'Se quitará tu asignación a esta liga y se cerrará tu sesión. La liga, sus equipos y jugadores se conservarán. El superadministrador deberá asignar un administrador para recuperar el acceso. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar asignación',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _accionAdmin = true);
    try {
      await Supabase.instance.client.rpc(
        'lm_quitar_mi_asignacion_admin',
        params: {'p_liga_id': _ligaId!},
      );
      try {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Asignación retirada. No se pudo cerrar la sesión; vuelve a intentar cerrar sesión.',
              ),
            ),
          );
      }
      if (mounted)
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PostgrestException
                  ? e.message
                  : 'No se pudo retirar la asignación. Inténtalo de nuevo.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _accionAdmin = false);
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerEquiposBackend() async {
    if (_ligaId == null) return [];
    final equipos = await Supabase.instance.client
        .from('equipos')
        .select('*')
        .eq('liga_id', _ligaId!);
    return List<Map<String, dynamic>>.from(equipos);
  }

  void _verJugadoresDelEquipo(Map<String, dynamic> equipo) {
    if (_ligaId == null || equipo['liga_id'].toString() != _ligaId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaRevisionJugadoresAdmin(
          equipoId: equipo['id'].toString(),
          nombreEquipo: equipo['nombre']?.toString() ?? 'Equipo',
        ),
      ),
    );
  }

  void _verDetallesPresidente(Map<String, dynamic> equipo) {
    final presiNombre =
        (equipo['delegado_nombre'] ?? equipo['presidente_nombre'] ?? '')
            .toString()
            .toUpperCase();
    final presiCedula =
        equipo['delegado_cedula'] ?? equipo['presidente_cedula'] ?? 'N/A';
    final presiCorreo = equipo['presidente_correo'] ?? 'N/A';
    final presiTel =
        equipo['delegado_telefono'] ?? equipo['presidente_telefono'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) {
        return _AdminDialog(
          title: const Text('Detalles del Presidente / Admin'),
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
        );
      },
    );
  }

  Future<void> _editarEquipo(Map<String, dynamic> equipo) async {
    final nombreEquipoCtrl = TextEditingController(
      text: (equipo['nombre'] ?? '').toString().toUpperCase(),
    );
    final presiNombreCtrl = TextEditingController(
      text: (equipo['delegado_nombre'] ?? equipo['presidente_nombre'] ?? '')
          .toString()
          .toUpperCase(),
    );
    final presiCedulaCtrl = TextEditingController(
      text: equipo['delegado_cedula'] ?? equipo['presidente_cedula'] ?? '',
    );
    final presiTelefonoCtrl = TextEditingController(
      text: equipo['delegado_telefono'] ?? equipo['presidente_telefono'] ?? '',
    );
    final presiCorreoCtrl = TextEditingController(
      text: equipo['presidente_correo'] ?? '',
    );

    String? urlEscudoExistente = equipo['escudo_url'] ?? equipo['logo_url'];
    Uint8List? imagenBytes;
    bool subiendoImagen = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> seleccionarImagen() async {
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

            return _AdminDialog(
              title: const Text('Editar Equipo y Presidente'),
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
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Escudo del Equipo:',
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
                                : (urlEscudoExistente != null &&
                                          urlEscudoExistente.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.network(
                                            urlEscudoExistente,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.shield,
                                                      size: 40,
                                                      color: Colors.indigo,
                                                    ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.shield,
                                          size: 40,
                                          color: Colors.indigo,
                                        )),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: subiendoImagen
                                ? null
                                : seleccionarImagen,
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              imagenBytes != null
                                  ? 'Cambiar Imagen'
                                  : 'Subir Imagen',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Datos del Presidente:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: presiNombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Presidente',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: presiCedulaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cédula',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: presiTelefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: presiCorreoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: subiendoImagen
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: subiendoImagen
                      ? null
                      : () async {
                          final nuevoNombre = nombreEquipoCtrl.text
                              .trim()
                              .toUpperCase();
                          if (nuevoNombre.isEmpty) return;

                          setDialogState(() {
                            subiendoImagen = true;
                          });

                          String? finalUrl = urlEscudoExistente;

                          try {
                            if (imagenBytes != null) {
                              final path =
                                  'escudos/${equipo['id']}_${DateTime.now().millisecondsSinceEpoch}.png';

                              await Supabase.instance.client.storage
                                  .from('escudos')
                                  .uploadBinary(path, imagenBytes!);

                              finalUrl = Supabase.instance.client.storage
                                  .from('escudos')
                                  .getPublicUrl(path);
                            }

                            await Supabase.instance.client
                                .from('equipos')
                                .update({
                                  'nombre': nuevoNombre,
                                  'escudo_url': finalUrl,
                                  'delegado_nombre': presiNombreCtrl.text
                                      .trim()
                                      .toUpperCase(),
                                  'delegado_cedula': presiCedulaCtrl.text
                                      .trim(),
                                  'delegado_telefono': presiTelefonoCtrl.text
                                      .trim(),
                                  'presidente_nombre': presiNombreCtrl.text
                                      .trim()
                                      .toUpperCase(),
                                  'presidente_cedula': presiCedulaCtrl.text
                                      .trim(),
                                  'presidente_telefono': presiTelefonoCtrl.text
                                      .trim(),
                                  'presidente_correo': presiCorreoCtrl.text
                                      .trim()
                                      .toLowerCase(),
                                })
                                .eq('id', equipo['id'])
                                .eq('liga_id', _ligaId!);

                            if (mounted) {
                              Navigator.pop(context);
                              setState(() {});
                            }
                          } catch (e) {
                            print('Error al guardar cambios del equipo: $e');
                            setDialogState(() {
                              subiendoImagen = false;
                            });
                          }
                        },
                  child: subiendoImagen
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _mostrarDialogoCrearEquipo() async {
    if (_ligaId == null) return;
    final creado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoNuevoResponsable(tipo: 'equipo', ligaId: _ligaId),
    );
    if (creado == true && mounted) await _cargarDatosIniciales();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorCarga != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administrador de liga')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Colors.indigo, size: 40),
                const SizedBox(height: 16),
                Text(_errorCarga!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _cargarDatosIniciales,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F5),
      appBar: AppBar(
        title: const Text('Panel de Administrador de Liga'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6FB),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            _LogoLiga(url: _logoLigaUrl, radio: 26),
                            TextButton.icon(
                              onPressed: _subiendoLogo || _accionAdmin
                                  ? null
                                  : _subirLogoLiga,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _subiendoLogo
                                    ? 'Guardando logo…'
                                    : (_logoLigaUrl?.isNotEmpty ?? false)
                                    ? 'Cambiar logo'
                                    : 'Subir logo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          'LigaMaster SaaS',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4351BF),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          _adminNombre.isEmpty
                              ? 'Administrador de liga'
                              : _adminNombre,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: _accionAdmin
                                  ? null
                                  : () => _datosAdministrador(),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Ver datos'),
                            ),
                            TextButton.icon(
                              onPressed: _accionAdmin
                                  ? null
                                  : () => _datosAdministrador(editar: true),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.orange,
                              ),
                              label: const Text('Editar'),
                            ),
                            TextButton.icon(
                              onPressed: _accionAdmin
                                  ? null
                                  : _quitarAdministrador,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              label: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Equipos de la liga: $_nombreLiga',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _ligaId == null
                                ? null
                                : () {
                                    final tema = Theme.of(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Theme(
                                          data: tema,
                                          child: PantallaCampeonatos(
                                            ligaId: _ligaId!,
                                            nombreLiga: _nombreLiga,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: const Text('Campeonatos'),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF166534),
                              foregroundColor: Colors.white),
                            onPressed: _ligaId == null ? null : () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) =>
                                PantallaTesoreria(ligaId: _ligaId!))),
                            icon: const Icon(Icons.account_balance_wallet_outlined),
                            label: const Text('Tesorería'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _mostrarDialogoCrearEquipo,
                            icon: const Icon(Icons.add),
                            label: const Text('Nuevo Equipo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _obtenerEquiposBackend(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error al cargar equipos: ${snapshot.error}',
                                ),
                              );
                            }
                            final equipos = snapshot.data ?? [];
                            if (equipos.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No hay equipos registrados en esta liga.',
                                ),
                              );
                            }
                            return Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Abre un equipo para revisar y calificar a sus jugadores.',
                                  ),
                                ),
                                SizedBox(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: equipos.length,
                                    itemBuilder: (context, index) {
                                      final equipo = equipos[index];
                                      final String? escudoUrl =
                                          equipo['escudo_url'] ??
                                          equipo['logo_url'];

                                      final compacto = MediaQuery.sizeOf(context).width < 600;
                                      final acciones = Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Ver jugadores',
                                                icon: const Icon(
                                                  Icons.groups,
                                                  color: Colors.indigo,
                                                ),
                                                onPressed: () =>
                                                    _verJugadoresDelEquipo(
                                                      equipo,
                                                    ),
                                              ),
                                              IconButton(
                                                tooltip: 'Datos del presidente',
                                                icon: const Icon(
                                                  Icons.person_outline,
                                                ),
                                                onPressed: () =>
                                                    _verDetallesPresidente(
                                                      equipo,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  color: Colors.orange,
                                                ),
                                                tooltip: 'Editar Equipo',
                                                onPressed: () =>
                                                    _editarEquipo(equipo),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                tooltip: 'Eliminar Equipo',
                                                onPressed: () async {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => _AdminDialog(
                                                      title: const Text(
                                                        'Confirmar Eliminación',
                                                      ),
                                                      content: Text(
                                                        '¿Deseas eliminar el equipo "${equipo['nombre']}"?',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                              ),
                                                          child: const Text(
                                                            'Cancelar',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors.red,
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                          onPressed: () async {
                                                            await Supabase
                                                                .instance
                                                                .client
                                                                .from('equipos')
                                                                .delete()
                                                                .eq(
                                                                  'id',
                                                                  equipo['id'],
                                                                )
                                                                .eq(
                                                                  'liga_id',
                                                                  _ligaId!,
                                                                );
                                                            if (context.mounted)
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                            setState(() {});
                                                          },
                                                          child: const Text(
                                                            'Eliminar',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                      return Card(
                                        child: Column(children: [ListTile(
                                          leading: GestureDetector(
                                            onTap: () =>
                                                _verJugadoresDelEquipo(equipo),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child:
                                                  escudoUrl != null &&
                                                      escudoUrl.isNotEmpty
                                                  ? Image.network(
                                                      escudoUrl,
                                                      width: 36,
                                                      height: 36,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => const Icon(
                                                            Icons.shield,
                                                            color:
                                                                Colors.indigo,
                                                            size: 32,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.shield,
                                                      color: Colors.indigo,
                                                      size: 32,
                                                    ),
                                            ),
                                          ),
                                          title: InkWell(
                                            onTap: () =>
                                                _verJugadoresDelEquipo(equipo),
                                            child: Text(
                                              equipo['nombre'] ?? 'Sin nombre',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Categorías: Fútbol Senior · Femenino · Sub 40 · Sub 12',
                                          ),
                                          trailing: compacto ? null : acciones,
                                        ),
                                        if (compacto) Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: acciones),
                                        ]),
                                      );
                                    },
                                  ),
                                ),
                              ],
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
    );
  }
}

/// Pantalla exclusiva del administrador. No sustituye pantallas del superadmin.
class PantallaRevisionJugadoresAdmin extends StatefulWidget {
  const PantallaRevisionJugadoresAdmin({
    super.key,
    required this.equipoId,
    required this.nombreEquipo,
    this.campeonatoCalificaciones,
    this.campeonatosCalificaciones,
    this.categoriaInicial,
  });
  final String equipoId;
  final String nombreEquipo;
  /// Solo la comisión usa las consultas limitadas a una asignación explícita.
  final String? campeonatoCalificaciones;
  final List<String>? campeonatosCalificaciones;
  final String? categoriaInicial;

  @override
  State<PantallaRevisionJugadoresAdmin> createState() => _RevisionState();
}

class _RevisionState extends State<PantallaRevisionJugadoresAdmin> {
  late Future<List<Map<String, dynamic>>> _carga;
  String? _categoria;
  final Set<String> _ocupados = {};

  @override
  void initState() {
    super.initState();
    _categoria = widget.categoriaInicial;
    _carga = _leer();
  }

  Future<List<Map<String, dynamic>>> _leer() async {
    final cliente = Supabase.instance.client;
    if (widget.campeonatoCalificaciones != null) {
      final ids = (widget.campeonatosCalificaciones ??
        [widget.campeonatoCalificaciones!]).toSet();
      final listas = await Future.wait(ids.map((id) async {
        final jugadores = List<Map<String, dynamic>>.from(await cliente.rpc(
          'lm_comision_jugadores', params: {
            'p_campeonato_id': id,
            'p_equipo_id': int.parse(widget.equipoId),
          }));
        return [for (final jugador in jugadores)
          {...jugador, '_campeonato_comision': id}];
      }));
      return listas.expand((lista) => lista).toList();
    }
    final usuario = cliente.auth.currentUser;
    if (usuario == null) throw StateError('La sesión ha terminado.');
    final perfil = await cliente
        .from('perfiles')
        .select('rol')
        .eq('id', usuario.id)
        .maybeSingle();
    if (perfil?['rol'] != 'admin')
      throw StateError('Acceso reservado al administrador de liga.');
    final equipoId = int.parse(widget.equipoId);
    final equipo = await cliente
        .from('equipos')
        .select('id')
        .eq('id', equipoId)
        .maybeSingle();
    if (equipo == null)
      throw StateError('El equipo no está disponible para tu cuenta.');
    final datos = await cliente
        .from('jugadores')
        .select('*')
        .eq('equipo_id', equipoId)
        .order('apellidos')
        .order('nombres');
    final campeonatos = List<Map<String, dynamic>>.from(
      await cliente.rpc('lm_campeonatos_vigencia_equipo',
        params: {'p_equipo_id': equipoId}),
    );
    final inscripciones = await cliente.from('campeonato_jugadores')
        .select('campeonato_id,jugador_id,estado')
        .eq('equipo_id', equipoId);
    return List<Map<String, dynamic>>.from(datos).where((jugador) {
      final activo = campeonatos.where((c) => c['activo'] == true &&
        c['categoria'] == jugador['categoria']).firstOrNull;
      return activo == null || !inscripciones.any((i) =>
        i['campeonato_id'].toString() == activo['id'].toString() &&
        i['jugador_id'].toString() == jugador['id'].toString() &&
        i['estado'] == 'retirado');
    }).toList();
  }

  void _recargar() {
    if (mounted)
      setState(() {
        _carga = _leer();
      });
  }

  String _fecha(dynamic valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();
    if (fecha == null) return 'Sin registrar';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} ${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  String _nombre(Map<String, dynamic> j) =>
      '${j['nombres'] ?? ''} ${j['apellidos'] ?? ''}'.trim();

  String _error(Object e) => e is PostgrestException ? e.message : e.toString();

  Future<void> _revisar(Map<String, dynamic> jugador) async {
    final id = jugador['id'].toString();
    if (_ocupados.contains(id)) return;
    setState(() {
      _ocupados.add(id);
    });
    final texto = TextEditingController(
      text: jugador['observaciones']?.toString() ?? '',
    );
    bool guardando = false;
    String? error;
    try {
      if (!mounted) return;
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, cambiar) => PopScope(
            canPop: !guardando,
            child: _AdminDialog(
              backgroundColor: const Color(0xFFF8F6FB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text('Revisar jugador'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombre(jugador),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: texto,
                        enabled: !guardando,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 4000,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones de la revisión',
                          hintText:
                              'Documentación verificada, correcciones pendientes…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (jugador['fecha_calificacion'] != null)
                        const Text(
                          'Al guardar una nueva revisión, el jugador deberá calificarse nuevamente.',
                        ),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: guardando
                      ? null
                      : () async {
                          if (texto.text.trim().isEmpty) {
                            cambiar(() {
                              error =
                                  'Escribe las observaciones antes de guardar.';
                            });
                            return;
                          }
                          cambiar(() {
                            guardando = true;
                            error = null;
                          });
                          try {
                            await Supabase.instance.client.rpc(
                              widget.campeonatoCalificaciones == null
                                  ? 'lm_revisar_jugador' : 'lm_comision_revisar_jugador',
                              params: {
                                if (widget.campeonatoCalificaciones != null)
                                  'p_campeonato_id': jugador['_campeonato_comision'] ?? widget.campeonatoCalificaciones,
                                'p_jugador_id': id,
                                'p_observaciones': texto.text.trim(),
                              },
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _recargar();
                          } catch (e) {
                            if (ctx.mounted)
                              cambiar(() {
                                guardando = false;
                                error = _error(e);
                              });
                          }
                        },
                  child: Text(guardando ? 'Guardando…' : 'Guardar revisión'),
                ),
              ],
            ),
          ),
        ),
      );
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      texto.dispose();
      if (mounted)
        setState(() {
          _ocupados.remove(id);
        });
    }
  }

  Future<void> _calificar(Map<String, dynamic> jugador) async {
    final id = jugador['id'].toString();
    if (_ocupados.contains(id)) return;
    setState(() {
      _ocupados.add(id);
    });
    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => _AdminDialog(
          title: const Text('Calificar jugador'),
          content: Text(
            '¿Confirmas la calificación de ${_nombre(jugador)}?\n\n'
            '${widget.campeonatoCalificaciones == null
              ? 'Se guardarán tu nombre y la fecha del servidor.'
              : 'Se conservará el nombre del administrador de la liga y quedará registrada la acción de la comisión.'}\n\n'
            'Revisión: ${jugador['observaciones'] ?? ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Calificar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
      await Supabase.instance.client.rpc(
        widget.campeonatoCalificaciones == null
            ? 'lm_calificar_jugador' : 'lm_comision_calificar_jugador',
        params: {'p_jugador_id': id,
          if (widget.campeonatoCalificaciones != null)
            'p_campeonato_id': jugador['_campeonato_comision'] ?? widget.campeonatoCalificaciones},
      );
      _recargar();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error(e))));
    } finally {
      if (mounted)
        setState(() {
          _ocupados.remove(id);
        });
    }
  }

  Widget _cuadroFoto(String titulo, String url, {bool documento = false}) {
    return Column(
      children: [
        Text(titulo, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCAC4D0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: url.isEmpty
              ? const Center(
                  child: Text(
                    'Sin imagen guardada',
                    textAlign: TextAlign.center,
                  ),
                )
              : documento
              ? ImagenCedula(referencia: url)
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      'No se pudo cargar la imagen',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _detalles(Map<String, dynamic> jugador) {
    jugador = Map<String, dynamic>.from(jugador);
    jugador['num_camiseta'] ??= jugador['dorsal'] ?? jugador['numero_camiseta'];
    const campos = {
      'cedula': 'Cédula',
      'num_camiseta': 'Número de camiseta',
      'fecha_nacimiento': 'Fecha de nacimiento',
      'categoria': 'Categoría',
      'posicion': 'Posición',
      'tipo_jugador': 'Tipo de jugador',
      'email': 'Correo',
      'telefono': 'Teléfono',
      'direccion': 'Dirección',
    };
    showDialog<void>(
      context: context,
      builder: (ctx) => _AdminDialog(
        title: Text(_nombre(jugador)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _cuadroFoto(
                        'Foto del jugador',
                        (jugador['foto_url']?.toString().trim() ?? '')
                                .isNotEmpty
                            ? jugador['foto_url'].toString().trim()
                            : jugador['foto_perfil_url']?.toString().trim() ??
                                  '',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _cuadroFoto(
                        'Cédula (parte delantera)',
                        jugador['foto_cedula_url']?.toString().trim() ?? '',
                        documento: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...campos.entries.map(
                  (campo) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: SelectableText(
                      '${campo.value}: ${jugador[campo.key] ?? 'Sin registrar'}',
                    ),
                  ),
                ),
                const Divider(),
                SelectableText(
                  'Observaciones: ${jugador['observaciones'] ?? 'Sin revisión'}',
                ),
                Text(
                  'Revisado por: ${jugador['revisado_por'] ?? 'Sin registrar'}',
                ),
                Text('Fecha de revisión: ${_fecha(jugador['fecha_revision'])}'),
                Text(
                  'Calificado por: ${jugador['calificado_por'] ?? 'Sin registrar'}',
                ),
                Text(
                  'Fecha de calificación: ${_fecha(jugador['fecha_calificacion'])}',
                ),
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
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _temaAdmin(),
    child: Scaffold(
      backgroundColor: const Color(0xFFF2F2F5),
      appBar: AppBar(
        title: Text(widget.campeonatoCalificaciones == null ? widget.nombreEquipo
          : '${widget.nombreEquipo.split(' · ').first} · ${_categoria ?? 'Todas las categorías'}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6FB),
            borderRadius: BorderRadius.circular(22),
          ),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _carga,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _recargar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              final todos = snapshot.data ?? [];
              final categorias =
                  <String>{
                    'Fútbol Senior', 'Femenino', 'Sub 40', 'Sub 12',
                    ...todos
                      .map((j) => j['categoria']?.toString() ?? '')
                      .where((c) => c.isNotEmpty),
                  }.toList()
                    ..sort();
              final seleccion = categorias.contains(_categoria)
                  ? _categoria
                  : null;
              final jugadores = todos
                  .where(
                    (j) => seleccion == null || j['categoria'] == seleccion,
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: Color(0xFF4351BF),
                      child: Icon(
                        Icons.sports_soccer,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'LigaMaster SaaS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4351BF),
                    ),
                  ),
                  const Text(
                    'Revisión y calificación de jugadores',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ControlCentrado(
                    ancho: 360,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: seleccion,
                      hint: const Text('Todas las categorías'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todas las categorías'),
                        ),
                        ...categorias.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (valor) => setState(() {
                        _categoria = valor;
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: jugadores.isEmpty
                        ? const Center(
                            child: Text('No hay jugadores registrados.'),
                          )
                        : ListView.separated(
                            itemCount: jugadores.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final j = jugadores[index];
                              final revisado =
                                  (j['estado'] == 'Revisado' ||
                                      j['estado'] == 'Calificado') &&
                                  j['fecha_revision'] != null;
                              final calificado =
                                  j['estado'] == 'Calificado' &&
                                  j['fecha_calificacion'] != null &&
                                  j['calificado_por_id'] != null;
                              final sinFirma =
                                  j['estado'] == 'Calificado' && !calificado;
                              final categoriaColor = switch (j['categoria']?.toString()) {
                                'Femenino' => const Color(0xFFBE1176),
                                'Sub 12' => const Color(0xFF925900),
                                'Sub 40' => const Color(0xFF1D4DE2),
                                _ => const Color(0xFF166534),
                              };
                              final ocupado = _ocupados.contains(
                                j['id'].toString(),
                              );
                              return Card(
                                elevation: 0,
                                color: categoriaColor.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(color: categoriaColor.withValues(alpha: 0.3))),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          ClipOval(
                                            child: SizedBox(
                                              width: 56,
                                              height: 56,
                                              child: Image.network(
                                                (j['foto_url']?.toString().trim().isNotEmpty ?? false)
                                                    ? j['foto_url'].toString()
                                                    : j['foto_perfil_url']?.toString() ?? '',
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _nombre(j),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF166534),
                                                  ),
                                                ),
                                                Text(
                                                  'Cédula: ${j['cedula'] ?? ''} · ${j['categoria'] ?? ''} · ${j['posicion'] ?? ''}',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          const Chip(
                                            backgroundColor: Color(0xFFDCFCE7),
                                            side: BorderSide(color: Color(0xFF86CBA2)),
                                            labelStyle: TextStyle(color: Color(0xFF166534),
                                              fontWeight: FontWeight.w600),
                                            label: Text('Inscrito'),
                                            avatar: Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 18,
                                            ),
                                          ),
                                          Chip(
                                            backgroundColor: const Color(0xFFFFF3D6),
                                            side: const BorderSide(color: Color(0xFFE5C68C)),
                                            labelStyle: const TextStyle(color: Color(0xFF925900),
                                              fontWeight: FontWeight.w600),
                                            label: Text(
                                              revisado
                                                  ? 'Revisado'
                                                  : 'Pendiente de revisión',
                                            ),
                                            avatar: Icon(
                                              Icons.fact_check,
                                              color: revisado
                                                  ? Colors.orange
                                                  : Colors.grey,
                                              size: 18,
                                            ),
                                          ),
                                          Chip(
                                            backgroundColor: const Color(0xFFE7EDFF),
                                            side: const BorderSide(color: Color(0xFFAABEF9)),
                                            labelStyle: const TextStyle(color: Color(0xFF1D4DE2),
                                              fontWeight: FontWeight.w600),
                                            label: Text(
                                              calificado
                                                  ? 'Calificado'
                                                  : 'Sin calificar',
                                            ),
                                            avatar: Icon(
                                              Icons.verified,
                                              color: calificado
                                                  ? Colors.indigo
                                                  : Colors.grey,
                                              size: 18,
                                            ),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              backgroundColor: const Color(0xFFFCE7F3),
                                              foregroundColor: const Color(0xFFBE1176)),
                                            onPressed: () => _detalles(j),
                                            child: const Text('Ver ficha'),
                                          ),
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: const Color(0xFF925900),
                                              foregroundColor: Colors.white,
                                              side: const BorderSide(color: Color(0xFF925900))),
                                            onPressed: ocupado
                                                ? null
                                                : () => _revisar(j),
                                            child: Text(
                                              revisado
                                                  ? 'Editar revisión'
                                                  : 'Revisar',
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF166534),
                                              foregroundColor: Colors.white),
                                            onPressed:
                                                ocupado ||
                                                    !revisado ||
                                                    calificado
                                                ? null
                                                : () => _calificar(j),
                                            child: Text(
                                              ocupado
                                                  ? 'Procesando…'
                                                  : 'Calificar',
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (sinFirma)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Registro anterior con estado Calificado, sin firma de calificación. Primero pulsa Revisar.',
                                            style: TextStyle(
                                              color: Color(0xFF8D6500),
                                            ),
                                          ),
                                        ),
                                      if (revisado)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            'Observaciones: ${j['observaciones'] ?? ''}\n'
                                            'Revisado por ${j['revisado_por'] ?? ''} · ${_fecha(j['fecha_revision'])}',
                                          ),
                                        ),
                                      if (calificado)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            'Calificado por ${j['calificado_por'] ?? ''} · ${_fecha(j['fecha_calificacion'])}',
                                            style: const TextStyle(
                                              color: Colors.indigo,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

ThemeData _temaAdmin() => temaLigaMaster();

class _AdminDialog extends StatelessWidget {
  const _AdminDialog({
    this.title,
    this.content,
    this.actions,
    this.logoUrl,
    this.backgroundColor,
    this.shape,
  });
  final String? logoUrl;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  @override
  Widget build(BuildContext context) => Theme(
    data: _temaAdmin(),
    child: AlertDialog(
      backgroundColor: const Color(0xFFF8F6FB),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LogoLiga(url: logoUrl, radio: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LigaMaster SaaS',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4351BF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (title != null) title!,
        ],
      ),
      content: SizedBox(width: 620, child: content),
      actions: actions,
    ),
  );
}

class _EditarDatosAdmin extends StatefulWidget {
  final String ligaId;
  final Map<String, dynamic> datos;
  final String? logoUrl;
  const _EditarDatosAdmin({
    required this.ligaId,
    required this.datos,
    this.logoUrl,
  });
  @override
  State<_EditarDatosAdmin> createState() => _EditarDatosAdminState();
}

class _EditarDatosAdminState extends State<_EditarDatosAdmin> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _cedula;
  late final TextEditingController _telefono;
  bool _guardando = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(
      text: widget.datos['admin_nombre']?.toString() ?? '',
    );
    _cedula = TextEditingController(
      text: widget.datos['admin_cedula']?.toString() ?? '',
    );
    _telefono = TextEditingController(
      text: widget.datos['admin_telefono']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _cedula.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'lm_editar_mis_datos_admin',
        params: {
          'p_liga_id': widget.ligaId,
          'p_nombre': _nombre.text.trim(),
          'p_cedula': _cedula.text.trim(),
          'p_telefono': _telefono.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No se pudo guardar. Comprueba tu conexión.',
        );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: _AdminDialog(
      logoUrl: widget.logoUrl,
      title: const Text('Editar administrador'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  enabled: !_guardando,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Escribe el nombre.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cedula,
                  enabled: !_guardando,
                  maxLength: 10,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cédula',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v?.trim().isNotEmpty ?? false) &&
                          !RegExp(r'^\d{10}$').hasMatch(v!.trim())
                      ? 'La cédula debe tener 10 dígitos.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefono,
                  enabled: !_guardando,
                  maxLength: 30,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: widget.datos['admin_correo']?.toString() ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Correo de acceso',
                    helperText:
                        'El correo de acceso se conserva en este formulario.',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
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

class _LogoLiga extends StatelessWidget {
  final String? url;
  final double radio;
  const _LogoLiga({this.url, required this.radio});
  @override
  Widget build(BuildContext context) {
    final imagen = url?.trim() ?? '';
    final respaldo = Icon(
      Icons.sports_soccer,
      color: Colors.white,
      size: radio,
    );
    return Container(
      width: radio * 2,
      height: radio * 2,
      decoration: const BoxDecoration(
        color: Color(0xFF4351BF),
        shape: BoxShape.circle,
      ),
      child: imagen.isEmpty
          ? respaldo
          : ClipOval(
              child: ColoredBox(
                color: Colors.white,
                child: Image.network(
                  imagen,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF4351BF),
                  ),
                ),
              ),
            ),
    );
  }
}
