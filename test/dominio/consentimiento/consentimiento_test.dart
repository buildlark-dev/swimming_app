import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';

/// Invariantes del consentimiento, de `data-model.md` y del contrato.
void main() {
  final cuando = DateTime.utc(2026, 10, 15, 10);

  const acudiente = Otorgante(
    nombre: 'María Gómez',
    documento: '43123456',
    calidad: 'madre',
  );

  Consentimiento consentimiento({
    Set<Alcance> alcances = const {Alcance.datosDeEntrenamiento},
    Otorgante otorgante = acudiente,
    bool menorFueOido = true,
    DateTime? revocadoEn,
  }) =>
      Consentimiento(
        nadadorId: 'n1',
        otorgadoPor: otorgante,
        otorgadoEn: cuando,
        alcances: alcances,
        versionDelTexto: 'v1',
        menorFueOido: menorFueOido,
        revocadoEn: revocadoEn,
      );

  group('un consentimiento tiene que amparar algo', () {
    test('sin alcances no se construye', () {
      expect(
        () => consentimiento(alcances: const {}),
        throwsA(isA<ConsentimientoSinAlcance>()),
        reason: 'Registrarlo daría por autorizado algo que nadie autorizó',
      );
    });
  });

  group('FR-021 — el menor tiene que haber sido oído', () {
    test('sin esa constancia no se construye', () {
      expect(
        () => consentimiento(menorFueOido: false),
        throwsA(isA<MenorNoOido>()),
      );
    });

    test('un mayor de edad que consiente por sí mismo no necesita oír a nadie', () {
      final propio = consentimiento(
        otorgante: const Otorgante.elPropioNadador(
          nombre: 'Juan Pérez',
          documento: '1020304050',
        ),
        menorFueOido: false,
      );

      expect(propio.vigente, isTrue);
      expect(propio.otorgadoPor.esElPropioNadador, isTrue);
    });
  });

  group('FR-023 — el alcance no se concede en bloque', () {
    test('cubrir entrenamiento no cubre video', () {
      final soloEntrenamiento = consentimiento();

      expect(soloEntrenamiento.cubre(Alcance.datosDeEntrenamiento), isTrue);
      expect(
        soloEntrenamiento.cubre(Alcance.video),
        isFalse,
        reason: 'El principio V exige que el consentimiento de video sea '
            'específico y separado. Si conceder uno concediera el otro, la '
            'familia habría autorizado algo que no leyó',
      );
    });

    test('se pueden cubrir los dos, y entonces cubre los dos', () {
      final ambos = consentimiento(
        alcances: {Alcance.datosDeEntrenamiento, Alcance.video},
      );

      expect(ambos.cubre(Alcance.datosDeEntrenamiento), isTrue);
      expect(ambos.cubre(Alcance.video), isTrue);
    });

    test('revocado no cubre nada, aunque los alcances sigan ahí', () {
      final revocado = consentimiento(
        alcances: {Alcance.datosDeEntrenamiento, Alcance.video},
        revocadoEn: cuando.add(const Duration(days: 30)),
      );

      expect(revocado.cubre(Alcance.datosDeEntrenamiento), isFalse);
      expect(revocado.cubre(Alcance.video), isFalse);
    });
  });

  group('vigencia', () {
    test('se deriva de la fecha de revocación, no es un campo', () {
      expect(consentimiento().vigente, isTrue);
      expect(consentimiento(revocadoEn: cuando).vigente, isFalse);
    });
  });

  group('C8 — revocar no borra el pasado', () {
    test('quién otorgó y cuándo sobreviven a la revocación', () {
      final despues = cuando.add(const Duration(days: 100));
      final revocado = consentimiento().revocar(despues);

      expect(revocado.vigente, isFalse);
      expect(revocado.revocadoEn, despues);
      expect(
        revocado.otorgadoEn,
        cuando,
        reason: 'Ese registro es la prueba de que el tratamiento anterior '
            'estuvo amparado. Borrarlo al revocar destruiría justamente la '
            'evidencia que protege al entrenador',
      );
      expect(revocado.otorgadoPor, acudiente);
    });

    test('el alcance y la versión del texto también se conservan', () {
      final revocado = consentimiento(
        alcances: {Alcance.datosDeEntrenamiento, Alcance.video},
      ).revocar(cuando);

      expect(revocado.alcances, hasLength(2));
      expect(revocado.versionDelTexto, 'v1');
    });
  });

  group('FR-018 — el texto informativo va versionado', () {
    test('cada consentimiento consta bajo la versión que su otorgante leyó', () {
      final viejo = Consentimiento(
        nadadorId: 'n1',
        otorgadoPor: acudiente,
        otorgadoEn: cuando,
        alcances: const {Alcance.datosDeEntrenamiento},
        versionDelTexto: 'v1',
        menorFueOido: true,
      );

      final nuevo = consentimiento();

      // Cambiar el texto no reescribe lo que alguien ya aceptó.
      expect(viejo.versionDelTexto, 'v1');
      expect(nuevo.versionDelTexto, 'v1');
    });
  });

  group('lo que el otorgante declara', () {
    test('un otorgante incompleto se detecta', () {
      const sinDocumento = Otorgante(
        nombre: 'María',
        documento: '  ',
        calidad: 'madre',
      );

      expect(sinDocumento.estaCompleto, isFalse);
      expect(acudiente.estaCompleto, isTrue);
    });

    test('la calidad es texto libre, sin lista cerrada', () {
      // Quién cuida a un niño no cabe en una lista de opciones.
      const abuela = Otorgante(
        nombre: 'Rosa',
        documento: '21000111',
        calidad: 'abuela, con custodia desde 2024',
      );

      expect(abuela.calidad, contains('custodia'));
      expect(abuela.estaCompleto, isTrue);
    });
  });

  group('los alcances se leen de su clave sin interpretarse', () {
    test('las claves son las que viajan al servidor', () {
      expect(Alcance.porClave('datosDeEntrenamiento'),
          Alcance.datosDeEntrenamiento);
      expect(Alcance.porClave('video'), Alcance.video);
    });

    test('cualquier otra cosa es null', () {
      for (final basura in ['videos', 'Video', 'todo', '']) {
        expect(Alcance.porClave(basura), isNull);
      }
    });
  });
}
