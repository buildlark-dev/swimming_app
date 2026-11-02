import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/metodologia/validacion_fase.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

import '../auditoria/ayuda_planes.dart';

/// Prohibición de fase ATR en categorías que no la usan, y regla de
/// alternancia de Tecnificación (sección 11).
void main() {
  late ConstructorPlanes constructor;

  setUpAll(() {
    constructor = ConstructorPlanes();
  });

  Plan planTecnificacion({required List<Sesion> sesiones}) => Plan(
    nombre: 'Perfeccionamiento técnico',
    categoria: Categoria.tecnificacion,
    estiloObjetivo: Estilo.libre,
    microciclos: const [
      Microciclo(
        id: 'm1',
        nombre: 'Perfeccionamiento de pecho y mariposa',
        orden: 1,
        objetivo: 'Técnica',
      ),
    ],
    sesiones: sesiones,
  );

  group('admisibilidad de la fase ATR', () {
    test('Iniciación no admite fase ATR', () {
      final plan = Plan(
        nombre: 'Adaptación acuática',
        categoria: Categoria.iniciacion,
        estiloObjetivo: Estilo.libre,
        faseAtr: FaseAtr.acumulacion,
      );

      final resultado = const ValidacionFase().admiteFase(plan);

      expect(resultado.valida, isFalse);
      expect(resultado.motivo, contains('no usa el modelo ATR'));
    });

    test('Tecnificación tampoco', () {
      final plan = Plan(
        nombre: 'Perfeccionamiento',
        categoria: Categoria.tecnificacion,
        estiloObjetivo: Estilo.libre,
        faseAtr: FaseAtr.transformacion,
      );

      expect(const ValidacionFase().admiteFase(plan).valida, isFalse);
    });

    test('Precompetitivo sí admite fase ATR', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const ValidacionFase().admiteFase(plan).valida, isTrue);
    });

    test('una categoría sin ATR y sin fase es válida', () {
      final plan = Plan(
        nombre: 'Adaptación acuática',
        categoria: Categoria.iniciacion,
        estiloObjetivo: Estilo.libre,
      );

      expect(const ValidacionFase().admiteFase(plan).valida, isTrue);
    });
  });

  group('regla de alternancia de Tecnificación', () {
    Sesion sesionDeEstilo(Estilo estilo) =>
        constructor.sesionConZonas(const {Zona.a1: 900}, estilo: estilo);

    test('cumple con sesión 1 de Pecho y sesión 2 de Mariposa', () {
      final plan = planTecnificacion(
        sesiones: [
          sesionDeEstilo(Estilo.pecho),
          sesionDeEstilo(Estilo.mariposa),
        ],
      );

      final resultado = const ReglaAlternanciaTecnificacion().comprobar(plan);
      expect(resultado.valida, isTrue);
    });

    test('falla si la sesión 1 no es de Pecho', () {
      final plan = planTecnificacion(
        sesiones: [
          sesionDeEstilo(Estilo.libre),
          sesionDeEstilo(Estilo.mariposa),
        ],
      );

      final resultado = const ReglaAlternanciaTecnificacion().comprobar(plan);

      expect(resultado.valida, isFalse);
      expect(resultado.motivo, contains('se esperaba Pecho'));
    });

    test('falla si la sesión 2 no es de Mariposa', () {
      final plan = planTecnificacion(
        sesiones: [sesionDeEstilo(Estilo.pecho), sesionDeEstilo(Estilo.libre)],
      );

      final resultado = const ReglaAlternanciaTecnificacion().comprobar(plan);

      expect(resultado.valida, isFalse);
      expect(resultado.motivo, contains('se esperaba Mariposa'));
    });

    test('falla si el microciclo tiene menos sesiones de las que exige', () {
      final plan = planTecnificacion(sesiones: [sesionDeEstilo(Estilo.pecho)]);

      final resultado = const ReglaAlternanciaTecnificacion().comprobar(plan);

      expect(resultado.valida, isFalse);
      expect(resultado.motivo, contains('necesita 2'));
    });

    test('la regla no aplica a otras categorías', () {
      final plan = constructor.planAcumulacionCorrecto();
      final resultado = const ReglaAlternanciaTecnificacion().comprobar(plan);

      expect(
        resultado.valida,
        isTrue,
        reason: 'Precompetitivo no tiene alternancia obligatoria',
      );
    });

    test('solo Tecnificación tiene la regla', () {
      for (final categoria in Categoria.values) {
        expect(
          categoria.tieneAlternanciaObligatoria,
          categoria == Categoria.tecnificacion,
        );
      }
    });
  });
}
