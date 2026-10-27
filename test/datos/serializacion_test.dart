import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
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
