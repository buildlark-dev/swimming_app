/// Cómo va su entrenamiento, en corto.
///
/// **No consulta nada.** Se arma con lo que el recorrido del nadador ya tiene
/// cargado desde la feature 003 —su plan, sus registros, qué le toca hoy y de
/// cuándo son los datos—, y por eso `Home` abre sin conexión sin que haya que
/// construir nada para lograrlo (decisión D11).
///
/// Lo que este resumen **no** lleva está fijado en su prueba, leyendo este
/// archivo: nada que la app no calcule de verdad. Un resumen que anima con
/// cifras que nadie calculó es justo lo que un nadador de nueve años se va a
/// creer, y el principio IV no delega eso.
library;

import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/dominio/calculo/sesion_del_dia.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';

class ResumenDelNadador {
  const ResumenDelNadador({
    required this.entregadas,
    required this.cumplidas,
    required this.hoy,
    required this.tienePlan,
    this.ultimaRespuesta,
    this.ultimaSincronizacion,
    this.hayPendientes = false,
  });

  /// Lo que hay, dicho como el nadador lo lee.
  factory ResumenDelNadador.de({
    required Plan? plan,
    required List<RegistroDeSesion> registros,
    required QueTocaHoy hoy,
    DateTime? ultimaSincronizacion,
    bool hayPendientes = false,
  }) {
    if (plan == null) {
      return ResumenDelNadador(
        entregadas: 0,
        cumplidas: 0,
        hoy: hoy,
        tienePlan: false,
        ultimaSincronizacion: ultimaSincronizacion,
        hayPendientes: hayPendientes,
      );
    }

    // Se reutiliza el cálculo de la feature 003 en lugar de contar aquí. Si
    // «cumplida» significara una cosa en la sesión del día y otra en esta
    // pantalla, el nadador vería dos verdades sobre lo mismo.
    final adherencia = ProgresoDelNadador(
      plan: plan,
      registros: registros,
    ).adherenciaDelPlan;

    return ResumenDelNadador(
      entregadas: adherencia.programadas,
      cumplidas: adherencia.realizadas,
      hoy: hoy,
      tienePlan: true,
      ultimaRespuesta: _laMasReciente(registros),
      ultimaSincronizacion: ultimaSincronizacion,
      hayPendientes: hayPendientes,
    );
  }

  /// Cuántas sesiones le han entregado.
  final int entregadas;

  /// De esas, cuántas marcó como hechas. **Nunca más que [entregadas]**: un
  /// registro de una sesión que ya no está en el plan no infla la cuenta,
  /// porque el cálculo recorre las sesiones del plan y no los registros.
  final int cumplidas;

  /// Qué le toca hoy. Puede ser «no hay sesiones por delante», que también es
  /// una respuesta: lo que no puede haber es una pantalla vacía sin explicar.
  final QueTocaHoy hoy;

  /// Si ya tiene un plan publicado y asignado.
  final bool tienePlan;

  /// Lo último que quiso anotar, si anotó algo.
  ///
  /// Puede faltar, y **eso no es un fallo**: anotar la carga interna no es
  /// obligatorio (principio VIII). Quien no anota nada sigue viendo su plan.
  final RegistroDeSesion? ultimaRespuesta;

  /// Cuándo se pudo poner al día por última vez. Puede faltar, y entonces la
  /// pantalla lo dice en lugar de dar sus datos por frescos.
  final DateTime? ultimaSincronizacion;

  /// Si queda algo suyo por enviar.
  final bool hayPendientes;

  static RegistroDeSesion? _laMasReciente(List<RegistroDeSesion> registros) {
    if (registros.isEmpty) return null;

    var reciente = registros.first;
    for (final registro in registros.skip(1)) {
      if (registro.registradoEn.isAfter(reciente.registradoEn)) {
        reciente = registro;
      }
    }
    return reciente;
  }
}
