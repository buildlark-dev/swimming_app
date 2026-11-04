import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

import '../dominio/auditoria/ayuda_planes.dart';
import '../dominio/notacion/ayuda_pruebas.dart';

/// Ida y vuelta de la serialización, y exportación legible (principio V).
void main() {
  late ConstructorPlanes constructor;

  setUpAll(() {
    constructor = ConstructorPlanes();
  });

  group('ida y vuelta de un plan', () {
    test('conserva los metros', () {
      final plan = constructor.planAcumulacionCorrecto();
      final json = planAJson(plan, conSesiones: true);
      final recuperado = planDesdeJson(json, cargarBibliotecaReal());

      expect(recuperado.metros, plan.metros);
    });

    test('conserva el porcentaje técnico', () {
      final plan = constructor.planAcumulacionCorrecto();
      final json = planAJson(plan, conSesiones: true);
      final recuperado = planDesdeJson(json, cargarBibliotecaReal());

      expect(
        recuperado.porcentajeTecnico,
        closeTo(plan.porcentajeTecnico, 0.01),
      );
    });

    test('conserva categoría, estilo y fase', () {
      final plan = constructor.planAcumulacionCorrecto();
      final recuperado = planDesdeJson(
        planAJson(plan, conSesiones: true),
        cargarBibliotecaReal(),
      );

      expect(recuperado.categoria, plan.categoria);
      expect(recuperado.estiloObjetivo, plan.estiloObjetivo);
      expect(recuperado.faseAtr, plan.faseAtr);
    });

    test('conserva las zonas de cada serie', () {
      final plan = constructor.planAcumulacionCorrecto();
      final recuperado = planDesdeJson(
        planAJson(plan, conSesiones: true),
        cargarBibliotecaReal(),
      );

      final zonasOriginales = plan.sesiones.first.todasLasSeries
          .map((s) => s.zona)
          .toList();
      final zonasRecuperadas = recuperado.sesiones.first.todasLasSeries
          .map((s) => s.zona)
          .toList();

      expect(zonasRecuperadas, zonasOriginales);
    });

    test('conserva los ejercicios de la Biblioteca', () {
      final plan = constructor.planAcumulacionCorrecto();
      final recuperado = planDesdeJson(
        planAJson(plan, conSesiones: true),
        cargarBibliotecaReal(),
      );

      expect(recuperado.metrosTecnicos, plan.metrosTecnicos);
    });

    test('conserva el origen del plan', () {
      final generado = constructor.comoGenerado(
        constructor.planAcumulacionCorrecto(),
      );
      final recuperado = planDesdeJson(
        planAJson(generado, conSesiones: true),
        cargarBibliotecaReal(),
      );

      expect(
        recuperado.origen,
        OrigenPlan.automatico,
        reason: 'FR-026: la trazabilidad del origen sobrevive al guardado',
      );
    });

    test('un plan manual se recupera como manual', () {
      final recuperado = planDesdeJson(
        planAJson(constructor.planAcumulacionCorrecto(), conSesiones: true),
        cargarBibliotecaReal(),
      );

      expect(recuperado.origen, OrigenPlan.manual);
    });

    test('un documento sin origen se lee como manual', () {
      final json = planAJson(constructor.planAcumulacionCorrecto())
        ..remove('origen');

      expect(
        planDesdeJson(json, cargarBibliotecaReal()).origen,
        OrigenPlan.manual,
      );
    });

    test('no guarda los derivados: se recalculan', () {
      final plan = constructor.planAcumulacionCorrecto();
      final json = planAJson(plan, conSesiones: true);

      expect(json.containsKey('metros'), isFalse);
      expect(json.containsKey('porcentajeTecnico'), isFalse);
    });
  });

  group('exportación legible', () {
    test('un plan exportado es JSON válido', () async {
      final repositorio = RepositorioPlanesMemoria();
      final id = await repositorio.guardarBorrador(
        constructor.planAcumulacionCorrecto().copiarCon(id: null),
      );

      final exportado = await repositorio.exportar(id);
      final texto = jsonEncode(exportado);

      expect(texto, isNotEmpty);
      expect(jsonDecode(texto), isA<Map<String, dynamic>>());
    });

    test('el plan exportado incluye sus sesiones', () async {
      final repositorio = RepositorioPlanesMemoria();
      final plan = constructor.planAcumulacionCorrecto().copiarCon(id: null);
      final id = await repositorio.guardarBorrador(plan);

      final exportado = await repositorio.exportar(id);

      expect(exportado['sesiones'], isA<List<dynamic>>());
      expect((exportado['sesiones'] as List<dynamic>).length, 3);
    });

    test('un nadador exportado conserva sus datos', () async {
      final repositorio = RepositorioNadadoresMemoria();
      final id = await repositorio.guardar(
        const Nadador(
          nombre: 'Nadador de prueba',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '100 Libre',
        ),
      );

      final exportado = await repositorio.exportar(id);

      expect(exportado['nombre'], 'Nadador de prueba');
      expect(exportado['categoria'], 'Precompetitivo');
      expect(exportado['estiloObjetivo'], 'Libre');
    });
  });

  group('el repositorio protege la inmutabilidad', () {
    test('no deja sobrescribir un plan aprobado', () async {
      final repositorio = RepositorioPlanesMemoria();
      final aprobado = constructor.planAcumulacionCorrecto().copiarCon(
        estado: EstadoPlan.aprobado,
      );

      expect(
        () => repositorio.guardarBorrador(aprobado),
        throwsA(isA<FalloDeDatos>()),
      );
    });

    test('crear una versión exige que el original esté aprobado', () async {
      final repositorio = RepositorioPlanesMemoria();
      final id = await repositorio.guardarBorrador(
        constructor.planAcumulacionCorrecto().copiarCon(id: null),
      );

      expect(
        () => repositorio.crearVersionDesde(id),
        throwsA(isA<FalloDeDatos>()),
      );
    });

    test('la versión nueva apunta al plan aprobado', () async {
      final repositorio = RepositorioPlanesMemoria();
      final aprobado = constructor.planAcumulacionCorrecto().copiarCon(
        id: 'plan-aprobado',
        estado: EstadoPlan.aprobado,
      );
      await repositorio.guardarAprobado(aprobado, <String, dynamic>{});

      final nueva = await repositorio.crearVersionDesde('plan-aprobado');

      expect(nueva.estado, EstadoPlan.borrador);
      expect(nueva.versionAnteriorId, 'plan-aprobado');
      expect(nueva.metros, aprobado.metros);
    });
  });

  group('ida y vuelta del macrociclo (feature 009)', () {
    EstructuraConfirmada estructura() => EstructuraConfirmada(
      modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
      modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
      bloques: [
        BloqueConfirmado(
          fase: FaseAtr.acumulacion,
          desde: DateTime(2026, 11, 1),
          hasta: DateTime(2026, 11, 28),
          porQue: 'Acumulación, las primeras 4 semanas.',
        ),
        BloqueConfirmado(
          fase: FaseAtr.realizacion,
          desde: DateTime(2026, 11, 29),
          hasta: DateTime(2026, 12, 13),
          porQue: 'Realización, las últimas 2 semanas antes de competir.',
        ),
      ],
      confirmadaEn: DateTime(2026, 10, 31, 20, 15),
      diasPorSemana: const [1, 3, 5],
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    );

    Macrociclo macrociclo({EstructuraConfirmada? cual}) => Macrociclo(
      nadadorId: 'n-ana',
      nombre: 'Hacia el Departamental',
      estructura: cual ?? estructura(),
      mesociclos: const ['plan-a', 'plan-b'],
      fechaDeCompetencia: DateTime(2026, 12, 13),
      versionMetodologia: '3.6.0',
    );

    test('conserva la estructura que el entrenador confirmó', () {
      final recuperado = macrocicloDesdeJson(macrocicloAJson(macrociclo()));

      expect(recuperado.estructura.modeloDeLaPrueba, contains('umbral alto'));
      expect(recuperado.estructura.modeloDelNadador, contains('agarre'));
      expect(recuperado.estructura.bloques, hasLength(2));
      expect(recuperado.estructura.bloques.first.fase, FaseAtr.acumulacion);
      expect(recuperado.estructura.bloques.last.porQue, contains('2 semanas'));
    });

    test('conserva el orden de los mesociclos', () {
      final m = Macrociclo(
        nadadorId: 'n-ana',
        nombre: 'Hacia el Departamental',
        estructura: estructura(),
        mesociclos: const ['plan-z', 'plan-a', 'plan-m'],
        fechaDeCompetencia: DateTime(2026, 12, 13),
        versionMetodologia: '3.6.0',
      );

      expect(macrocicloDesdeJson(macrocicloAJson(m)).mesociclos, [
        'plan-z',
        'plan-a',
        'plan-m',
      ]);
    });

    test('un bloque sin fase vuelve sin fase', () {
      // M6: en Iniciación y Tecnificación la fase nula es la respuesta
      // correcta. Si la ida y vuelta le pusiera una, el motor rechazaría el
      // plan al regenerarlo y nadie sabría por qué.
      final sinFase = EstructuraConfirmada(
        modeloDeLaPrueba: 'Familiarización con el medio.',
        modeloDelNadador: 'Empieza ahora, flota bien.',
        bloques: [
          BloqueConfirmado(
            fase: null,
            desde: DateTime(2026, 11, 1),
            hasta: DateTime(2026, 12, 13),
            porQue: 'Sin fase: Iniciación no trabaja por fases ATR.',
          ),
        ],
        confirmadaEn: DateTime(2026, 10, 31, 20, 15),
        diasPorSemana: const [1, 3, 5],
        duracionSesionMinutos: 90,
        longitudPiscina: 25,
      );

      final recuperado = macrocicloDesdeJson(
        macrocicloAJson(macrociclo(cual: sinFase)),
      );
      expect(recuperado.estructura.bloques.single.fase, isNull);
    });

    test('la hora de la confirmación sobrevive, no solo el día', () {
      // Es el registro de un acto del entrenador. Guardar solo el día
      // perdería cuál de dos confirmaciones del mismo día fue.
      final recuperado = macrocicloDesdeJson(macrocicloAJson(macrociclo()));
      expect(recuperado.estructura.confirmadaEn, DateTime(2026, 10, 31, 20, 15));
    });

    test('las tres entradas del motor sobreviven', () {
      final recuperado = macrocicloDesdeJson(macrocicloAJson(macrociclo()));

      expect(recuperado.estructura.diasPorSemana, [1, 3, 5]);
      expect(recuperado.estructura.duracionSesionMinutos, 90);
      expect(recuperado.estructura.longitudPiscina, 25);
    });

    test('si faltan, falla en lugar de poner un 25 y un 90 por omisión', () {
      // Las puso el entrenador. Un valor por omisión al leer sería una
      // suposición nuestra con su firma encima, y el plan generado la
      // heredaría sin que nada avisara.
      for (final campo in [
        'diasPorSemana',
        'duracionSesionMinutos',
        'longitudPiscina',
      ]) {
        final json = macrocicloAJson(macrociclo());
        (json['estructura'] as Map<String, dynamic>).remove(campo);

        expect(
          () => macrocicloDesdeJson(json),
          throwsA(isA<EstructuraInvalida>()),
          reason: 'quitar $campo tendría que fallar',
        );
      }
    });

    test('un documento sin estructura falla con un mensaje legible', () {
      // **No vuelve a medias.** Un macrociclo sin la estructura confirmada no
      // se puede reconstruir, y derivarla aquí sería inventar lo que el
      // entrenador decidió.
      final json = macrocicloAJson(macrociclo())..remove('estructura');
      expect(
        () => macrocicloDesdeJson(json),
        throwsA(isA<MacrocicloInvalido>()),
      );
    });

    test('una fecha ilegible falla en lugar de inventar un día', () {
      // Con un `DateTime(2026)` por defecto, el bloque caería en una fecha
      // falsa y pasaría las invariantes. Esto es lo que la feature 008
      // aprendió con el `as Timestamp?` sobre un String, salvo que aquí el
      // fallo se nombra en lugar de dejar la pantalla girando.
      final json = macrocicloAJson(macrociclo());
      (json['estructura'] as Map<String, dynamic>)['confirmadaEn'] = 'ayer';
      expect(
        () => macrocicloDesdeJson(json),
        throwsA(isA<EstructuraInvalida>()),
      );
    });
  });

  group('el plan guarda de qué macrociclo es mesociclo', () {
    test('ida y vuelta de los dos campos nuevos', () {
      final mesociclo = constructor.planAcumulacionCorrecto().copiarCon(
        macrocicloId: 'macro-1',
        ordenEnElMacrociclo: 2,
      );

      final recuperado = planDesdeJson(
        planAJson(mesociclo, conSesiones: true),
        cargarBibliotecaReal(),
      );

      expect(recuperado.macrocicloId, 'macro-1');
      expect(recuperado.ordenEnElMacrociclo, 2);
    });

    test('un plan suelto vuelve suelto, y el orden vuelve nulo y no cero', () {
      // **Cero es una posición y nulo es «no pertenece a ninguno».** Si el
      // orden ausente volviera como 0, un plan suelto quedaría en cabeza de
      // una preparación a la que no pertenece.
      final recuperado = planDesdeJson(
        planAJson(constructor.planAcumulacionCorrecto()),
        cargarBibliotecaReal(),
      );

      expect(recuperado.macrocicloId, isNull);
      expect(recuperado.ordenEnElMacrociclo, isNull);
    });

    test('el orden cero sí se guarda cuando es de verdad el primero', () {
      // El control de que la prueba de arriba no pasa porque el cero se
      // tire siempre.
      final primero = constructor.planAcumulacionCorrecto().copiarCon(
        macrocicloId: 'macro-1',
        ordenEnElMacrociclo: 0,
      );

      expect(
        planDesdeJson(
          planAJson(primero),
          cargarBibliotecaReal(),
        ).ordenEnElMacrociclo,
        0,
      );
    });
  });

  group('repositorio de sesiones', () {
    test('guarda y recupera las sesiones de un plan', () async {
      final repositorio = RepositorioSesionesMemoria();
      final sesion = constructor.sesionModelo();

      await repositorio.guardar('plan-1', sesion);
      await repositorio.guardar('plan-1', sesion);

      final recuperadas = await repositorio.obtenerDePlan('plan-1');
      expect(recuperadas, hasLength(2));
      expect(recuperadas.first.metros, sesion.metros);
    });

    test('las sesiones de otro plan no se mezclan', () async {
      final repositorio = RepositorioSesionesMemoria();
      await repositorio.guardar('plan-1', constructor.sesionModelo());

      expect(await repositorio.obtenerDePlan('plan-2'), isEmpty);
    });
  });
}
