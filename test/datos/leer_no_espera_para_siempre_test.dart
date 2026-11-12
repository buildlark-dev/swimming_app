/// Leer **no espera para siempre**, ni siquiera cuando el servidor no contesta.
///
/// Hallazgo del recorrido, cerrando T088 de la feature 004 —que es C1 de la
/// 003, «el escenario que justifica la feature»—. Con el avión puesto y la app
/// cerrada del todo, Ana la abre y `Ver Plan` **se queda girando para
/// siempre**: ni error, ni contenido, ni la sesión de hoy. En logcat, solo el
/// watch stream de Firestore reintentando.
///
/// La caché estaba, y con persistencia activada: el fichero
/// `firestore.emuladores.demo-natacion.(default)` existe en el dispositivo. El
/// dato estaba ahí y la pantalla no lo alcanzaba.
///
/// La causa es la misma que la de `preguntar_no_espera_al_servidor_test`, del
/// lado de leer: el SDK de Firestore no lanza cuando no hay red, **deja el
/// Future abierto**. `_delServidor` atrapaba cualquier fallo —eso ya se
/// arregló— pero un Future que no termina no es un fallo que se pueda atrapar.
///
/// Así que la regla, dicha entera: **lo que cuelga de la red se acota.** Su
/// historial está en el teléfono; esperar al servidor por él es cambiar su
/// pantalla por una promesa.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/registros_de_las_dos_partes.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

import '../dominio/analisis/dobles_de_analisis.dart';

/// Un servidor que **acepta y no contesta**, como Firestore sin red.
class _ServidorMudo implements RepositorioRegistros {
  final _colgados = <Completer<void>>[];

  int lecturas = 0;

  Future<void> _colgar() {
    final completer = Completer<void>();
    _colgados.add(completer);
    return completer.future;
  }

  @override
  Future<RegistroDeSesion?> obtener(String id) async {
    lecturas++;
    await _colgar();
    return null;
  }

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async {
    lecturas++;
    await _colgar();
    return const [];
  }

  @override
  Future<void> guardar(RegistroDeSesion registro) async {}

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => const {};

  @override
  Future<void> eliminarDe(String nadadorId) async {}

  @override
  Future<Set<String>> nadadoresConRegistros() async {
    await _colgar();
    return const {};
  }
}

void main() {
  late RegistrosDeMentira local;
  late _ServidorMudo servidor;
  late RegistrosDeLasDosPartes repo;

  setUp(() {
    local = RegistrosDeMentira()
      ..sembrar(registroDe(sesionId: 's1', planId: 'plan-1', rpe: 7));
    servidor = _ServidorMudo();
    repo = RegistrosDeLasDosPartes(
      local: local,
      servidor: servidor,
      // Corta, para que la prueba no espere los segundos de producción.
      esperaAlServidor: const Duration(milliseconds: 50),
    );
  });

  test(
    'obtenerDePlan vuelve con lo del teléfono si el servidor calla',
    () async {
      // **Sin `timeout` esta prueba se colgaría**, igual que se colgó la
      // pantalla. Con él, una regresión falla en lugar de parar la suite.
      final suyos = await repo
          .obtenerDePlan('n-ana', 'plan-1')
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail(
              'leer esperó al servidor: eso es la pantalla de una nadadora sin '
              'señal girando para siempre, que es justo lo que la feature 003 '
              'promete que no pasa',
            ),
          );

      expect(suyos, hasLength(1));
      expect(suyos.single.rpePercibido, 7);
      expect(servidor.lecturas, 1, reason: 'se intenta, no se espera sin fin');
    },
  );

  test('obtener vuelve aunque solo pueda contestar el servidor', () async {
    // **Un identificador que el teléfono no tiene**, a propósito: con uno que
    // sí tiene, `obtener` vuelve antes de preguntar y la prueba pasaría igual
    // sin el acotado. Lo encontró el control negativo, no la prueba en verde.
    final suyo = await repo
        .obtener('n-ana|plan-1|s9|plan-1')
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('obtener esperó al servidor'),
        );

    expect(suyo, isNull, reason: 'no está en ninguna de las dos partes');
    expect(servidor.lecturas, 1, reason: 'se preguntó, y se dejó de esperar');
  });

  test('lo local se devuelve aunque el servidor nunca conteste', () async {
    // Lo que ella escribió está en su teléfono. Que el servidor no conteste no
    // puede quitárselo de la pantalla.
    local.sembrar(registroDe(sesionId: 's2', planId: 'plan-1', rpe: 3));

    final suyos = await repo
        .obtenerDePlan('n-ana', 'plan-1')
        .timeout(const Duration(seconds: 2));

    expect(suyos.map((r) => r.sesionId).toSet(), {'s1', 's2'});
  });
}
