/// Una fecha que no viene como texto **no puede tumbar la pantalla**.
///
/// Hallazgo del recorrido de la 010 en el Pixel 7, y el peor de los tres.
///
/// `EnvioAFirestore` escribe `recibidoEn` con `FieldValue.serverTimestamp()`,
/// así que el servidor lo guarda como `Timestamp`. `registroDesdeJson` lo leía
/// con `as String?`. Resultado: **todo registro que ha viajado al servidor y
/// vuelve es ilegible**, y la excepción sube por
/// `registrosDelLinaje` → `_loQueAnoto` sin que nadie la pare.
///
/// Lo que se veía: Ana marcaba su sesión, el registro llegaba a Firestore con
/// su esfuerzo y sus palabras, y su pantalla seguía diciendo «Sesiones
/// cumplidas: 0 de 39» y «Te quedaron 2 sesiones por marcar». Igual que el
/// defecto que la feature 009 arregló en esta misma pantalla, pero por otra
/// causa: entonces era que nadie releía, y ahora es que la lectura no termina.
///
/// Y no era solo suyo. El `Análisis` del entrenador lee por el mismo camino,
/// así que habría dejado de funcionar **en cuanto un nadador respondiera algo
/// de verdad**: con los registros de la siembra iba bien, porque la siembra
/// escribe texto y sin `recibidoEn`.
///
/// La app ya tenía este defecto nombrado, del revés, en
/// `molestias_firestore.dart`: «El `TypeError` de un `as Timestamp?` sobre
/// texto es lo que dejó los `Ajustes` de una nadadora girando para siempre en
/// la feature 007».
///
/// Así que la regla, dicha de una vez: **un campo con un tipo inesperado deja
/// un hueco, no tumba la lectura.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';

void main() {
  Map<String, dynamic> registro({Object? recibidoEn, Object? registradoEn}) =>
      <String, dynamic>{
        'id': 'n-ana|plan-1|s1|3.6.0',
        'nadadorId': 'n-ana',
        'planId': 'plan-1',
        'sesionId': 's1',
        'versionDePlan': '3.6.0',
        'realizada': true,
        'registradoEn': registradoEn ?? '2026-11-06T18:30:00.000',
        'rpePercibido': 7,
        'observaciones': 'Los ultimos 100 me costaron',
        'recibidoEn': ?recibidoEn,
      };

  test('texto ISO, que es como lo escribe el dispositivo', () {
    final leido = registroDesdeJson(
      registro(recibidoEn: '2026-11-06T18:30:05.000'),
    );

    expect(leido.recibidoEn, DateTime(2026, 11, 6, 18, 30, 5));
    expect(leido.rpePercibido, 7);
  });

  test('un DateTime, que es a lo que se normaliza lo del servidor', () {
    final leido = registroDesdeJson(
      registro(recibidoEn: DateTime(2026, 11, 6, 18, 30, 5)),
    );

    expect(leido.recibidoEn, DateTime(2026, 11, 6, 18, 30, 5));
  });

  test('algo que no es ninguna de las dos deja un hueco, no una excepción', () {
    // Aquí es donde estaba el defecto: un `Timestamp` entraba por este camino
    // y el `as String?` lo convertía en un TypeError que subía hasta la
    // pantalla. Lo que llega mal se queda en nulo y la lectura sigue.
    late final RegistroDeSesion leido;
    expect(
      () => leido = registroDesdeJson(registro(recibidoEn: 1762453805)),
      returnsNormally,
    );

    expect(leido.recibidoEn, isNull);
    expect(
      leido.rpePercibido,
      7,
      reason: 'lo demás del registro se lee: un campo raro no se lleva todo',
    );
  });

  test('registradoEn tampoco tumba nada, y cae en su respaldo', () {
    late final RegistroDeSesion leido;
    expect(
      () => leido = registroDesdeJson(registro(registradoEn: 1762453805)),
      returnsNormally,
    );

    expect(leido.registradoEn, DateTime(2026));
    expect(leido.observaciones, 'Los ultimos 100 me costaron');
  });

  test('sin recibidoEn sigue siendo nulo: todavía no ha viajado', () {
    expect(registroDesdeJson(registro()).recibidoEn, isNull);
  });
}
