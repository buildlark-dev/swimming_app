/// Donde el entrenador le pone nombre a lo suyo (feature 012, US1).
///
/// Tres cosas se fijan aquí, y la tercera es la que sostiene el resto de la
/// feature:
///
/// 1. Está en ajustes, con lo demás que él gobierna de su propia cuenta.
/// 2. Un nombre en blanco se rechaza **con palabras que él puede usar**, no
///    con el texto que lanza el dominio.
/// 3. **Cambiarle el nombre no mueve a nadie** (FR-003). Es cierto por cómo
///    está guardado —el nombre en la comunidad, la pertenencia en la ficha de
///    cada nadadora— y esta prueba lo comprueba en vez de confiar en ello.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/comunidad/comunidad.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/ajustes/mi_comunidad.dart';

void main() {
  late _Comunidades repo;

  setUp(() => repo = _Comunidades());

  Future<void> montar(WidgetTester tester, {String entrenador = 'e-uno'}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MiComunidad(entrenadorId: entrenador, comunidades: repo),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin servidor, la sección no se pinta', (tester) async {
    // Un campo que no puede terminar lo que empieza es peor que ningún campo.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MiComunidad(entrenadorId: 'e-uno', comunidades: null),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mi comunidad'), findsNothing);
  });

  testWidgets('aparece, y enseña el nombre que ya tiene', (tester) async {
    repo.guardadas['e-uno'] = Comunidad(
      id: 'e-uno',
      entrenadorId: 'e-uno',
      nombre: 'Club Acuático del Valle',
    );

    await montar(tester);

    expect(find.text('Mi comunidad'), findsOneWidget);
    expect(find.text('Club Acuático del Valle'), findsOneWidget);
  });

  testWidgets('guardar un nombre lo deja guardado', (tester) async {
    await montar(tester);

    await tester.enterText(
      find.byKey(const Key('nombre-de-la-comunidad')),
      'Escuela Ribera',
    );
    await tester.tap(find.text('Guardar el nombre'));
    await tester.pumpAndSettle();

    expect(repo.guardadas['e-uno']?.nombre, 'Escuela Ribera');
    expect(find.byKey(const Key('comunidad-guardada')), findsOneWidget);
    expect(
      find.textContaining('Escuela Ribera'),
      findsWidgets,
      reason: 'se le dice qué verán sus nadadores, con el nombre dentro',
    );
  });

  testWidgets('un nombre en blanco se rechaza en sus palabras', (tester) async {
    await montar(tester);

    await tester.enterText(
      find.byKey(const Key('nombre-de-la-comunidad')),
      '   ',
    );
    await tester.tap(find.text('Guardar el nombre'));
    await tester.pumpAndSettle();

    expect(repo.guardadas, isEmpty);

    final aviso = tester.widget<Text>(
      find.byKey(const Key('comunidad-problema')),
    );
    expect(
      aviso.data,
      isNot(contains('no puede estar en blanco')),
      reason:
          'eso es lo que lanza el dominio, no lo que se le dice a alguien que '
          'está escribiendo un nombre',
    );
    expect(aviso.data, contains('nadadores'));
  });

  testWidgets('renombrar no mueve a nadie', (tester) async {
    // **FR-003.** El nombre vive aquí y la pertenencia vive en la ficha de
    // cada nadadora, justo para que esto sea cierto sin que nadie tenga que
    // acordarse. Con una pertenencia y una solicitud esperando en pie, un
    // renombrado no toca ninguna de las dos.
    repo.guardadas['e-uno'] = Comunidad(
      id: 'e-uno',
      entrenadorId: 'e-uno',
      nombre: 'Antes',
    );
    repo.pertenencias['n-ana'] = 'e-uno';
    repo.solicitudesEsperando['n-juan'] = 'e-uno';

    await montar(tester);
    await tester.enterText(
      find.byKey(const Key('nombre-de-la-comunidad')),
      'Después',
    );
    await tester.tap(find.text('Guardar el nombre'));
    await tester.pumpAndSettle();

    expect(repo.guardadas['e-uno']?.nombre, 'Después');
    expect(repo.pertenencias['n-ana'], 'e-uno');
    expect(repo.solicitudesEsperando['n-juan'], 'e-uno');
    expect(
      repo.guardadas['e-uno']?.entrenadorId,
      'e-uno',
      reason: 'y la comunidad sigue siendo suya',
    );
  });

  testWidgets('si no se puede leer, lo dice y no inventa', (tester) async {
    repo.falla = true;

    await montar(tester);

    expect(find.byKey(const Key('comunidad-problema')), findsOneWidget);
  });
}

class _Comunidades implements RepositorioComunidades {
  final Map<String, Comunidad> guardadas = {};

  /// Lo que esta pantalla **no** puede tocar, y que la prueba del renombrado
  /// vigila: quién pertenece y quién está esperando.
  final Map<String, String> pertenencias = {};
  final Map<String, String> solicitudesEsperando = {};

  bool falla = false;

  @override
  Future<Comunidad?> deEntrenador(String entrenadorId) async {
    if (falla) throw const FalloDeDatos('no se pudo leer');
    return guardadas[entrenadorId];
  }

  @override
  Future<Comunidad?> obtener(String comunidadId) async =>
      guardadas[comunidadId];

  @override
  Future<List<Comunidad>> lasQueSePuedenOfrecer() async =>
      guardadas.values.toList();

  @override
  Future<void> guardar(Comunidad comunidad) async =>
      guardadas[comunidad.id] = comunidad;
}
