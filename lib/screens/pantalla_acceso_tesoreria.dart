import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_tesoreria.dart';
import 'pantalla_login.dart';

class PantallaAccesoTesoreria extends StatefulWidget {
  const PantallaAccesoTesoreria({super.key});
  @override
  State<PantallaAccesoTesoreria> createState() =>
      _PantallaAccesoTesoreriaState();
}

class _PantallaAccesoTesoreriaState extends State<PantallaAccesoTesoreria> {
  late Future<List<Map<String, dynamic>>> _ligas;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    _ligas = _leer();
  }

  Future<List<Map<String, dynamic>>> _leer() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client.rpc('lm_tesoreria_ligas'),
      );

  Future<void> _salir() async {
    setState(() => _cerrando = true);
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PantallaLogin()),
        (_) => false,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cerrar sesión. Intenta nuevamente.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tesorería'),
      actions: [
        IconButton(
          tooltip: 'Actualizar ligas',
          onPressed: () => setState(() => _ligas = _leer()),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: _cerrando ? null : _salir,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _ligas,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snap.error is PostgrestException
                      ? (snap.error as PostgrestException).message
                      : 'No se pudo abrir Tesorería.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => setState(() => _ligas = _leer()),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  const Text(
                    'LigaMaster SaaS',
                    style: TextStyle(
                      color: Color(0xFF4351BF),
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Selecciona una liga para gestionar cobros, pagos y estados de cuenta.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  for (final liga in snap.data ?? <Map<String, dynamic>>[])
                    Card(
                      color: const Color(0xFFE2F2E8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFF166534),
                        ),
                        title: Text(
                          '${liga['nombre']}',
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF166534),
                        ),
                        onTap: _cerrando
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PantallaTesoreria(
                                    ligaId: '${liga['id']}',
                                    accesoTesoreria: true,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  if (snap.data?.isEmpty ?? true)
                    const Text('No hay ligas disponibles.'),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
