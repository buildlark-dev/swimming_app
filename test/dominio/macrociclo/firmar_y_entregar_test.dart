/// M13, M14, M15, M16, M17 — firmar el macrociclo y entregarlo.
///
/// Tres cosas que esta feature no puede estropear y una que no puede inventar:
///
/// - **La auditoría es la misma.** Un mesociclo pasa la sección 16 como
///   cualquier otro plan, no una versión ligera por venir de un macrociclo.
/// - **Firmar es un acto**, por muchos mesociclos que haya (M15). Si el
///   entrenador tuviera que firmar siete veces, la enmienda de la constitución
///   v2.0.0 se habría cumplido en la letra y no en el fondo.
/// - **Entregar es todo o nada** (M16). Un nadador viendo cuatro de siete
///   mesociclos es peor que viendo ninguno: no sabe que le faltan tres.
/// - **Firmar no es entregar** (M17), aquí como desde la feature 001.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/derivar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Un repositorio de asignaciones que falla en la enésima entrega.
///
/// **Falla como falla el de verdad**: deja hechas las anteriores. Un doble que
/// no guardara ninguna haría pasar la prueba de «todo o nada» sin que hubiera
/// nada que deshacer, que es la clase de doble cómodo que la feature 008
/// aprendió a desconfiar.
class _AsignacionesQueFallanEnLa extends RepositorioAsignacionesMemoria {
  _AsignacionesQueFallanEnLa(this.cual);

  final int cual;
  int _hechas = 0;

  @override
  Future<void> asignar(Asignacion asignacion) async {
    _hechas++;
    if (_hechas == cual) {
      throw const FalloDeDatos('se cayó la red a mitad de la entrega');
    }
    await super.asignar(asignacion);
  }
}

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
  late RepositorioAsignacionesMemoria asignaciones;

  setUp(() {
    planes = RepositorioPlanesMemoria();
    sesiones = RepositorioSesionesMemoria();
    macrociclos = RepositorioMacrociclosMemoria();
    asignaciones = RepositorioAsignacionesMemoria();
  });

  EstructuraConfirmada estructura() {
    final propuesto = esqueletoParaMacrociclo(
      fechaDeCompetencia: competencia,
      hoy: hoy,
      categoria: Categoria.precompetitivo,
    );
    return EstructuraConfirmada(
      modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
      modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
      bloques: propuesto.bloques,
      confirmadaEn: hoy,
      diasPorSemana: const [1, 3, 5],
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    );
  }

  Future<MacrocicloGuardado> guardado() async {
    final resultado = derivarMacrociclo(
      estructura: estructura(),
      ficha: ficha,
      biblioteca: biblioteca(),
      versionMetodologia: '3.6.0',
      nombre: 'Hacia el Departamental',
      fechaDeCompetencia: competencia,
    );
    if (resultado is DerivacionImposible) fail(resultado.enQueBloque);

    return guardarElMacrociclo(
      derivado: resultado as MacrocicloDerivado,
      planes: planes,
      sesiones: sesiones,
      macrociclos: macrociclos,
    );
  }

  group('la revisión antes de firmar (M13, M14)', () {
    test('audita cada mesociclo con la auditoría de siempre', () async {
      final macro = await guardado();
      final revision = revisarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos,
      );

      expect(revision.porMesociclo, hasLength(3));
      for (final auditado in revision.porMesociclo) {
        expect(
          auditado.criterios,
          isNotEmpty,
          reason: 'un mesociclo se revisó sin criterios: eso no es auditar',
        );
      }
    });

    test('un macrociclo derivado por el motor pasa la auditoría', () async {
      // Lo mismo que el principio III pide de cualquier salida automática:
      // que cumpla **por construcción** y no por casualidad.
      final macro = await guardado();
      final revision = revisarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos,
      );

      expect(
        revision.sePuedeFirmar,
        isTrue,
        reason: revision.porMesociclo
            .expand((r) => r.criterios.where((c) => !c.cumple))
            .map((c) => c.id)
            .join(', '),
      );
    });

    test('un mesociclo que falta impide firmar, no pasa en vacío', () async {
      // M14 por la puerta de atrás: si la lista de mesociclos llega
      // incompleta, comprobar «los que hay están bien» daría verde.
      final macro = await guardado();
      final revision = revisarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos.take(2).toList(),
      );

      expect(revision.sePuedeFirmar, isFalse);
      expect(revision.impedimentos, hasLength(1));
    });
  });

  group('firmar es un acto (M15)', () {
    test('una llamada firma el macrociclo y sus tres mesociclos', () async {
      final macro = await guardado();

      final firmado = await firmarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos,
        planes: planes,
        macrociclos: macrociclos,
        hoy: hoy,
      );

      expect(firmado.estado, EstadoPlan.aprobado);
      for (final mesociclo in await planes.listar()) {
        expect(mesociclo.estado, EstadoPlan.aprobado);
        expect(mesociclo.fechaAprobacion, hoy);
      }
    });

    test('la firma guarda la instantánea de auditoría de cada uno', () async {
      // Es parte de lo que se firmó, no un informe aparte: la feature 001 la
      // guarda con el plan y aquí no cambia.
      final macro = await guardado();
      await firmarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos,
        planes: planes,
        macrociclos: macrociclos,
        hoy: hoy,
      );

      for (final mesociclo in macro.mesociclos) {
        expect(planes.auditoriaDe(mesociclo.id!), isNotNull);
      }
      expect(macrociclos.auditoriaDe(macro.macrociclo.id!), isNotNull);
    });

    test('con un mesociclo que no pasa, no se firma ninguno', () async {
      // Medio firmado no es un estado, es una avería. El mesociclo roto lleva
      // una sesión sin series, que es lo que la auditoría rechaza.
      final macro = await guardado();
      final roto = macro.mesociclos.first.copiarCon(
        sesiones: const [],
        microciclos: macro.mesociclos.first.microciclos,
      );

      await expectLater(
        firmarElMacrociclo(
          macrociclo: macro.macrociclo,
          mesociclos: [roto, ...macro.mesociclos.skip(1)],
          planes: planes,
          macrociclos: macrociclos,
          hoy: hoy,
        ),
        throwsA(isA<FalloDeDatos>()),
      );

      for (final mesociclo in await planes.listar()) {
        expect(
          mesociclo.estado,
          EstadoPlan.borrador,
          reason: 'se firmó un mesociclo mientras otro no pasaba',
        );
      }
    });
  });

  group('firmar no es entregar (M17)', () {
    test('un macrociclo firmado no le ha llegado al nadador', () async {
      final macro = await guardado();
      await firmarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos,
        planes: planes,
        macrociclos: macrociclos,
        hoy: hoy,
      );

      expect(await asignaciones.deNadador('n-ana'), isEmpty);
    });

    test('entregar un macrociclo sin firmar no se puede', () async {
      final macro = await guardado();

      await expectLater(
        entregarElMacrociclo(
          macrociclo: macro.macrociclo,
          mesociclos: macro.mesociclos,
          planes: planes,
          asignaciones: asignaciones,
          macrociclos: macrociclos,
          hoy: hoy,
        ),
        throwsA(isA<FalloDeDatos>()),
      );
    });
  });

  group('la entrega es todo o nada (M16)', () {
    Future<MacrocicloGuardado> firmado() async {
      final macro = await guardado();
      final firmado = await firmarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos,
        planes: planes,
        macrociclos: macrociclos,
        hoy: hoy,
      );
      return MacrocicloGuardado(
        macrociclo: firmado,
        mesociclos: [
          for (final m in macro.mesociclos)
            m.copiarCon(estado: EstadoPlan.aprobado),
        ],
      );
    }

    test('entregar asigna los tres mesociclos al nadador', () async {
      final macro = await firmado();

      final entregado = await entregarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos,
        planes: planes,
        asignaciones: asignaciones,
        macrociclos: macrociclos,
        hoy: hoy,
      );

      expect(entregado.estado, EstadoPlan.publicado);
      expect(await asignaciones.deNadador('n-ana'), hasLength(3));
      for (final mesociclo in await planes.listar()) {
        expect(mesociclo.estado, EstadoPlan.publicado);
      }
    });

    test('si falla la tercera, el nadador no se queda con dos', () async {
      // **Esta es la que importa.** Dos de tres entregados es la situación que
      // M16 describe como peor que ninguno, y se produce sola en cuanto la red
      // se corta a mitad de un bucle.
      final macro = await firmado();
      final queFallan = _AsignacionesQueFallanEnLa(3);

      await expectLater(
        entregarElMacrociclo(
          macrociclo: macro.macrociclo,
          mesociclos: macro.mesociclos,
          planes: planes,
          asignaciones: queFallan,
          macrociclos: macrociclos,
          hoy: hoy,
        ),
        throwsA(isA<FalloDeDatos>()),
      );

      expect(
        await queFallan.deNadador('n-ana'),
        isEmpty,
        reason: 'quedaron mesociclos entregados de una entrega que falló',
      );
    });

    test('y el macrociclo no queda como entregado', () async {
      final macro = await firmado();

      await expectLater(
        entregarElMacrociclo(
          macrociclo: macro.macrociclo,
          mesociclos: macro.mesociclos,
          planes: planes,
          asignaciones: _AsignacionesQueFallanEnLa(2),
          macrociclos: macrociclos,
          hoy: hoy,
        ),
        throwsA(isA<FalloDeDatos>()),
      );

      final enElAlmacen = await macrociclos.obtener(macro.macrociclo.id!);
      expect(enElAlmacen!.estado, isNot(EstadoPlan.publicado));
    });
  });
}
