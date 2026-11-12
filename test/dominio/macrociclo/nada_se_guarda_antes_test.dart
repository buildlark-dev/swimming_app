/// M10, FR-002, SC-010 — **nada existe antes de que el entrenador confirme.**
///
/// Este es el cerrojo que la feature 009 tiene que vigilar de verdad, y la
/// razón es que hoy se cumple por accidente: todavía no hay nada construido,
/// así que no hay nada que guardar. Eso es exactamente el peligro. La primera
/// vista previa cómoda que guarde un borrador «para no recalcularlo» lo rompe
/// **sin que nada falle**.
///
/// Por eso se comprueba **sobre los repositorios y no sobre la pantalla**. La
/// feature 008 lo aprendió dos veces: que una cosa no se enseñe no dice nada
/// sobre si existe. Una prueba de widget que mirase que no aparece un plan en
/// la lista seguiría pasando con el borrador guardado en Firestore.
///
/// Y tiene las dos mitades. La de «no hay nada» sola pasaría con una
/// implementación que no guardara nunca; la de «después sí hay» es la que le
/// da sentido.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/derivar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  final hoy = DateTime(2026, 11, 4);
  final competencia = hoy.add(const Duration(days: 98));

  Biblioteca biblioteca() => Biblioteca.desdeJson(
    jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  const ficha = Nadador(
    id: 'n-ana',
    nombre: 'Ana María Restrepo',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
  );

  late RepositorioPlanesMemoria planes;
  late RepositorioSesionesMemoria sesiones;
  late RepositorioMacrociclosMemoria macrociclos;

  setUp(() {
    // Conectados, como en la app: guardar un plan escribe sus sesiones, y se
    // leen del mismo sitio. Sin conectarlos, el repositorio de planes se crea
    // el suyo y esta prueba miraría un almacén vacío que nadie usa.
    sesiones = RepositorioSesionesMemoria();
    planes = RepositorioPlanesMemoria(sesiones: sesiones);
    macrociclos = RepositorioMacrociclosMemoria();
  });

  EsqueletoPropuesto proponer() => esqueletoParaMacrociclo(
    fechaDeCompetencia: competencia,
    hoy: hoy,
    categoria: Categoria.precompetitivo,
  );

  EstructuraConfirmada confirmar(EsqueletoPropuesto propuesto) =>
      EstructuraConfirmada(
        modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
        modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
        bloques: propuesto.bloques,
        confirmadaEn: hoy,
        diasPorSemana: const [1, 3, 5],
        duracionSesionMinutos: 90,
        longitudPiscina: 25,
      );

  MacrocicloDerivado derivar(EstructuraConfirmada estructura) {
    final resultado = derivarMacrociclo(
      estructura: estructura,
      ficha: ficha,
      biblioteca: biblioteca(),
      versionMetodologia: '3.6.0',
      nombre: 'Hacia el Departamental',
      fechaDeCompetencia: competencia,
    );
    if (resultado is DerivacionImposible) fail(resultado.enQueBloque);
    return resultado as MacrocicloDerivado;
  }

  Future<void> noHayNadaGuardado(String cuando) async {
    expect(
      await planes.listar(),
      isEmpty,
      reason: 'había planes guardados $cuando',
    );
    expect(
      macrociclos.cuantosHay,
      0,
      reason: 'había macrociclos guardados $cuando',
    );
    expect(
      await macrociclos.deNadador('n-ana'),
      isEmpty,
      reason: 'había macrociclos de ese nadador $cuando',
    );
  }

  group('antes de confirmar', () {
    test('al abrir, sin hacer nada, no hay nada', () async {
      await noHayNadaGuardado('al empezar');
    });

    test('proponer el esqueleto no guarda nada', () async {
      final propuesto = proponer();

      expect(propuesto.hayEsqueleto, isTrue);
      expect(propuesto.bloques, hasLength(3));
      await noHayNadaGuardado('después de proponer el esqueleto');
    });

    test('proponerlo diez veces tampoco: no se cachea en el almacén', () async {
      // Es la tentación concreta: «ya que lo calculé, lo guardo». Derivar un
      // macrociclo de catorce semanas son catorce llamadas al motor, así que
      // alguien querrá no repetirlas. Se repiten: son puras y rápidas.
      for (var i = 0; i < 10; i++) {
        proponer();
      }
      await noHayNadaGuardado('después de proponer diez veces');
    });

    test('**derivar tampoco guarda nada**', () async {
      // La mitad que menos se ve: la derivación produce el macrociclo entero,
      // cuarenta y dos sesiones incluidas, y no toca el almacenamiento. Lo que
      // devuelve vive en memoria hasta que alguien llame a `guardarElMacrociclo`.
      final derivado = derivar(confirmar(proponer()));

      expect(derivado.mesociclos, hasLength(3));
      expect(derivado.llamadasAlMotor, 14);
      await noHayNadaGuardado('después de derivar el macrociclo completo');
    });

    test('ni con una estructura que el entrenador editó', () async {
      final propuesto = proponer();
      final editada = EstructuraConfirmada(
        modeloDeLaPrueba: 'Otra cosa.',
        modeloDelNadador: 'Otra cosa más.',
        // Se queda con los dos últimos bloques, como si él hubiera recortado.
        bloques: [
          BloqueConfirmado(
            fase: propuesto.bloques[1].fase,
            desde: propuesto.bloques[1].desde,
            hasta: propuesto.bloques[1].hasta,
            porQue: propuesto.bloques[1].porQue,
          ),
          propuesto.bloques[2],
        ],
        confirmadaEn: hoy,
        diasPorSemana: const [1, 3, 5],
        duracionSesionMinutos: 90,
        longitudPiscina: 25,
      );

      derivar(editada);
      await noHayNadaGuardado('después de derivar una estructura editada');
    });
  });

  group('al confirmar, y no antes', () {
    test('se guardan el macrociclo, sus mesociclos y sus sesiones', () async {
      // **La otra mitad.** Sin esta, todo lo de arriba pasaría con un
      // `guardarElMacrociclo` que no hiciera nada.
      final derivado = derivar(confirmar(proponer()));
      await noHayNadaGuardado('justo antes de guardar');

      final guardado = await guardarElMacrociclo(
        derivado: derivado,
        planes: planes,

        macrociclos: macrociclos,
      );

      expect(macrociclos.cuantosHay, 1);
      expect(await planes.listar(), hasLength(3));
      expect(guardado.macrociclo.id, isNotNull);

      for (final mesociclo in guardado.mesociclos) {
        expect(
          await sesiones.obtenerDePlan(mesociclo.id!),
          isNotEmpty,
          reason: 'el mesociclo ${mesociclo.nombre} se guardó sin sus sesiones',
        );
      }
    });

    test('el macrociclo guardado apunta a sus mesociclos, en orden', () async {
      final guardado = await guardarElMacrociclo(
        derivado: derivar(confirmar(proponer())),
        planes: planes,

        macrociclos: macrociclos,
      );

      expect(guardado.macrociclo.mesociclos, [
        for (final m in guardado.mesociclos) m.id,
      ]);
    });

    test('y cada mesociclo sabe de qué macrociclo es', () async {
      // El viaje de vuelta. Sin él, los mesociclos quedarían guardados sin
      // `macrocicloId` y la pantalla del nadador no podría situarlos.
      final guardado = await guardarElMacrociclo(
        derivado: derivar(confirmar(proponer())),
        planes: planes,

        macrociclos: macrociclos,
      );

      for (final mesociclo in await planes.listar()) {
        expect(mesociclo.macrocicloId, guardado.macrociclo.id);
        expect(mesociclo.ordenEnElMacrociclo, isNotNull);
      }
    });

    test('todo nace en borrador: guardar no es firmar', () async {
      final guardado = await guardarElMacrociclo(
        derivado: derivar(confirmar(proponer())),
        planes: planes,

        macrociclos: macrociclos,
      );

      expect(guardado.macrociclo.estado, EstadoPlan.borrador);
      for (final mesociclo in await planes.listar()) {
        expect(mesociclo.estado, EstadoPlan.borrador);
      }
    });

    test('las sesiones guardadas tienen identificador', () async {
      // Es el identificador que los registros del nadador van a referenciar.
      // Si quedaran sin él, no habría a qué apuntar.
      final guardado = await guardarElMacrociclo(
        derivado: derivar(confirmar(proponer())),
        planes: planes,

        macrociclos: macrociclos,
      );

      for (final mesociclo in guardado.mesociclos) {
        for (final sesion in mesociclo.sesiones) {
          expect(sesion.id, isNotNull);
        }
      }
    });
  });
}

// --- Control negativo (T028) --------------------------------------------
//
// La pregunta que hay que contestar aquí no es «¿pasa la prueba?», es «¿esta
// prueba vería algo si lo hubiera?». Un `noHayNadaGuardado` que consultara mal
// el repositorio pasaría siempre, y el cerrojo sería decorativo.
//
// Hecho el 2026-11-04: se añadió una llamada a `guardarElMacrociclo` al
// principio de «derivar tampoco guarda nada», que es lo que haría una vista
// previa que cachea el borrador. La prueba se puso roja y dijo exactamente lo
// que había pasado:
//
//     había planes guardados después de derivar el macrociclo completo
//
// Después se quitó. El cerrojo ve el almacenamiento, y el mensaje señala el
// momento.
