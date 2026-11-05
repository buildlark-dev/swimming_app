/// El cerrojo sobre `RepositorioPlanesFirestore`, leído en su fuente.
///
/// **Por qué sobre la fuente y no ejecutándolo.** `cloud_firestore` necesita
/// una app Flutter y canales de plataforma, así que una prueba `flutter test`
/// no puede hablar con el emulador: lo que corre contra él son las pruebas de
/// reglas, en JavaScript, y esas escriben documentos a mano en lugar de pasar
/// por este repositorio. Es el mismo recurso que la feature 008 usó para el
/// contrato con el servidor: leer la fuente cuando lo que se quiere fijar es
/// una propiedad del código.
///
/// Lo que vigila es el defecto concreto que la feature 009 encontró:
/// `planAJson` **no incluye las sesiones** —en Firestore cada una es un
/// documento de la subcolección—, así que guardar un plan guardaba el plan y
/// nada de lo que lleva dentro. Las escribía solo el editor, una a una. Un
/// plan generado por el motor y guardado por código llegaba sin ninguna.
///
/// El comportamiento está fijado en
/// `test/datos/el_plan_se_guarda_con_sus_sesiones_test.dart`, sobre la
/// interfaz. Esto comprueba que la implementación que no se puede ejecutar
/// aquí también lo cumple.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const ruta = 'lib/datos/firestore/repositorios_firestore.dart';

  late String fuente;

  setUpAll(() {
    fuente = File(ruta).readAsStringSync();
  });

  /// El cuerpo de un método, desde su firma hasta el cierre del `try`.
  String cuerpoDe(String firma) {
    final desde = fuente.indexOf(firma);
    expect(desde, greaterThan(-1), reason: 'no se encontró «$firma» en $ruta');

    // Hasta el siguiente `@override`, que es donde empieza el método que
    // sigue. Si alguien reordena el archivo esto se nota, y mejor así.
    final hasta = fuente.indexOf('@override', desde + firma.length);
    return fuente.substring(desde, hasta == -1 ? fuente.length : hasta);
  }

  test('la prueba no pasa por vacía: el archivo existe y tiene contenido', () {
    expect(fuente.length, greaterThan(1000));
    expect(fuente, contains('class RepositorioPlanesFirestore'));
  });

  // **Se busca la llamada, no el nombre.**
  //
  // La primera versión de estas dos pruebas buscaba `_guardarLasSesiones` en el
  // trozo de fuente del método, y el control negativo las dejó verdes al
  // quitar la llamada: el trozo incluye la **definición** del ayudante, que
  // también contiene ese nombre. La prueba encontraba la declaración y daba el
  // método por bueno.
  test('guardarBorrador escribe las sesiones del plan', () {
    expect(
      cuerpoDe('Future<String> guardarBorrador(Plan plan)'),
      contains('await _guardarLasSesiones(asignado, plan);'),
      reason:
          'guardar un borrador tiene que escribir sus sesiones: `planAJson` '
          'no las incluye, así que sin esto el plan se guarda vacío',
    );
  });

  test('guardarAprobado también', () {
    expect(
      cuerpoDe('Future<void> guardarAprobado('),
      contains('await _guardarLasSesiones(id, plan);'),
      reason:
          'lo firmado se guarda con lo que lleva dentro, o queda firmado un '
          'plan vacío',
    );
  });

  test('y lo hace a través del repositorio de sesiones', () {
    // No con una escritura propia a la subcolección: hay un sitio que sabe
    // cómo se guarda una sesión, y duplicarlo haría que las dos formas
    // pudieran discrepar.
    expect(
      fuente,
      contains('await _sesiones.guardar(planId, sesion)'),
      reason: 'las sesiones se escriben por `RepositorioSesiones`',
    );
  });

  test('el plan y sus sesiones se leen juntos', () {
    // La otra mitad: si `obtener` no pegara las sesiones de la subcolección,
    // escribirlas no serviría de nada.
    expect(
      cuerpoDe('Future<Plan?> obtener(String id)'),
      contains('_sesiones.obtenerDePlan(id)'),
    );
  });

  test('`planAJson` sigue sin incluir las sesiones por omisión', () {
    // Es la razón de todo lo anterior y conviene que se note si cambia: el
    // documento del plan **no** lleva las sesiones dentro, y por eso hay que
    // escribirlas aparte. Si algún día `planAJson` las incluyera, esta prueba
    // se pondría roja y habría que decidir de nuevo dónde viven.
    final serializacion = File(
      'lib/datos/serializacion.dart',
    ).readAsStringSync();

    expect(
      serializacion,
      contains("if (conSesiones) 'sesiones': plan.sesiones.map(sesionAJson)"),
      reason:
          'las sesiones solo entran en el JSON del plan cuando se piden '
          'explícitamente, y `guardarBorrador` no las pide',
    );
  });
}
