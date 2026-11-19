/// Lo que ella contestó **no se le vuelve a pedir** (FR-010, FR-011).
///
/// Ana no pudo entrenar el martes y lo dijo en la app. El jueves, su plan
/// seguía listando el martes entre las sesiones que le faltan por marcar, y su
/// entrenador leía ese mismo hueco. Ella contestó. La app volvía a preguntar.
///
/// ## Esto no añade un concepto: enciende uno que ya estaba
///
/// `ProgresoEnElMacrociclo` ya distinguía las tres categorías, y lo decía en su
/// propia documentación:
///
/// > **No es lo mismo que no haber contestado**… «No la hice» es un dato: el
/// > nadador estuvo ahí y dijo lo que pasó. «No contestó» es la ausencia de un
/// > dato… Mezclarlas le enseñaría al entrenador un hueco donde hay una
/// > respuesta, o una respuesta donde hay un hueco.
///
/// Y ya tenía `sinContestar`, con la regla correcta, con pruebas que afirman
/// que las tres categorías parten exactamente las sesiones pasadas. **Nada en
/// `lib/` lo llamaba.** `pendientes` se escribió al lado, excluyendo solo
/// `hechas`, y esa es la que leen las pantallas.
///
/// Es el mismo defecto que `alVolverLaRed`: algo correcto, construido, probado
/// y nunca conectado. Dos veces en la misma feature.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/progreso_en_el_macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  final hoy = DateTime(2026, 11, 18);

  Sesion sesion(String id, DateTime? fecha) =>
      Sesion(id: id, microcicloId: 'm1', fecha: fecha);

  RegistroDeSesion respuesta(String sesionId, {required bool laHizo}) =>
      RegistroDeSesion(
        nadadorId: 'n-ana',
        planId: 'p1',
        sesionId: sesionId,
        versionDePlan: '1',
        realizada: laHizo,
        registradoEn: hoy,
      );

  Plan plan(List<Sesion> sesiones) => Plan(
    id: 'p1',
    nombre: 'Mesociclo 1',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    estado: EstadoPlan.publicado,
    versionMetodologia: '3.6.0',
    sesiones: sesiones,
  );

  ProgresoEnElMacrociclo progresoCon({
    required List<Sesion> sesiones,
    required List<RegistroDeSesion> registros,
  }) => ProgresoEnElMacrociclo(
    mesociclos: [plan(sesiones)],
    registros: registros,
    hoy: hoy,
  );

  List<String> pendientesDe(ProgresoEnElMacrociclo p) =>
      p.pendientes.map((s) => s.id!).toList();

  test('una sesión pasada que contestó «no la hice» no está pendiente', () {
    final progreso = progresoCon(
      sesiones: [sesion('martes', DateTime(2026, 11, 17))],
      registros: [respuesta('martes', laHizo: false)],
    );

    expect(
      pendientesDe(progreso),
      isEmpty,
      reason:
          'ella estuvo ahí y dijo lo que pasó. Volver a pedírselo es no haber '
          'escuchado',
    );
  });

  test('una que no contestó de ninguna manera sí está pendiente', () {
    final progreso = progresoCon(
      sesiones: [sesion('jueves', DateTime(2026, 11, 12))],
      registros: const [],
    );

    expect(
      pendientesDe(progreso),
      ['jueves'],
      reason: 'el silencio no es una respuesta',
    );
  });

  test('una que marcó como hecha no está pendiente', () {
    final progreso = progresoCon(
      sesiones: [sesion('lunes', DateTime(2026, 11, 16))],
      registros: [respuesta('lunes', laHizo: true)],
    );

    expect(pendientesDe(progreso), isEmpty);
  });

  test('la de hoy, sin contestar, no cuenta: el día no ha terminado', () {
    final progreso = progresoCon(
      sesiones: [sesion('hoy', hoy)],
      registros: const [],
    );

    expect(pendientesDe(progreso), isEmpty);
  });

  test('una sin fecha no cuenta: no hay día en el que se perdiera', () {
    final progreso = progresoCon(
      sesiones: [sesion('suelta', null)],
      registros: const [],
    );

    expect(pendientesDe(progreso), isEmpty);
  });

  test('las tres categorías siguen partiendo lo pasado', () {
    // El invariante que esta clase ya tenía probado, ahora con `pendientes`
    // apoyada encima: lo que ella ve son exactamente las sin contestar.
    final progreso = progresoCon(
      sesiones: [
        sesion('hecha', DateTime(2026, 11, 10)),
        sesion('dijoQueNo', DateTime(2026, 11, 11)),
        sesion('muda', DateTime(2026, 11, 12)),
      ],
      registros: [
        respuesta('hecha', laHizo: true),
        respuesta('dijoQueNo', laHizo: false),
      ],
    );

    expect(progreso.hechas, {'hecha'});
    expect(progreso.dijoQueNo, {'dijoQueNo'});
    expect(progreso.sinContestar, {'muda'});
    expect(
      pendientesDe(progreso),
      ['muda'],
      reason: 'una regla, un sitio: lo pendiente es lo que no contestó',
    );
  });

  test('y lo pendiente va de la más antigua a la más reciente', () {
    final progreso = progresoCon(
      sesiones: [
        sesion('despues', DateTime(2026, 11, 14)),
        sesion('antes', DateTime(2026, 11, 10)),
      ],
      registros: const [],
    );

    expect(pendientesDe(progreso), ['antes', 'despues']);
  });
}
