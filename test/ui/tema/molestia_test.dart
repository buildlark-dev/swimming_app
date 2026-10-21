/// Garantía V11 — un reporte de molestia no se viste de alarma.
///
/// Un nadador que dice que le molestó el hombro está dando **información**, no
/// declarando una avería. El reporte tiene que cumplir dos cosas a la vez, y
/// están en tensión:
///
/// - **Encontrarse sin leer todas las observaciones de todas las sesiones**
///   (SC-006). Por eso va arriba del historial y lleva color.
/// - **No parecer una urgencia médica.** El principio IV prohíbe que la app
///   diagnostique o proponga conducta, y pintar algo de rojo es una forma de
///   opinar: dice «esto es grave» sin que nadie lo haya valorado.
///
/// La resolución es el tono de cuidado. Visible, pero sin veredicto.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/planes/respuestas_del_nadador.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  final hoy = DateTime(2026, 10, 20, 7);

  Sesion sesion(String id) => Sesion(
        id: id,
        microcicloId: 'm1',
        fecha: hoy,
        objetivoTecnico: 'Técnica de eficiencia en Libre',
        objetivoFisiologico: 'Base aeróbica',
        partes: const [
          Parte(tipo: TipoParte.inicial),
          Parte(tipo: TipoParte.central),
          Parte(tipo: TipoParte.cierre),
        ],
      );

  Plan plan(List<Sesion> sesiones) => Plan(
        id: 'p1',
        nombre: 'Microciclo',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
        estado: EstadoPlan.publicado,
        microciclos: const [
          Microciclo(id: 'm1', nombre: 'Semana 1', orden: 1),
        ],
        sesiones: sesiones,
      );

  RegistroDeSesion conMolestia(String sesionId) => RegistroDeSesion(
        nadadorId: 'n1',
        planId: 'p1',
        sesionId: sesionId,
        versionDePlan: 'v1',
        realizada: true,
        registradoEn: hoy,
        molestia: const ReporteDeMolestia(
          descripcion: 'Molestia en el hombro derecho al nadar espalda',
          zonaDelCuerpo: 'hombro derecho',
        ),
      );

  Future<void> montar(
    WidgetTester tester, {
    required bool hayMolestia,
    bool oscuro = false,
  }) async {
    final s = sesion('s1');
    final progreso = ProgresoDelNadador(
      plan: plan([s]),
      registros: hayMolestia
          ? [conMolestia('s1')]
          : [
              RegistroDeSesion(
                nadadorId: 'n1',
                planId: 'p1',
                sesionId: 's1',
                versionDePlan: 'v1',
                realizada: true,
                registradoEn: hoy,
              ),
            ],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: oscuro ? Tema.oscuro() : Tema.claro(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RespuestasDelNadador(progreso: progreso),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Los avisos que hay en pantalla, con su tono.
  List<Aviso> avisos(WidgetTester tester) =>
      tester.widgetList<Aviso>(find.byType(Aviso)).toList();

  group('V11 — el reporte no usa el tono de error', () {
    for (final oscuro in [false, true]) {
      testWidgets(oscuro ? 'en oscuro' : 'en claro', (tester) async {
        await montar(tester, hayMolestia: true, oscuro: oscuro);

        final encontrados = avisos(tester);
        expect(
          encontrados,
          isNotEmpty,
          reason: 'Si no hay ningún aviso, esta prueba no mide nada',
        );

        for (final aviso in encontrados) {
          expect(
            aviso.tono,
            isNot(TonoDeAviso.error),
            reason: 'El reporte de molestia está pintado como una avería. El '
                'principio IV prohíbe que la app opine sobre la gravedad: eso '
                'lo decide el entrenador',
          );
        }

        expect(
          encontrados.map((a) => a.tono),
          contains(TonoDeAviso.cuidado),
          reason: 'Tiene que llevar tono de cuidado: visible para encontrarlo, '
              'sin cara de urgencia médica',
        );
      });
    }
  });

  group('SC-006 — se encuentra sin leerlo todo', () {
    testWidgets('está en pantalla con lo que dijo el nadador', (tester) async {
      await montar(tester, hayMolestia: true);

      expect(find.textContaining('Reportes de molestia'), findsOneWidget);
      expect(
        find.textContaining('hombro derecho'),
        findsWidgets,
        reason: 'La molestia se nombra tal como la escribió el nadador',
      );
    });

    testWidgets('dice en voz alta que la app no decide', (tester) async {
      // Es la frase que sostiene el principio IV en esta pantalla. Si
      // desapareciera, el color sería lo único que hablaría.
      await montar(tester, hayMolestia: true);

      expect(
        find.text('La app no propone ninguna conducta: decide usted.'),
        findsOneWidget,
      );
    });

    testWidgets('sin molestias, no ocupa pantalla', (tester) async {
      // Un aviso que sale siempre deja de significar algo.
      await montar(tester, hayMolestia: false);

      expect(find.textContaining('Reportes de molestia'), findsNothing);
    });
  });

  group('la prueba no pasa por vacía', () {
    testWidgets('sabría ver un tono de error si lo hubiera', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: const Scaffold(
            body: Aviso(tono: TonoDeAviso.error, mensaje: 'Algo falló'),
          ),
        ),
      );
      await tester.pump();

      expect(avisos(tester).single.tono, TonoDeAviso.error);
    });
  });
}
