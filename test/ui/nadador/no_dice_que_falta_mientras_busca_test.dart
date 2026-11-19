/// **Ninguna pantalla afirma una ausencia que no ha comprobado** (FR-013).
///
/// Tercer defecto del recorrido. Ana abre su progreso sin señal y durante
/// veinte segundos la pantalla le dice que no tiene plan asignado y que su
/// progreso aparecerá cuando su entrenador le dé uno. Tiene un macrociclo,
/// entregado hace semanas, y está en el teléfono que tiene en la mano.
///
/// Mientras lo dice, es mentira. Y lo dice con las mismas palabras exactas que
/// la app guarda para una nadadora que de verdad no tiene nada, así que ella no
/// puede distinguir «todavía estoy buscando» de «no hay».
///
/// Las dos pantallas, no una: la misma frase vive en `Mi progreso` y en la
/// sesión del día. Arreglar una y dejar la otra es dejársela al siguiente
/// recorrido.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/lectura/lectura.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_mi_progreso.dart';
import 'package:provider/provider.dart';

import '../../dominio/sincronizacion/dobles_de_sincronizacion.dart';

/// Las palabras que la app guarda para quien de verdad no tiene nada.
const _elVacio = 'Todavía no tienes un plan asignado';

void main() {
  final hoy = DateTime(2026, 11, 18);

  EstadoNadador estadoNuevo() => EstadoNadador(
    sincronizador: Sincronizador(
      registros: RegistrosDeMentiraLocales(),
      bandeja: BandejaDeMentira(),
      red: RedDeMentira(),
      transporte: TransporteMudo()..contesta = true,
      reloj: () => hoy,
    ),
    reloj: () => hoy,
  );

  Plan unPlan() => Plan(
    id: 'p1',
    nombre: 'Mesociclo 1',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    estado: EstadoPlan.publicado,
    versionMetodologia: '3.6.0',
    sesiones: [Sesion(id: 's1', microcicloId: 'm1', fecha: hoy)],
  );

  Future<void> montar(WidgetTester tester, EstadoNadador estado) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoNadador>.value(
          value: estado,
          child: const PantallaMiProgreso(),
        ),
      ),
    );
    await tester.pump();
  }

  group('el estado de la lectura', () {
    test('antes de que nadie le diga nada, está cargando', () {
      expect(estadoNuevo().progreso, isA<Cargando<Object?>>());
    });

    test('con un plan, hay', () {
      final estado = estadoNuevo()
        ..abrirComo(const Nadador(id: 'n1', nombre: 'Ana'), plan: unPlan());

      expect(estado.progreso, isA<Hay<Object?>>());
    });

    test('sin plan, pero ya preguntado, no hay', () {
      final estado = estadoNuevo()
        ..abrirComo(const Nadador(id: 'n1', nombre: 'Ana'));

      expect(estado.progreso, isA<NoHay<Object?>>());
    });

    test('si la lectura falló, no se pudo', () {
      final estado = estadoNuevo()..noSePudoAbrir('el servidor no contestó');

      expect(estado.progreso, isA<NoSePudo<Object?>>());
    });
  });

  group('Mi progreso', () {
    testWidgets('mientras busca, no dice que no tiene plan', (tester) async {
      await montar(tester, estadoNuevo());

      expect(
        find.text(_elVacio),
        findsNothing,
        reason:
            'está en el teléfono que ella tiene en la mano. Decirle que no '
            'tiene plan mientras se busca es mentirle, y encima con las '
            'palabras que la app guarda para quien de verdad no tiene nada',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('cuando no hay, lo dice con las palabras de siempre', (
      tester,
    ) async {
      final estado = estadoNuevo()
        ..abrirComo(const Nadador(id: 'n1', nombre: 'Ana'));
      await montar(tester, estado);

      expect(find.text(_elVacio), findsOneWidget);
    });

    testWidgets('cuando no se pudo leer, no dice que no hay', (tester) async {
      final estado = estadoNuevo()..noSePudoAbrir('el servidor no contestó');
      await montar(tester, estado);

      expect(
        find.text(_elVacio),
        findsNothing,
        reason: 'un fallo y una ausencia no son lo mismo y no se le ven igual',
      );
      expect(find.textContaining('No se pudo'), findsOneWidget);
    });

    testWidgets('y no le enseña nada de la red', (tester) async {
      final estado = estadoNuevo()
        ..noSePudoAbrir('SocketException: Failed host lookup');
      await montar(tester, estado);

      for (final prohibido in [
        'SocketException',
        'Failed host lookup',
        'reintentar',
      ]) {
        expect(
          find.textContaining(prohibido),
          findsNothing,
          reason: 'el motivo es para la pantalla, no para ella',
        );
      }
    });
  });
}
