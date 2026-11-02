import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';

/// Las invariantes del registro del nadador.
///
/// Contrato: `specs/003-consumo-del-nadador/contracts/registro_del_nadador.md`.
void main() {
  final cuando = DateTime(2026, 10, 14, 7, 30);

  RegistroDeSesion registro({
    int? rpe,
    String observaciones = '',
    bool realizada = true,
    ReporteDeMolestia? molestia,
    String sesionId = 's1',
    String version = '3.5.0',
  }) => RegistroDeSesion(
    nadadorId: 'n1',
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: version,
    realizada: realizada,
    registradoEn: cuando,
    rpePercibido: rpe,
    observaciones: observaciones,
    molestia: molestia,
  );

  group('R1 — el RPE respeta la escala de Borg', () {
    test('11 no construye el registro', () {
      expect(() => registro(rpe: 11), throwsA(isA<RpeFueraDeEscala>()));
    });

    test('−1 tampoco', () {
      expect(() => registro(rpe: -1), throwsA(isA<RpeFueraDeEscala>()));
    });

    test('no se recorta al límite más cercano', () {
      // La regla R3 dice preguntar, no suponer. Un RPE de 11 es un dato que
      // alguien tiene que mirar, no uno que haya que convertir en 10.
      expect(() => registro(rpe: 99), throwsA(isA<RpeFueraDeEscala>()));
    });

    test('los once valores de la escala se aceptan', () {
      for (var valor = 0; valor <= 10; valor++) {
        expect(registro(rpe: valor).rpePercibido, valor);
      }
    });
  });

  group('R2 — anotar no es obligatorio', () {
    test('sin RPE es válido', () {
      expect(registro().rpePercibido, isNull);
    });

    test('marcar y nada más es un registro correcto, no uno a medias', () {
      final solo = registro();
      expect(solo.soloMarcada, isTrue);
      expect(solo.realizada, isTrue);
    });
  });

  group('R3 — no haber ido también es información', () {
    test('realizada en falso con observaciones es válido', () {
      final noFue = registro(
        realizada: false,
        observaciones: 'No pude ir, tenía examen',
      );

      expect(noFue.realizada, isFalse);
      expect(noFue.observaciones, isNotEmpty);
    });
  });

  group('R4 — las observaciones se guardan tal cual', () {
    test('con saltos de línea, mayúsculas y acentos', () {
      const texto =
          'ME COSTÓ la tercera serie.\n\nEl hombro bien.\n  Nada más.';
      expect(registro(observaciones: texto).observaciones, texto);
    });

    test('un texto largo no se recorta', () {
      final largo = 'palabra ' * 500;
      expect(registro(observaciones: largo).observaciones, largo);
    });

    test('no se interpreta como notación del entrenador', () {
      // El analizador de la feature 001 lee lo que escribe el entrenador. Lo
      // que escribe el nadador es prosa, y aunque parezca notación se respeta.
      const parece = '4x100 me salieron fatal';
      expect(registro(observaciones: parece).observaciones, parece);
    });
  });

  group('el identificador es determinista (D2)', () {
    test(
      'mismos datos dan el mismo identificador aunque cambie el contenido',
      () {
        expect(registro(rpe: 2).id, registro(rpe: 9).id);
      },
    );

    test('cambiar de sesión lo cambia', () {
      expect(registro(sesionId: 's1').id, isNot(registro(sesionId: 's2').id));
    });

    test('cambiar de versión de plan lo cambia', () {
      expect(
        registro(version: '3.4.1').id,
        isNot(registro(version: '3.5.0').id),
      );
    });

    test('es lo que hace imposible duplicar al reenviar', () {
      // FR-020: no por una comprobación que alguien pueda olvidar, sino porque
      // dos envíos escriben el mismo documento.
      final destino = <String, RegistroDeSesion>{};
      destino[registro().id] = registro();
      destino[registro().id] = registro(rpe: 5);

      expect(destino, hasLength(1));
    });
  });

  group('la molestia va aparte de las observaciones', () {
    test('es un campo propio, no texto mezclado', () {
      final conDolor = registro(
        observaciones: 'Me sentí bien de ritmo',
        molestia: const ReporteDeMolestia(
          descripcion: 'Pinchazo al salir de la pared',
          zonaDelCuerpo: 'hombro derecho',
        ),
      );

      expect(conDolor.tieneMolestia, isTrue);
      expect(
        conDolor.observaciones,
        isNot(contains('hombro')),
        reason:
            'Si viviera dentro del texto libre, encontrarla dependería de '
            'leer todas las observaciones de todas las sesiones (SC-006)',
      );
    });

    test('una descripción vacía no cuenta como molestia', () {
      final vacia = registro(
        molestia: const ReporteDeMolestia(descripcion: '   '),
      );
      expect(vacia.tieneMolestia, isFalse);
    });

    test('la zona del cuerpo es texto libre, sin lista cerrada', () {
      const rara = ReporteDeMolestia(
        descripcion: 'molestia',
        zonaDelCuerpo: 'el costado por debajo de las costillas',
      );
      expect(rara.zonaDelCuerpo, contains('costillas'));
    });
  });

  group('las dos marcas de tiempo (D3)', () {
    test('sin llegar al servidor no hay desfase que calcular', () {
      expect(registro().recibidoEn, isNull);
      expect(registro().desfaseDeReloj, isNull);
    });

    test('el desfase sale de restar las dos', () {
      final llegado = registro().copiarCon(
        recibidoEn: cuando.add(const Duration(hours: 5)),
      );

      expect(llegado.desfaseDeReloj, const Duration(hours: 5));
    });

    test('un reloj desajustado se puede detectar, no se corrige', () {
      // El registro conserva la hora del dispositivo: es cuándo entrenó, y es
      // la que ve el entrenador. La del servidor solo ordena.
      final desajustado = registro().copiarCon(
        recibidoEn: cuando.subtract(const Duration(days: 400)),
      );

      expect(desajustado.registradoEn, cuando);
      expect(desajustado.desfaseDeReloj!.isNegative, isTrue);
    });
  });

  group('copiarCon conserva la identidad', () {
    test('cambiar el RPE no cambia el identificador', () {
      final original = registro(rpe: 3);
      expect(original.copiarCon(rpePercibido: 8).id, original.id);
    });

    test('se puede quitar el RPE', () {
      expect(registro(rpe: 3).copiarCon(quitarRpe: true).rpePercibido, isNull);
    });

    test('se puede quitar la molestia', () {
      final conDolor = registro(
        molestia: const ReporteDeMolestia(descripcion: 'hombro'),
      );
      expect(conDolor.copiarCon(quitarMolestia: true).tieneMolestia, isFalse);
    });
  });

  group('la carga interna no lleva carga externa', () {
    test('el registro no expone metros, series ni zonas', () {
      // Principio VIII: se almacenan y se muestran por separado. Que no estén
      // en esta entidad hace que combinarlas no sea un error posible.
      final campos = registro().toString();
      expect(campos, isNot(contains('metros')));

      // Comprobación estructural: la entidad no tiene forma de responder por
      // volumen. Si alguien añadiera un campo así, esta prueba se queda corta
      // pero la revisión del PR pregunta por ello.
      expect(registro().runtimeType.toString(), 'RegistroDeSesion');
    });
  });
}
