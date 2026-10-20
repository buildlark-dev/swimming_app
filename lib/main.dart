import 'dart:async';

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/auth/sesion_firebase.dart';
import 'package:natacion_app/datos/firestore/configuracion.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/ui/acceso/estado_sesion.dart';
import 'package:natacion_app/ui/tema/tema.dart';
import 'package:natacion_app/ui/acceso/pantalla_acceso.dart';
import 'package:natacion_app/datos/firestore/envio_registros.dart';
import 'package:natacion_app/datos/firestore/repositorios_firestore.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/local/repositorios_locales.dart';
import 'package:natacion_app/datos/recursos/biblioteca_empaquetada.dart';
import 'package:natacion_app/datos/red/estado_de_red.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_mi_progreso.dart';
import 'package:natacion_app/ui/nadador/perfil_activo.dart';
import 'package:natacion_app/ui/planes/pantalla_plan.dart';
import 'package:natacion_app/ui/nadador/pantalla_sesion_del_dia.dart';
import 'package:natacion_app/datos/recursos/version_metodologia.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/ui/editor/pantalla_editor.dart';
import 'package:natacion_app/ui/generacion/pantalla_peticion.dart';
import 'package:natacion_app/ui/nadadores/pantalla_perfiles.dart';
import 'package:provider/provider.dart';

/// Punto de entrada de la aplicación.
///
/// `USAR_EMULADORES` se pasa con `--dart-define=USAR_EMULADORES=true` y decide
/// si la capa de datos apunta a los emuladores locales. Por omisión es falsa,
/// de modo que un arranque descuidado nunca escriba en un proyecto real.
const bool usarEmuladores =
    bool.fromEnvironment('USAR_EMULADORES', defaultValue: false);

void main() {
  runApp(const AppNatacion());
}

/// Todo lo que la app necesita cargar antes de empezar.
class RecursosIniciales {
  const RecursosIniciales({
    required this.biblioteca,
    required this.versionMetodologia,
    required this.indiceTerminos,
    required this.red,
    required this.transporte,
    this.identidad,
    this.firestore,
  });

  final Biblioteca biblioteca;
  final String versionMetodologia;

  /// Vocabulario de diagnóstico del entrenador. Puede venir vacío: entonces
  /// los diagnósticos se reportan como vacío de Biblioteca en lugar de
  /// resolverse con un ejercicio aproximado.
  final IndiceTerminos indiceTerminos;

  /// Si hay red, para el recorrido del nadador (feature 003).
  final EstadoDeRed red;

  /// Quién lleva los registros del nadador a su destino.
  final EnvioDeRegistros transporte;

  /// Quién está usando la app (feature 004).
  ///
  /// Nula cuando no hay servidor con el que hablar. Entonces la app entra en
  /// **modo local**: ver [PantallaPrincipal.modoLocal].
  final Identidad? identidad;

  /// La base de datos, si la hay. Nula en modo local.
  ///
  /// Es lo que decide si el trabajo del entrenador sobrevive al cierre de la
  /// app o se pierde al recargar.
  final FirebaseFirestore? firestore;
}

class AppNatacion extends StatelessWidget {
  const AppNatacion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planificación de natación',
      theme: temaSeguro(Tema.claro),
      darkTheme: temaSeguro(Tema.oscuro),
      // Sigue al sistema, sin ajuste propio (decisión D3). El interruptor
      // pertenece a la pantalla de Ajustes de la feature 007, y construirlo
      // aquí sería hacer algo que esa feature va a rehacer.
      themeMode: ThemeMode.system,
      home: const PantallaInicio(),
    );
  }
}

/// El tema, o la apariencia por omisión si no se pudiera construir.
///
/// **Garantía V14**: quedarse sin abrir por un asunto de aspecto no es
/// aceptable. Ya hubo un caso en este proyecto —el arranque sin Firebase del
/// PR #5— donde un fallo que debía degradar tumbaba el arranque entero, y la
/// lección fue que estas cosas se escriben antes de necesitarlas.
///
/// Se atrapa cualquier fallo, no solo las excepciones: un error al construir
/// una escala de color es un `Error`, no una `Exception`, que es exactamente
/// lo que se nos escapó aquella vez.
ThemeData temaSeguro(ThemeData Function() construir) {
  try {
    return construir();
  } catch (_) {
    return ThemeData(useMaterial3: true);
  }
}

/// Carga la Biblioteca Oficial y la versión de metodología antes de abrir la
/// app. Sin biblioteca no se puede comprobar la regla de no invención, así que
/// no se muestra nada hasta tenerla.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late final Future<RecursosIniciales> _recursos = _cargar();

  /// De todo lo que se carga aquí, **solo la biblioteca puede tumbar el
  /// arranque**. Es deliberado: sin ella no se puede comprobar la regla de no
  /// invención, así que no hay app que mostrar. Todo lo demás degrada: la
  /// versión de metodología se marca como desconocida, el índice de términos
  /// queda vacío y Firestore, si no está, deja la app trabajando en local.
  /// Si algún día otro recurso empieza a propagar, el mensaje de error de
  /// abajo pasa a mentir.
  Future<RecursosIniciales> _cargar() async {
    final biblioteca = await CargadorBiblioteca().cargar();
    final version = await CargadorVersionMetodologia().cargar();
    final indice = await CargadorIndiceTerminos().cargar();
    // Firestore puede no estar: sin credenciales, sin emuladores, o sin red.
    // **La app arranca igual.** El nadador lee y escribe en local, y lo
    // pendiente espera. Caerse porque no hay conexión sería justo lo contrario
    // de lo que esta feature promete.
    final datos =
        await const ConfiguracionDatos(usarEmuladores: usarEmuladores)
            .conectar();

    return RecursosIniciales(
      biblioteca: biblioteca,
      versionMetodologia: version,
      indiceTerminos: indice,
      // La detección de red sondea de verdad en lugar de preguntarle al
      // sistema: «hay wifi» y «el servidor responde» son cosas distintas, y a
      // pie de piscina la segunda es la que importa.
      red: RedPorSondeo(sondear: () async => datos != null),
      transporte: _TransporteSiHayFirestore(datos),
      // Sin Firestore no hay con quién autenticarse. La app arranca igual y
      // entra en modo local, que es lo que permite seguir desarrollando sin
      // levantar los emuladores.
      identidad:
          datos == null ? null : SesionFirebase.porOmision(firestore: datos),
      firestore: datos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecursosIniciales>(
      future: _recursos,
      builder: (context, instantanea) {
        if (instantanea.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Planificación de natación')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la Biblioteca Oficial de ejercicios.\n'
                  'Sin ella no se puede comprobar la regla de no invención.\n\n'
                  '${instantanea.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (!instantanea.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _Acceso(recursos: instantanea.data!);
      },
    );
  }
}

/// Decide qué se enseña según haya sesión o no.
///
/// Sin servidor no hay con quién autenticarse, y la app entra en **modo
/// local**. No es un atajo: es el modo en que se desarrolla sin levantar los
/// emuladores, y en él no hay nada que proteger porque no hay dónde guardar
/// nada. Va rotulado para que nadie lo confunda con la app de verdad.
class _Acceso extends StatelessWidget {
  const _Acceso({required this.recursos});

  final RecursosIniciales recursos;

  @override
  Widget build(BuildContext context) {
    final identidad = recursos.identidad;

    if (identidad == null) {
      return PantallaPrincipal(recursos: recursos, modoLocal: true);
    }

    return ChangeNotifierProvider<SesionActiva>(
      create: (_) => SesionActiva(identidad: identidad),
      child: Consumer<SesionActiva>(
        builder: (context, sesion, _) {
          switch (sesion.estado) {
            case EstadoDeSesion.comprobando:
              // No se enseña la pantalla de acceso mientras no se sepa quién
              // eres: haría parpadear a quien ya tiene sesión cada vez que
              // abre la app al borde de la piscina.
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );

            case EstadoDeSesion.preparando:
              // La cuenta existe; el servidor todavía le está asignando el
              // rol. Dura unos segundos y hay que decirlo, no dejar la
              // pantalla en blanco ni devolver a nadie al login.
              return const _Preparando();

            case EstadoDeSesion.sinRol:
              return _SinRol(
                alReintentar: () => sesion.reintentar(),
                alSalir: () => sesion.cerrarSesion(),
              );

            case EstadoDeSesion.fuera:
              return PantallaAcceso(
                alEnviar: ({
                  required String correo,
                  required String clave,
                  required ModoDeAcceso modo,
                }) async {
                  try {
                    if (modo == ModoDeAcceso.crear) {
                      await identidad.crearCuenta(correo: correo, clave: clave);
                    } else {
                      await identidad.entrar(correo: correo, clave: clave);
                    }
                    return null;
                  } on FalloDeAcceso catch (e) {
                    return e.mensaje;
                  }
                },
              );

            case EstadoDeSesion.dentro:
              return PantallaPrincipal(
                // La clave fuerza a reconstruir el estado entero al cambiar de
                // cuenta. Sin esto, el editor, la bandeja y el recorrido del
                // nadador sobrevivirían al cambio y el segundo hermano vería
                // lo del primero.
                key: ValueKey(sesion.cuenta!.id),
                recursos: recursos,
                cuenta: sesion.cuenta,
              );
          }
        },
      ),
    );
  }
}

/// La cuenta existe y el servidor le está asignando el rol.
class _Preparando extends StatelessWidget {
  const _Preparando();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Preparando tu cuenta',
                key: const Key('preparando-cuenta'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tarda unos segundos la primera vez.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hay sesión, pero el rol nunca llegó.
///
/// Se muestra en lugar de devolver al login, porque volver al login invita a
/// registrarse otra vez y el problema se repite igual.
class _SinRol extends StatelessWidget {
  const _SinRol({required this.alReintentar, required this.alSalir});

  final VoidCallback alReintentar;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_disabled_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Tu cuenta quedó a medio preparar',
                  key: const Key('cuenta-sin-rol'),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'La cuenta existe, pero el servidor no terminó de '
                  'configurarla. No hace falta volver a crearla: eso haría '
                  'una cuenta nueva con el mismo problema.\n\n'
                  'Avisa al entrenador.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('boton-reintentar-rol'),
                  onPressed: alReintentar,
                  child: const Text('Volver a intentarlo'),
                ),
                TextButton(onPressed: alSalir, child: const Text('Salir')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Navegación entre el editor de sesión y los perfiles de nadador.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({
    super.key,
    required this.recursos,
    this.cuenta,
    this.modoLocal = false,
  });

  final RecursosIniciales recursos;

  /// Quién tiene la sesión abierta. Nula en [modoLocal].
  final Cuenta? cuenta;

  /// Sin servidor: no hay cuentas, no hay consentimiento y no hay dónde
  /// guardar nada. Es el modo de desarrollo, y va rotulado.
  final bool modoLocal;

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    // Lo guardado está ahí antes de que nadie toque nada. Con la persistencia
    // de Firestore activada, esta lectura responde **también sin red**: lo del
    // entrenador se lee de la caché (FR-034).
    unawaited(_recargar());
  }

  /// Los repositorios. Con servidor persisten; en modo local, no.
  ///
  /// Hasta la feature 004 `main.dart` usaba los de memoria **aunque los de
  /// Firestore existieran desde la 001**: estaban escritos y nadie los
  /// llamaba. El trabajo del entrenador se perdía al recargar.
  late final FirebaseFirestore? _db = widget.recursos.firestore;

  late final RepositorioSesiones _sesiones = _db == null
      ? RepositorioSesionesMemoria()
      : RepositorioSesionesFirestore(_db, widget.recursos.biblioteca);

  late final RepositorioPlanes _repoPlanes = _db == null
      ? RepositorioPlanesMemoria()
      : RepositorioPlanesFirestore(
          _db,
          widget.recursos.biblioteca,
          _sesiones,
        );

  late final RepositorioNadadores _nadadores = _db == null
      ? RepositorioNadadoresMemoria()
      : RepositorioNadadoresFirestore(_db);

  late final RepositorioAsignaciones _repoAsignaciones = _db == null
      ? RepositorioAsignacionesMemoria()
      : RepositorioAsignacionesFirestore(_db);

  /// Un solo estado de editor para toda la app, para que lo generado en la
  /// primera pestaña aparezca en la segunda.
  late final EstadoEditor _editor =
      EstadoEditor(biblioteca: widget.recursos.biblioteca);

  /// Estado del recorrido del nadador (feature 003).
  ///
  /// Se monta sobre el almacén local y la bandeja de salida: **escribir no
  /// consulta la red**, y lo que quede pendiente viaja cuando vuelva.
  late final EstadoNadador _nadador = EstadoNadador(
    sincronizador: Sincronizador(
      registros: RegistrosLocales(_almacen),
      bandeja: BandejaLocal(_almacen),
      red: widget.recursos.red,
      transporte: widget.recursos.transporte,
    ),
  );

  /// Particionado por cuenta: dos hermanos con el mismo teléfono no comparten
  /// ni una clave, tampoco en la bandeja de salida (garantía A9).
  late final AlmacenLocal _almacen =
      AlmacenPreferencias(cuentaId: widget.cuenta?.id);

  /// Lo que hay cargado ahora mismo, para pintar. **La fuente de verdad son
  /// los repositorios**: esto es una copia que se recarga desde ellos.
  final List<Plan> _planes = [];

  late final RegistrosLocales _registros = RegistrosLocales(_almacen);

  /// A quiénes se les ha entregado cada plan.
  ///
  /// Una asignación por nadador, no una lista dentro del plan: ver
  /// `lib/dominio/entidades/asignacion.dart`.
  final List<Asignacion> _asignaciones = [];

  /// Publica y asigna: es el puente entre el entrenador y el nadador.
  ///
  /// **Dos cosas distintas y por eso dos parámetros.** El plan cambia de
  /// estado; cada entrega es una asignación propia, que en el servidor pasa
  /// por la puerta de consentimiento de ese nadador.
  Future<void> _entregar(Plan publicado, List<String> nadadoresIds) async {
    final planId = publicado.id;
    if (planId == null) return;

    await _repoPlanes.guardarAprobado(publicado, const {});

    // Una escritura por nadador. Cada una pasa por la puerta: si alguno no
    // tiene consentimiento vigente, el servidor la deniega y se dice cuál.
    final sinPermiso = <String>[];
    for (final nadadorId in nadadoresIds) {
      try {
        await _repoAsignaciones.asignar(
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

  /// Vuelve a leer de los repositorios lo que se pinta.
  Future<void> _recargar() async {
    final planes = await _repoPlanes.listar();
    final asignaciones = await _repoAsignaciones.listar();

    if (!mounted) return;
    setState(() {
      _planes
        ..clear()
        ..addAll(planes);
      _asignaciones
        ..clear()
        ..addAll(asignaciones);
    });
  }

  /// Carga el perfil elegido con su plan publicado y sus registros.
  Future<void> _abrirComoNadador(Nadador nadador) async {
    final plan = planDe(nadador, _planes, _asignaciones);
    final registros = plan == null
        ? <RegistroDeSesion>[]
        : await _registros.obtenerDePlan(nadador.id ?? '', plan.id ?? '');

    _nadador.abrirComo(nadador, plan: plan, registros: registros);
    await _nadador.sincronizar();
  }

  /// Abre el plan que se está revisando para aprobarlo y entregarlo.
  Future<void> _revisarPlan() async {
    final plan = _editor.planRevisado;
    if (plan == null) return;

    final nadadores = await _nadadores.listar();
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

  @override
  void dispose() {
    _editor.dispose();
    _nadador.dispose();
    super.dispose();
  }

  void _abrirGenerado(MicrocicloGenerado generado) {
    _editor.abrirGenerado(generado.plan);
    setState(() => _indice = 1);
  }

  /// Qué pestañas le tocan a quien está dentro.
  ///
  /// No es una comodidad: un nadador no tiene nada que hacer en el editor, y
  /// las reglas de acceso le denegarían todo lo que intentara desde ahí. Lo
  /// que decide es `Permisos`, no una condición escrita en esta pantalla.
  ///
  /// En modo local se ven todas, porque no hay rol que consultar y es el modo
  /// con el que se desarrolla.
  bool _leToca(_Pestana pestana) {
    if (widget.modoLocal) return true;
    final cuenta = widget.cuenta;
    if (cuenta == null) return false;
    return pestana.esDelEntrenador ? cuenta.esEntrenador : cuenta.esNadador;
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = <Widget>[
      PantallaPeticion(
        biblioteca: widget.recursos.biblioteca,
        indiceTerminos: widget.recursos.indiceTerminos,
        alGenerar: _abrirGenerado,
      ),
      ChangeNotifierProvider<EstadoEditor>.value(
        value: _editor,
        child: PantallaEditor(alRevisarPlan: _revisarPlan),
      ),
      PantallaPerfiles(repositorio: _nadadores),
      // El recorrido del nadador va en su propia pestaña y sobre su propio
      // estado. Es la feature 003: el nadador y el entrenador son dos
      // recorridos distintos sobre el mismo dominio, y mezclarlos en las mismas
      // pantallas haría que cada cambio para uno arriesgara al otro.
      ChangeNotifierProvider<EstadoNadador>.value(
        value: _nadador,
        child: PantallaSesionDelDia(
          selector: FutureBuilder<List<Nadador>>(
            future: _nadadores.listar(),
            builder: (context, instantanea) => SelectorDePerfil(
              estado: _nadador,
              nadadores: instantanea.data ?? const [],
              planes: _planes,
              asignaciones: _asignaciones,
              alElegir: _abrirComoNadador,
            ),
          ),
        ),
      ),
      ChangeNotifierProvider<EstadoNadador>.value(
        value: _nadador,
        child: const PantallaMiProgreso(),
      ),
    ];

    // Pestaña y pantalla van emparejadas para que filtrar por rol no pueda
    // desalinear los índices. Hacerlo con dos listas paralelas y un índice
    // compartido es la forma clásica de acabar enseñando el editor al pulsar
    // «Mi progreso».
    final visibles = <(_Pestana, Widget)>[
      for (var i = 0; i < _Pestana.values.length; i++)
        if (_leToca(_Pestana.values[i])) (_Pestana.values[i], pantallas[i]),
    ];

    if (visibles.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tu cuenta todavía no tiene nada asignado.\n'
              'Cuando tu entrenador te inscriba, aparecerá aquí.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final indice = _indice.clamp(0, visibles.length - 1);

    return Scaffold(
      body: Column(
        children: [
          _BarraDeSesion(cuenta: widget.cuenta, modoLocal: widget.modoLocal),
          Expanded(child: visibles[indice].$2),
        ],
      ),
      bottomNavigationBar: visibles.length < 2
          ? null
          : NavigationBar(
              selectedIndex: indice,
              onDestinationSelected: (i) => setState(() => _indice = i),
              destinations: [
                for (final (pestana, _) in visibles)
                  NavigationDestination(
                    icon: Icon(pestana.icono),
                    selectedIcon: Icon(pestana.iconoActivo),
                    label: pestana.etiqueta,
                  ),
              ],
            ),
    );
  }
}

/// Las pestañas de la app, y de quién es cada una.
enum _Pestana {
  generar(
    etiqueta: 'Generar',
    icono: Icons.auto_awesome_outlined,
    iconoActivo: Icons.auto_awesome,
    esDelEntrenador: true,
  ),
  editor(
    etiqueta: 'Editor',
    icono: Icons.edit_note_outlined,
    iconoActivo: Icons.edit_note,
    esDelEntrenador: true,
  ),
  nadadores(
    etiqueta: 'Nadadores',
    icono: Icons.groups_outlined,
    iconoActivo: Icons.groups,
    esDelEntrenador: true,
  ),
  miSesion(
    etiqueta: 'Mi sesión',
    icono: Icons.pool_outlined,
    iconoActivo: Icons.pool,
    esDelEntrenador: false,
  ),
  miProgreso(
    etiqueta: 'Mi progreso',
    icono: Icons.timeline_outlined,
    iconoActivo: Icons.timeline,
    esDelEntrenador: false,
  );

  const _Pestana({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.esDelEntrenador,
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final bool esDelEntrenador;
}

/// Quién está dentro, y por dónde se sale.
///
/// En modo local, en cambio, avisa de que no hay servidor. No es decoración:
/// sin servidor no hay consentimiento registrado, y el principio V exige que
/// en ese caso la app se use solo con datos de prueba.
class _BarraDeSesion extends StatelessWidget {
  const _BarraDeSesion({required this.cuenta, required this.modoLocal});

  final Cuenta? cuenta;
  final bool modoLocal;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    if (modoLocal) {
      return Material(
        color: esquema.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: esquema.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Modo local, sin servidor: no hay cuentas ni consentimiento '
                  'registrado, y nada se guarda al cerrar. Solo datos de '
                  'prueba.',
                  key: const Key('aviso-modo-local'),
                  style: TextStyle(color: esquema.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dentro = cuenta;
    if (dentro == null) return const SizedBox.shrink();

    return Material(
      color: esquema.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(
              dentro.esEntrenador ? Icons.sports : Icons.person_outline,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dentro.esEntrenador ? 'Entrenador' : 'Nadador',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton.icon(
              key: const Key('boton-cerrar-sesion'),
              onPressed: () => context.read<SesionActiva>().cerrarSesion(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Salir'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Envía registros si hay Firestore, y si no, falla de forma recuperable.
///
/// Un fallo aquí deja el registro **pendiente** y se reintenta (garantía G3).
/// No es una excepción que el nadador deba ver: es el caso normal a pie de
/// piscina, y el único error que sí se le muestra es el de escritura local.
class _TransporteSiHayFirestore implements EnvioDeRegistros {
  const _TransporteSiHayFirestore(this.firestore);

  final FirebaseFirestore? firestore;

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) {
    final instancia = firestore;
    if (instancia == null) {
      throw const FalloDeDatos('Sin conexión con el servidor');
    }
    return EnvioAFirestore(instancia).enviar(registro);
  }
}
