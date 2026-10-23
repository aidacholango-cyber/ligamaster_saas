import '../lib/models/jugador_vocal.dart';

void comprobar(bool valor, String mensaje) {
  if (!valor) throw StateError(mensaje);
}

void main() {
  final jugadores = <Map<String, dynamic>>[
    {'id': 'a', 'camiseta': 9},
    {'id': 'b', 'camiseta': '09'},
    {'id': 'c', 'camiseta': 19},
    {'id': 'd', 'camiseta': null},
    {'id': 'e', 'camiseta': 0},
  ];
  comprobar(
    buscarCamisetaVocal(jugadores, '9').length == 2,
    'Conservar coincidencias duplicadas para elegir',
  );
  comprobar(
    buscarCamisetaVocal(jugadores, '19').single['id'] == 'c',
    'Coincidencia exacta, no parcial',
  );
  comprobar(
    buscarCamisetaVocal(jugadores, '').isEmpty,
    'No mostrar toda la plantilla sin número',
  );
  comprobar(
    buscarCamisetaVocal(jugadores, 'no').isEmpty,
    'Rechazar texto no numérico',
  );
  comprobar(buscarCamisetaVocal(jugadores, '-1').isEmpty, 'Rechazar negativo');
  comprobar(
    buscarCamisetaVocal(jugadores, '0').single['id'] == 'e',
    'Aceptar camiseta cero',
  );
  comprobar(
    nombreCortoVocal('  JUAN CARLOS ', ' PEREZ LOPEZ') == 'JUAN PEREZ',
    'Un nombre y un apellido',
  );
  comprobar(nombreCortoVocal(null, null).isEmpty, 'Datos vacíos');
  print('8 comprobaciones correctas del modelo del vocal.');
}
