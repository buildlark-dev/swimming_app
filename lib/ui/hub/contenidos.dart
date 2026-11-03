/// De contenido a pantalla. **El único sitio donde se decide eso.**
///
/// El reparto —qué contenido le toca a cada rol en cada destino— vive en el
/// dominio y se comprueba sin pintar nada. Aquí solo se empareja cada contenido
/// con la pantalla que lo muestra, y cada destino con su icono, que es lo único
/// de esto que es de Flutter.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/preferencias/apariencia.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/constancia.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/datos_personales/derechos_del_titular.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/hub/destino.dart';
import 'package:natacion_app/dominio/hub/resumen_del_entrenador.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';
import 'package:natacion_app/ui/editor/pantalla_editor.dart';
import 'package:natacion_app/ui/generacion/pantalla_peticion.dart';
import 'package:natacion_app/ui/ajustes/pantalla_ajustes.dart';
import 'package:natacion_app/dominio/peticiones/molestias_enlazadas.dart';
import 'package:natacion_app/ui/hub/cola_del_entrenador.dart';
import 'package:natacion_app/ui/hub/home_del_entrenador.dart';
import 'package:natacion_app/ui/hub/home_del_nadador.dart';
import 'package:natacion_app/ui/hub/planes_del_entrenador.dart';
import 'package:natacion_app/ui/hub/todavia_no.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_mi_progreso.dart';
import 'package:natacion_app/ui/peticion/peticion_del_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_sesion_del_dia.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

/// Lo que las pantallas del HUB necesitan para montarse.
///
/// Va junto en un objeto porque son muchas cosas y pasarlas una por una por
/// cada función intermedia convierte cualquier cambio en una cascada.
class ContextoDelHub {
  const ContextoDelHub({
    required this.biblioteca,
    required this.indiceTerminos,
    required this.versionMetodologia,
    required this.nadadores,
    required this.peticiones,
    required this.almacen,
    this.estaRetenida,
    this.repositorioPlanes,
    this.molestias,
    this.alCerrarPeticion,
    required this.editor,
    required this.nadador,
    required this.planes,
    required this.asignaciones,
    required this.resumenDelEntrenador,
    this.noSePudoContar,
    this.queMirar = QueMirar.todos,
    this.idsQueMirar,
    this.alQuitarElFiltro,
    this.alMirar,
    required this.irAVerPlan,
    required this.alGenerar,
    required this.alRevisarPlan,
    required this.alEntregar,
    required this.uid,
    required this.repositorioPerfil,
    this.nadadorId,
    this.operaciones,
    this.identidad,
    this.constancias,
    this.derechos,
    this.alElegirApariencia,
    this.conmutadorDeRecorrido,
    this.selectorDePerfil,
  });

  final Biblioteca biblioteca;
  final IndiceTerminos indiceTerminos;
  final String versionMetodologia;
  final RepositorioNadadores nadadores;

  /// Lo que los nadadores piden (feature 008). Nulo sin servidor.
  final RepositorioPeticiones? peticiones;

  /// El almacén de esta cuenta, para lo que se responde a medias.
  final AlmacenLocal? almacen;

  /// Donde se guarda el borrador que sale de una petición, antes de firmarlo.
  final RepositorioPlanes? repositorioPlanes;

  /// Si lo que mandó sigue retenido en el dispositivo (feature 008).
  final Future<bool> Function(String nadadorId)? estaRetenida;

  /// Las molestias que el nadador ya contó en sus sesiones. **Se leen donde
  /// ya viven; esta feature no las copia** (FR-038). Nulo sin servidor.
  final LectorDeMolestias? molestias;

  /// Cierra una petición a través del servidor. Nulo sin servidor.
  final AlCerrarPeticion? alCerrarPeticion;

  final EstadoEditor editor;
  final EstadoNadador nadador;

  final List<Plan> planes;
  final List<Asignacion> asignaciones;
  final ResumenDelEntrenador? resumenDelEntrenador;

  /// Por qué no se pudo contar, si no se pudo.
  final String? noSePudoContar;

  /// Qué grupo de planes se está mirando, y cómo salir de él.
  final QueMirar queMirar;
  final Set<String>? idsQueMirar;
  final VoidCallback? alQuitarElFiltro;
  final void Function(QueMirar)? alMirar;

  final VoidCallback irAVerPlan;
  final void Function(MicrocicloGenerado) alGenerar;
  final Future<void> Function() alRevisarPlan;
  final Future<void> Function(Plan, List<String>) alEntregar;

  /// Lo que `Ajustes` necesita. Todo de quien está dentro y de nadie más.
  final String uid;
  final String? nadadorId;
  final RepositorioPerfil repositorioPerfil;
  final OperacionesDelServidor? operaciones;
  final Identidad? identidad;
  final LectorDeConstancias? constancias;
  final DerechosDelTitular? derechos;
  final ValueChanged<Apariencia>? alElegirApariencia;

  /// Solo en modo local: el conmutador de recorrido (decisión D13).
  final Widget? conmutadorDeRecorrido;

  /// La herramienta del entrenador para abrir la app como uno de sus
  /// nadadores. **Nula en el recorrido del nadador**: allí le hablaba de una
  /// pestaña que no tiene, y su perfil se abre solo, desde su cuenta.
  final Widget? selectorDePerfil;
}

/// El icono de cada destino. Lo único de Flutter que el reparto necesita.
IconData iconoDe(Destino destino, {bool activo = false}) {
  return switch (destino) {
    Destino.generar =>
      activo ? Icons.auto_awesome : Icons.auto_awesome_outlined,
    Destino.verPlan => activo ? Icons.pool : Icons.pool_outlined,
    Destino.home => activo ? Icons.home : Icons.home_outlined,
    Destino.analisis => activo ? Icons.timeline : Icons.timeline_outlined,
    Destino.ajustes => activo ? Icons.settings : Icons.settings_outlined,
  };
}

/// Qué se pinta en un destino para un rol.
///
/// La decisión de **qué le toca** no está aquí: está en `reparto`, en el
/// dominio. Aquí solo se traduce a widgets.
Widget contenidoDe(Destino destino, Rol rol, ContextoDelHub ctx) {
  final queHay = reparto(destino, rol);

  return switch (queHay) {
    TodaviaNo() => TodaviaNoHay(destino: destino, queHay: queHay),
    Contiene(contenido: final contenido) => _pantallaDe(contenido, ctx),
  };
}

Widget _pantallaDe(Contenido contenido, ContextoDelHub ctx) {
  return switch (contenido) {
    Contenido.generadorYEditor => _GenerarDelEntrenador(ctx: ctx),
    Contenido.peticionDelNadador => PeticionDelNadador(
      nadadorId: ctx.nadadorId,
      nadadores: ctx.nadadores,
      peticiones: ctx.peticiones,
      estaRetenida: ctx.estaRetenida,
      almacen: ctx.almacen,
    ),
    Contenido.planesDelEntrenador => PlanesDelEntrenador(
      queMirar: ctx.queMirar,
      idsQueMirar: ctx.idsQueMirar,
      alQuitarElFiltro: ctx.alQuitarElFiltro,
      planes: ctx.planes,
      asignaciones: ctx.asignaciones,
      nadadores: ctx.nadadores,
      versionMetodologia: ctx.versionMetodologia,
      alEntregar: ctx.alEntregar,
    ),
    Contenido.homeDelEntrenador => HomeDelEntrenador(
      resumen: ctx.resumenDelEntrenador,
      noSePudoContar: ctx.noSePudoContar,
      alMirar: ctx.alMirar,
    ),
    Contenido.sesionDelDia => ChangeNotifierProvider<EstadoNadador>.value(
      value: ctx.nadador,
      child: PantallaSesionDelDia(selector: ctx.selectorDePerfil),
    ),
    Contenido.miProgreso => ChangeNotifierProvider<EstadoNadador>.value(
      value: ctx.nadador,
      child: const PantallaMiProgreso(),
    ),
    Contenido.homeDelNadador => ChangeNotifierProvider<EstadoNadador>.value(
      value: ctx.nadador,
      child: HomeDelNadador(irAVerPlan: ctx.irAVerPlan),
    ),
    Contenido.ajustes => PantallaAjustes(
      uid: ctx.uid,
      nadadorId: ctx.nadadorId,
      repositorioPerfil: ctx.repositorioPerfil,
      operaciones: ctx.operaciones,
      identidad: ctx.identidad,
      constancias: ctx.constancias,
      derechos: ctx.derechos,
      alElegirApariencia: ctx.alElegirApariencia,
      conmutadorDeRecorrido: ctx.conmutadorDeRecorrido,
    ),
  };
}

/// El `Generar` del entrenador: el generador y el editor en un mismo destino.
///
/// Son dos pantallas y un solo sitio porque así el plan recién generado se
/// revisa **sin cambiar de destino** (FR-009). El `IndexedStack` mantiene las
/// dos vivas: lo escrito a medias en una sigue ahí al volver de la otra.
class _GenerarDelEntrenador extends StatefulWidget {
  const _GenerarDelEntrenador({required this.ctx});

  final ContextoDelHub ctx;

  @override
  State<_GenerarDelEntrenador> createState() => _GenerarDelEntrenadorState();
}

class _GenerarDelEntrenadorState extends State<_GenerarDelEntrenador> {
  int _cual = 0;

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;

    return Column(
      key: const Key('generar-del-entrenador'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaciado.amplio,
            vertical: Espaciado.corto,
          ),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Generador'),
                icon: Icon(Icons.auto_awesome_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Editor'),
                icon: Icon(Icons.edit_note_outlined),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Solicitudes'),
                icon: Icon(Icons.inbox_outlined),
              ),
            ],
            selected: {_cual},
            onSelectionChanged: (cual) => setState(() => _cual = cual.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _cual,
            children: [
              PantallaPeticion(
                biblioteca: ctx.biblioteca,
                indiceTerminos: ctx.indiceTerminos,
                alGenerar: (generado) {
                  // Lo generado se abre en el editor, aquí mismo.
                  ctx.alGenerar(generado);
                  setState(() => _cual = 1);
                },
              ),
              ChangeNotifierProvider<EstadoEditor>.value(
                value: ctx.editor,
                child: PantallaEditor(alRevisarPlan: ctx.alRevisarPlan),
              ),
              // La cola vive aquí, junto al generador y el editor, y no en un
              // sexto destino: los cinco del HUB no cambian, y con ellos se
              // quedan quietos los cerrojos de la feature 007 —incluido el
              // que mide si las cinco etiquetas caben a 320 px.
              ColaDelEntrenador(
                peticiones: ctx.peticiones,
                nadadores: ctx.nadadores,
                molestias: ctx.molestias,
                planes: ctx.repositorioPlanes,
                biblioteca: ctx.biblioteca,
                versionMetodologia: ctx.versionMetodologia,
                alCerrar: ctx.alCerrarPeticion,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
