import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/exportacion.dart';
import 'package:natacion_app/dominio/biblioteca/propuestas.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

import '../dominio/auditoria/ayuda_planes.dart';

/// Exportación legible (principio V) y propuestas de ejercicio (FR-004).
void main() {
  late ConstructorPlanes constructor;

  setUpAll(() {
    constructor = ConstructorPlanes();
  });

  group('exportación de un plan', () {
    test('produce JSON válido y legible sin la app', () {
      final plan = constructor.planAcumulacionCorrecto();
      final documento = const Exportacion().plan(plan);
      final texto = const Exportacion().aTexto(documento);

      final recuperado = jsonDecode(texto) as Map<String, dynamic>;
      expect(recuperado['formato'], formatoExportacion);
      expect(recuperado['plan'], isA<Map<String, dynamic>>());
    });

    test('incluye las sesiones completas', () {
      final plan = constructor.planAcumulacionCorrecto();
      final documento = const Exportacion().plan(plan);

      final datosPlan = documento['plan'] as Map<String, dynamic>;
      expect(datosPlan['sesiones'], hasLength(3));
    });

    test('registra la versión de metodología cuando se conoce', () {
      final plan = constructor.planAcumulacionCorrecto();
      final documento =
          const Exportacion().plan(plan, versionMetodologia: '3.4');

      expect(documento['versionMetodologia'], '3.4');
    });
  });

  group('exportación de un nadador', () {
    test('incluye sus datos y sus planes', () {
      const nadador = Nadador(
        nombre: 'Nadador de prueba',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
      );
      final documento = const Exportacion().nadador(
        nadador,
        planes: [constructor.planAcumulacionCorrecto()],
      );

      expect(
        (documento['nadador'] as Map<String, dynamic>)['nombre'],
        'Nadador de prueba',
      );
      expect(documento['planes'], hasLength(1));
    });
  });

  group('minimización de datos (FR-032)', () {
    test('el documento exportado no lleva campos no declarados', () {
      const nadador = Nadador(
        nombre: 'Nadador de prueba',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
      );
      final datos = const Exportacion().nadador(nadador)['nadador']
          as Map<String, dynamic>;

      const declarados = {
        'nombre',
        'fechaNacimiento',
        'categoria',
        'estiloObjetivo',
        'pruebaObjetivo',
        'marcas',
        'diagnosticoTecnico',
      };

      for (final clave in datos.keys) {
        expect(
          declarados,
          contains(clave),
          reason: 'El campo "$clave" no está declarado en la feature. El '
              'principio V exige recolectar solo lo que tiene un uso '
              'declarado',
        );
      }
    });

    test('un plan exportado no incluye datos personales del nadador', () {
      final plan = constructor.planAcumulacionCorrecto();
      final texto = const Exportacion().aTexto(const Exportacion().plan(plan));

      // Desde la feature 004 un plan **no sabe de quién es**: la entrega es
      // una asignación, un documento aparte. Así que un plan exportado no
      // contiene identificadores de nadador en absoluto, que es todavía menos
      // de lo que el principio V pedía.
      expect(texto.contains('nadadoresIds'), isFalse);
      expect(texto.toLowerCase().contains('fechanacimiento'), isFalse);
      expect(texto.toLowerCase().contains('nadadorid'), isFalse);
    });
  });

  group('propuestas de ejercicio (FR-004)', () {
    test('una propuesta nunca puede usarse en un plan', () {
      final propuesta = PropuestaEjercicio(
        nombrePropuesto: 'PATADA EN DIAGONAL',
        descripcion: 'Descripción de prueba',
        estilo: Estilo.libre,
        motivo: 'No hay ejercicio para este error',
        fecha: DateTime(2026, 9, 25),
      );

      expect(propuesta.puedeUsarseEnUnPlan, isFalse);
    });

    test('se registra fuera del plan, en estado pendiente', () {
      final registro = RegistroPropuestas();
      final propuesta = registro.registrar(
        PropuestaEjercicio(
          nombrePropuesto: 'PATADA EN DIAGONAL',
          descripcion: 'Descripción de prueba',
          estilo: Estilo.libre,
          motivo: 'Vacío detectado',
          fecha: DateTime(2026, 9, 25),
        ),
      );

      expect(propuesta.estado, EstadoPropuesta.pendiente);
      expect(registro.pendientes, hasLength(1));
    });

    test('aprobarla no la mete en la Biblioteca, solo deja constancia', () {
      final registro = RegistroPropuestas();
      final propuesta = registro.registrar(
        PropuestaEjercicio(
          nombrePropuesto: 'PATADA EN DIAGONAL',
          descripcion: 'Descripción de prueba',
          estilo: Estilo.libre,
          motivo: 'Vacío detectado',
          fecha: DateTime(2026, 9, 25),
        ),
      );

      registro.marcar(propuesta.id!, EstadoPropuesta.aprobada);

      final aprobada = registro.todas.first;
      expect(aprobada.estado, EstadoPropuesta.aprobada);
      expect(
        aprobada.puedeUsarseEnUnPlan,
        isFalse,
        reason: 'Incorporarla exige editar el documento normativo y subir su '
            'versión, según el flujo de la constitución',
      );
    });
  });
}
