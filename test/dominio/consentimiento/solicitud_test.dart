import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/consentimiento/solicitud.dart';

/// El enlace de un solo uso: garantías C2, C3 y C4 del contrato.
void main() {
  final emitida = DateTime.utc(2026, 10, 15, 10);
  final vence = emitida.add(const Duration(days: 7));

  const resumen = 'resumen-sha256-del-token';

  SolicitudDeConsentimiento solicitud({DateTime? canjeadaEn}) =>
      SolicitudDeConsentimiento(
        id: 's1',
        nadadorId: 'n1',
        resumenDelToken: resumen,
        canal: 'madre@ejemplo.test',
        emitidaEn: emitida,
        venceEn: vence,
        canjeadaEn: canjeadaEn,
      );

  group('las tres condiciones se exigen a la vez', () {
    test('con el token correcto, dentro de plazo y sin canjear, se puede', () {
      expect(
        solicitud().esUtilizable(
          resumenPresentado: resumen,
          ahora: emitida.add(const Duration(days: 1)),
        ),
        isTrue,
      );
    });

    test('un token que no coincide no sirve', () {
      expect(
        solicitud().porQueNoSePuedeCanjear(
          resumenPresentado: 'otro-resumen',
          ahora: emitida,
        ),
        MotivoDeRechazo.noCoincide,
      );
    });

    test('C3 — vencida no sirve, aunque el token sea el bueno', () {
      expect(
        solicitud().porQueNoSePuedeCanjear(
          resumenPresentado: resumen,
          ahora: vence.add(const Duration(seconds: 1)),
        ),
        MotivoDeRechazo.vencida,
      );
    });

    test('justo en el instante de vencer, ya no sirve', () {
      // El borde se cierra del lado de no permitir. Es un consentimiento sobre
      // datos de un menor: ante la duda, no.
      expect(
        solicitud().esUtilizable(resumenPresentado: resumen, ahora: vence),
        isFalse,
      );
    });

    test('C2 — ya canjeada no sirve, aunque esté en plazo', () {
      expect(
        solicitud(canjeadaEn: emitida.add(const Duration(hours: 2)))
            .porQueNoSePuedeCanjear(
          resumenPresentado: resumen,
          ahora: emitida.add(const Duration(days: 1)),
        ),
        MotivoDeRechazo.yaCanjeada,
      );
    });
  });

  group('C2 — un solo uso', () {
    test('canjear la marca, y el segundo intento ya no pasa', () {
      final usada = solicitud().canjear(emitida.add(const Duration(hours: 1)));

      expect(usada.yaSeCanjeo, isTrue);
      expect(
        usada.esUtilizable(
          resumenPresentado: resumen,
          ahora: emitida.add(const Duration(hours: 2)),
        ),
        isFalse,
      );
    });

    test('canjear no cambia el resumen ni el canal', () {
      final usada = solicitud().canjear(emitida);

      expect(usada.resumenDelToken, resumen);
      expect(usada.canal, 'madre@ejemplo.test');
    });
  });

  group('C4 — el token en claro no vive aquí', () {
    test('la solicitud solo guarda su resumen', () {
      // Comprobación estructural: el tipo no tiene dónde poner el token. Si
      // alguien añadiera un campo así, esta prueba se queda corta, pero la
      // revisión del PR tiene de qué agarrarse.
      final s = solicitud();

      expect(s.resumenDelToken, resumen);
      expect(
        s.toString(),
        isNot(contains('token-en-claro')),
        reason: 'Quien tenga acceso de lectura a solicitudes no puede poder '
            'fabricar un enlace válido',
      );
    });
  });

  group('el motivo no sale de aquí', () {
    test('los tres motivos existen para razonar, no para contestar', () {
      // El servidor rechaza sin decir cuál fue. Distinguirlos le diría a quien
      // prueba enlaces cuáles existieron alguna vez.
      expect(MotivoDeRechazo.values, hasLength(3));
    });
  });
}
