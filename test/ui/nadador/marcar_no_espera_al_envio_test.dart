/// Marcar la sesión **vuelve en el acto**, aunque el envío se quede colgado.
///
/// Garantía G1 de la feature 003, y escenario C2: «anotar sin conexión, y que
/// llegue». El recorrido en el Pixel 7 lo encontró roto en la peor forma
/// posible: con el avión puesto, Ana pulsa «Marcar como realizada» y el botón
/// **gira para siempre**. No había error, ni aviso, ni tick. La anotación
/// estaba a salvo —`guardar` escribe y encola antes de intentar nada— y ella
/// no tenía manera de saberlo.
///
/// El acotado del envío (`enviar_no_espera_para_siempre_test.dart`) cierra el
/// agujero grande. Esto cierra el resto: **la pantalla no espera siquiera a
/// ese plazo**. El registro ya está guardado cuando se lanza el intento; la
/// propia línea decía «Intento inmediato. Si no hay red, el registro ya está a
/// salvo» y aun así lo esperaba.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';

void main() {
  final hoy = DateTime(2026, 11, 12, 18);

  late _Registros registros;
  late _Bandeja bandeja;
  late _TransporteMudo transporte;
  late EstadoNadador estado;

  final laDeHoy = Sesion(id: 's1', microcicloId: 'm1', fecha: hoy);

  setUp(() {
    registros = _Registros();
    bandeja = _Bandeja();
    transporte = _TransporteMudo();

    estado = EstadoNadador(
      sincronizador: Sincronizador(
        registros: registros,
        bandeja: bandeja,
        // Como en producción con el avión puesto: el sondeo dice que sí y el
        // transporte acepta y calla.
        red: _RedQueSiempreDiceQueSi(),
        transporte: transporte,
        reloj: () => hoy,
        esperaAlEnvio: const Duration(seconds: 30),
      ),
      reloj: () => hoy,
    );

    estado.abrirComo(
      const Nadador(id: 'n-ana', nombre: 'Ana'),
      plan: Plan(
        id: 'p1',
        nombre: 'Mesociclo 1: Acumulación',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
        estado: EstadoPlan.publicado,
        versionMetodologia: '3.6.0',
        sesiones: [laDeHoy],
      ),
    );
  });

  test('responder vuelve sin esperar al envío', () async {
    // **El cerrojo.** El plazo del envío es de treinta segundos a propósito:
    // si esto lo esperara, la prueba fallaría aquí en lugar de dejar la suite
    // parada, y la nadadora vería el botón girando media hora de reloj.
    final resultado = await estado
        .responder(sesion: laDeHoy, realizada: true, rpePercibido: 7)
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail(
            'marcar esperó al envío: eso es una nadadora al borde de la '
            'piscina que pulsa y no ve nada, que es la garantía G1 rota',
          ),
        );

    expect(resultado.si, isTrue);
  });

  test('y lo anotado queda guardado y encolado', () async {
    await estado.responder(sesion: laDeHoy, realizada: true, rpePercibido: 7);

    expect(registros.guardados, hasLength(1));
    expect(registros.guardados.values.single.rpePercibido, 7);
    expect(
      await bandeja.pendientes(),
      hasLength(1),
      reason: 'no esperar al envío no es renunciar a enviarlo',
    );
  });

  test('el intento se lanza igual, solo que no se espera', () async {
    await estado.responder(sesion: laDeHoy, realizada: true);

    // Un turno del bucle de eventos basta: lo que se quitó es el `await`, no
    // la llamada.
    await Future<void>.delayed(Duration.zero);

    expect(transporte.intentos, 1);
  });
}

class _TransporteMudo implements EnvioDeRegistros {
  int intentos = 0;

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async {
    intentos++;
    return Completer<DateTime>().future;
  }
}

class _RedQueSiempreDiceQueSi implements EstadoDeRed {
  @override
  Future<bool> hayConexion() async => true;

  @override
  Stream<bool> get cambios => const Stream.empty();
}

class _Registros implements RepositorioRegistros {
  final Map<String, RegistroDeSesion> guardados = {};

  @override
  Future<RegistroDeSesion?> obtener(String id) async => guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async =>
      guardados.values.where((r) => r.nadadorId == n && r.planId == p).toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      guardados[registro.id] = registro;

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => const {};

  @override
  Future<void> eliminarDe(String nadadorId) async =>
      guardados.removeWhere((_, r) => r.nadadorId == nadadorId);

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      guardados.values.map((r) => r.nadadorId).toSet();
}

class _Bandeja implements BandejaDeSalida {
  final Map<String, EnvioPendiente> _envios = {};

  @override
  Future<void> encolar(String registroId) async =>
      _envios[registroId] = EnvioPendiente(registroId: registroId);

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _envios.values.where((e) => e.esperaEnvio).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async =>
      _envios[registroId];

  @override
  Future<void> actualizar(EnvioPendiente envio) async =>
      _envios[envio.registroId] = envio;
}
