/// El cerrojo sobre `PeticionesFeedbackFirestore`, leído en su fuente.
///
/// **Por qué sobre la fuente y no ejecutándolo.** `cloud_firestore` necesita
/// una app Flutter y canales de plataforma, así que una prueba `flutter test`
/// no puede hablar con el emulador: lo que corre contra él son las pruebas de
/// reglas, en JavaScript, y esas escriben documentos a mano en lugar de pasar
/// por este repositorio. Es el mismo recurso que
/// `el_plan_firestore_guarda_sus_sesiones_test.dart`.
///
/// Lo que vigila es el defecto `75a765f` de la feature 009: **una consulta de
/// Firestore se demuestra por sus filtros**, no por los documentos que
/// devolvería. A la consulta de macrociclos le faltaba el filtro de estado, el
/// servidor la negaba entera, y la pantalla de la nadadora salía con «The
/// caller does not have permission». En memoria no se veía.
///
/// El comportamiento está fijado en
/// `test/datos/la_peticion_se_guarda_igual_test.dart`, sobre la interfaz. Esto
/// comprueba que la implementación que no se puede ejecutar aquí también lo
/// cumple.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const ruta = 'lib/datos/firestore/peticiones_feedback_firestore.dart';

  late String fuente;

  setUpAll(() {
    fuente = File(ruta).readAsStringSync();
  });

  /// El cuerpo de un método, desde su firma hasta el `@override` siguiente.
  String cuerpoDe(String firma) {
    final desde = fuente.indexOf(firma);
    expect(desde, greaterThan(-1), reason: 'no se encontró «$firma» en $ruta');

    final hasta = fuente.indexOf('@override', desde + firma.length);
    return fuente.substring(desde, hasta == -1 ? fuente.length : hasta);
  }

  test('la prueba no pasa por vacía: el archivo existe y tiene contenido', () {
    expect(fuente.length, greaterThan(1000));
    expect(fuente, contains('class PeticionesFeedbackFirestore'));
  });

  test('deNadadorEnPlan filtra por nadadorId Y por planId', () {
    final cuerpo = cuerpoDe(
      'Future<List<PeticionDeFeedback>> deNadadorEnPlan(',
    );

    expect(
      cuerpo,
      contains("where('nadadorId', isEqualTo: nadadorId)"),
      reason: 'sin este filtro la consulta pide las de todos y se rechaza',
    );
    expect(
      cuerpo,
      contains("where('planId', isEqualTo: planId)"),
      reason:
          'el segundo filtro no es redundante: la regla solo puede demostrar '
          'que la consulta pide lo permitido si la consulta lo dice',
    );
  });

  test('deNadador filtra por nadadorId', () {
    final cuerpo = cuerpoDe('Future<List<PeticionDeFeedback>> deNadador(');

    expect(cuerpo, contains("where('nadadorId', isEqualTo: nadadorId)"));
  });

  test('marcarVista actualiza un campo y no reescribe el documento', () {
    final cuerpo = cuerpoDe(
      'Future<void> marcarVista(String peticionId, DateTime cuando)',
    );

    // `update` con una sola clave. Un `set` reescribiría el documento entero
    // —incluida la pregunta del nadador— y la regla, que exige
    // `hasOnly(['vistaEn'])`, lo rechazaría. Es exactamente lo que le pasó a
    // la entrega de un plan en la feature 009.
    expect(cuerpo, contains('.update({'));
    expect(cuerpo, contains("'vistaEn'"));
    expect(
      cuerpo,
      isNot(contains('.set(')),
      reason: 'un set reescribe el documento entero y la regla lo rechaza',
    );
    expect(
      cuerpo,
      isNot(contains("'pregunta'")),
      reason: 'la única escritura del entrenador aquí es «la vi»',
    );
  });

  test('guardar usa el identificador determinista, no un documento nuevo', () {
    final cuerpo = cuerpoDe(
      'Future<void> guardar(PeticionDeFeedback peticion)',
    );

    expect(cuerpo, contains('.doc(peticion.id)'));
    expect(
      cuerpo,
      isNot(contains('.add(')),
      reason:
          'con un identificador automático, reenviar crearía una segunda '
          'petición sobre la misma sesión',
    );
  });

  test('la colección no se llama como las peticiones de plan', () {
    expect(fuente, contains("= 'peticionesDeFeedback'"));
    expect(
      fuente,
      isNot(contains("'peticionesDePlan'")),
      reason:
          'dos colecciones parecidas en la misma base es como se escribe una '
          'regla contra la equivocada, y aquí hay datos de un menor',
    );
  });
}
