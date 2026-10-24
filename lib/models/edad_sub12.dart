/// Edad de la categoría por año calendario, sin descontar meses o días.
int edadSub12(DateTime nacimiento, {DateTime? hoy}) =>
    (hoy ?? DateTime.now()).year - nacimiento.year;

String? errorEdadSub12(DateTime nacimiento, {DateTime? hoy}) {
  final edad = edadSub12(nacimiento, hoy: hoy);
  if (edad > 12) {
    return 'No puede ingresar en Sub 12: tiene $edad años por año de nacimiento. El máximo es 12 años.';
  }
  return null;
}
