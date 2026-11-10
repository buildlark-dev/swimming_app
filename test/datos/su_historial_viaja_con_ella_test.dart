/// Su historial no se queda en un teléfono.
///
/// **Hallazgo del recorrido de la feature 009, en el Pixel 7.** La pantalla
/// del macrociclo recibía `registrosLocales`, así que lo que el nadador ve
/// —«Sesiones cumplidas: 2 de 10»— salía solo del almacén de ese dispositivo.
/// El servidor lo tenía: desde la feature 003 los registros se envían, y
/// `RegistrosFirestore` sabe leerlos. Nadie los leía para él.
///
/// Se notaba en el sitio peor posible: cambiar de móvil o reinstalar dejaba la
/// cuenta en cero, con el dato a salvo en el servidor, justo debajo de una
/// frase que dice «Lo que ya habías anotado sigue ahí».
///
/// Lo que **no** cambia es escribir. Escribir sigue yendo al dispositivo y
/// encolándose después (garantía G1 de la feature 003): un nadador a pie de
/// piscina no espera a la red para anotar, y eso no se toca. Lo que cambia es
/// leer.
///
/// Las tres reglas de esta unión, y por qué:
///
/// - **gana lo local**. Lo que todavía no se ha enviado es lo más reciente que
///   él escribió; si el servidor mandara, una respuesta recién puesta se vería
///   reemplazada por la anterior delante de sus ojos.
/// - **sin red se trabaja igual**. Si el servidor no contesta, se devuelve lo
///   local y nadie se entera: lo contrario sería dejarle sin su plan por un
///   problema de cobertura, que es lo que la feature 003 prohíbe (A8).
/// - **no se escribe en el servidor al leer**. Traerse lo del servidor al
///   almacén parecería cómodo y sería otra fuente de verdad que mantener.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/registros_de_las_dos_partes.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Un repositorio en memoria que puede negarse, como el servidor sin red.
class _Registros implements RepositorioRegistros {
  /// Se pone a true para hacer de servidor sin red.
  bool seNiega = false;
  final guardados = <String, RegistroDeSesion>{};

  /// Para comprobar que nadie escribe donde no debe.
  final escrituras = <String>[];

  void sembrar(RegistroDeSesion registro) =>
      guardados[registro.id] = registro;

  void _comprobar() {
    if (seNiega) throw const FalloDeDatos('sin red');
  }

  @override
  Future<RegistroDeSesion?> obtener(String id) async {
    _comprobar();
    return guardados[id];
  }

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async {
    _comprobar();
    return guardados.values
        .where((r) => r.nadadorId == nadadorId && r.planId == planId)
        .toList();
  }

  @override
  Future<void> guardar(RegistroDeSesion registro) async {
    _comprobar();
    escrituras.add(registro.id);
    guardados[registro.id] = registro;
  }

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {
    'de': nadadorId,
  };

  @override
  Future<void> eliminarDe(String nadadorId) async {
    escrituras.add('borrado:$nadadorId');
    guardados.removeWhere((_, r) => r.nadadorId == nadadorId);
  }

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      guardados.values.map((r) => r.nadadorId).toSet();
}

void main() {
  RegistroDeSesion anotado(
    String sesionId, {
    bool realizada = true,
    int? rpe,
    DateTime? cuando,
  }) => RegistroDeSesion(
    nadadorId: 'n-ana',
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: '3.6.0',
    realizada: realizada,
    rpePercibido: rpe,
    registradoEn: cuando ?? DateTime(2026, 11, 2),
  );

  late _Registros local;
  late _Registros servidor;
  late RegistrosDeLasDosPartes juntos;

  setUp(() {
    local = _Registros();
    servidor = _Registros();
    juntos = RegistrosDeLasDosPartes(local: local, servidor: servidor);
  });

  group('leer', () {
    test('en un teléfono nuevo se ve lo que hay en el servidor', () async {
      // El caso del hallazgo: el almacén está vacío porque es otro aparato.
      servidor.sembrar(anotado('s-1'));
      servidor.sembrar(anotado('s-2'));

      final suyos = await juntos.obtenerDePlan('n-ana', 'p1');

      expect(
        suyos.map((r) => r.sesionId).toSet(),
        {'s-1', 's-2'},
        reason: 'su historial se quedaba en el teléfono donde lo escribió',
      );
    });

    test('se juntan los dos lados, sin repetir', () async {
      servidor.sembrar(anotado('s-1'));
      local.sembrar(anotado('s-1'));
      local.sembrar(anotado('s-2'));

      final suyos = await juntos.obtenerDePlan('n-ana', 'p1');

      expect(suyos, hasLength(2));
      expect(suyos.map((r) => r.sesionId).toSet(), {'s-1', 's-2'});
    });

    test('gana lo local, que es lo más reciente que él escribió', () async {
      // Lo que aún no se ha enviado es su última palabra. Si mandara el
      // servidor, vería cómo su respuesta recién puesta vuelve atrás sola.
      servidor.sembrar(anotado('s-1', rpe: 4));
      local.sembrar(anotado('s-1', rpe: 9));

      final suyos = await juntos.obtenerDePlan('n-ana', 'p1');

      expect(suyos.single.rpePercibido, 9);
    });

    test('sin red se devuelve lo local y no se nota', () async {
      // Garantía A8: un problema de cobertura no le deja sin su plan.
      local.sembrar(anotado('s-1'));
      servidor.seNiega = true;

      final suyos = await juntos.obtenerDePlan('n-ana', 'p1');

      expect(suyos.map((r) => r.sesionId).toList(), ['s-1']);
    });

    test('sin red y sin nada local, una lista vacía y no un fallo', () async {
      servidor.seNiega = true;

      expect(await juntos.obtenerDePlan('n-ana', 'p1'), isEmpty);
    });

    test('obtener uno también mira los dos lados', () async {
      servidor.sembrar(anotado('s-1'));

      expect((await juntos.obtener(anotado('s-1').id))?.sesionId, 's-1');
    });

    test('y ahí también gana lo local', () async {
      servidor.sembrar(anotado('s-1', rpe: 4));
      local.sembrar(anotado('s-1', rpe: 9));

      expect((await juntos.obtener(anotado('s-1').id))?.rpePercibido, 9);
    });
  });

  group('escribir, que no cambia', () {
    test('guardar escribe en el dispositivo y NO en el servidor', () async {
      // La garantía G1 de la feature 003: anotar no espera a la red. El envío
      // lo hace la bandeja de salida, después y por su cuenta.
      await juntos.guardar(anotado('s-1'));

      expect(local.escrituras, ['n-ana|p1|s-1|3.6.0']);
      expect(
        servidor.escrituras,
        isEmpty,
        reason: 'anotar pasó a depender de la red',
      );
    });

    test('guardar funciona con el servidor caído', () async {
      servidor.seNiega = true;

      await expectLater(juntos.guardar(anotado('s-1')), completes);
    });

    test('borrar solo toca el dispositivo, y es deliberado', () async {
      // **Borrar en el servidor está prohibido desde el cliente**, y la regla
      // lo dice: «el derecho al borrado del principio V se ejerce por la vía
      // del servidor, que puede dejar constancia de que se ejerció». Juntar
      // las dos lecturas no puede abrir esa puerta por la espalda.
      local.sembrar(anotado('s-1'));
      servidor.sembrar(anotado('s-1'));

      await juntos.eliminarDe('n-ana');

      expect(local.guardados, isEmpty);
      expect(
        servidor.guardados,
        isNotEmpty,
        reason: 'borrar desde el cliente llegó al servidor',
      );
    });
  });
}
