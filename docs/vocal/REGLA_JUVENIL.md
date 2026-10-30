# Validación automática de titulares

Ejecutar completo `11_regla_juvenil.sql` en Supabase SQL Editor. Requiere los
módulos anteriores de vocalía y del ingreso manual del administrador.

- **Fútbol Senior y Femenino**: para ingresar 11 titulares debe haber al menos
  un jugador menor de 18 años en la fecha oficial del partido. Puede haber más.
  Si no hay juvenil, se admiten hasta 10 titulares.
- **Sub 40**: para ingresar 11 titulares debe estar un jugador de 38 años,
  calculados por año calendario del encuentro, sin importar el mes. Se admite
  máximo uno de 38 en cancha a la vez. Sin ese jugador, hasta 10 titulares.
  La inscripción permite la excepción de 38 y sigue rechazando menores de 38.
- **Sub 12**: no se aplica esta obligación ni se cambia su validación de edad.

La comprobación sucede automáticamente al buscar la camiseta del titular once,
al guardar y al publicar. No hay selector de tiempos, cronómetro ni botón de
segundo tiempo. El requisito se comprueba entre **titulares**, no en suplentes.
La tabla de cambios conserva su funcionamiento; al completar un equipo que
empezó con diez, la entrada se registra allí sin alterar los diez titulares.
Este módulo no certifica por reloj el minuto real de los cambios.

En Sub 40, si entra otro jugador de 38 como cambio, debe señalarse la salida
del de 38 que estaba jugando; si ambos quedan en cancha no permite guardar.
Una sustitución pendiente de asignar puede completarse en pantalla, pero no se
guarda/publica si incumple el máximo de un jugador de 38.

Supabase obtiene los nacimientos reales de las fichas; no confía en edades
enviadas desde el navegador. El trigger comprueba también llamadas a las RPC
anteriores y el ingreso manual del administrador. No cambia firmas, informes,
tarjetas, cobros ni resultados publicados, ni modifica fichas o planillas
históricas al instalarse.

Las pruebas locales verifican límites de edad, ambas categorías de menores,
titulares frente a suplentes, independencia entre equipos, excepción Sub 40,
bloqueo del titular once adulto, admisión del juvenil y ausencia de controles
de tiempo. La ejecución del SQL en la base real corresponde al administrador.
