/// Garantía H29 — la apariencia sobrevive al cierre de sesión.
///
/// Parece un detalle y es la clase de cosa que se nota tres veces: `vaciar()`
/// borra todo lo que vive bajo `natacion_app/<cuentaId>/`, y la feature 006 lo
/// dejó así a propósito, porque el grupo son hermanos que comparten teléfono.
///
/// Una preferencia guardada ahí se iría con cada salida. Y no debe irse: la
/// apariencia es del dispositivo —quien tiene el teléfono al sol lo quiere
/// claro— y no es un dato personal de nadie (decisión D4).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/preferencias/apariencia.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const preferencias = PreferenciasDelDispositivo();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('dónde vive', () {
    test('**la clave no está bajo el prefijo que se vacía**', () {
      expect(
        PreferenciasDelDispositivo.claveApariencia.startsWith('natacion_app/'),
        isFalse,
        reason:
            'Todo lo que empieza por `natacion_app/` lo borra `vaciar()` '
            'al cerrar sesión',
      );
      expect(
        PreferenciasDelDispositivo.claveRecorridoLocal.startsWith(
          'natacion_app/',
        ),
        isFalse,
      );
    });
  });

  group('al cerrar sesión', () {
    test('la elección sigue ahí', () async {
      await preferencias.guardarApariencia(Apariencia.oscuro);

      // Lo que hace `cerrarSesion()` con lo de esta cuenta.
      await AlmacenPreferencias(cuentaId: 'u-ana').vaciar();

      expect(await preferencias.apariencia(), Apariencia.oscuro);
    });

    test('y tampoco se la lleva el vaciado de una cuenta sin id', () async {
      await preferencias.guardarApariencia(Apariencia.claro);

      await AlmacenPreferencias().vaciar();

      expect(await preferencias.apariencia(), Apariencia.claro);
    });

    test('lo de la cuenta sí se va, que es lo que se quería', () async {
      final almacen = AlmacenPreferencias(cuentaId: 'u-ana');
      await almacen.escribir('registros', 'r1', {'realizada': true});

      await almacen.vaciar();

      expect(await almacen.leer('registros', 'r1'), isNull);
    });
  });

  group('por omisión', () {
    test('sigue al teléfono, que es lo que la app hacía hasta ahora', () async {
      expect(await preferencias.apariencia(), Apariencia.delSistema);
    });

    test('una clave que no se entiende no rompe nada', () async {
      SharedPreferences.setMockInitialValues({
        PreferenciasDelDispositivo.claveApariencia: 'fucsia',
      });

      expect(await preferencias.apariencia(), Apariencia.delSistema);
    });
  });

  group('el recorrido en modo local', () {
    test('se recuerda', () async {
      await preferencias.guardarRecorridoLocal('nadador');
      expect(await preferencias.recorridoLocal(), 'nadador');
    });

    test('y falta la primera vez', () async {
      expect(await preferencias.recorridoLocal(), isNull);
    });
  });
}
