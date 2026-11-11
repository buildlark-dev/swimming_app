/// El HUB: la barra de cinco destinos y los dos recorridos.
///
/// Vivía dentro de `main.dart` hasta la feature 007. Salió aquí porque son dos
/// trabajos distintos —arrancar la app y disponerla— y porque esta feature
/// multiplica el segundo por dos recorridos (decisión D1).
///
/// Lo que decide **qué le toca a quién** no está en este archivo: está en
/// `lib/dominio/hub/destino.dart`, en Dart puro, y se comprueba sin pintar
/// nada. Aquí se monta lo que esa tabla dice.
///
/// Los contenidos se mantienen vivos en un `IndexedStack`: cambiar de destino
/// conserva lo escrito a medias (H8). Y como solo se construyen los del rol que
/// entró, **el contenido del otro recorrido no existe ni en memoria** (H6).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/firestore/molestias_firestore.dart';
import 'package:natacion_app/dominio/peticiones/molestias_enlazadas.dart';
import 'package:natacion_app/datos/firestore/consentimientos.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/local/repositorios_locales.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/preferencias/apariencia.dart';
import 'package:natacion_app/datos/recursos/recursos_iniciales.dart';
import 'package:natacion_app/dominio/consentimiento/constancia.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/datos_personales/derechos_del_titular.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/hub/destino.dart';
import 'package:natacion_app/dominio/hub/resumen_del_entrenador.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/ui/macrociclo/estructura.dart';
import 'package:natacion_app/ui/macrociclo/revisar_macrociclo.dart';
import 'package:natacion_app/ui/hub/contenidos.dart';
import 'package:natacion_app/ui/hub/repositorios_del_hub.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/perfil_activo.dart';
import 'package:natacion_app/ui/planes/pantalla_plan.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

/// La casa de la app: cinco destinos, dos recorridos.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({
    super.key,
    required this.recursos,
    this.cuenta,
    this.modoLocal = false,
    this.repositorios,
    this.hoyParaPruebas,
    this.alElegirApariencia,
  });

  final RecursosIniciales recursos;

  /// Quién tiene la sesión abierta. Nula en [modoLocal].
  final Cuenta? cuenta;

  /// Sin servidor: no hay cuentas, no hay consentimiento y no hay dónde
  /// guardar nada. Es el modo de desarrollo, y va rotulado.
  final bool modoLocal;

  /// Para que la app entera se repinte cuando alguien elige la apariencia en
  /// Ajustes. Nula en pruebas.
  final ValueChanged<Apariencia>? alElegirApariencia;

  /// Para pruebas: repositorios ya sembrados.
  ///
  /// En la app no se pasa, y se construyen de los recursos. Existe porque sin
  /// esto el recorrido del nadador no se podía comprobar: los repositorios se
  /// creaban dentro del estado y no había forma de sembrar ni un nadador.
  final RepositoriosDelHub? repositorios;

  /// Para pruebas: qué día es hoy.
  ///
  /// En la app no se pasa y es `DateTime.now()`. Existe porque una prueba
  /// anclada al día real se pone roja sola: pasó en la feature 007 con cuatro
  /// pruebas del HUB que fallaron el 2026-11-02 sin que nadie tocara el
  /// código.
  final DateTime? hoyParaPruebas;

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  /// Se abre en `Home`, para los dos roles (decisión D3).
  Destino _destino = Destino.home;

  /// En modo local no hay rol que consultar, así que se elige a propósito
  /// (decisión D13). Adivinarlo sería peor.
  Rol _recorridoLocal = Rol.entrenador;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
  }

  /// Particionado por cuenta: dos hermanos con el mismo teléfono no comparten
  /// ni una clave, tampoco en la bandeja de salida (garantía A9).
  late final AlmacenLocal _almacen = AlmacenPreferencias(
    cuentaId: widget.cuenta?.id,
  );

  late final RepositoriosDelHub _repos =
      widget.repositorios ?? RepositoriosDelHub.de(widget.recursos, _almacen);

  /// Sus propios datos de cuenta, para Ajustes. Sin servidor, vacíos: se ven
  /// pero no hay nada guardado que mostrar.
  late final RepositorioPerfil _repositorioPerfil =
      widget.recursos.firestore == null
      ? RepositorioPerfilEnMemoria()
      : RepositorioPerfilFirestore(widget.recursos.firestore!);

  /// La constancia del consentimiento, para poder verla. Nula sin servidor.
  late final LectorDeConstancias? _constancias =
      widget.recursos.firestore == null
      ? null
      : ConstanciasFirestore(widget.recursos.firestore!);

  /// Las molestias que sus nadadores ya contaron en sus sesiones, para que las
  /// vea al abrir una petición. **Solo lee**: nada de esta feature las copia
  /// (FR-038). Nulo sin servidor.
  late final LectorDeMolestias? _molestias = widget.recursos.firestore == null
      ? null
      : MolestiasFirestore(widget.recursos.firestore!);

  /// El conmutador de recorrido del modo local. Vive en Ajustes (T053).
  Widget _conmutadorDeRecorrido() => SegmentedButton<Rol>(
    key: const Key('recorrido-en-modo-local'),
    segments: const [
      ButtonSegment(value: Rol.entrenador, label: Text('Entrenador')),
      ButtonSegment(value: Rol.nadador, label: Text('Nadador')),
    ],
    selected: {_recorridoLocal},
    onSelectionChanged: (cual) => setState(() => _recorridoLocal = cual.first),
  );

  /// Un solo estado de editor para todo el destino `Generar`, para que lo
  /// generado aparezca en el editor sin cambiar de sitio.
  late final EstadoEditor _editor = EstadoEditor(
    biblioteca: widget.recursos.biblioteca,
  );

  /// El recorrido del nadador (feature 003).
  ///
  /// **Escribir no consulta la red**, y lo que quede pendiente viaja cuando
  /// vuelva.
  late final EstadoNadador _nadador = EstadoNadador(
    sincronizador: Sincronizador(
      registros: _repos.registrosLocales,
      bandeja: BandejaLocal(_almacen),
      red: widget.recursos.red,
      transporte: widget.recursos.transporte,
    ),
    // Para que pueda preguntarle algo de una sesión que ya nadó (feature 010).
    // Nulo sin servidor, y entonces la pantalla no lo ofrece.
    peticiones: _repos.peticionesDeFeedback,
  );

  /// Lo que hay cargado para pintar. **La fuente de verdad son los
  /// repositorios**: esto es una copia que se recarga desde ellos.
  final List<Plan> _planes = [];
  final List<Asignacion> _asignaciones = [];

  ResumenDelEntrenador? _resumen;

  /// Por qué no se pudo contar, si no se pudo. La portada lo dice en lugar de
  /// girar sin fin.
  String? _noSePudoContar;

  /// Qué macrociclo tiene cada nadador: `nadadorId` -> `macrocicloId`.
  ///
  /// Se carga con **una sola consulta** junto con lo demás de la portada, no
  /// una por ficha.
  Map<String, String> _macrocicloDe = const {};

  /// Qué grupo de planes se vino a mirar desde la portada.
  QueMirar _queMirar = QueMirar.todos;

  Rol? get _rol => widget.modoLocal ? _recorridoLocal : widget.cuenta?.rol;

  bool get _esEntrenador => _rol == Rol.entrenador;

  /// Carga lo que el recorrido de quien entró necesita, y **solo eso**.
  ///
  /// La diferencia no es de comodidad: pedir la lista de planes es una lectura
  /// que las reglas le deniegan a un nadador, así que su recorrido tiene que
  /// llegar a lo suyo por sus asignaciones.
  Future<void> _cargar() async {
    if (_esEntrenador) {
      await _recargar();
    } else {
      await _abrirMiPerfil();
    }
  }

  /// **El nadador llega a lo suyo sin tocar nada** (T067).
  ///
  /// Antes su perfil solo se abría si elegía un chip en el selector del
  /// entrenador, y ese selector se alimenta de una lista que las reglas no le
  /// dejan leer: veía «Todavía no hay perfiles. Crea uno en la pestaña
  /// Nadadores» —sobre una pestaña que no tiene— y su plan no aparecía nunca.
  ///
  /// Ahora sale de su cuenta: su ficha, sus asignaciones, y de ahí su plan
  /// publicado.
  Future<void> _abrirMiPerfil() async {
    final nadadorId = widget.cuenta?.nadadorId;
    if (nadadorId == null) return;

    try {
      final nadador = await _repos.nadadores.obtener(nadadorId);
      if (nadador == null) return;

      final suyas = await _repos.asignaciones.deNadador(nadadorId);

      // De haber varios, el último: es el que está entrenando. Misma regla que
      // `planDe`, que no se puede reutilizar aquí porque esa trabaja sobre la
      // lista completa de planes y el nadador no puede pedirla.
      Plan? plan;
      for (final asignacion in suyas) {
        final candidato = await _repos.planes.obtener(asignacion.planId);
        if (candidato != null && candidato.estado == EstadoPlan.publicado) {
          plan = candidato;
        }
      }

      final registros = plan == null
          ? <RegistroDeSesion>[]
          // Su teléfono y el servidor: entrar desde otro aparato no le
          // borra lo que ya había contestado.
          : await _repos.registrosDelNadador.obtenerDePlan(
              nadadorId,
              plan.id ?? '',
            );

      if (!mounted) return;
      _nadador.abrirComo(nadador, plan: plan, registros: registros);
      await _nadador.sincronizar();
    } on FalloDeDatos {
      // Sin red y sin caché, entra igual: su plan aparecerá cuando se pueda
      // leer. Dejarlo fuera de la app por un problema de lectura sería lo
      // contrario de lo que la feature 003 promete.
    }
  }

  /// Vuelve a leer lo del entrenador, y recuenta su resumen.
  Future<void> _recargar() async {
    try {
      final listados = await _repos.planes.listar();

      // **Los borradores, completos.**
      //
      // `listar()` no trae las sesiones a propósito: es una consulta en lugar
      // de una por plan. Pero sin sesiones la auditoría da cualquier plan por
      // incompleto, así que «esperando tu firma» no podía dar otra cosa que
      // cero —lo enseñó la app, con un borrador delante y el número en 0—.
      //
      // Se completan **solo los borradores**, que son pocos y son los únicos
      // que el número mira. Los demás se quedan como vienen.
      final planes = <Plan>[];
      for (final plan in listados) {
        final id = plan.id;
        if (plan.estado != EstadoPlan.borrador || id == null) {
          planes.add(plan);
          continue;
        }
        planes.add(await _repos.planes.obtener(id) ?? plan);
      }

      final asignaciones = await _repos.asignaciones.listar();
      final conRegistros = await _repos.registrosParaContar
          .nadadoresConRegistros();
      final macrociclos = await _repos.macrociclos.macrocicloPorNadador();

      if (!mounted) return;
      setState(() {
        _planes
          ..clear()
          ..addAll(planes);
        _asignaciones
          ..clear()
          ..addAll(asignaciones);
        _macrocicloDe = macrociclos;
        _resumen = ResumenDelEntrenador.de(
          planes: planes,
          asignaciones: asignaciones,
          nadadoresConRegistros: conRegistros,
        );
      });
    } catch (fallo) {
      // **Cualquier fallo, no solo los que tienen nombre.**
      //
      // Lo encontró la app en vivo: un documento con una forma que el cliente
      // no esperaba —una fecha guardada como marca de tiempo donde se leía
      // texto— lanza un `TypeError`, que no es `FalloDeDatos` ni
      // `FalloDeAlmacenLocal`. Con un `catch` por tipo, eso se escapaba y
      // **la portada se quedaba girando para siempre**, sin decir nada.
      //
      // Girar sin fin es la peor respuesta posible: no se puede distinguir de
      // «está tardando». Así que se guarda qué pasó y la pantalla lo dice.
      if (!mounted) return;
      setState(() => _noSePudoContar = '$fallo');
    }
  }

  /// Publica y asigna: es el puente entre el entrenador y el nadador.
  ///
  /// **Dos cosas distintas y por eso dos parámetros.** El plan cambia de
  /// estado; cada entrega es una asignación propia, que en el servidor pasa
  /// por la puerta de consentimiento de ese nadador.
  Future<void> _entregar(Plan publicado, List<String> nadadoresIds) async {
    final planId = publicado.id;
    if (planId == null) return;

    // **Solo el estado.** Reescribir el documento entero —que es lo que hace
    // `guardarAprobado`— cambia más campos que `estado`, y la regla de
    // Firestore solo acepta la entrega cuando el diff afecta a ese y a nada
    // más: lo firmado es inmutable (FR-025). Entregar fallaba con «The caller
    // does not have permission». Lo encontró el recorrido de la feature 009.
    await _repos.planes.publicar(planId);

    // Una escritura por nadador. Cada una pasa por la puerta: si alguno no
    // tiene consentimiento vigente, el servidor la deniega y se dice cuál.
    final sinPermiso = <String>[];
    for (final nadadorId in nadadoresIds) {
      try {
        await _repos.asignaciones.asignar(
          Asignacion(
            planId: planId,
            nadadorId: nadadorId,
            asignadaEn: DateTime.now(),
          ),
        );
      } on FalloDeDatos {
        sinPermiso.add(nadadorId);
      }
    }

    await _recargar();

    if (!mounted || sinPermiso.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No se pudo entregar a ${sinPermiso.length} nadador'
          '${sinPermiso.length == 1 ? '' : 'es'}: les falta el consentimiento '
          'del acudiente.',
        ),
      ),
    );
  }

  /// Carga el perfil elegido con su plan publicado y sus registros.
  ///
  /// Sigue siendo la herramienta del entrenador para abrir la app como uno de
  /// sus nadadores, y en modo local la única forma de ver ese recorrido.
  Future<void> _abrirComoNadador(Nadador nadador) async {
    final plan = planDe(nadador, _planes, _asignaciones);
    final registros = plan == null
        ? <RegistroDeSesion>[]
        : await _repos.registrosDelNadador.obtenerDePlan(
            nadador.id ?? '',
            plan.id ?? '',
          );

    _nadador.abrirComo(nadador, plan: plan, registros: registros);
    await _nadador.sincronizar();
  }

  /// Abre el plan que se está revisando para aprobarlo y entregarlo.
  Future<void> _revisarPlan() async {
    final plan = _editor.planRevisado;
    if (plan == null) return;

    final nadadores = await _repos.nadadores.listar();
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PantallaPlan(
          plan: plan,
          versionMetodologia: widget.recursos.versionMetodologia,
          nadadores: nadadores,
          alEntregar: _entregar,
        ),
      ),
    );
  }

  void _abrirGenerado(MicrocicloGenerado generado) {
    _editor.abrirGenerado(generado.plan);
  }

  /// Empezar un macrociclo para un nadador (feature 009).
  ///
  /// Los dos actos van en dos pantallas: confirmar la estructura y, con lo
  /// guardado, revisar para firmar y entregar. **La navegación está aquí**
  /// porque el HUB es quien tiene los repositorios.
  Future<void> _empezarUnMacrociclo(Nadador ficha) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (contextoDeLaRuta) => PantallaEstructura(
          ficha: ficha,
          biblioteca: widget.recursos.biblioteca,
          indiceTerminos: widget.recursos.indiceTerminos,
          versionMetodologia: widget.recursos.versionMetodologia,
          hoy: DateTime.now(),
          planes: _repos.planes,

          macrociclos: _repos.macrociclos,
          alVolver: () => Navigator.of(contextoDeLaRuta).pop(),
          alConfirmar: (guardado) =>
              Navigator.of(contextoDeLaRuta).pushReplacement<void, void>(
                MaterialPageRoute(
                  builder: (contextoDeLaRevision) => PantallaRevisarMacrociclo(
                    guardado: guardado,
                    hoy: DateTime.now(),
                    planes: _repos.planes,
                    asignaciones: _repos.asignaciones,
                    macrociclos: _repos.macrociclos,
                    alVolver: () => Navigator.of(contextoDeLaRevision).pop(),
                  ),
                ),
              ),
        ),
      ),
    );

    // Al volver, los planes del HUB cambiaron: hay mesociclos nuevos.
    if (mounted) await _cargar();
  }

  /// Abrir el macrociclo que un nadador **ya tiene** (feature 009).
  ///
  /// **Sin esto el reajuste no se podía hacer.** La pantalla de revisión, que
  /// es donde vive, solo se alcanzaba desde `_empezarUnMacrociclo`: salir de
  /// ella dejaba el macrociclo inalcanzable, y en la lista de planes sus
  /// mesociclos aparecían como tres planes sueltos sin nada que dijera que
  /// son uno. El recorrido en el Pixel 7 se paró aquí.
  ///
  /// Y el reajuste está hecho para después (M30, FR-029): el entrenador mira
  /// cómo respondió el nadador y entonces decide. Eso es otro día y otra
  /// sesión de la app.
  Future<void> _verSuMacrociclo(Nadador ficha) async {
    final macrocicloId = _macrocicloDe[ficha.id];
    if (macrocicloId == null) return;

    try {
      final macrociclo = await _repos.macrociclos.obtener(macrocicloId);
      if (macrociclo == null) return;

      final mesociclos = <Plan>[];
      for (final id in macrociclo.mesociclos) {
        final plan = await _repos.planes.obtener(id);
        if (plan != null) mesociclos.add(plan);
      }

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (contextoDeLaRevision) => PantallaRevisarMacrociclo(
            guardado: MacrocicloGuardado(
              macrociclo: macrociclo,
              mesociclos: mesociclos,
            ),
            hoy: DateTime.now(),
            planes: _repos.planes,
            asignaciones: _repos.asignaciones,
            macrociclos: _repos.macrociclos,
            alVolver: () => Navigator.of(contextoDeLaRevision).pop(),
          ),
        ),
      );

      // Al volver pudo haber reajuste: hay versiones nuevas de mesociclos.
      if (mounted) await _cargar();
    } on FalloDeDatos catch (problema) {
      if (!mounted) return;
      setState(() => _noSePudoContar = problema.mensaje);
    }
  }

  @override
  void dispose() {
    _editor.dispose();
    _nadador.dispose();
    super.dispose();
  }

  /// El selector de perfil: **solo del entrenador y del modo local**.
  ///
  /// En el recorrido del nadador le hablaba de una pestaña que no tiene, y su
  /// perfil se abre solo desde su cuenta.
  Widget? get _selector {
    if (!widget.modoLocal && _esEntrenador) return null;
    if (!widget.modoLocal) return null;

    return FutureBuilder<List<Nadador>>(
      future: _repos.nadadores.listar(),
      builder: (context, instantanea) => SelectorDePerfil(
        estado: _nadador,
        nadadores: instantanea.data ?? const [],
        planes: _planes,
        asignaciones: _asignaciones,
        alElegir: _abrirComoNadador,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rol = _rol;

    if (rol == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(Espaciado.seccion),
            child: Text(
              'Tu cuenta todavía no tiene nada asignado.\n'
              'Cuando tu entrenador te inscriba, aparecerá aquí.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final ctx = ContextoDelHub(
      biblioteca: widget.recursos.biblioteca,
      indiceTerminos: widget.recursos.indiceTerminos,
      versionMetodologia: widget.recursos.versionMetodologia,
      nadadores: _repos.nadadores,
      peticiones: _repos.peticiones,
      estaRetenida: _repos.estaRetenida,
      alReintentarLoRetenido: _repos.reintentarLoRetenido,
      repositorioPlanes: _repos.planes,
      molestias: _molestias,
      alCerrarPeticion: widget.recursos.operaciones?.cerrarPeticion,
      almacen: _almacen,
      editor: _editor,
      nadador: _nadador,
      planes: _planes,
      asignaciones: _asignaciones,
      resumenDelEntrenador: _resumen,
      noSePudoContar: _noSePudoContar,
      queMirar: _queMirar,
      idsQueMirar: _resumen?.idsDe(_queMirar),
      alQuitarElFiltro: () => setState(() => _queMirar = QueMirar.todos),
      alMirar: (que) => setState(() {
        _queMirar = que;
        _destino = Destino.verPlan;
      }),
      irAVerPlan: () => setState(() => _destino = Destino.verPlan),
      alGenerar: _abrirGenerado,
      alRevisarPlan: _revisarPlan,
      alEntregar: _entregar,
      // Sin servidor no se ofrece: un macrociclo que no se puede guardar es
      // una pantalla que no puede terminar lo que empieza (H12).
      alEmpezarUnMacrociclo: widget.recursos.firestore == null
          ? null
          : _empezarUnMacrociclo,
      alVerSuMacrociclo: widget.recursos.firestore == null
          ? null
          : _verSuMacrociclo,
      quienTieneMacrociclo: _macrocicloDe.keys.toSet(),
      macrociclos: widget.recursos.firestore == null
          ? null
          : _repos.macrociclos,
      // **Su teléfono y el servidor**: su historial no se queda en un
      // aparato (hallazgo del recorrido de la 009).
      registrosDelNadador: _repos.registrosDelNadador,
      // **Del servidor, no de su dispositivo** (feature 010, decisión D3).
      registrosDelEntrenador: _repos.registrosParaElEntrenador,
      // Aparte de `macrociclos`, que es el del nadador y se queda nulo sin
      // servidor para que `Ver Plan` enseñe su sesión de hoy.
      macrociclosDelEntrenador: _repos.macrociclos,
      // Lo que los nadadores le preguntaron sobre una sesión (US4).
      peticionesDeFeedback: _repos.peticionesDeFeedback,
      asignacionesDelEntrenador: _repos.asignaciones,
      hoy: widget.hoyParaPruebas ?? DateTime.now(),
      selectorDePerfil: _selector,
      uid: widget.cuenta?.id ?? '',
      nadadorId: widget.cuenta?.nadadorId,
      repositorioPerfil: _repositorioPerfil,
      operaciones: widget.recursos.operaciones,
      identidad: widget.recursos.identidad,
      constancias: _constancias,
      // **Aquí se enchufa por primera vez lo que la feature 004 construyó.**
      // `DerechosDelTitular` existía con sus pruebas y ninguna pantalla lo
      // montaba: los tres derechos de la Ley 1581 estaban en el código y no
      // estaban para la persona.
      derechos: DerechosDelTitular(
        nadadores: _repos.nadadores,
        registros: _repos.registrosParaContar,
        asignaciones: _repos.asignaciones,
      ),
      alElegirApariencia: widget.alElegirApariencia,
      conmutadorDeRecorrido: widget.modoLocal ? _conmutadorDeRecorrido() : null,
    );

    return PopScope(
      // Volver atrás lleva a `Home`; desde `Home`, sale de la app (H10).
      canPop: _destino == Destino.home,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho && _destino != Destino.home) {
          setState(() => _destino = Destino.home);
        }
      },
      child: Scaffold(
        // **Por debajo del reloj.** Sin esto, en un teléfono la franja de
        // sesión se pinta bajo la barra de estado y «Entrenador» queda encima
        // de la hora. El `Scaffold` no lo evita por su cuenta cuando no hay
        // `AppBar`, que es el caso desde que el HUB pone su propio título.
        //
        // `bottom: false` porque abajo ya se encarga `NavigationBar`, que
        // añade el hueco de la barra de gestos él mismo; duplicarlo dejaría
        // una franja vacía.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _BarraDeSesion(
                cuenta: widget.cuenta,
                modoLocal: widget.modoLocal,
              ),
              // El nombre del destino, cuando la barra no puede mostrarlo.
              // Nadie se queda sin saber dónde está.
              _TituloDelDestino(destino: _destino),
              Expanded(
                child: IndexedStack(
                  index: _destino.posicion,
                  children: [
                    for (final destino in Destino.values)
                      contenidoDe(destino, rol, ctx),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, medidas) {
            // **Donde no caben, cede la barra y no la palabra.**
            //
            // Son cuentas, no gusto: a 320 px cada destino tiene 64, y
            // «Ver Plan» necesita 100 con la etiqueta de 13 px que la feature
            // 005 declaró como suelo —«no baja de aquí», porque algunos de
            // quienes leen esto tienen nueve años—. Cinco etiquetas en
            // español piden unos 440 px, más de lo que mide un teléfono.
            //
            // Así que por debajo de ese ancho la barra muestra iconos y el
            // nombre del destino va de título, entero y a tamaño de lectura.
            // Abreviar «Análisis» o encoger la letra sería decidir que el
            // vocabulario cede ante la maquetación, y en esta app es al revés.
            final caben = medidas.maxWidth >= anchoParaLasEtiquetas;

            return NavigationBar(
              selectedIndex: _destino.posicion,
              labelBehavior: caben
                  ? NavigationDestinationLabelBehavior.alwaysShow
                  : NavigationDestinationLabelBehavior.alwaysHide,
              onDestinationSelected: (posicion) =>
                  setState(() => _destino = Destino.values[posicion]),
              destinations: [
                for (final destino in Destino.values)
                  NavigationDestination(
                    key: Key('destino-${destino.name}'),
                    icon: Icon(iconoDe(destino)),
                    selectedIcon: Icon(iconoDe(destino, activo: true)),
                    label: destino.etiqueta,
                    tooltip: destino.etiqueta,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Quién está dentro, y el aviso de modo local.
///
/// **Ya no lleva «Salir»**: cerrar sesión vive en `Ajustes` desde la feature
/// 007 (H23, FR-019), y tenerlo en dos sitios no lo hace más fácil de
/// encontrar, solo más fácil de pulsar sin querer.
///
/// El aviso de modo local **se queda**, porque avisa de una condición y no de
/// una identidad: sin servidor no hay consentimiento registrado, y el
/// principio V exige que entonces la app se use solo con datos de prueba.
class _BarraDeSesion extends StatelessWidget {
  const _BarraDeSesion({required this.cuenta, required this.modoLocal});

  final Cuenta? cuenta;
  final bool modoLocal;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    if (modoLocal) {
      // **Tono de cuidado, no de error.**
      //
      // El modo local no es un fallo: es un modo de trabajo, el que permite
      // desarrollar sin servidor. Lo que exige es cuidado.
      return const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Espaciado.amplio,
          vertical: Espaciado.corto,
        ),
        child: Aviso(
          tono: TonoDeAviso.cuidado,
          icono: Icons.cloud_off_outlined,
          claveDelMensaje: Key('aviso-modo-local'),
          mensaje:
              'Modo local, sin servidor: no hay cuentas ni consentimiento '
              'registrado, y nada se guarda al cerrar. Solo datos de prueba. '
              'El recorrido se elige en Ajustes.',
        ),
      );
    }

    final dentro = cuenta;
    if (dentro == null) return const SizedBox.shrink();

    return Material(
      key: const Key('barra-de-sesion'),
      color: esquema.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaciado.amplio,
          vertical: Espaciado.minimo,
        ),
        child: Row(
          children: [
            Icon(
              dentro.esEntrenador ? Icons.sports : Icons.person_outline,
              size: 18,
            ),
            const SizedBox(width: Espaciado.corto),
            Expanded(
              child: Text(
                dentro.esEntrenador ? 'Entrenador' : 'Nadador',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuántos píxeles de ancho hacen falta para que las cinco etiquetas caben.
///
/// Medido, no elegido: la más larga —«Ver Plan»— pide 100 px con la etiqueta de
/// 13 px que la feature 005 fijó como suelo, y son cinco. Por debajo de esto la
/// barra pasa a iconos y el nombre va de título (garantía H9).
///
/// En la práctica: **ningún teléfono llega**. Los anchos de teléfono van de 320
/// a 430, así que las cinco etiquetas se ven en tableta y en escritorio, y en el
/// teléfono se ve el nombre del destino actual, entero, como título.
const double anchoParaLasEtiquetas = 500;

/// El nombre del destino, cuando la barra no puede mostrarlo.
///
/// No es decoración: es la mitad de la promesa. La barra cede las etiquetas en
/// pantallas angostas, y el nombre tiene que seguir leyéndose **entero y a
/// tamaño de lectura** en alguna parte.
class _TituloDelDestino extends StatelessWidget {
  const _TituloDelDestino({required this.destino});

  final Destino destino;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    if (ancho >= anchoParaLasEtiquetas) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        left: Espaciado.amplio,
        right: Espaciado.amplio,
        top: Espaciado.normal,
      ),
      child: Row(
        children: [
          Icon(iconoDe(destino, activo: true), size: 20),
          const SizedBox(width: Espaciado.corto),
          Expanded(
            child: Text(
              destino.etiqueta,
              key: Key('titulo-${destino.name}'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}
