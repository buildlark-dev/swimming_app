/// Registros del nadador y bandeja de salida, en el dispositivo.
///
/// **Local primero.** `guardar` escribe en el dispositivo y no mira la red: es
/// la garantía G1 del contrato de sincronización, y es lo que hace que escribir
/// a pie de piscina no pueda fallar por falta de señal.
library;

import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/exportacion.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

const String _coleccionRegistros = 'registros';
const String _coleccionBandeja = 'bandeja';

class RegistrosLocales implements RepositorioRegistros {
  const RegistrosLocales(this.almacen);

  final AlmacenLocal almacen;

  @override
  Future<RegistroDeSesion?> obtener(String registroId) async {
    final documento = await almacen.leer(_coleccionRegistros, registroId);
    return documento == null ? null : registroDesdeJson(documento);
  }

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async {
    final todos = await almacen.leerTodo(_coleccionRegistros);
    return todos.values
        .map(registroDesdeJson)
        .where((r) => r.nadadorId == nadadorId && r.planId == planId)
        .toList();
  }

  @override
  Future<void> guardar(RegistroDeSesion registro) async {
    // Un fallo aquí **sí** se propaga (garantía S8): si el dispositivo rechaza
    // la escritura, el dato se perdería, y eso el nadador tiene que saberlo.
    await almacen.escribir(
      _coleccionRegistros,
      registro.id,
      registroAJson(registro),
    );
  }

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async {
    final todos = await almacen.leerTodo(_coleccionRegistros);
    final suyos = todos.values
        .map(registroDesdeJson)
        .where((r) => r.nadadorId == nadadorId)
        .toList();

    return <String, dynamic>{
      'formato': formatoExportacion,
      'exportadoEl': DateTime.now().toIso8601String(),
      'registros': suyos.map(registroAJson).toList(),
    };
  }

  @override
  Future<void> eliminarDe(String nadadorId) async {
    final todos = await almacen.leerTodo(_coleccionRegistros);

    for (final entrada in todos.entries) {
      final registro = registroDesdeJson(entrada.value);
      if (registro.nadadorId != nadadorId) continue;
      await almacen.borrar(_coleccionRegistros, entrada.key);
      await almacen.borrar(_coleccionBandeja, entrada.key);
    }
  }

  @override
  Future<Set<String>> nadadoresConRegistros() async {
    final todos = await almacen.leerTodo(_coleccionRegistros);
    return todos.values.map(registroDesdeJson).map((r) => r.nadadorId).toSet();
  }
}

class BandejaLocal implements BandejaDeSalida {
  const BandejaLocal(this.almacen);

  final AlmacenLocal almacen;

  @override
  Future<void> encolar(String registroId) async {
    final existente = await estadoDe(registroId);

    // Reencolar un registro ya enviado lo devuelve a pendiente: el contenido
    // cambió y hay que mandarlo otra vez. Conserva el contador de intentos,
    // porque es información de diagnóstico, no un castigo.
    await actualizar(
      EnvioPendiente(
        registroId: registroId,
        intentos: existente?.intentos ?? 0,
        ultimoIntento: existente?.ultimoIntento,
      ),
    );
  }

  @override
  Future<List<EnvioPendiente>> pendientes() async {
    final todos = await almacen.leerTodo(_coleccionBandeja);
    return todos.values
        .map(envioDesdeJson)
        .where((e) => e.esperaEnvio)
        .toList();
  }

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async {
    final documento = await almacen.leer(_coleccionBandeja, registroId);
    return documento == null ? null : envioDesdeJson(documento);
  }

  @override
  Future<void> actualizar(EnvioPendiente envio) async {
    await almacen.escribir(
      _coleccionBandeja,
      envio.registroId,
      envioAJson(envio),
    );
  }
}
