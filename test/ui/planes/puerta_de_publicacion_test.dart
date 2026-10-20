import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/ui/planes/pantalla_plan.dart';

/// Garantía P5 — el consentimiento es puerta de publicación.
///
/// Quien la hace cumplir es el servidor. Esto comprueba que la pantalla no
/// ofrezca lo que el servidor va a rechazar, y que diga **qué falta** en lugar
/// de dejar un error genérico después de haberlo intentado.
///
/// La feature 003 enseñó por qué esto necesita prueba: T006 estuvo marcada
/// como hecha sin estarlo porque nada recorría el camino de verdad.
void main() {
  Plan planAprobado() => Plan(
        id: 'p1',
        nombre: 'Microciclo de base',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '800 Libre',
        estado: EstadoPlan.aprobado,
        versionMetodologia: '3.6.0',
        fechaAprobacion: DateTime(2026, 10, 15),
        microciclos: const [
          Microciclo(
            id: 'm1',
            nombre: 'Semana 1',
            orden: 1,
            objetivo: 'Base aeróbica',
          ),
        ],
        sesiones: [
          Sesion(
            id: 's1',
            microcicloId: 'm1',
            fecha: DateTime(2026, 10, 15),
            objetivoTecnico: 'Técnica de eficiencia',
            objetivoFisiologico: 'Base aeróbica',
            partes: [
              Parte(
                tipo: TipoParte.inicial,
                series: const [
                  Serie(
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

  const conConsentimiento = Nadador(
    id: 'n1',
    nombre: 'Nadador con autorización',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
  );

  const sinConsentimiento = Nadador(
    id: 'n2',
    nombre: 'Nadador sin autorización',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
  );

  Future<void> abrirEntrega(
    WidgetTester tester, {
    required Set<String> permitidos,
    void Function(Plan, List<String>)? alEntregar,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaPlan(
          plan: planAprobado(),
          versionMetodologia: '3.6.0',
          nadadores: const [conConsentimiento, sinConsentimiento],
          conConsentimiento: permitidos,
          alEntregar: alEntregar,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entregar al nadador'));
    await tester.pumpAndSettle();
  }

  CheckboxListTile casillaDe(WidgetTester tester, String nombre) =>
      tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text(nombre),
          matching: find.byType(CheckboxListTile),
        ),
      );

  testWidgets('quien no tiene consentimiento no se puede marcar',
      (tester) async {
    await abrirEntrega(tester, permitidos: {'n1'});

    expect(casillaDe(tester, conConsentimiento.nombre).enabled, isTrue);
    expect(
      casillaDe(tester, sinConsentimiento.nombre).enabled,
      isFalse,
      reason: 'El consentimiento es puerta de publicación (FR-013). Ofrecer '
          'la casilla sería ofrecer algo que el servidor va a denegar',
    );
  });

  testWidgets('y se dice qué falta, no un error genérico', (tester) async {
    await abrirEntrega(tester, permitidos: {'n1'});

    expect(
      find.textContaining('Sin consentimiento del acudiente'),
      findsOneWidget,
    );
  });

  testWidgets('sin ningún consentimiento no se puede marcar a nadie',
      (tester) async {
    await abrirEntrega(tester, permitidos: const {});

    expect(casillaDe(tester, conConsentimiento.nombre).enabled, isFalse);
    expect(casillaDe(tester, sinConsentimiento.nombre).enabled, isFalse);
  });

  testWidgets('el valor por omisión no deja publicar a nadie', (tester) async {
    // Si el valor por omisión fuera «todos», olvidar pasarlo abriría la puerta
    // en silencio. Es la peor forma de equivocarse en esto, así que la
    // omisión es la segura.
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaPlan(
          plan: planAprobado(),
          versionMetodologia: '3.6.0',
          nadadores: const [conConsentimiento],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregar al nadador'));
    await tester.pumpAndSettle();

    expect(casillaDe(tester, conConsentimiento.nombre).enabled, isFalse);
  });

  testWidgets('a quien sí tiene consentimiento se le entrega', (tester) async {
    Plan? entregado;
    List<String>? entregadoA;
    await abrirEntrega(
      tester,
      permitidos: {'n1'},
      alEntregar: (plan, nadadores) {
        entregado = plan;
        entregadoA = nadadores;
      },
    );

    await tester.tap(find.text(conConsentimiento.nombre));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar y entregar'));
    await tester.pumpAndSettle();

    expect(entregado, isNotNull);
    expect(entregado!.estado, EstadoPlan.publicado);
    expect(
      entregadoA,
      ['n1'],
      reason: 'Publicar y asignar son dos cosas: el plan cambia de estado, y '
          'cada entrega es una asignación propia que pasa por la puerta de '
          'consentimiento de ese nadador',
    );
  });
}
