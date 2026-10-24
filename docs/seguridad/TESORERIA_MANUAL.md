## Instalación

Ejecutar completo `tesoreria_manual.sql` en Supabase SQL Editor y reiniciar
la aplicación. El script añade tablas y funciones de tesorería; no actualiza
partidos, jugadores, tarjetas, calendarios ni resultados existentes.

## Uso

1. Administrador: Fixture → Planilla y resultado → debajo de cada equipo,
   Tesorería → Ingresar / editar cobros.
2. Ingresar moneda, arbitraje y mantenimiento. Añadir sanciones T.A./T.R.
   indicando camiseta y monto, u otros conceptos. Todos los importes son
   manuales; no existen tarifas ni multas automáticas.
3. Guardar borrador o publicar. El borrador no reemplaza el desglose publicado.
4. Delegado: panel de su equipo → Tesorería · Cobros por partido → Total a pagar.
   También aparece el total publicado debajo de cada equipo en la planilla
   del vocal, sin permiso de edición.

## Comprobación con las cuentas reales

- Sin sanciones: publicar solo arbitraje y mantenimiento y verificar su suma.
- Guardar un borrador: el delegado debe seguir viendo la publicación anterior.
- Publicar cambios: actualizar el delegado y comprobar el nuevo detalle.
- El delegado no debe acceder a cobros de otro equipo ni guardar importes.
- Editar desde dos sesiones: el guardado obsoleto debe pedir recargar.
- No publicar cobros reales durante la comprobación salvo que corresponda.

## Validación local

`flutter test --no-pub test/cobro_manual_test.dart` comprueba centavos, decimales,
rechazo de importes inválidos y desgloses sin sanciones o con sanciones manuales.
La aplicación suma centavos enteros y el servidor recalcula el total al guardar.
Las tablas no admiten acceso directo de las cuentas de la aplicación: las
funciones verifican la liga del administrador y el equipo del delegado.

Este módulo registra cobros y sus publicaciones; no registra pagos ni saldos
abonados. Cada publicación y borrador conserva una entrada en el historial.
Los partidos con cobros conservan referencias para proteger el historial.
