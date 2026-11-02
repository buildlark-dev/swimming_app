/// Estado de lo que el nadador ve y escribe.
///
/// Mantiene el perfil activo, su plan publicado, sus registros y si queda algo
/// por enviar. **Todo lo que lee sale del almacenamiento local o de la caché**:
/// consultar el plan, la sesión del día y el progreso nunca espera a la red
/// (FR-005).
library;

import 'package:flutter/foundation.dart';
import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/dominio/calculo/sesion_del_dia.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

class EstadoNadador extends ChangeNotifier {
  EstadoNadador({required this.sincronizador, DateTime Function()? reloj})
    : _ahora = reloj ?? DateTime.now;

  final Sincronizador sincronizador;
  final DateTime Function() _ahora;

  Nadador? _nadador;
  Plan? _plan;
  List<RegistroDeSesion> _registros = const [];
  bool _hayPendientes = false;
  DateTime? _ultimaSincronizacion;

  Nadador? get nadador => _nadador;
  Plan? get plan => _plan;
  List<RegistroDeSesion> get registros => List.unmodifiable(_registros);

  /// Si queda algo por enviar, para pintar el aviso.
  bool get hayPendientes => _hayPendientes;

  /// Cuándo se sincronizó por última vez.
  ///
  /// Sale de la decisión D1 y la especificación no lo pedía: la lectura sin
  /// conexión solo cubre lo ya descargado, así que el nadador tiene derecho a
  /// saber si lo que está leyendo está al día.
  DateTime? get ultimaSincronizacion => _ultimaSincronizacion;

  /// Lo que le toca hoy. Nunca una pantalla vacía (FR-002).
  QueTocaHoy get hoy {
    final actual = _plan;
    if (actual == null) return const SinSesionesPorDelante();
    return queTocaHoy(actual, _ahora());
  }

  ProgresoDelNadador? get progreso {
    final actual = _plan;
    if (actual == null) return null;
    return ProgresoDelNadador(plan: actual, registros: _registros);
  }

  /// El registro de una sesión, si el nadador ya respondió.
  RegistroDeSesion? registroDe(String? sesionId) {
    if (sesionId == null) return null;
    for (final registro in _registros) {
      if (registro.sesionId == sesionId) return registro;
    }
    return null;
  }

  void abrirComo(
    Nadador nadador, {
    Plan? plan,
    List<RegistroDeSesion>? registros,
  }) {
    _nadador = nadador;
    _plan = plan;
    _registros = registros ?? const [];
    notifyListeners();
  }

  /// Guarda la respuesta del nadador.
  ///
  /// **No consulta la red** (garantía G1): escribe en el dispositivo y encola.
  /// Después intenta enviar, y si no hay señal el registro queda pendiente y el
  /// aviso aparece. Escribir no puede fallar por falta de conexión.
  Future<void> responder({
    required Sesion sesion,
    required bool realizada,
    int? rpePercibido,
    String observaciones = '',
    ReporteDeMolestia? molestia,
  }) async {
    final nadadorActual = _nadador;
    final planActual = _plan;
    if (nadadorActual == null || planActual == null) return;

    final registro = RegistroDeSesion(
      nadadorId: nadadorActual.id ?? '',
      planId: planActual.id ?? '',
      sesionId: sesion.id ?? '',
      versionDePlan: planActual.versionMetodologia ?? '',
      realizada: realizada,
      registradoEn: _ahora(),
      rpePercibido: rpePercibido,
      observaciones: observaciones,
      molestia: molestia,
    );

    await sincronizador.guardar(registro);
    _recordar(registro);

    // Intento inmediato. Si no hay red, el registro ya está a salvo.
    await sincronizar();
  }

  /// Intenta vaciar la bandeja y actualiza el aviso.
  Future<void> sincronizar() async {
    final resultado = await sincronizador.sincronizar();
    _hayPendientes = await sincronizador.hayPendientes();

    if (resultado.enviados.isNotEmpty) {
      _ultimaSincronizacion = _ahora();
    }

    notifyListeners();
  }

  void _recordar(RegistroDeSesion registro) {
    final restantes = _registros
        .where((r) => r.sesionId != registro.sesionId)
        .toList();
    _registros = [...restantes, registro];
  }
}
