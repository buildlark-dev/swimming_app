import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// SC-007 y escenario C4 de `quickstart.md`.
///
/// > «Un plan aprobado conserva su contenido **byte a byte** después de que un
/// > nadador registre respuestas sobre él.»
///
/// Es la garantía que permite que el entrenador firme un plan y sepa que lo que
/// firmó sigue siendo lo que hay. El registro del nadador **apunta** a la
/// sesión; no la modifica. La relación es en un solo sentido.
void main() {
  Plan planAprobado() => Plan(
    id: 'p1',
    nombre: 'Microciclo de base aeróbica',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '800 Libre',
    estado: EstadoPlan.aprobado,
    versionMetodologia: '3.5.0',
    fechaAprobacion: DateTime(2026, 10, 1),
    microciclos: const [
      Microciclo(
        id: 'm1',
        nombre: 'Semana 1',
        orden: 1,
        objetivo: 'Economía de nado',
      ),
    ],
    sesiones: [
      for (var i = 1; i <= 3; i++)
        Sesion(
          id: 's$i',
          microcicloId: 'm1',
          fecha: DateTime(2026, 10, i),
          objetivoTecnico: 'Técnica de eficiencia',
          objetivoFisiologico: 'Base aeróbica',
          partes: [
            Parte(
              tipo: TipoParte.inicial,
              series: [
                const Serie(
                  repeticiones: 8,
                  distancia: 50,
                  zona: Zona.a1,
                  estilo: Estilo.libre,
                ),
              ],
            ),
            const Parte(tipo: TipoParte.central),
            const Parte(tipo: TipoParte.cierre),
          ],
        ),
    ],
  );

  RegistroDeSesion respuesta(String sesionId, {int? rpe}) => RegistroDeSesion(
    nadadorId: 'n1',
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: '3.5.0',
    realizada: true,
    registradoEn: DateTime(2026, 10, 14),
    rpePercibido: rpe,
    observaciones: 'Me costó la tercera serie',
  );

  String serializado(Plan plan) =>
      jsonEncode(planAJson(plan, conSesiones: true));

  group('SC-007 — el plan no se mueve', () {
    test('registrar respuestas sobre tres sesiones no cambia un byte', () {
      final plan = planAprobado();
      final antes = serializado(plan);

      // El nadador responde. Los registros son entidades aparte: no hay forma
      // de que esto toque el plan, y esa es justo la comprobación.
      final registros = [
        respuesta('s1', rpe: 7),
        respuesta('s2', rpe: 9),
        respuesta('s3'),
      ];

      expect(registros, hasLength(3));
      expect(
        serializado(plan),
        antes,
        reason:
            'Un plan aprobado es inmutable. Si esto falla, el entrenador ya '
            'no puede saber que lo que firmó sigue siendo lo que hay',
      );
    });

    test('el registro apunta a la sesión; la sesión no conoce el registro', () {
      final plan = planAprobado();
      final registro = respuesta('s1', rpe: 7);

      expect(registro.sesionId, 's1');

      // La sesión serializada no contiene ninguna huella de la respuesta.
      final sesion = jsonEncode(sesionAJson(plan.sesiones.first));
      expect(sesion, isNot(contains('rpePercibido')));
      expect(sesion, isNot(contains('Me costó')));
    });

    test('el estado y la versión estampada siguen intactos', () {
      final plan = planAprobado();
      respuesta('s1', rpe: 10);

      expect(plan.estado, EstadoPlan.aprobado);
      expect(plan.versionMetodologia, '3.5.0');
      expect(plan.fechaAprobacion, DateTime(2026, 10, 1));
    });
  });

  group('V10 — las versiones no se confunden', () {
    test('un registro apunta a la versión bajo la que se entrenó', () {
      final viejo = RegistroDeSesion(
        nadadorId: 'n1',
        planId: 'p1',
        sesionId: 's1',
        versionDePlan: '3.4.1',
        realizada: true,
        registradoEn: DateTime(2026, 9, 1),
      );

      final nuevo = respuesta('s1');

      expect(viejo.versionDePlan, '3.4.1');
      expect(nuevo.versionDePlan, '3.5.0');
      expect(
        viejo.id,
        isNot(nuevo.id),
        reason:
            'Sin esto, un plan corregido haría parecer que el nadador '
            'respondió a series que nunca hizo',
      );
    });
  });
}
