/// Garantías P8, P9 y P10 — la puerta del menor, también en las peticiones.
///
/// Es el principio V y es la misma puerta que la feature 004 construyó. Lo que
/// esta feature **no** hace es abrir un tercer camino por el que los datos de
/// un menor salgan del dispositivo: reutiliza la bandeja de salida y la puerta
/// que ya existen y están probadas.
///
/// Lo retenido **no es un estado nuevo**. Fue la decisión D6 de la feature
/// 003: una petición retenida por falta de consentimiento *es* una petición
/// pendiente, y modelarlo como otra cosa duplicaría un mecanismo que ya
/// funciona.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/dominio/consentimiento/puerta.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/datos/peticiones/peticiones_con_puerta.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final hoy = DateTime(2026, 11, 2);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  RespuestasDePeticion respuestas() => RespuestasDePeticion(
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
    fechaDeCompetencia: hoy.add(const Duration(days: 24)),
    diasDisponibles: [hoy.add(const Duration(days: 1))],
    duracionSesionMinutos: 90,
    longitudPiscina: 25,
  );

  PeticionesConPuerta conPuerta({
    required bool abierta,
    _Servidor? servidor,
    AlmacenLocal? almacen,
  }) => PeticionesConPuerta(
    servidor: servidor ?? _Servidor(),
    puerta: _Puerta(abierta),
    almacen: almacen ?? AlmacenPreferencias(cuentaId: 'u-ana'),
    ahora: () => hoy,
  );

  group('P9 — con la puerta cerrada no sale nada', () {
    test('el servidor no recibe la petición', () async {
      final servidor = _Servidor();
      final peticiones = conPuerta(abierta: false, servidor: servidor);

      await peticiones.enviar(nadadorId: 'n-ana', respuestas: respuestas());

      expect(
        servidor.recibidas,
        isEmpty,
        reason: 'Con un menor sin consentimiento, nada sale del dispositivo',
      );
    });

    test('pero lo respondido queda retenido, no perdido', () async {
      final peticiones = conPuerta(abierta: false);

      await peticiones.enviar(nadadorId: 'n-ana', respuestas: respuestas());

      final mia = await peticiones.miPeticion('n-ana');
      expect(mia, isNotNull);
      expect(mia!.estado, EstadoDePeticion.esperando);
    });

    test('y se sabe que está retenida, para poder decirlo', () async {
      final peticiones = conPuerta(abierta: false);

      await peticiones.enviar(nadadorId: 'n-ana', respuestas: respuestas());

      expect(await peticiones.estaRetenida('n-ana'), isTrue);
    });

    test('**control negativo**: con la puerta abierta sale', () async {
      final servidor = _Servidor();
      final peticiones = conPuerta(abierta: true, servidor: servidor);

      await peticiones.enviar(nadadorId: 'n-ana', respuestas: respuestas());

      expect(servidor.recibidas, hasLength(1));
      expect(await peticiones.estaRetenida('n-ana'), isFalse);
    });
  });

  group('P10 — en cuanto hay consentimiento, sale sin reescribirla', () {
    test('lo retenido viaja tal cual', () async {
      final servidor = _Servidor();
      final almacen = AlmacenPreferencias(cuentaId: 'u-ana');

      // Se responde con la puerta cerrada.
      await conPuerta(
        abierta: false,
        servidor: servidor,
        almacen: almacen,
      ).enviar(nadadorId: 'n-ana', respuestas: respuestas());

      expect(servidor.recibidas, isEmpty);

      // El acudiente autoriza, y lo retenido sale **sin volver a escribirlo**.
      final yaConPermiso = conPuerta(
        abierta: true,
        servidor: servidor,
        almacen: almacen,
      );
      await yaConPermiso.reintentarLoRetenido('n-ana');

      expect(servidor.recibidas, hasLength(1));
      expect(servidor.recibidas.single.pruebaObjetivo, '200 Libre');
      expect(await yaConPermiso.estaRetenida('n-ana'), isFalse);
    });

    test('si sigue cerrada, sigue retenida', () async {
      final servidor = _Servidor();
      final almacen = AlmacenPreferencias(cuentaId: 'u-ana');

      await conPuerta(
        abierta: false,
        servidor: servidor,
        almacen: almacen,
      ).enviar(nadadorId: 'n-ana', respuestas: respuestas());

      final todaviaNo = conPuerta(
        abierta: false,
        servidor: servidor,
        almacen: almacen,
      );
      await todaviaNo.reintentarLoRetenido('n-ana');

      expect(servidor.recibidas, isEmpty);
      expect(await todaviaNo.estaRetenida('n-ana'), isTrue);
    });
  });

  group('un fallo de red retiene igual que la puerta', () {
    test('lo que no salió por la red se guarda para luego', () async {
      // La bandeja no distingue: lo que no salió, no salió. Es la decisión D6
      // de la feature 003, y vale igual aquí.
      final servidor = _Servidor(falla: true);
      final peticiones = conPuerta(abierta: true, servidor: servidor);

      await peticiones.enviar(nadadorId: 'n-ana', respuestas: respuestas());

      expect(await peticiones.estaRetenida('n-ana'), isTrue);
      expect(await peticiones.miPeticion('n-ana'), isNotNull);
    });
  });

  group('lo del servidor manda sobre lo retenido', () {
    test('si el servidor ya tiene una, es la que vale', () async {
      final servidor = _Servidor()
        ..recibidas.add(respuestas())
        ..devuelve = PeticionDePlan(
          nadadorId: 'n-ana',
          enviadaEn: hoy,
          respuestas: respuestas(),
          estado: EstadoDePeticion.rechazada,
          motivoDelRechazo: 'Esta semana no.',
          respondidaEn: hoy,
        );

      final peticiones = conPuerta(abierta: true, servidor: servidor);
      final mia = await peticiones.miPeticion('n-ana');

      expect(mia!.estado, EstadoDePeticion.rechazada);
      expect(mia.motivoDelRechazo, 'Esta semana no.');
    });
  });
}

class _Puerta implements PuertaDeConsentimiento {
  const _Puerta(this.abierta);

  final bool abierta;

  @override
  Future<bool> puedeSalir(String nadadorId) async => abierta;
}

class _Servidor implements RepositorioPeticiones {
  _Servidor({this.falla = false});

  final bool falla;
  final List<RespuestasDePeticion> recibidas = [];
  PeticionDePlan? devuelve;

  @override
  Future<void> enviar({
    required String nadadorId,
    required RespuestasDePeticion respuestas,
  }) async {
    if (falla) throw StateError('sin red');
    recibidas.add(respuestas);
  }

  @override
  Future<PeticionDePlan?> miPeticion(String nadadorId) async => devuelve;

  @override
  Future<List<PeticionDePlan>> cola() async => const [];

  @override
  Future<void> marcarEnRevision(String nadadorId) async {}
}
