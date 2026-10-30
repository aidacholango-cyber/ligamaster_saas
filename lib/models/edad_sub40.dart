/// Edad por año calendario: no se descuentan meses ni días.
int edadSub40(DateTime nacimiento, {DateTime? hoy}) =>
    (hoy ?? DateTime.now()).year - nacimiento.year;

String? errorEdadSub40(DateTime nacimiento, {DateTime? hoy}) {
  final edad = edadSub40(nacimiento, hoy: hoy);
  if (edad < 38) {
    return 'No puede ingresar en Sub 40: tiene $edad años por año de nacimiento. Se admiten desde 39 años y la excepción de 38 años.';
  }
  return null;
}
