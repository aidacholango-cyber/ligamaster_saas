import 'dart:async';
import 'package:flutter/material.dart';

/// Consulta automática con los permisos actuales. No abre canales públicos.
mixin RefrescoDeportivo<T extends StatefulWidget> on State<T> {
  Timer? _relojDeportivo;
  bool _leyendoDeporte = false;
  Future<void> refrescarDeporte();
  @override
  void initState() {
    super.initState();
    _relojDeportivo = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted ||
          _leyendoDeporte ||
          ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
        return;
      _leyendoDeporte = true;
      try {
        await refrescarDeporte();
      } catch (_) {
        // Conservar la última lectura ante una interrupción; reintentar en el siguiente ciclo.
      } finally {
        _leyendoDeporte = false;
      }
    });
  }

  @override
  void dispose() {
    _relojDeportivo?.cancel();
    super.dispose();
  }
}
