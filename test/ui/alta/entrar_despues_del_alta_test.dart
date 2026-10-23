/// Que «Entrar» entre.
///
/// **Esta prueba existe por un fallo que se vio en la app y en ninguna
/// prueba.** Quien acababa de crear su cuenta terminaba el alta, leía «Ya estás
/// dentro», pulsaba «Entrar»… y volvía a «¿Cómo te llamas?». Lo mismo al cerrar
/// sesión y volver a entrar. La única salida era cerrar la PWA y abrirla de
/// nuevo.
///
/// La causa son dos suposiciones que la puerta hacía sobre una lectura:
///
/// 1. Que **justo después de guardar**, volver a leer el perfil devuelve lo que
///    se acaba de guardar. No tiene por qué: lo escribe el servidor y el
///    cliente lee por su cuenta.
/// 2. Que **una lectura que falla significa que no hay perfil**. Recién
///    iniciada la sesión, la lectura puede fallar porque el cliente todavía no
///    lleva el token nuevo, y eso no dice nada del perfil.
///
/// Las dos acababan en el mismo sitio —el alta— y por eso el síntoma parecía
/// uno. Lo que cambia no es que se deje pasar sin más: es que **el alta recién
/// terminada se cree** (la guardó el servidor y contestó) y que **una lectura
/// que falla se reintente** antes de concluir nada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/alta/pantalla_alta.dart';
import 'package:natacion_app/ui/alta/puerta_del_perfil.dart';
import 'package:natacion_app/ui/tema/tema.dart';
import 'package:provider/provider.dart';

void main() {
  final completo = Perfil(
    nombre: 'Ana María',
    fechaNacimiento: DateTime(1995, 4, 12),
    terminos: AceptacionDeTerminos(
      version: 'v1',
      aceptadaEn: DateTime(2026, 10, 21),
    ),
  );

  Future<void> abrir(
    WidgetTester tester, {
    required RepositorioPerfil repositorio,
  }) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: PuertaDelPerfil(
          uid: 'u1',
          correo: 'nadador@ejemplo.com',
          repositorio: repositorio,
          operaciones: _ServidorQueAcepta(),
          dentro: const Scaffold(body: Text('Mi entrenamiento')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Recorre el alta de un adulto hasta el final, por la puerta de verdad.
  ///
  /// Escribe a través del estado que la propia puerta creó, porque lo que se
  /// prueba es lo que pasa **después** de terminar, no cómo se rellena.
  Future<void> terminarElAlta(WidgetTester tester) async {
    final estado = Provider.of<EstadoAlta>(
      tester.element(find.byType(PantallaAlta)),
      listen: false,
    )
      ..escribirNombre('Ana María')
      ..escribirNacimiento(DateTime(1995, 4, 12))
      ..aceptarTerminos(aceptados: true);

    while (!estado.esElUltimo) {
      estado.avanzar();
    }
    await tester.pump();

    await tester.tap(find.byKey(const Key('alta-terminar')));
    await tester.pumpAndSettle();
  }

  group('al terminar el alta, «Entrar» entra', () {
    testWidgets('aunque la lectura del perfil todavía no vea lo guardado',
        (tester) async {
      // El caso real: el servidor guardó y contestó, y el cliente sigue
      // leyendo vacío. Antes volvía al alta; es el fallo que se reportó.
      await abrir(tester, repositorio: RepositorioPerfilEnMemoria());
      await terminarElAlta(tester);

      expect(find.text('Ya estás dentro'), findsOneWidget);

      await tester.tap(find.byKey(const Key('alta-continuar')));
      await tester.pumpAndSettle();

      expect(
        find.text('Mi entrenamiento'),
        findsOneWidget,
        reason: 'El alta la guardó el servidor y contestó. Devolver al alta a '
            'quien acaba de terminarla es pedirle los mismos datos dos veces',
      );
      expect(find.text('¿Cómo te llamas?'), findsNothing);
    });

    testWidgets('y aunque la lectura falle', (tester) async {
      await abrir(tester, repositorio: _RepositorioQueFalla());
      await terminarElAlta(tester);

      await tester.tap(find.byKey(const Key('alta-continuar')));
      await tester.pumpAndSettle();

      expect(find.text('Mi entrenamiento'), findsOneWidget);
    });
  });

  group('una lectura que falla se reintenta antes de concluir nada', () {
    test('el primer fallo no se toma por respuesta', () async {
      final debajo = _RepositorioQueFalla(vecesQueFalla: 2, luego: completo);
      final repositorio = RepositorioPerfilConReintentos(
        debajo,
        espera: (_) async {},
      );

      expect((await repositorio.obtener('u1')).nombre, completo.nombre);
      expect(debajo.intentos, 3);
    });

    test('pero no se insiste para siempre', () async {
      // Un servidor caído tiene que acabar en el fallo, que es lo que deja
      // ver la salida «Entrar de todos modos». Insistir sin fin es la rueda
      // que no se para.
      final debajo = _RepositorioQueFalla(vecesQueFalla: 99);
      final repositorio = RepositorioPerfilConReintentos(
        debajo,
        espera: (_) async {},
      );

      await expectLater(repositorio.obtener('u1'), throwsA(isA<Exception>()));
      expect(debajo.intentos, 3);
    });

    test('un perfil vacío no es un fallo y no se reintenta', () async {
      // Es el estado legítimo de toda cuenta creada antes de la feature 006.
      // Reintentarlo retrasaría el alta de quien sí tiene que recorrerla.
      final debajo = _RepositorioQueFalla(vecesQueFalla: 0);
      final repositorio = RepositorioPerfilConReintentos(
        debajo,
        espera: (_) async {},
      );

      expect((await repositorio.obtener('u1')).estaCompleto, isFalse);
      expect(debajo.intentos, 1);
    });

    testWidgets('con un fallo al abrir, se entra sin pasar por el alta',
        (tester) async {
      await abrir(
        tester,
        repositorio: RepositorioPerfilConReintentos(
          _RepositorioQueFalla(vecesQueFalla: 1, luego: completo),
          espera: (_) async {},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Mi entrenamiento'),
        findsOneWidget,
        reason: 'Es el caso de cerrar sesión y volver a entrar: la lectura '
            'falla una vez porque el cliente aún no lleva el token nuevo',
      );
    });
  });
}

// ---------------------------------------------------------------------------

class _RepositorioQueFalla implements RepositorioPerfil {
  _RepositorioQueFalla({this.vecesQueFalla = 99, this.luego});

  final int vecesQueFalla;
  final Perfil? luego;
  int intentos = 0;

  @override
  Future<Perfil> obtener(String uid) async {
    intentos++;
    if (intentos <= vecesQueFalla) {
      throw Exception('no se pudo leer el perfil');
    }
    return luego ?? const Perfil();
  }
}

class _ServidorQueAcepta implements OperacionesDelServidor {
  @override
  Future<PerfilGuardado> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async =>
      const PerfilGuardado(esMenor: false, nadadorId: 'n1');

  @override
  Future<void> pedirConsentimiento({
    required String nadadorId,
    required String canal,
    Set<Alcance> alcances = const {Alcance.datosDeEntrenamiento},
  }) async {}

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
