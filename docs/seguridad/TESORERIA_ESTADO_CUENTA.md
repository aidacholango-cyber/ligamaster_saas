# Tesorería: estados de cuenta por equipo

## Activación

1. Con el módulo existente de cobros manuales instalado, ejecutar completo
   `tesoreria_estado_cuenta.sql` en Supabase SQL Editor.
2. Abrir la aplicación con el administrador de liga y pulsar **Tesorería**,
   junto a Campeonatos. Elegir campeonato/categoría y equipo.
3. Si se utiliza la aplicación publicada, subir el código y esperar a que
   Vercel publique el nuevo commit. Subir SQL a GitHub no lo ejecuta en Supabase.

No se ha instalado este SQL desde las herramientas locales: requiere ejecutarlo
en el proyecto Supabase correspondiente.

## Qué se conserva

- Los importes se consultan directamente desde el desglose **publicado** de cada
  equipo en vocalía/planilla. Los borradores no se suman ni se imprimen.
- Se muestran todos los partidos de ese equipo en la categoría/campeonato.
  Cuando solo el rival tiene cobro publicado, se muestra **Cobro de este equipo
  pendiente de publicar**, sin copiar ni sumar el importe del rival.
- Se incluyen campeonatos anteriores e inactivos para consultar el historial.
- Los importes continúan siendo manuales. No se calculan multas por tarjetas.
- Las tablas anteriores de cobros e historial no se modifican.

## Movimientos

Cada movimiento pertenece a un partido, un equipo y la moneda de su cobro:

- **Pago recibido del equipo**: dinero que efectivamente recibió la liga.
- **Dinero entregado al árbitro**: egreso atribuido a ese equipo y partido.
  Debe indicar el nombre del árbitro. No reduce nuevamente la deuda del equipo.
  Si el pago al árbitro cubre ambos equipos, registrar una sola vez cada parte
  atribuida a cada equipo; no registrar dos veces el pago completo.
- Fecha, referencia/número de recibo y fotografía opcional del comprobante.
  El comprobante admite PNG/JPG/WebP de hasta 5 MB y se guarda en el bucket
  privado `tesoreria_comprobantes`. No se generan enlaces públicos.
- Los errores se corrigen con **Anular con motivo** y un movimiento nuevo.
  La anulación conserva el original, el motivo, el usuario y la fecha.
- Se admiten abonos y pagos superiores al cobro; el exceso aparece como crédito
  a favor (saldo negativo), sin ocultarlo ni modificar el cobro.
- Reintentar el mismo guardado utiliza el mismo UUID y no duplica el pago.

## Recaudación desde vocalía

Debajo del total de cada equipo hay botones **Recibido del equipo** y **Pagado
al árbitro**. Ambos utilizan los mismos movimientos de Tesorería, con UUID,
partido, equipo, importe y usuario autenticado. El vocal no puede modificar
el desglose cobrado ni anular movimientos (la corrección corresponde al admin).

El servidor permite registrar al vocal activo solo para los equipos participantes
de una planilla abierta, de un campeonato activo y fase abierta, con cobro ya
publicado. Al confirmar el partido se deshabilita esta captura. No se añaden
botones de captura a las hojas de solo lectura ni al ingreso manual del admin.
Para pagos registrados después del cierre, el administrador usa Tesorería.

La ruta nueva del comprobante incluye liga/partido/equipo/UUID/archivo, para
autorizar el archivo con los mismos límites. Los comprobantes anteriores del
administrador siguen funcionando con su ruta original.

El saldo es **cobros publicados − pagos del equipo no anulados**. Los egresos
al árbitro se muestran aparte. No se suman monedas distintas. Si se corrige un
cobro publicado, el informe refleja el nuevo cobro y conserva los movimientos
con su moneda original; no convierte monedas automáticamente.

## Período e impresión

Los filtros seleccionan **partidos por su fecha** (o fecha de publicación si aún
no tienen horario). El informe incluye todos los pagos de esos partidos,
independientemente de la fecha del pago. No es un libro de caja por fecha de
movimiento ni un saldo acumulado anterior al período. Sin filtros muestra
todo el historial disponible del campeonato y equipo seleccionados.

**Imprimir estado de cuenta** abre el diálogo de impresión del navegador:
permite elegir impresora o Guardar como PDF. Incluye nombre del equipo,
liga/campeonato/categoría, desglose por partido y jugador sancionado, pagos,
entregas al árbitro, anulaciones y totales por moneda. No incluye enlaces
privados, identificadores internos ni datos de contacto de jugadores.

## Permisos y verificación

- El administrador solo consulta/escribe en su liga. El vocal puede consultar
  la recaudación del partido y capturar movimientos con las restricciones de
  vocalía anteriores. No recibe acceso al catálogo ni al historial general.
  La comisión de calificaciones no recibe permisos de tesorería.
- La consulta individual admite al delegado de su propio equipo. La pantalla
  administrativa se abre únicamente desde el panel administrador.
- Los comprobantes privados son accesibles al administrador de su liga; el vocal
  puede subir/leer los del partido/equipo que puede cobrar, mientras esté abierto.
- Confirmar con Supabase real: abono de 10 sobre cobro de 15 deja saldo 5;
  entregar 5 al árbitro mantiene ese saldo 5. Anular el abono restaura saldo 15.
- Probar que otro administrador, un vocal y la comisión no pueden registrar
  movimientos ni leer comprobantes de otra liga.

Las pruebas locales verifican cálculos, monedas, anulaciones, límites de período,
escape HTML y registro de pago con actualización inmediata mediante HTTP simulado.
