/// Garantías H15 y H16 — el resumen del nadador.
///
/// Dos cosas que este cerrojo protege, y la segunda importa más de lo que
/// parece:
///
/// - **No hace ninguna consulta.** Sale de lo que la feature 003 ya mantiene,
///   y por eso `Home` abre sin conexión sin construir nada para lograrlo.
/// - **No inventa nada.** Ni metas, ni logros, ni rachas, ni proyecciones. No
///   existen como dato, y el principio IV no permite fabricarlos (FR-015). Un
///   resumen que anima con cifras que nadie calculó es justo lo que un nadador
///   de nueve años se va a creer.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/calculo/sesion_del_dia.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/hub/resumen_del_nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  final hoy = DateTime(2026, 10, 27, 7);

  Sesion sesion(String id, DateTime fecha) => Sesion(
    id: id,
    microcicloId: 'm1',
    fecha: fecha,
    objetivoTecnico: 'Técnica de eficiencia en Libre',
    objetivoFisiologico: 'Base aeróbica',
    partes: const [Parte(tipo: TipoParte.central)],
  );

  Plan plan({int sesiones = 3}) => Plan(
    id: 'p1',
    nombre: 'Microciclo de base',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    estado: EstadoPlan.publicado,
    versionMetodologia: '3.6.0',
    microciclos: const [Microciclo(id: 'm1', nombre: 'Semana 1', orden: 1)],
    sesiones: [
      for (var i = 0; i < sesiones; i++)
        sesion('s$i', hoy.add(Duration(days: i))),
    ],
  );

  RegistroDeSesion registro(
    String sesionId, {
    required bool realizada,
    DateTime? cuando,
    int? rpe,
  }) => RegistroDeSesion(
    nadadorId: 'n1',
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: '3.6.0',
    realizada: realizada,
    registradoEn: cuando ?? hoy,
    rpePercibido: rpe,
  );

  group('sin plan todavía', () {
    test('no estalla, y los números son cero', () {
      final r = ResumenDelNadador.de(
        plan: null,
        registros: const [],
        hoy: const SinSesionesPorDelante(),
      );

      expect(r.entregadas, 0);
      expect(r.cumplidas, 0);
      expect(r.ultimaRespuesta, isNull);
    });

    test('lo dice: no es una pantalla vacía sin explicación', () {
      final r = ResumenDelNadador.de(
        plan: null,
        registros: const [],
        hoy: const SinSesionesPorDelante(),
      );

      expect(r.tienePlan, isFalse);
    });
  });

  group('con plan', () {
    test('entregadas son las sesiones del plan', () {
      final r = ResumenDelNadador.de(
        plan: plan(sesiones: 4),
        registros: const [],
        hoy: SinSesionHoy(
          siguiente: sesion('s0', hoy.add(const Duration(days: 1))),
          cuando: hoy.add(const Duration(days: 1)),
        ),
      );

      expect(r.entregadas, 4);
      expect(r.cumplidas, 0);
    });

    test('cumplidas son las que marcó como realizadas', () {
      final r = ResumenDelNadador.de(
        plan: plan(),
        registros: [
          registro('s0', realizada: true),
          registro('s1', realizada: false),
        ],
        hoy: SinSesionHoy(
          siguiente: sesion('s0', hoy.add(const Duration(days: 1))),
          cuando: hoy.add(const Duration(days: 1)),
        ),
      );

      expect(r.cumplidas, 1);
      expect(r.entregadas, 3);
    });

    test('cumplidas nunca es mayor que entregadas', () {
      // Registros de sesiones que ya no están en el plan —porque el entrenador
      // publicó una versión nueva— no pueden inflar la cuenta.
      final r = ResumenDelNadador.de(
        plan: plan(sesiones: 2),
        registros: [
          registro('s0', realizada: true),
          registro('s1', realizada: true),
          registro('s9', realizada: true),
        ],
        hoy: SinSesionHoy(
          siguiente: sesion('s0', hoy.add(const Duration(days: 1))),
          cuando: hoy.add(const Duration(days: 1)),
        ),
      );

      expect(r.cumplidas, lessThanOrEqualTo(r.entregadas));
      expect(r.cumplidas, 2);
    });
  });

  group('la última respuesta', () {
    test('es la más reciente, no la primera de la lista', () {
      final r = ResumenDelNadador.de(
        plan: plan(),
        registros: [
          registro('s0', realizada: true, cuando: hoy, rpe: 4),
          registro(
            's1',
            realizada: true,
            cuando: hoy.subtract(const Duration(days: 3)),
            rpe: 9,
          ),
        ],
        hoy: SinSesionHoy(
          siguiente: sesion('s0', hoy.add(const Duration(days: 1))),
          cuando: hoy.add(const Duration(days: 1)),
        ),
      );

      expect(r.ultimaRespuesta?.rpePercibido, 4);
    });

    test('falta si no ha anotado nada, y eso no es un fallo', () {
      // El principio VIII: anotar no es obligatorio. Quien no anota sigue
      // viendo su plan, y su resumen no puede tratarlo como un problema.
      final r = ResumenDelNadador.de(
        plan: plan(),
        registros: const [],
        hoy: SinSesionHoy(
          siguiente: sesion('s0', hoy.add(const Duration(days: 1))),
          cuando: hoy.add(const Duration(days: 1)),
        ),
      );

      expect(r.ultimaRespuesta, isNull);
    });
  });

  group('de cuándo son los datos', () {
    test('se guarda para poder decirlo (H14)', () {
      final cuando = hoy.subtract(const Duration(hours: 5));
      final r = ResumenDelNadador.de(
        plan: plan(),
        registros: const [],
        hoy: SinSesionHoy(
          siguiente: sesion('s0', hoy.add(const Duration(days: 1))),
          cuando: hoy.add(const Duration(days: 1)),
        ),
        ultimaSincronizacion: cuando,
        hayPendientes: true,
      );

      expect(r.ultimaSincronizacion, cuando);
      expect(r.hayPendientes, isTrue);
    });

    test('puede faltar, y entonces se sabe que falta', () {
      final r = ResumenDelNadador.de(
        plan: plan(),
        registros: const [],
        hoy: SinSesionHoy(
          siguiente: sesion('s0', hoy.add(const Duration(days: 1))),
          cuando: hoy.add(const Duration(days: 1)),
        ),
      );

      expect(r.ultimaSincronizacion, isNull);
      expect(r.hayPendientes, isFalse);
    });
  });

  group('lo que el resumen NO lleva (FR-015, H16)', () {
    test('ni metas, ni logros, ni rachas, ni proyecciones', () {
      // **Se lee el fuente, no una lista que la propia clase declare.** Una
      // lista de «campos permitidos» mantenida a mano es un cerrojo que se
      // abre solo: quien añadiera una racha tampoco la apuntaría ahí.
      final fuente = File(
        'lib/dominio/hub/resumen_del_nadador.dart',
      ).readAsStringSync().toLowerCase();

      for (final inventado in [
        'meta',
        'logro',
        'racha',
        'proyeccion',
        'prediccion',
        'insignia',
        'puntos',
        'ranking',
      ]) {
        expect(
          fuente,
          isNot(contains(inventado)),
          reason:
              '«$inventado» no existe como dato en esta app. El principio '
              'IV no permite fabricarlo, y un nadador de nueve años se lo '
              'creería',
        );
      }
    });

    test('la prueba no pasa por vacía', () {
      final fuente = File(
        'lib/dominio/hub/resumen_del_nadador.dart',
      ).readAsStringSync();

      expect(fuente, contains('class ResumenDelNadador'));
      expect(fuente.length, greaterThan(500));
    });
  });
}
