// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';

@JS('document.getElementById')
external _Marco? _buscarMarco(JSString id);

extension type _Marco(JSObject _) implements JSObject {
  external _VentanaImpresion? get contentWindow;
}

extension type _VentanaImpresion(JSObject _) implements JSObject {
  external void focus();
  external void print();
}

Future<void> imprimirTesoreria(String contenido) async {
  html.document.getElementById('impresion-tesoreria')?.remove();
  final marco = html.IFrameElement()
    ..id = 'impresion-tesoreria'
    ..title = 'Estado de cuenta del equipo'
    ..style.position = 'fixed'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = '0'
    ..srcdoc = contenido;
  final cargado = marco.onLoad.first;
  html.document.body!.append(marco);
  await cargado.timeout(const Duration(seconds: 15));
  final ventana = _buscarMarco('impresion-tesoreria'.toJS)?.contentWindow;
  if (ventana == null) throw StateError('No se pudo preparar la impresión.');
  ventana.focus();
  ventana.print();
}
