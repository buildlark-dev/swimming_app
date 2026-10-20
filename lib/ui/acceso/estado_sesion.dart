/// La sesión activa, para la interfaz.
///
/// Escucha a [Identidad] y expone la cuenta a quien la necesite. La decisión
/// de qué puede hacer cada quien vive en `lib/dominio/cuentas/permisos.dart`, y
/// hacerla cumplir es de las reglas de acceso.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// En qué punto está la sesión.
///
/// `comprobando` y `preparando` existen a propósito y **no se colapsan con
/// `fuera`**. Al abrir la app hay un instante en que todavía no se sabe quién
/// eres, y enseñar la pantalla de acceso ahí haría parpadear a quien ya tiene
/// sesión. Y justo después de crear una cuenta hay otro en que la sesión es
/// real pero el servidor aún no le ha puesto el rol.
///
/// Confundir ese segundo caso con `fuera` fue un fallo de verdad: quien se
/// registraba volvía a la pantalla de crear cuenta sin que nada le explicara
/// por qué.
enum EstadoDeSesion {
  comprobando,
  preparando,
  dentro,
  fuera,

  /// Hubo sesión, pero el rol nunca llegó.
  ///
  /// No es un estado transitorio: significa que algo del lado del servidor no
  /// hizo su trabajo. Se muestra como tal en lugar de devolver a nadie al
  /// login, porque volver al login invita a registrarse otra vez y el problema
  /// se repite.
  sinRol,
}

class SesionActiva extends ChangeNotifier {
  SesionActiva({required this.identidad, this.esperas = esperasPorOmision}) {
    _suscripcion = identidad.cambios.listen(_actualizar);
    unawaited(_primera());
  }

  final Identidad identidad;

  /// Cuánto esperar entre reintentos mientras el rol no llega.
  ///
  /// El disparador que lo asigna corre después de crear la cuenta y tarda unos
  /// segundos. Una sola comprobación inmediata casi nunca lo alcanza, que es
  /// exactamente lo que fallaba.
  final List<Duration> esperas;

  static const List<Duration> esperasPorOmision = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
  ];

  StreamSubscription<EstadoDeCuenta>? _suscripcion;

  EstadoDeSesion _estado = EstadoDeSesion.comprobando;
  EstadoDeSesion get estado => _estado;

  Cuenta? _cuenta;
  Cuenta? get cuenta => _cuenta;

  bool get hayCuenta => _cuenta != null;

  /// Para no lanzar dos esperas a la vez si llegan dos avisos seguidos.
  bool _esperandoRol = false;

  /// Ya se agotaron los reintentos y no hay que volver a empezar solo.
  ///
  /// Hace falta porque comprobar el rol **refresca el token a la fuerza**, y
  /// cada refresco hace que el flujo de cambios emita de nuevo. Sin esta
  /// bandera, esa emisión reiniciaba la espera y la pantalla se quedaba en
  /// «preparando» para siempre, refrescando el token sin parar.
  bool _rendido = false;

  Future<void> _primera() async {
    try {
      _actualizar(await identidad.actual());
    } on Exception {
      // Sin red ni caché no se puede resolver quién eres. Se trata como estar
      // fuera: la app enseña la pantalla de acceso en lugar de quedarse
      // comprobando para siempre.
      _actualizar(const SinSesion());
    }
  }

  void _actualizar(EstadoDeCuenta estado) {
    switch (estado) {
      case SinSesion():
        _cuenta = null;
        _esperandoRol = false;
        _rendido = false;
        _fijar(EstadoDeSesion.fuera);

      case CuentaLista(:final cuenta):
        _cuenta = cuenta;
        _esperandoRol = false;
        _rendido = false;
        _fijar(EstadoDeSesion.dentro);

      case CuentaSinRol():
        _cuenta = null;

        // Si ya se agotaron los reintentos, se queda como está. Volver a
        // «preparando» cada vez que el token se refresca es exactamente el
        // bucle que dejaba la pantalla cargando sin fin.
        if (_rendido) return;

        _fijar(EstadoDeSesion.preparando);
        if (!_esperandoRol) unawaited(_esperarAlRol());
    }
  }

  void _fijar(EstadoDeSesion nuevo) {
    _estado = nuevo;
    notifyListeners();
  }

  /// Vuelve a preguntar mientras el rol no llegue, y se rinde diciéndolo.
  Future<void> _esperarAlRol() async {
    _esperandoRol = true;

    for (final espera in esperas) {
      await Future<void>.delayed(espera);
      if (!_esperandoRol) return; // Llegó por otra vía, o se cerró sesión.

      final EstadoDeCuenta ahora;
      try {
        ahora = await identidad.actual();
      } on Exception {
        continue;
      }

      if (ahora is! CuentaSinRol) {
        _actualizar(ahora);
        return;
      }
    }

    // Se acabaron los reintentos. **No se devuelve a nadie al login**: eso
    // invitaría a registrarse otra vez y a repetir el problema. Se dice lo que
    // pasa, que es que la cuenta existe y le falta el rol.
    _esperandoRol = false;
    _rendido = true;
    _fijar(EstadoDeSesion.sinRol);
  }

  /// Vuelve a intentarlo, para el botón de la pantalla de espera.
  Future<void> reintentar() async {
    _rendido = false;
    _fijar(EstadoDeSesion.preparando);
    if (!_esperandoRol) await _esperarAlRol();
  }

  Future<void> cerrarSesion() => identidad.cerrarSesion();

  @override
  void dispose() {
    _esperandoRol = false;
    _suscripcion?.cancel();
    super.dispose();
  }
}
