import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Garantía A9 — el almacenamiento local está particionado por cuenta.
///
/// El grupo de Iniciación Avanzada son niños de 7 a 10 años, y los hermanos
/// comparten teléfono. Un registro que aparece bajo la cuenta equivocada es el
/// dato personal de un menor en manos de otra persona, aunque esa persona sea
/// su hermano.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferencias;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferencias = await SharedPreferences.getInstance();
  });

  AlmacenPreferencias almacenDe(String? cuentaId) => AlmacenPreferencias(
        preferencias: preferencias,
        cuentaId: cuentaId,
      );

  group('dos cuentas en el mismo dispositivo', () {
    test('no se leen lo que escribió la otra', () async {
      final hermanoMayor = almacenDe('u-mayor');
      final hermanaMenor = almacenDe('u-menor');

      await hermanoMayor.escribir('registros', 'r1', {'rpe': 8});
      await hermanaMenor.escribir('registros', 'r1', {'rpe': 3});

      expect((await hermanoMayor.leer('registros', 'r1'))!['rpe'], 8);
      expect((await hermanaMenor.leer('registros', 'r1'))!['rpe'], 3);
    });

    test('la misma clave en los dos no se pisa', () async {
      // Los identificadores de registro son deterministas y se construyen con
      // el nadadorId, así que en la práctica no chocarían. La partición no
      // depende de eso: si algún día cambia la forma del identificador, esto
      // sigue sosteniéndose.
      await almacenDe('u-a').escribir('registros', 'misma', {'de': 'a'});
      await almacenDe('u-b').escribir('registros', 'misma', {'de': 'b'});

      expect((await almacenDe('u-a').leer('registros', 'misma'))!['de'], 'a');
      expect((await almacenDe('u-b').leer('registros', 'misma'))!['de'], 'b');
    });

    test('leerTodo de una no devuelve nada de la otra', () async {
      await almacenDe('u-a').escribir('registros', 'r1', {'de': 'a'});
      await almacenDe('u-a').escribir('registros', 'r2', {'de': 'a'});
      await almacenDe('u-b').escribir('registros', 'r3', {'de': 'b'});

      final deA = await almacenDe('u-a').leerTodo('registros');
      final deB = await almacenDe('u-b').leerTodo('registros');

      expect(deA.keys, unorderedEquals(['r1', 'r2']));
      expect(deB.keys, ['r3']);
    });

    test('la bandeja de salida tampoco se mezcla', () async {
      // Es la colección que más importa: lo que está esperando a enviarse.
      // Si se mezclara, un registro saldría atribuido al hermano equivocado.
      await almacenDe('u-a').escribir('envios', 'e1', {'intentos': 0});
      await almacenDe('u-b').escribir('envios', 'e2', {'intentos': 0});

      expect((await almacenDe('u-a').leerTodo('envios')).keys, ['e1']);
      expect((await almacenDe('u-b').leerTodo('envios')).keys, ['e2']);
    });
  });

  group('vaciar al cerrar sesión', () {
    test('borra todo lo de esa cuenta, en todas sus colecciones', () async {
      final almacen = almacenDe('u-a');
      await almacen.escribir('registros', 'r1', {'rpe': 7});
      await almacen.escribir('envios', 'e1', {'intentos': 0});
      await almacen.escribir('planes', 'p1', {'nombre': 'Microciclo'});

      await almacen.vaciar();

      expect(await almacen.leerTodo('registros'), isEmpty);
      expect(await almacen.leerTodo('envios'), isEmpty);
      expect(await almacen.leerTodo('planes'), isEmpty);
    });

    test('no toca lo de la otra cuenta, porque también es de alguien', () async {
      await almacenDe('u-a').escribir('registros', 'r1', {'de': 'a'});
      await almacenDe('u-b').escribir('registros', 'r2', {'de': 'b'});

      await almacenDe('u-a').vaciar();

      expect(await almacenDe('u-a').leerTodo('registros'), isEmpty);
      expect(
        (await almacenDe('u-b').leerTodo('registros')).keys,
        ['r2'],
        reason: 'Cerrar la sesión de uno no puede borrar lo del otro. Lo que '
            'el hermano escribió sin conexión sigue esperando a enviarse',
      );
    });

    test('tras vaciar, la misma cuenta empieza limpia', () async {
      final almacen = almacenDe('u-a');
      await almacen.escribir('registros', 'r1', {'rpe': 7});
      await almacen.vaciar();

      expect(await almacen.leer('registros', 'r1'), isNull);
    });
  });

  group('antes de iniciar sesión', () {
    test('lo escrito sin cuenta no aparece bajo ninguna cuenta', () async {
      await almacenDe(null).escribir('registros', 'r1', {'suelto': true});

      expect(await almacenDe('u-a').leer('registros', 'r1'), isNull);
      expect(await almacenDe(null).leer('registros', 'r1'), isNotNull);
    });

    test('vaciar una cuenta no se lleva lo que no es de nadie', () async {
      await almacenDe(null).escribir('registros', 'r1', {'suelto': true});
      await almacenDe('u-a').escribir('registros', 'r2', {'de': 'a'});

      await almacenDe('u-a').vaciar();

      expect(await almacenDe(null).leer('registros', 'r1'), isNotNull);
    });
  });

  group('borrar una colección sigue respetando la partición', () {
    test('borrarColeccion no cruza cuentas', () async {
      await almacenDe('u-a').escribir('registros', 'r1', {'de': 'a'});
      await almacenDe('u-b').escribir('registros', 'r2', {'de': 'b'});

      await almacenDe('u-a').borrarColeccion('registros');

      expect(await almacenDe('u-a').leerTodo('registros'), isEmpty);
      expect((await almacenDe('u-b').leerTodo('registros')).keys, ['r2']);
    });
  });
}
