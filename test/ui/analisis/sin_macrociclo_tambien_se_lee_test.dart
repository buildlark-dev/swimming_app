/// **Sin macrociclo también se lee lo que contestó.**
///
/// Hallazgo del recorrido de la 010 en el Pixel 7, y vale la pena contarlo
/// entero porque es la forma que este recorrido existe para cazar:
///
/// Ana tenía `p-publicado` entregado y asignado, con tres sesiones y dos
/// respuestas, una de ellas **con una molestia**. La lista del `Análisis` la
/// marcaba —«Contó una molestia», leído del servidor— y al abrirla la pantalla
/// decía «Todavía no tiene macrociclo» y no enseñaba nada. **La app se
/// contradecía en dos pantallas suyas, con el dato delante.**
///
/// La causa: la lectura resolvía sus sesiones **a través del macrociclo**. Una
/// nadadora a la que se le entregó un plan directamente —que es lo que hacen
/// las features 003, 004 y 007, y sigue siendo un camino válido— no tiene
/// ninguno, así que no había mesociclos, ni sesiones, ni respuestas.
///
/// El otro lado ya lo tenía resuelto desde M23: sin macrociclo, `Ver Plan`
/// enseña lo que la feature 003 le dio. Al del entrenador le faltaba el mismo
/// respaldo, y esto es ese respaldo: **sus planes entregados**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;
  late RepositorioAsignacionesMemoria asignaciones;

  setUp(() {
    repos = ReposDeAnalisis();
    asignaciones = RepositorioAsignacionesMemoria();
  });

  /// Un plan entregado, fuera de todo macrociclo: lo que la 003 dejaba.
  Future<void> sembrarPlanSuelto() async {
    repos.planes.sembrar(
      mesociclo(
        id: 'p-publicado',
        sesiones: [
          sesionDe(id: 's0', fecha: lunes),
          sesionDe(id: 's-1', fecha: miercoles),
          sesionDe(id: 's-2', fecha: viernes),
        ],
      ),
    );

    await asignaciones.asignar(
      Asignacion(
        planId: 'p-publicado',
        nadadorId: 'n-ana',
        asignadaEn: DateTime(2026, 11, 1),
      ),
    );
  }

  testWidgets('con un plan entregado y sin macrociclo, se leen sus sesiones', (
    tester,
  ) async {
    conPantallaAlta(tester);

    await sembrarPlanSuelto();
    repos.registros
      ..sembrar(registroDe(sesionId: 's0', planId: 'p-publicado', rpe: 6))
      ..sembrar(
        registroDe(
          sesionId: 's-2',
          planId: 'p-publicado',
          rpe: 7,
          molestia: const ReporteDeMolestia(
            descripcion: 'Me molesta al sacar el brazo',
            zonaDelCuerpo: 'Hombro derecho',
          ),
        ),
      );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: '', asignaciones: asignaciones),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('sin-macrociclo-que-leer')),
      findsNothing,
      reason:
          'tiene un plan entregado y dos respuestas: decir que no hay nada '
          'que leer es mentir con el dato delante',
    );

    expect(find.byKey(const Key('sesion-y-respuesta-s0')), findsOneWidget);
    expect(find.byKey(const Key('sesion-y-respuesta-s-2')), findsOneWidget);

    expect(
      tester.widget<Text>(find.byKey(const Key('lo-que-contesto-s0'))).data,
      contains('6'),
    );
  });

  testWidgets('la molestia de un plan suelto también se ve', (tester) async {
    conPantallaAlta(tester);

    await sembrarPlanSuelto();
    repos.registros.sembrar(
      registroDe(
        sesionId: 's-2',
        planId: 'p-publicado',
        rpe: 7,
        molestia: const ReporteDeMolestia(
          descripcion: 'Me molesta al sacar el brazo',
          zonaDelCuerpo: 'Hombro derecho',
        ),
      ),
    );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: '', asignaciones: asignaciones),
    );
    await tester.pumpAndSettle();

    // Era lo más grave del defecto: la lista la marcaba y al abrirla
    // desaparecía.
    expect(find.byKey(const Key('molestias-de-n-ana')), findsOneWidget);
    expect(find.text('Me molesta al sacar el brazo'), findsWidgets);
  });

  testWidgets('un plan aprobado y sin entregar no es suyo todavía', (
    tester,
  ) async {
    conPantallaAlta(tester);

    // **Firmar no es entregar**, y sin asignación no es de nadie.
    repos.planes.sembrar(
      mesociclo(
        id: 'p-aprobado',
        estado: EstadoPlan.aprobado,
        sesiones: [sesionDe(id: 'sa', fecha: lunes)],
      ),
    );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: '', asignaciones: asignaciones),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sesion-y-respuesta-sa')), findsNothing);
    expect(find.byKey(const Key('sin-macrociclo-que-leer')), findsOneWidget);
  });

  testWidgets('sin plan y sin macrociclo se dice, sin marco vacío', (
    tester,
  ) async {
    conPantallaAlta(tester);

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: '', asignaciones: asignaciones),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sin-macrociclo-que-leer')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('con macrociclo manda el macrociclo, no los planes sueltos', (
    tester,
  ) async {
    conPantallaAlta(tester);

    // El macrociclo trae `plan-1` con s1..s3; el plan suelto trae s0, s-1, s-2.
    final macrocicloId = await repos.sembrarMacrociclo();
    await sembrarPlanSuelto();

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        asignaciones: asignaciones,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sesion-y-respuesta-s1')), findsOneWidget);
    expect(
      find.byKey(const Key('sesion-y-respuesta-s0')),
      findsNothing,
      reason:
          'el respaldo es para cuando no hay macrociclo; con uno, mezclar los '
          'dos le contaría dos veces lo que programó',
    );
  });
}
