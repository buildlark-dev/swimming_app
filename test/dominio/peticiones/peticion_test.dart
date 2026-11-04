/// Los estados imposibles de `PeticionDePlan`, que no se pueden construir.
///
/// No son comprobaciones defensivas: cada una sostiene un requisito. Un
/// rechazo sin motivo deja al nadador sin saber por qué (FR-026); una petición
/// aprobada sin plan es una firma sobre nada.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';

void main() {
  final enviada = DateTime(2026, 11, 2, 7);
  final respondida = DateTime(2026, 11, 3, 9);

  RespuestasDePeticion respuestas() => RespuestasDePeticion(
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
    fechaDeCompetencia: DateTime(2026, 11, 26),
    diasDisponibles: [DateTime(2026, 11, 3), DateTime(2026, 11, 5)],
    duracionSesionMinutos: 90,
    longitudPiscina: 25,
  );

  PeticionDePlan petir({
    EstadoDePeticion estado = EstadoDePeticion.esperando,
    String? motivo,
    String? planId,
    DateTime? respondidaEn,
  }) => PeticionDePlan(
    nadadorId: 'n-ana',
    enviadaEn: enviada,
    respuestas: respuestas(),
    estado: estado,
    motivoDelRechazo: motivo,
    planId: planId,
    respondidaEn: respondidaEn,
  );

  group('una petición recién enviada', () {
    test('espera, sin motivo, sin plan y sin fecha de respuesta', () {
      final peticion = petir();

      expect(peticion.estado, EstadoDePeticion.esperando);
      expect(peticion.motivoDelRechazo, isNull);
      expect(peticion.planId, isNull);
      expect(peticion.respondidaEn, isNull);
      expect(peticion.estaAbierta, isTrue);
    });

    test('su identificador es el del nadador, y por eso no hay dos abiertas', () {
      expect(petir().id, 'n-ana');
    });
  });

  group('un rechazo sin motivo no se puede construir', () {
    test('con el motivo vacío, revienta', () {
      expect(
        () => petir(
          estado: EstadoDePeticion.rechazada,
          motivo: '',
          respondidaEn: respondida,
        ),
        throwsA(isA<RechazoSinMotivo>()),
      );
    });

    test('con el motivo en blanco, también', () {
      expect(
        () => petir(
          estado: EstadoDePeticion.rechazada,
          motivo: '   ',
          respondidaEn: respondida,
        ),
        throwsA(isA<RechazoSinMotivo>()),
      );
    });

    test('sin motivo, igual', () {
      expect(
        () => petir(
          estado: EstadoDePeticion.rechazada,
          respondidaEn: respondida,
        ),
        throwsA(isA<RechazoSinMotivo>()),
      );
    });

    test('**control negativo**: con motivo, se construye', () {
      final peticion = petir(
        estado: EstadoDePeticion.rechazada,
        motivo: 'Pediste cinco días y en Precompetitivo son tres.',
        respondidaEn: respondida,
      );

      expect(peticion.motivoDelRechazo, isNotEmpty);
      expect(peticion.estaAbierta, isFalse);
    });
  });

  group('aprobar sin plan sería firmar sobre nada', () {
    test('aprobada sin planId revienta', () {
      expect(
        () => petir(
          estado: EstadoDePeticion.aprobada,
          respondidaEn: respondida,
        ),
        throwsA(isA<AprobacionSinPlan>()),
      );
    });

    test('**control negativo**: con plan, se construye', () {
      final peticion = petir(
        estado: EstadoDePeticion.aprobada,
        planId: 'p-1',
        respondidaEn: respondida,
      );

      expect(peticion.planId, 'p-1');
      expect(peticion.estaAbierta, isFalse);
    });
  });

  group('lo que espera no puede llevar respuesta', () {
    test('esperando con motivo de rechazo revienta', () {
      expect(
        () => petir(motivo: 'algo'),
        throwsA(isA<PeticionIncoherente>()),
      );
    });

    test('esperando con fecha de respuesta revienta', () {
      expect(
        () => petir(respondidaEn: respondida),
        throwsA(isA<PeticionIncoherente>()),
      );
    });

    test('en revisión sigue abierta, y sin respuesta', () {
      final peticion = petir(estado: EstadoDePeticion.enRevision);

      expect(peticion.estaAbierta, isTrue);
      expect(peticion.respondidaEn, isNull);
    });
  });

  group('los cuatro estados se leen en español, sin jerga', () {
    test('cada uno tiene su frase, y ninguna promete fecha', () {
      for (final estado in EstadoDePeticion.values) {
        expect(estado.comoLoLeeElNadador.trim(), isNotEmpty);

        for (final promesa in ['mañana', 'en 24', 'en 48', 'pronto', 'horas']) {
          expect(
            estado.comoLoLeeElNadador.toLowerCase(),
            isNot(contains(promesa)),
            reason:
                'FR-027: no se le promete al nadador ninguna fecha de '
                'respuesta, y «$promesa» lo parece',
          );
        }
      }
    });

    test('solo dos estados cierran la petición', () {
      expect(
        EstadoDePeticion.values.where((e) => !e.estaAbierta),
        [EstadoDePeticion.aprobada, EstadoDePeticion.rechazada],
      );
    });
  });

  test('la ventana de molestias son cuatro semanas (T066)', () {
    // Criterio del entrenador, no de la metodología: cubre un microciclo más
    // el anterior. Está aquí para que cambiarla sea una edición y una prueba.
    expect(ventanaDeMolestias, const Duration(days: 28));
  });
}
