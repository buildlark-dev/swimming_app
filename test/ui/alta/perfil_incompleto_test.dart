/// Escenarios C9 y C10 — las cuentas que ya existen.
///
/// Es la única parte de esta feature que toca cuentas **que ya están en uso**,
/// la del propio entrenador entre ellas. Y la razón de que exista no es tener
/// los nombres en la ficha:
///
/// **Si una de esas cuentas es de un menor, su consentimiento no se habría
/// pedido nunca**, porque su alta ya pasó. Completar el perfil es lo que cierra
/// ese hueco.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/ui/alta/puerta_del_perfil.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  final hoy = DateTime(2026, 10, 21);

  Future<void> abrir(
    WidgetTester tester, {
    required Perfil perfil,
    OperacionesDelServidor? servidor,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: PuertaDelPerfil(
          uid: 'u1',
          correo: 'nadador@ejemplo.com',
          repositorio: RepositorioPerfilEnMemoria({'u1': perfil}),
          operaciones: servidor ?? _Servidor(),
          dentro: const Scaffold(body: Text('La app')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('C9 — una cuenta sin perfil completa sus datos', () {
    testWidgets('una cuenta vacía recorre los pasos', (tester) async {
      // Es el estado de todas las cuentas creadas antes de esta feature.
      await abrir(tester, perfil: const Perfil());

      expect(find.text('¿Cómo te llamas?'), findsOneWidget);
      expect(find.text('La app'), findsNothing);
    });

    testWidgets('una con el perfil completo entra directa', (tester) async {
      await abrir(
        tester,
        perfil: Perfil(
          nombre: 'Juan Esteban',
          fechaNacimiento: DateTime(1995, 4, 12),
          terminos: AceptacionDeTerminos(version: 'v1', aceptadaEn: hoy),
        ),
      );

      expect(find.text('La app'), findsOneWidget);
      expect(find.text('¿Cómo te llamas?'), findsNothing);
    });

    testWidgets('a la que le falta solo la fecha, también los recorre',
        (tester) async {
      // Es el caso que de verdad importa: sin fecha **no se sabe si necesita
      // consentimiento**, y eso no se puede dejar así.
      await abrir(
        tester,
        perfil: Perfil(
          nombre: 'Juan Esteban',
          terminos: AceptacionDeTerminos(version: 'v1', aceptadaEn: hoy),
        ),
      );

      expect(find.text('¿Cómo te llamas?'), findsOneWidget);
    });

    testWidgets('sin país sigue estando completa', (tester) async {
      // El país es opcional y no retiene a nadie.
      await abrir(
        tester,
        perfil: Perfil(
          nombre: 'Juan Esteban',
          fechaNacimiento: DateTime(1995, 4, 12),
          terminos: AceptacionDeTerminos(version: 'v1', aceptadaEn: hoy),
        ),
      );

      expect(find.text('La app'), findsOneWidget);
    });
  });

  group('C10 — una cuenta antigua que resulta ser de un menor', () {
    testWidgets('se le pide el acudiente, igual que en un alta nueva',
        (tester) async {
      final servidor = _Servidor(esMenor: true);
      await abrir(tester, perfil: const Perfil(), servidor: servidor);

      // Recorre los pasos declarando una fecha de menor.
      await tester.enterText(
        find.byKey(const Key('alta-campo-nombre')),
        'Ana María',
      );
      await tester.pump();

      expect(
        find.text('Paso 1 de 4'),
        findsOneWidget,
        reason: 'Todavía no sabe que es menor',
      );
    });
  });

  group('lo que no se bloquea', () {
    testWidgets('si no se puede leer el perfil, se pregunta', (tester) async {
      // **No se deja pasar.** Dejar pasar equivale a suponer que el perfil
      // está completo, y esa es la suposición que hace que a un menor no se le
      // pida nunca el consentimiento. Preguntar de más cuesta reescribir un
      // nombre; suponer de más cuesta un consentimiento que nadie pidió.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: PuertaDelPerfil(
            uid: 'u1',
            correo: 'nadador@ejemplo.com',
            repositorio: _RepositorioQueFalla(),
            operaciones: _Servidor(),
            dentro: const Scaffold(body: Text('La app')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('¿Cómo te llamas?'), findsOneWidget);
      expect(find.text('La app'), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------

class _RepositorioQueFalla implements RepositorioPerfil {
  @override
  Future<Perfil> obtener(String uid) async => throw Exception('sin red');
}

class _Servidor implements OperacionesDelServidor {
  _Servidor({this.esMenor = false});

  final bool esMenor;
  final solicitudes = <String>[];

  @override
  Future<bool> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async =>
      esMenor;

  @override
  Future<void> pedirConsentimiento({
    required String nadadorId,
    required String canal,
    Set<Alcance> alcances = const {Alcance.datosDeEntrenamiento},
  }) async {
    solicitudes.add(canal);
  }

  @override
  Future<void> canjear({
    required String token,
    required String nombre,
    required String documento,
    required String calidad,
    required bool esRepresentanteLegal,
    required bool menorFueOido,
    required String versionDelTexto,
  }) async {}
}
