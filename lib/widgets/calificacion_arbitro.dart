import 'package:flutter/material.dart';

/// Una sola valoración del vocal para todo el partido.
class CalificacionArbitro extends StatelessWidget {
  const CalificacionArbitro({
    super.key,
    required this.valor,
    required this.editable,
    required this.alCambiar,
  });
  final String? valor;
  final bool editable;
  final ValueChanged<String> alCambiar;
  static const opciones = {
    'malo': 'Malo',
    'bueno': 'Bueno',
    'excelente': 'Excelente',
  };

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 360,
      child: Card(
        color: const Color(0xFFFCE7F3),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.sports, color: Color(0xFFBE1176)),
          title: const Text(
            'Calificación del árbitro',
            style: TextStyle(
              color: Color(0xFFBE1176),
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: valor == null ? null : Text(opciones[valor] ?? ''),
          children: [
            RadioGroup<String>(
              groupValue: valor,
              onChanged: (seleccion) {
                if (editable && seleccion != null) alCambiar(seleccion);
              },
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opcion in opciones.entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: editable ? () => alCambiar(opcion.key) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(opcion.value, style: const TextStyle(fontSize: 14)),
                          Radio<String>(
                            value: opcion.key,
                            enabled: editable,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            activeColor: opcion.key == 'malo'
                          ? const Color(0xFFB82018)
                          : opcion.key == 'bueno'
                          ? const Color(0xFF925900)
                          : const Color(0xFF166534),
                          ),
                        ]),
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
