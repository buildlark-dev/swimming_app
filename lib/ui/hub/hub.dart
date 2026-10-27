/// El HUB: la barra de cinco destinos y los dos recorridos.
///
/// Vivía dentro de `main.dart` hasta la feature 007. Sale aquí porque son dos
/// trabajos distintos —arrancar la app y disponerla— y porque esta feature
/// multiplica el segundo por dos recorridos: dejarlo dentro llevaba el archivo
/// de arranque por encima de las mil doscientas líneas (decisión D1).
///
/// Lo que entró aquí entró **sin cambiar nada**. El reparto por rol, los
/// destinos y las pantallas nuevas llegan en las tareas siguientes, cada una
/// con su cerrojo escrito antes.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:natacion_app/datos/firestore/repositorios_firestore.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/local/repositorios_locales.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/recursos/recursos_iniciales.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/acceso/estado_sesion.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';
import 'package:natacion_app/ui/editor/pantalla_editor.dart';
import 'package:natacion_app/ui/generacion/pantalla_peticion.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_mi_progreso.dart';
import 'package:natacion_app/ui/nadador/pantalla_sesion_del_dia.dart';
import 'package:natacion_app/ui/nadador/perfil_activo.dart';
import 'package:natacion_app/ui/nadadores/pantalla_perfiles.dart';
import 'package:natacion_app/ui/planes/pantalla_plan.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

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
      // **Tono de cuidado, no de error.**
      //
      // El modo local no es un fallo: es un modo de trabajo, el que permite
      // desarrollar sin servidor. Lo que exige es cuidado, porque sin servidor
      // no hay consentimiento registrado y el principio V obliga a usar solo
      // datos de prueba. Pintarlo de rojo lo confundía con una avería.
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaciado.amplio,
          vertical: Espaciado.corto,
        ),
        child: const Aviso(
          tono: TonoDeAviso.cuidado,
          icono: Icons.cloud_off_outlined,
          claveDelMensaje: Key('aviso-modo-local'),
          mensaje: 'Modo local, sin servidor: no hay cuentas ni consentimiento '
              'registrado, y nada se guarda al cerrar. Solo datos de prueba.',
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
