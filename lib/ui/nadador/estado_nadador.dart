/// Estado de lo que el nadador ve y escribe.
///
/// Mantiene el perfil activo, su plan publicado, sus registros y si queda algo
/// por enviar. **Todo lo que lee sale del almacenamiento local o de la caché**:
/// consultar el plan, la sesión del día y el progreso nunca espera a la red
/// (FR-005).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/dominio/calculo/sesion_del_dia.dart';
import 'package:natacion_app/datos/peticiones/peticiones_de_las_dos_partes.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/macrociclo/puede_marcarse.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

class EstadoNadador extends ChangeNotifier {
  EstadoNadador({
    required this.sincronizador,
    DateTime Function()? reloj,
    this.peticiones,
  }) : _ahora = reloj ?? DateTime.now;

  final Sincronizador sincronizador;
  final DateTime Function() _ahora;

  /// Hoy, como lo ve este estado. Las pantallas lo necesitan para saber si una
  /// sesión ya pasó, y tomarlo de `DateTime.now()` dentro de un widget es lo
  /// que dejó cuatro pruebas del HUB poniéndose rojas solas en la feature 007.
  DateTime get ahora => _ahora();

  /// Las peticiones de feedback que ella puede mandar (feature 010, US4).
  ///
  /// **Nulo sin servidor**: no hay a quién pedirle nada ni dónde guardarlo, y
  /// la pantalla calla en lugar de ofrecer un botón que no puede terminar lo
  /// que empieza (H12).
  final RepositorioPeticionesDeFeedback? peticiones;

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
    // **Las de quien estaba antes no se quedan.** El grupo son hermanos que
    // comparten teléfono, y una pregunta de ella colgando del perfil de él
    // sería lo mismo que la garantía A7 prohíbe al cerrar sesión.
    _peticiones = const [];
    notifyListeners();

    // Y se leen las suyas, sin bloquear la pintura: la pantalla sale con lo
    // que hay y se despierta cuando lleguen.
    recargarPeticiones();
  }

  /// Guarda la respuesta del nadador.
  ///
  /// **No consulta la red** (garantía G1): escribe en el dispositivo y encola.
  /// Después intenta enviar, y si no hay señal el registro queda pendiente y el
  /// aviso aparece. Escribir no puede fallar por falta de conexión.
  /// Devuelve si se pudo, y cuando no, **por qué**, para que la pantalla lo
  /// diga en lugar de quedarse quieta.
  Future<SePuedeMarcar> responder({
    required Sesion sesion,
    required bool realizada,
    int? rpePercibido,
    String observaciones = '',
    ReporteDeMolestia? molestia,

    /// De qué plan es esta sesión, cuando no es el que está abierto.
    ///
    /// Hace falta desde la feature 009: un macrociclo tiene varios mesociclos,
    /// y el nadador marca sesiones de cualquiera de ellos desde la misma
    /// pantalla. Sin esto, el registro se guardaría con el `planId` del plan
    /// abierto y apuntaría al mesociclo equivocado — **y nada fallaría**: el
    /// registro existe, la pantalla lo pinta, y la adherencia de dos
    /// mesociclos sale mal.
    Plan? deEstePlan,
  }) async {
    final nadadorActual = _nadador;
    final planActual = deEstePlan ?? _plan;
    if (nadadorActual == null || planActual == null) return const Si();

    // **El cerrojo va aquí, donde se construye el registro** (M24, SC-006).
    //
    // «Por cualquier vía» significa esto: no que la pantalla esconda el botón,
    // sino que el registro de una sesión futura **no llegue a existir**. Un
    // cerrojo que viviera solo en un widget sería un cerrojo en una puerta de
    // tres, y la feature 009 añade dos vías nuevas a esta misma sesión.
    //
    // Se comprueba para cualquier respuesta y no solo para «la hice»: decir
    // «no la hice» de la sesión de mañana también es hablar de un día que no
    // ha pasado.
    final puede = puedeMarcarse(sesion: sesion, hoy: _ahora());
    if (!puede.si) return puede;

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

    // **Intento inmediato, y no se espera** (garantía G1).
    //
    // La línea de arriba ya dejó el registro a salvo: escrito en el
    // dispositivo y encolado. Lo que viene después es intentar que salga, y
    // eso depende de la red, así que no puede estar entre ella y la respuesta
    // de la pantalla.
    //
    // Esperarlo fue un defecto de verdad, y el recorrido en el Pixel 7 lo
    // encontró en su peor forma: con el avión puesto, el SDK de Firestore
    // acepta la escritura en su cola y no completa el Future, sin lanzar
    // nada. «Marcar como realizada» se quedaba girando **para siempre**, con
    // la anotación ya guardada y sin manera de que ella lo supiera. El envío
    // está acotado desde entonces, pero ni a ese plazo hay que esperar.
    //
    // `sincronizar` avisa por su cuenta con `notifyListeners`, que es como la
    // pantalla se entera de que la bandeja se vació.
    //
    // **Y el aviso se enciende aquí**, no al volver del intento. Está
    // pendiente desde este instante —`guardar` encoló— y es justo lo que
    // FR-017 le promete decirle: «Guardado el progreso, se enviará cuando
    // tengas acceso a internet». Dejarlo para después del intento era atar la
    // frase a la red otra vez, por la puerta de atrás.
    _hayPendientes = await sincronizador.hayPendientes();
    notifyListeners();

    unawaited(sincronizar());
    return const Si();
  }

  /// Intenta vaciar la bandeja y actualiza el aviso.
  Future<void> sincronizar() async {
    final resultado = await sincronizador.sincronizar();
    _hayPendientes = await sincronizador.hayPendientes();

    if (resultado.enviados.isNotEmpty) {
      _ultimaSincronizacion = _ahora();
    }

    // Y lo que preguntó sin señal (feature 010).
    //
    // Va aquí y no en la bandeja de salida porque la bandeja habla de
    // registros: su `encolar` recibe un `registroId` y su transporte envía un
    // `RegistroDeSesion`. Generalizarla para que lleve dos clases de cosas
    // habría puesto en juego las garantías de la feature 003 por una
    // necesidad que `PeticionesDeLasDosPartes` cubre con una lista de
    // pendientes propia.
    //
    // **Y solo lo pendiente.** Reenviar una petición que el entrenador ya vio
    // le borraría el `vistaEn`, porque la copia del teléfono no lo lleva.
    await _subirLoQuePreguntoSinSenal();

    notifyListeners();
  }

  Future<void> _subirLoQuePreguntoSinSenal() async {
    final repo = peticiones;
    final nadadorActual = _nadador;
    if (repo is! PeticionesDeLasDosPartes || nadadorActual == null) return;

    await repo.reenviarPendientes(nadadorActual.id ?? '');
    await recargarPeticiones();
  }

  // --- Pedir feedback (feature 010, US4) ---------------------------------

  List<PeticionDeFeedback> _peticiones = const [];

  /// Lo que pidió que su entrenador mirara.
  List<PeticionDeFeedback> get peticionesDeFeedback =>
      List.unmodifiable(_peticiones);

  /// Si se puede pedir feedback. Falso sin servidor.
  bool get puedePedirFeedback => peticiones != null;

  /// Su petición sobre una sesión, si preguntó algo.
  PeticionDeFeedback? peticionDe(String? sesionId) {
    if (sesionId == null) return null;
    for (final peticion in _peticiones) {
      if (peticion.sesionId == sesionId) return peticion;
    }
    return null;
  }

  /// Vuelve a leer sus peticiones, que es lo único que el entrenador toca.
  Future<void> recargarPeticiones() async {
    final repo = peticiones;
    final nadadorActual = _nadador;
    if (repo == null || nadadorActual == null) return;

    try {
      final plan = _plan?.id;
      // Por plan cuando lo hay, que es como su regla puede demostrar la
      // consulta: filtrando por nadador **y** por plan. Una consulta por plan
      // a secas la rechaza el servidor entera.
      _peticiones = plan == null
          ? await repo.deNadador(nadadorActual.id ?? '')
          : await repo.deNadadorEnPlan(nadadorActual.id ?? '', plan);
    } on Object {
      // Que no se puedan leer no borra lo que ya se leyó.
      return;
    }

    notifyListeners();
  }

  /// Pide feedback sobre una sesión que ya nadó.
  ///
  /// **No consulta la red** (garantía G1): el repositorio escribe en el
  /// dispositivo y después intenta subirlo. Si no hay señal, la petición queda
  /// pendiente y sube al sincronizar.
  ///
  /// El cerrojo del día va **aquí, donde se construye la petición**, y es el
  /// mismo `puedeMarcarse` de la feature 009 (M24): preguntar «¿cómo me
  /// salió?» de una sesión que no ha ocurrido no es una operación que falle,
  /// es una frase sin sentido. Un cerrojo que viviera solo en el widget sería
  /// un cerrojo en una puerta de tres.
  Future<SePudoPedir> pedirFeedback({
    required Sesion sesion,
    required String pregunta,
    Plan? deEstePlan,
  }) async {
    final repo = peticiones;
    final nadadorActual = _nadador;
    final planActual = deEstePlan ?? _plan;
    if (repo == null || nadadorActual == null || planActual == null) {
      return const NoHayDondeGuardarla();
    }

    if (!puedeMarcarse(sesion: sesion, hoy: _ahora()).si) {
      return const EsaSesionNoHaPasado();
    }

    // Una pregunta en blanco no llega al repositorio: el constructor la
    // rechazaría con una excepción, y esto la convierte en una respuesta que
    // la pantalla puede leer en voz alta.
    if (pregunta.trim().isEmpty) return const SinPregunta();

    final peticion = PeticionDeFeedback(
      nadadorId: nadadorActual.id ?? '',
      planId: planActual.id ?? '',
      sesionId: sesion.id ?? '',
      pregunta: pregunta,
      pedidaEn: _ahora(),
    );

    await repo.guardar(peticion);

    _peticiones = [..._peticiones.where((p) => p.id != peticion.id), peticion];
    notifyListeners();

    return const SePidio();
  }

  void _recordar(RegistroDeSesion registro) {
    final restantes = _registros
        .where((r) => r.sesionId != registro.sesionId)
        .toList();
    _registros = [...restantes, registro];
  }
}
