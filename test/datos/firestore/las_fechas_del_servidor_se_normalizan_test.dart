/// El cerrojo sobre `RegistrosFirestore`, leído en su fuente.
///
/// `cloud_firestore` necesita canales de plataforma, así que esto no se puede
/// ejecutar bajo `flutter test`: lo que corre contra el emulador son las
/// pruebas de reglas, en JavaScript, y esas escriben documentos a mano. Es el
/// mismo recurso que `el_plan_firestore_guarda_sus_sesiones_test.dart`.
///
/// Lo que vigila es el defecto que el recorrido de la 010 encontró en el
/// Pixel 7: `recibidoEn` vuelve del servidor como `Timestamp` —lo escribe
/// `FieldValue.serverTimestamp()`— y se leía con `as String?`. **Todo registro
/// que había viajado se volvía ilegible**, y el `TypeError` subía hasta la
/// pantalla.
///
/// El comportamiento tolerante está fijado en
/// `test/datos/una_fecha_del_servidor_no_rompe_la_pantalla_test.dart`, sobre la
/// serialización. Esto comprueba la otra mitad: que **quien sabe de
/// `Timestamp` es este archivo**, y que normaliza antes de deserializar para
/// que la hora del servidor no se pierda.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const ruta = 'lib/datos/firestore/registros_firestore.dart';

  late String fuente;

  setUpAll(() {
    fuente = File(ruta).readAsStringSync();
  });

  test('la prueba no pasa por vacía', () {
    expect(fuente.length, greaterThan(1000));
    expect(fuente, contains('class RegistrosFirestore'));
  });

  test('las dos lecturas normalizan las fechas antes de deserializar', () {
    // **Se busca la llamada, no el nombre.** La primera versión de la prueba
    // equivalente en la feature 009 buscaba el nombre del ayudante y el
    // control negativo la dejó verde, porque el trozo de fuente incluía su
    // definición. Así que se cuentan las llamadas.
    final llamadas = RegExp(
      r'registroDesdeJson\(_conFechasLegibles\(',
    ).allMatches(fuente).length;

    expect(
      llamadas,
      2,
      reason:
          'obtener y obtenerDePlan son los dos caminos por los que un registro '
          'del servidor entra en la app',
    );

    expect(
      RegExp(r'registroDesdeJson\(d\.data\(\)\)').hasMatch(fuente),
      isFalse,
      reason:
          'deserializar el documento crudo es exactamente lo que rompía: '
          '`recibidoEn` llega como Timestamp',
    );
  });

  test('conoce las tres formas de una fecha, y no adivina la cuarta', () {
    expect(fuente, contains('final Timestamp marca => marca.toDate()'));
    expect(fuente, contains('final DateTime fecha => fecha'));
    expect(fuente, contains('final String texto => DateTime.tryParse(texto)'));
    expect(
      fuente,
      contains('normalizado.remove(campo)'),
      reason:
          'lo que no se entiende se quita, y el respaldo lo decide la '
          'serialización: una fecha inventada aquí sería peor que un hueco',
    );
  });

  test('un documento que no se entiende se reporta como FalloDeDatos', () {
    expect(
      fuente,
      contains('No se pudo entender un registro guardado'),
      reason:
          'los errores se expresan en términos del dominio, no como '
          'excepciones de la librería de datos (contrato de repositorios.dart)',
    );
  });

  test('la serialización no sabe de Firestore', () {
    final serializacion = File(
      'lib/datos/serializacion.dart',
    ).readAsStringSync();

    expect(
      serializacion.contains('cloud_firestore'),
      isFalse,
      reason:
          'la usan el almacén del dispositivo y las pruebas; quien sabe de '
          'Timestamp es el archivo de Firestore',
    );
    expect(serializacion, contains('DateTime? fechaDeJson(Object? valor)'));
  });
}
