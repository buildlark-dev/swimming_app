/// Preguntar **no espera al servidor**, ni siquiera cuando el servidor no
/// contesta (FR-016, garantía G1).
///
/// Hallazgo del recorrido de la 010 en el Pixel 7, y el más fino de todos.
///
/// `pedir_feedback_sin_red_test.dart` ya cubría «sin red se guarda igual», y
/// pasaba. Pero su doble del servidor **lanza** cuando no hay red, y el SDK de
/// Firestore no hace eso: acepta el `set()` en su cola local y **deja el Future
/// sin completar hasta que el servidor confirme**. Con el avión activado,
/// logcat decía
///
///     [WriteStream]: Stream closed with status UNAVAILABLE
///     failed to connect to /10.0.2.2 (port 8080)
///
/// y ninguna excepción. `PeticionesDeLasDosPartes.guardar` esperaba ese Future,
/// así que `pedirFeedback` no volvía, y la pantalla de Ana no decía nada: para
/// ella, la app no había hecho nada.
///
/// **La lección de siempre con una vuelta más.** Este proyecto ya sabía que el
/// doble tiene que rechazar lo que el servidor rechaza; lo que faltaba es que
/// tiene que **volver donde el servidor se quedaría colgado**. Un doble que
/// lanza es más amable que uno que no contesta.
///
/// Los registros no tenían este problema porque la bandeja de salida pregunta
/// por la conectividad antes de intentar. Aquí no se pregunta: simplemente no
/// se espera, que es más robusto —una comprobación de red tiene siempre una
/// carrera entre la respuesta y el intento.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/peticiones/peticiones_de_las_dos_partes.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

import '../../ui/nadador/ayuda_pedir_feedback.dart';

/// Un servidor que **acepta y no contesta**, como Firestore sin red.
///
/// No lanza. Se queda con el Future abierto, que es lo que de verdad pasa.
class _ServidorQueNoContesta implements RepositorioPeticionesDeFeedback {
  final pedidas = <PeticionDeFeedback>[];
  final _colgados = <Completer<void>>[];

  /// Deja contestar a todas, como cuando vuelve la señal.
  void vuelveLaSenal() {
    for (final c in _colgados) {
      if (!c.isCompleted) c.complete();
    }
    _colgados.clear();
  }

  Future<void> _colgar() {
    final completer = Completer<void>();
    _colgados.add(completer);
    return completer.future;
  }

  @override
  Future<List<PeticionDeFeedback>> deNadador(String nadadorId) async {
    await _colgar();
    return const [];
  }

  @override
  Future<List<PeticionDeFeedback>> deNadadorEnPlan(String n, String p) async {
    await _colgar();
    return const [];
  }

  @override
  Future<void> guardar(PeticionDeFeedback peticion) async {
    pedidas.add(peticion);
    return _colgar();
  }

  @override
  Future<void> marcarVista(String peticionId, DateTime cuando) => _colgar();
}

void main() {
  late PeticionesEnMemoria local;
  late _ServidorQueNoContesta servidor;
  late PeticionesDeLasDosPartes repo;

  PeticionDeFeedback laSuya({String sesionId = 's1'}) => PeticionDeFeedback(
    nadadorId: 'n-ana',
    planId: 'plan-1',
    sesionId: sesionId,
    pregunta: 'El viraje del tercer 50, ¿lo hice bien?',
    pedidaEn: DateTime(2026, 11, 12, 2),
  );

  setUp(() {
    local = PeticionesEnMemoria();
    servidor = _ServidorQueNoContesta();
    repo = PeticionesDeLasDosPartes(
      local: local,
      servidor: servidor,
      // Corta, para que la prueba no espere los cinco segundos de producción.
      esperaAlServidor: const Duration(milliseconds: 50),
    );
  });

  test('guardar vuelve aunque el servidor no conteste', () async {
    // **Esto es el cerrojo.** Sin `timeout` la prueba se colgaría, igual que
    // se colgó la pantalla; con él, un `guardar` que espere al servidor falla
    // en lugar de dejar la suite parada para siempre.
    await repo
        .guardar(laSuya())
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail(
            'guardar esperó al servidor: eso es la garantía G1 rota, y es '
            'una nadadora al borde de la piscina sin señal que toca el botón '
            'y no ve nada',
          ),
        );

    expect(local.guardadas, hasLength(1));
    expect(
      servidor.pedidas,
      hasLength(1),
      reason: 'se intenta, lo que no se hace es esperar al intento',
    );
  });

  test('queda pendiente hasta que el servidor conteste', () async {
    await repo.guardar(laSuya());

    expect(repo.pendientes, contains('n-ana|plan-1|s1'));

    servidor.vuelveLaSenal();
    await Future<void>.delayed(Duration.zero);

    expect(
      repo.pendientes,
      isEmpty,
      reason: 'cuando el servidor confirma, deja de estar pendiente',
    );
  });

  test('reenviar tampoco espera', () async {
    await repo.guardar(laSuya());

    await repo
        .reenviarPendientes('n-ana')
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('reenviarPendientes esperó al servidor'),
        );
  });

  test('no se apila un intento por cada reenvío', () async {
    await repo.guardar(laSuya());
    await repo.reenviarPendientes('n-ana');
    await repo.reenviarPendientes('n-ana');

    expect(
      servidor.pedidas,
      hasLength(1),
      reason:
          'con un intento ya en vuelo no se lanza otro: con un identificador '
          'determinista no duplicaría, pero apilaría escrituras esperando',
    );
  });

  test('leer tampoco se cuelga: se devuelve lo del teléfono', () async {
    await repo.guardar(laSuya());

    final suyas = await repo
        .deNadador('n-ana')
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('leer esperó al servidor'),
        );

    expect(suyas, hasLength(1));
    expect(suyas.single.pregunta, 'El viraje del tercer 50, ¿lo hice bien?');
  });
}
