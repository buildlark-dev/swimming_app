import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/entidades/ciclo_vida_plan.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

import '../auditoria/ayuda_planes.dart';

/// FR-026 e invariante 14 de `data-model.md`.
///
/// El origen de un plan se fija al crearlo y **no cambia nunca**: ni al
/// editarlo, ni al aprobarlo, ni al crear una versión nueva. Perderlo borraría
/// la trazabilidad que el principio IV exige.
void main() {
  late ConstructorPlanes constructor;

  setUpAll(() {
    constructor = ConstructorPlanes();
  });

  group('valor por omisión', () {
    test('un plan nace manual si no se dice otra cosa', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(plan.origen, OrigenPlan.manual);
    });

    test('un plan puede nacer automático', () {
      final plan = constructor.comoGenerado(
        constructor.planAcumulacionCorrecto(),
      );
      expect(plan.origen, OrigenPlan.automatico);
    });
  });

  group('el origen no cambia al editar', () {
    test('copiarCon no permite cambiar un plan automático a manual', () {
      final generado = constructor.comoGenerado(
        constructor.planAcumulacionCorrecto(),
      );

      final editado = generado.copiarCon(nombre: 'Otro nombre');

      expect(
        editado.origen,
        OrigenPlan.automatico,
        reason: 'Editar un plan generado no lo convierte en manual',
      );
    });

    test('tampoco al revés', () {
      final manual = constructor.planAcumulacionCorrecto();
      final editado = manual.copiarCon(nombre: 'Otro nombre');

      expect(editado.origen, OrigenPlan.manual);
    });

    test('un intento explícito de cambiarlo se ignora', () {
      final generado = constructor.comoGenerado(
        constructor.planAcumulacionCorrecto(),
      );

      // copiarCon acepta el parámetro por uniformidad, pero no lo aplica:
      // el origen solo se fija al construir.
      final intento = generado.copiarCon(origen: OrigenPlan.manual);

      expect(
        intento.origen,
        OrigenPlan.automatico,
        reason: 'El origen se fija al crear el plan y ya no se toca',
      );
    });
  });

  group('el origen sobrevive al ciclo de vida', () {
    late CicloVidaPlan ciclo;

    setUp(() {
      ciclo = CicloVidaPlan(
        auditoria: Auditoria(),
        versionMetodologia: '3.4.1',
        ahora: () => DateTime(2026, 9, 29),
      );
    });

    test('un plan generado sigue siendo automático tras aprobarse', () {
      final generado = constructor.comoGenerado(
        constructor.planAcumulacionCorrecto(),
      );

      final resultado = ciclo.aprobar(generado);

      expect(resultado, isA<TransicionHecha>());
      expect((resultado as TransicionHecha).plan.origen, OrigenPlan.automatico);
    });

    test('sigue siendo automático tras publicarse', () {
      final generado = constructor.comoGenerado(
        constructor.planAcumulacionCorrecto(),
      );
      final aprobado = (ciclo.aprobar(generado) as TransicionHecha).plan;

      final publicado = ciclo.publicar(aprobado);

      expect((publicado as TransicionHecha).plan.origen, OrigenPlan.automatico);
    });

    test('una versión nueva hereda el origen del plan anterior', () {
      final generado = constructor.comoGenerado(
        constructor.planAcumulacionCorrecto(),
      );
      final aprobado = (ciclo.aprobar(generado) as TransicionHecha).plan;

      final nueva = ciclo.crearVersionDesde(aprobado);

      expect(
        nueva.origen,
        OrigenPlan.automatico,
        reason: 'Una versión nueva de un plan generado sigue siendo generada',
      );
    });

    test('una versión de un plan manual sigue siendo manual', () {
      final manual = constructor.planAcumulacionCorrecto();
      final aprobado = (ciclo.aprobar(manual) as TransicionHecha).plan;

      expect(ciclo.crearVersionDesde(aprobado).origen, OrigenPlan.manual);
    });
  });

  group('presentación', () {
    test('los dos orígenes tienen nombre legible', () {
      expect(OrigenPlan.manual.nombre, isNotEmpty);
      expect(OrigenPlan.automatico.nombre, isNotEmpty);
    });

    test('se distingue si fue generado', () {
      expect(OrigenPlan.automatico.fueGenerado, isTrue);
      expect(OrigenPlan.manual.fueGenerado, isFalse);
    });
  });
}
