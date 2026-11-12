/// El cerrojo sobre `RepositorioMacrociclosFirestore.deNadador`, en su fuente.
///
/// **El defecto que esto vigila lo encontró el recorrido en el Pixel 7, y no
/// lo podía encontrar ninguna otra cosa.** La nadadora abría «Ver Plan» con su
/// macrociclo entregado, guardado y asignado, y le salía:
///
///     No se pudieron leer los macrociclos de n-ana:
///     The caller does not have permission to execute the specified operation.
///
/// La regla estaba bien y el dato estaba bien. Lo que estaba mal era la
/// consulta. En Firestore **una consulta no se evalúa documento a documento**:
/// el servidor exige poder demostrar, mirando solo los filtros, que todo lo
/// que podría devolver es legible. La regla del nadador dice «el suyo **y**
/// entregado», así que una consulta que solo filtra por `nadadorId` no se
/// puede demostrar y se rechaza entera — aunque cada documento que fuera a
/// devolver estuviera entregado.
///
/// Las pruebas de reglas tenían siete positivas y ninguna lo vio, porque todas
/// leían un documento por su identificador. La app no hace eso nunca: la
/// pantalla de la nadadora no sabe el identificador de su macrociclo, lo
/// busca. Se comprobaba una puerta por la que la app no pasa.
///
/// El comportamiento está fijado contra el emulador en
/// `firebase/test/reglas_macrociclos.test.js` («la nadadora lista su
/// macrociclo filtrando tambien por entregado»). Esto comprueba que el
/// cliente hace **esa** consulta, porque `cloud_firestore` necesita una app
/// Flutter y no se puede ejecutar aquí.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const ruta = 'lib/datos/firestore/macrociclos_firestore.dart';

  late String fuente;

  setUpAll(() {
    fuente = File(ruta).readAsStringSync();
  });

  /// El cuerpo de `deNadador`, hasta el `@override` siguiente.
  String cuerpoDeNadador() {
    const firma = 'Future<List<Macrociclo>> deNadador(';
    final desde = fuente.indexOf(firma);
    expect(desde, greaterThan(-1), reason: 'no se encontró «$firma» en $ruta');

    final hasta = fuente.indexOf('@override', desde + firma.length);
    return fuente.substring(desde, hasta == -1 ? fuente.length : hasta);
  }

  test('la prueba no pasa por vacía: el archivo existe y tiene contenido', () {
    expect(fuente.length, greaterThan(500));
    expect(fuente, contains('class RepositorioMacrociclosFirestore'));
  });

  test('deNadador filtra por el nadador', () {
    expect(
      cuerpoDeNadador(),
      contains(".where('nadadorId', isEqualTo: nadadorId)"),
      reason: 'sin este filtro la consulta devolvería los de todos',
    );
  });

  test('deNadador filtra también por entregado', () {
    // **La mitad que faltaba.** Sin ella el servidor rechaza la consulta
    // entera y la nadadora no ve su camino.
    expect(
      cuerpoDeNadador(),
      contains("'estado', isEqualTo: EstadoPlan.publicado.name"),
      reason:
          'una consulta sin el filtro de estado no se puede demostrar contra '
          'la regla del nadador, y Firestore la rechaza entera',
    );
  });

  test('el estado filtrado sale del enum, no de un literal suelto', () {
    // Si alguien escribe `'publicado'` a mano y el día de mañana el enum
    // cambia de nombre, la consulta pide un estado que no existe y la
    // nadadora deja de ver nada **sin que falle nada**.
    expect(
      cuerpoDeNadador(),
      isNot(contains("'estado', isEqualTo: 'publicado'")),
      reason:
          'el estado tiene que venir del enum para que el compilador lo '
          'siga cuando cambie',
    );
  });
}
