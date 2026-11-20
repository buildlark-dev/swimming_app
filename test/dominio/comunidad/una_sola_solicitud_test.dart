/// FR-008 — una nadadora tiene como mucho una solicitud esperando.
///
/// **Por qué no basta con que las pantallas no lo ofrezcan.**
///
/// Dos solicitudes esperando son dos entrenadores que pueden aceptar a la
/// misma persona. La pertenencia vive en un solo sitio (research D1), así que
/// la segunda aceptación o pisa a la primera o se rechaza, y en cualquiera de
/// los dos casos quién se queda con ella lo decide el orden de llegada. Nadie
/// habría elegido eso: sería el resultado de no haber elegido nada.
///
/// Pedir en otro sitio es **cambiar de idea**, no pedir dos veces.
///
/// La decisión vive en el dominio y no dentro del repositorio para poder
/// comprobarse sin levantar un servidor (principio II). El caso que de verdad
/// importa es el tercero.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/comunidad/solicitud_de_ingreso.dart';

void main() {
  SolicitudDeIngreso pedida(
    String comunidadId, {
    EstadoDeSolicitud estado = EstadoDeSolicitud.esperando,
  }) => SolicitudDeIngreso(
    nadadorId: 'n-ana',
    comunidadId: comunidadId,
    pedidaEn: DateTime(2026, 11, 17),
    estado: estado,
  );

  test('sin solicitud anterior no hay nada que retirar', () {
    expect(laQueHayQueRetirar(null, 'e-uno'), isNull);
  });

  test('pedir en otro sitio retira la de antes', () {
    final anterior = pedida('e-uno');

    final retirar = laQueHayQueRetirar(anterior, 'e-dos');

    expect(retirar, isNotNull);
    expect(retirar!.comunidadId, 'e-uno');
  });

  test('volver a pedir en el MISMO sitio no retira nada', () {
    // **Este es el caso que importa.** El identificador es determinista
    // —`nadadorId|comunidadId`—, así que volver a pedir en el mismo sitio
    // reescribe el mismo documento. Retirarlo primero lo dejaría en
    // «retirada» un instante, y lo que provoca ese instante es justo lo que
    // la feature 010 aprendió a temer: un reintento sin señal.
    expect(laQueHayQueRetirar(pedida('e-uno'), 'e-uno'), isNull);
  });

  test('una ya resuelta no ocupa sitio', () {
    // Aceptada, rechazada o retirada: ninguna espera, así que ninguna estorba.
    // Y que una rechazada no estorbe es FR-012 por el otro lado: un rechazo no
    // es una prohibición.
    for (final estado in [
      EstadoDeSolicitud.aceptada,
      EstadoDeSolicitud.rechazada,
      EstadoDeSolicitud.retirada,
    ]) {
      expect(
        laQueHayQueRetirar(pedida('e-uno', estado: estado), 'e-dos'),
        isNull,
        reason: 'una solicitud $estado no deberia hacer falta retirarla',
      );
    }
  });

  test('retirar la anterior no la borra: la deja en retirada', () {
    // La constancia de que alguien pidió entrar no se tira. Las reglas lo
    // dicen también —`allow delete: if false`— y esto lo dice en el dominio.
    final retirada = pedida('e-uno').retirada(DateTime(2026, 11, 19));

    expect(retirada.estado, EstadoDeSolicitud.retirada);
    expect(retirada.comunidadId, 'e-uno');
    expect(retirada.pedidaEn, DateTime(2026, 11, 17));
    expect(retirada.resueltaEn, DateTime(2026, 11, 19));
  });

  test('y una ya resuelta no se puede retirar', () {
    expect(
      () => pedida('e-uno', estado: EstadoDeSolicitud.aceptada)
          .retirada(DateTime(2026, 11, 19)),
      throwsA(isA<TransicionNoEsSuya>()),
    );
  });
}
