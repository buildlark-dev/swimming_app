/// Lo que cada uno puede hacerle a una solicitud, y lo que no.
///
/// **`aceptada` es una palabra del entrenador.** La copia de la nadadora puede
/// pasar a `retirada` y a ningún otro sitio. Se comprueba en el tipo y no en el
/// widget que dibuja el botón: un cerrojo en una pantalla es un cerrojo en una
/// puerta de tres, que es como la feature 009 lo aprendió y como la 010 lo
/// repitió.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/comunidad/solicitud_de_ingreso.dart';

void main() {
  final pedidaEn = DateTime(2026, 11, 19, 8);
  final resueltaEn = DateTime(2026, 11, 19, 20);

  SolicitudDeIngreso recienPedida() => SolicitudDeIngreso(
    nadadorId: 'n-ana',
    comunidadId: 'c-entrenador',
    pedidaEn: pedidaEn,
  );

  test('nace esperando, y sin fecha de resolución', () {
    final solicitud = recienPedida();

    expect(solicitud.estado, EstadoDeSolicitud.esperando);
    expect(solicitud.estado.estaEsperando, isTrue);
    expect(solicitud.resueltaEn, isNull);
  });

  test('el identificador es determinista', () {
    expect(recienPedida().id, 'n-ana|c-entrenador');
    expect(
      recienPedida().id,
      recienPedida().id,
      reason:
          'pedir dos veces es pedir lo mismo: un reintento sin señal no puede '
          'crear dos solicitudes',
    );
  });

  group('lo que ella puede', () {
    test('retirarla mientras espera', () {
      final retirada = recienPedida().retirada(resueltaEn);

      expect(retirada.estado, EstadoDeSolicitud.retirada);
      expect(retirada.resueltaEn, resueltaEn);
    });

    test('y no retirar una ya resuelta', () {
      final aceptada = recienPedida().aceptada(resueltaEn);

      expect(
        () => aceptada.retirada(resueltaEn),
        throwsA(isA<TransicionNoEsSuya>()),
      );
    });
  });

  group('lo que es de él', () {
    test('aceptar y rechazar, mientras espera', () {
      expect(
        recienPedida().aceptada(resueltaEn).estado,
        EstadoDeSolicitud.aceptada,
      );
      expect(
        recienPedida().rechazada(resueltaEn).estado,
        EstadoDeSolicitud.rechazada,
      );
    });

    test('y nunca resolver dos veces', () {
      final rechazada = recienPedida().rechazada(resueltaEn);

      expect(
        () => rechazada.aceptada(resueltaEn),
        throwsA(isA<TransicionNoEsSuya>()),
        reason:
            'resolver una que ya no espera no es una corrección: es dos '
            'decisiones sobre la misma persona, y la segunda llega sin que '
            'nadie sepa que hubo una primera',
      );
    });

    test('un rechazo no lleva motivo escrito', () {
      // El control negativo vive, otra vez, en lo que el tipo **no** tiene: no
      // hay dónde poner un texto. No se le debe una explicación a quien
      // todavía no es su nadadora, y un texto libre viajando hasta una
      // desconocida es un problema sin ninguna ventaja.
      final rechazada = recienPedida().rechazada(resueltaEn);
      expect(rechazada.toString(), isNot(contains('motivo')));
    });
  });

  test('las claves que se guardan son las que las reglas esperan', () {
    // Si esta lista cambia, cambia también en `firestore.rules` el mismo día.
    expect(EstadoDeSolicitud.esperando.clave, 'esperando');
    expect(EstadoDeSolicitud.aceptada.clave, 'aceptada');
    expect(EstadoDeSolicitud.rechazada.clave, 'rechazada');
    expect(EstadoDeSolicitud.retirada.clave, 'retirada');

    expect(EstadoDeSolicitud.porClave('esperando'), EstadoDeSolicitud.esperando);
    expect(EstadoDeSolicitud.porClave('inventada'), isNull);
    expect(EstadoDeSolicitud.porClave(null), isNull);
  });

  test('resuelta es lo contrario de esperando, sin terceras opciones', () {
    for (final estado in EstadoDeSolicitud.values) {
      expect(estado.estaResuelta, isNot(estado.estaEsperando));
    }
  });
}
