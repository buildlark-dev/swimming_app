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
  );

  /// Lo que hay cargado para pintar. **La fuente de verdad son los
  /// repositorios**: esto es una copia que se recarga desde ellos.
  final List<Plan> _planes = [];
  final List<Asignacion> _asignaciones = [];

  ResumenDelEntrenador? _resumen;

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
          : await _repos.registrosLocales.obtenerDePlan(
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
      final planes = await _repos.planes.listar();
      final asignaciones = await _repos.asignaciones.listar();
      final conRegistros = await _repos.registrosParaContar
          .nadadoresConRegistros();

      if (!mounted) return;
      setState(() {
        _planes
          ..clear()
          ..addAll(planes);
        _asignaciones
          ..clear()
          ..addAll(asignaciones);
        _resumen = ResumenDelEntrenador.de(
          planes: planes,
          asignaciones: asignaciones,
          nadadoresConRegistros: conRegistros,
        );
      });
    } on FalloDeDatos {
      // El resumen se queda sin contar y la portada lo dice girando, en lugar
      // de mostrar cuatro ceros como si fueran datos.
    } on FalloDeAlmacenLocal {
      // **Y el almacén del dispositivo también puede faltar**: sin servidor,
      // contar quién ha respondido lo lee de ahí. Un navegador sin
      // almacenamiento no puede tumbar el arranque por un número de la
      // portada; es la misma lección del PR #5, cuando un fallo que debía
      // degradar se llevó la app entera.
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

    await _repos.planes.guardarAprobado(publicado, const {});

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
        : await _repos.registrosLocales.obtenerDePlan(
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
      editor: _editor,
      nadador: _nadador,
      planes: _planes,
      asignaciones: _asignaciones,
      resumenDelEntrenador: _resumen,
      irAVerPlan: () => setState(() => _destino = Destino.verPlan),
      alGenerar: _abrirGenerado,
      alRevisarPlan: _revisarPlan,
      alEntregar: _entregar,
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
        body: Column(
          children: [
            _BarraDeSesion(cuenta: widget.cuenta, modoLocal: widget.modoLocal),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _destino.posicion,
          onDestinationSelected: (posicion) =>
              setState(() => _destino = Destino.values[posicion]),
          destinations: [
            for (final destino in Destino.values)
              NavigationDestination(
                key: Key('destino-${destino.name}'),
                icon: Icon(iconoDe(destino)),
                selectedIcon: Icon(iconoDe(destino, activo: true)),
                label: destino.etiqueta,
              ),
          ],
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
