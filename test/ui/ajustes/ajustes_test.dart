/// Garantías H19 a H30 — Ajustes.
///
/// Aquí los tres derechos de la Ley 1581 dejan de ser inalcanzables. Están
/// construidos en el dominio desde la feature 004, con sus pruebas, y **ninguna
/// pantalla los usaba**: `DerechosDelTitular` no se construía en ningún sitio
/// de la interfaz.
///
/// El cerrojo que más importa de este archivo es H21: corregir un apellido no
/// puede mover la constancia de qué versión de los términos aceptó alguien ni
/// cuándo. Eso es un registro legal, no un campo.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/dominio/consentimiento/constancia.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/dominio/datos_personales/derechos_del_titular.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/ui/ajustes/pantalla_ajustes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final aceptadaEn = DateTime(2026, 9, 15, 10);

  Perfil perfilDePrueba({String nombre = 'Ana María Restrepo'}) => Perfil(
    nombre: nombre,
    fechaNacimiento: DateTime(2014, 3, 7),
    pais: 'CO',
    terminos: AceptacionDeTerminos(version: 'v1', aceptadaEn: aceptadaEn),
  );

  Future<_Operaciones> montar(
    WidgetTester tester, {
    Perfil? perfil,
    ConstanciaDeConsentimiento? constancia,
    String? nadadorId = 'n1',
    bool constanciasQueRevientan = false,
  }) async {
    SharedPreferences.setMockInitialValues({});

    // Ajustes es una lista larga, y un `ListView` no construye lo que no se
    // ve. Con una pantalla alta se monta entera y las aserciones hablan de lo
    // que hay, no de lo que cabe.
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final operaciones = _Operaciones();
    final nadadores = RepositorioNadadoresMemoria();
    await nadadores.guardar(
      const Nadador(id: 'n1', nombre: 'Ana María Restrepo'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaAjustes(
          uid: 'u1',
          nadadorId: nadadorId,
          repositorioPerfil: _PerfilSembrado(perfil ?? perfilDePrueba()),
          operaciones: operaciones,
          identidad: _Identidad(),
          constancias: constanciasQueRevientan
              ? const _ConstanciasQueRevientan()
              : _Constancias(constancia),
          derechos: DerechosDelTitular(
            nadadores: nadadores,
            registros: _Registros(),
            asignaciones: RepositorioAsignacionesMemoria(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return operaciones;
  }

  group('H19 — solo lo mío', () {
    testWidgets('muestra mis datos', (tester) async {
      await montar(tester);

      expect(find.text('Ana María Restrepo'), findsWidgets);
      expect(find.byKey(const Key('ajustes-mis-datos')), findsOneWidget);
    });

    testWidgets('no hay por dónde ver los datos de otra persona', (
      tester,
    ) async {
      await montar(tester);

      // Ni un selector de nadador, ni una lista, ni un campo de identificador.
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.byKey(const Key('ajustes-otro-nadador')), findsNothing);
    });
  });

  group('H20 y H21 — lo que aceptó', () {
    testWidgets('muestra la versión que aceptó y cuándo', (tester) async {
      await montar(tester);

      final seccion = find.byKey(const Key('ajustes-lo-que-acepte'));
      expect(seccion, findsOneWidget);
      expect(find.textContaining('v1'), findsWidgets);
      expect(find.textContaining('15/9/2026'), findsWidgets);
    });

    testWidgets('**corregir el nombre no manda la versión de los términos**', (
      tester,
    ) async {
      final operaciones = await montar(tester);

      await tester.tap(find.byKey(const Key('ajustes-corregir')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ajustes-campo-nombre')),
        'Ana María Restrepo Vélez',
      );
      await tester.tap(find.byKey(const Key('ajustes-guardar')));
      await tester.pumpAndSettle();

      expect(operaciones.corregido, isNotNull);
      expect(operaciones.corregido!['nombre'], 'Ana María Restrepo Vélez');
      expect(
        operaciones.guardoPerfilCompleto,
        isFalse,
        reason:
            '`guardarPerfil` re-sella `terminos.aceptadaEn` con la fecha '
            'de hoy. Corregir un apellido por esa vía diría que la persona '
            'aceptó hoy una versión que nadie le ha mostrado',
      );
    });
  });

  group('H24 y H25 — los tres derechos', () {
    testWidgets('qué se guarda, dicho en frases', (tester) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('ajustes-que-se-guarda')));
      await tester.pumpAndSettle();

      // Frases, no campos: es `QueSeGuarda.enPalabras` del dominio.
      expect(find.textContaining('Su nombre:'), findsWidgets);
      expect(find.textContaining('No hay fotos, ni videos'), findsWidgets);
    });

    testWidgets('llevárselo está a la vista', (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('ajustes-exportar')), findsOneWidget);
    });

    testWidgets('y la supresión también', (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('ajustes-suprimir')), findsOneWidget);
    });

    testWidgets('sin perfil de nadador, los derechos no se ofrecen en falso', (
      tester,
    ) async {
      // Una cuenta de entrenador no tiene ficha de nadador: no hay registros
      // ni asignaciones suyas que exportar o borrar.
      await montar(tester, nadadorId: null);

      expect(
        find.byKey(const Key('ajustes-sin-datos-de-nadador')),
        findsOneWidget,
      );
    });
  });

  group('H27 — la supresión pide dos pasos', () {
    testWidgets('el primero no borra nada', (tester) async {
      final operaciones = await montar(tester);

      await tester.tap(find.byKey(const Key('ajustes-suprimir')));
      await tester.pumpAndSettle();

      expect(operaciones.suprimio, isFalse);
    });

    testWidgets('y dice qué se borra y **qué sobrevive**', (tester) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('ajustes-suprimir')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Queda el registro de que hubo consentimiento'),
        findsWidgets,
        reason:
            'Son las palabras del dominio, y van a la vista: no en letra '
            'pequeña',
      );
    });

    testWidgets('el segundo paso es el que borra', (tester) async {
      final operaciones = await montar(tester);

      await tester.tap(find.byKey(const Key('ajustes-suprimir')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ajustes-suprimir-de-verdad')));
      await tester.pumpAndSettle();

      expect(operaciones.suprimio, isTrue);
    });
  });

  group('H23 y H30 — salir, y la contraseña', () {
    testWidgets('cerrar sesión está aquí', (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('ajustes-cerrar-sesion')), findsOneWidget);
    });

    testWidgets('la contraseña se cambia por correo, sin pedirla aquí', (
      tester,
    ) async {
      await montar(tester);

      expect(find.byKey(const Key('ajustes-cambiar-clave')), findsOneWidget);

      // Ningún campo de contraseña en toda la pantalla.
      final campos = tester.widgetList<TextField>(find.byType(TextField));
      for (final campo in campos) {
        expect(
          campo.obscureText,
          isFalse,
          reason:
              'Una pantalla que pide la contraseña nueva sin comprobar '
              'quién la escribe deja que cualquiera con el teléfono '
              'desbloqueado se quede con la cuenta',
        );
      }
    });
  });

  group('H29 — la apariencia', () {
    testWidgets('se puede elegir', (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('ajustes-apariencia')), findsOneWidget);
    });
  });

  group('H26 — nada de lo exportado se registra', () {
    // **Se lee el fuente.** Una traza no se ve en una prueba de widget: no
    // falla nada, no cambia la pantalla, y el dato acaba en la consola del
    // navegador o en los registros del servidor de hosting. Es la garantía
    // A17 de la feature 006 aplicada aquí, y el archivo que exporta es el
    // único sitio donde puede pasar.
    final fuente = File('lib/ui/ajustes/mis_derechos.dart').readAsStringSync();

    test('la prueba no pasa por vacía', () {
      expect(fuente, contains('exportar'));
      expect(fuente, contains('Clipboard'));
    });

    test('ni print, ni debugPrint, ni log, ni analítica', () {
      for (final via in [
        'print(',
        'debugPrint(',
        'developer.log(',
        'log(',
        'FirebaseAnalytics',
        'logEvent',
      ]) {
        expect(
          fuente,
          isNot(contains(via)),
          reason:
              'Lo que se exporta son los datos personales de alguien. '
              '«$via» los sacaría de la pantalla y los dejaría en un sitio '
              'que esa persona no eligió',
        );
      }
    });

    test('lo exportado va al portapapeles, que es de quien lo pidió', () {
      expect(fuente, contains('Clipboard.setData'));
    });
  });

  group('cargar a medias no deja Ajustes girando', () {
    testWidgets('se ve lo que sí hay, y se dice qué no se pudo leer', (
      tester,
    ) async {
      // **Lo encontró el teléfono, no una prueba.** Con la cuenta de una
      // nadadora, `Ajustes` se quedaba con la rueda dando vueltas y no había
      // forma de llegar a los derechos de la Ley 1581 ni a pedir el borrado.
      // La causa era una fecha con otra forma en el documento de
      // consentimiento, pero el defecto es este: que un fallo al leer **una**
      // cosa deje la pantalla entera sin aparecer. Con el entrenador no
      // pasaba, porque su cuenta no tiene constancia que leer.
      await montar(tester, constanciasQueRevientan: true);

      expect(
        find.byKey(const Key('ajustes-cargando')),
        findsNothing,
        reason: 'Girar para siempre no se distingue de estar tardando',
      );
      expect(find.byKey(const Key('ajustes-mis-datos')), findsOneWidget);
      expect(find.byKey(const Key('ajustes-no-se-pudo-leer')), findsOneWidget);
    });

    testWidgets('y se puede llegar a borrar los datos igual', (tester) async {
      await montar(tester, constanciasQueRevientan: true);

      expect(find.byKey(const Key('ajustes-suprimir')), findsOneWidget);
    });
  });
}

class _PerfilSembrado implements RepositorioPerfil {
  const _PerfilSembrado(this._perfil);

  final Perfil _perfil;

  @override
  Future<Perfil> obtener(String uid) async => _perfil;
}

class _Constancias implements LectorDeConstancias {
  const _Constancias(this._constancia);

  final ConstanciaDeConsentimiento? _constancia;

  @override
  Future<ConstanciaDeConsentimiento?> de(String nadadorId) async => _constancia;
}

/// Lo que hacía el documento con la fecha en texto: reventar con un `Error`,
/// que no es una `Exception` y se escapa de los `catch` por tipo.
class _ConstanciasQueRevientan implements LectorDeConstancias {
  const _ConstanciasQueRevientan();

  @override
  Future<ConstanciaDeConsentimiento?> de(String nadadorId) async =>
      throw TypeError();
}

class _Operaciones implements OperacionesDelServidor {
  // La feature 008 aÃ±adiÃ³ esta operaciÃ³n a la interfaz. Este doble no la
  // usa: lo que prueba es otro camino.
  @override
  Future<void> cerrarPeticion({
    required String nadadorId,
    required String decision,
    String? planId,
    String? motivo,
  }) async {}

  Map<String, dynamic>? corregido;
  bool guardoPerfilCompleto = false;
  bool suprimio = false;

  @override
  Future<PerfilGuardado> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async {
    guardoPerfilCompleto = true;
    return const PerfilGuardado(esMenor: false, nadadorId: 'n1');
  }

  @override
  Future<PerfilCorregido> corregirPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
  }) async {
    corregido = cuerpoDeCorreccion(
      nombre: nombre,
      fechaNacimiento: fechaNacimiento,
      pais: pais,
    );
    return PerfilCorregido(nombre: nombre, esMenor: true);
  }

  @override
  Future<DatosSuprimidos> suprimirMisDatos() async {
    suprimio = true;
    return const DatosSuprimidos(
      registrosEliminados: 3,
      asignacionesRetiradas: 1,
      perfilEliminado: true,
      cuentaEliminada: true,
    );
  }

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

class _Identidad implements Identidad {
  bool pidioClave = false;
  bool cerro = false;

  @override
  Future<EstadoDeCuenta> actual() async => const SinSesion();

  @override
  Stream<EstadoDeCuenta> get cambios => const Stream<EstadoDeCuenta>.empty();

  @override
  Future<void> entrar({required String correo, required String clave}) async {}

  @override
  Future<void> crearCuenta({
    required String correo,
    required String clave,
  }) async {}

  @override
  Future<void> cerrarSesion() async => cerro = true;

  @override
  Future<void> pedirCambioDeClave() async => pidioClave = true;
}

class _Registros implements RepositorioRegistros {
  @override
  Future<RegistroDeSesion?> obtener(String id) async => null;

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async =>
      const [];

  @override
  Future<void> guardar(RegistroDeSesion registro) async {}

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async =>
      <String, dynamic>{'registros': const []};

  @override
  Future<void> eliminarDe(String nadadorId) async {}

  @override
  Future<Set<String>> nadadoresConRegistros() async => const {};
}
