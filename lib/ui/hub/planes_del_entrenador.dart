/// El `Ver Plan` del entrenador: sus planes y sus nadadores.
///
/// Los dos en un destino, no en dos. La barra tiene cinco posiciones y el panel
/// de nadadores no se queda con una: buscar un plan y buscar a quién se lo
/// entregó son la misma tarea vista por dos lados.
///
/// Buscar y filtrar por nadador es FR-010, y sirve para lo que el entrenador
/// hace de verdad: encontrar el plan de alguien entre veinte.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/hub/resumen_del_entrenador.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/componentes/etiqueta_de_estado.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/nadadores/pantalla_perfiles.dart';
import 'package:natacion_app/ui/planes/pantalla_plan.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class PlanesDelEntrenador extends StatefulWidget {
  const PlanesDelEntrenador({
    super.key,
    required this.planes,
    required this.asignaciones,
    required this.nadadores,
    required this.versionMetodologia,
    required this.alEntregar,
    this.queMirar = QueMirar.todos,
    this.idsQueMirar,
    this.alQuitarElFiltro,
    this.alEmpezarUnMacrociclo,
  });

  final List<Plan> planes;
  final List<Asignacion> asignaciones;
  final RepositorioNadadores nadadores;
  final String versionMetodologia;
  final Future<void> Function(Plan, List<String>) alEntregar;

  /// Qué grupo se está mirando, porque se tocó un número de la portada.
  final QueMirar queMirar;

  /// Los planes de ese grupo. Nulo significa «todos».
  ///
  /// Vienen calculados del mismo sitio que el número: así el número y la lista
  /// que abre no pueden decir cosas distintas.
  final Set<String>? idsQueMirar;

  final VoidCallback? alQuitarElFiltro;

  /// Empezar un macrociclo para un nadador (feature 009).
  ///
  /// Nula sin servidor: sin dónde guardarlo, ofrecerlo llevaría a una pantalla
  /// que no puede terminar lo que empieza, y un control que no lleva a ninguna
  /// parte está prohibido desde la feature 007 (H12).
  final void Function(Nadador)? alEmpezarUnMacrociclo;

  @override
  State<PlanesDelEntrenador> createState() => _PlanesDelEntrenadorState();
}

class _PlanesDelEntrenadorState extends State<PlanesDelEntrenador> {
  int _cual = 0;
  String _busqueda = '';
  String? _nadadorFiltrado;
  List<Nadador> _suyos = const [];

  @override
  void initState() {
    super.initState();
    _cargarNadadores();
  }

  Future<void> _cargarNadadores() async {
    try {
      final nadadores = await widget.nadadores.listar();
      if (mounted) setState(() => _suyos = nadadores);
    } on FalloDeDatos {
      // Sin nadadores que listar, el filtro no aparece y los planes se siguen
      // viendo. Es un filtro, no una condición para trabajar.
    }
  }

  /// Los planes que pasan la búsqueda y el filtro.
  List<Plan> get _visibles {
    final texto = _busqueda.trim().toLowerCase();

    return widget.planes.where((plan) {
      // El grupo que se vino a mirar desde la portada, si vino alguno.
      final grupo = widget.idsQueMirar;
      if (grupo != null && !grupo.contains(plan.id)) return false;

      if (texto.isNotEmpty &&
          !plan.nombre.toLowerCase().contains(texto) &&
          !(plan.pruebaObjetivo.toLowerCase().contains(texto))) {
        return false;
      }

      final nadadorId = _nadadorFiltrado;
      if (nadadorId == null) return true;

      return widget.asignaciones.any(
        (a) => a.planId == plan.id && a.nadadorId == nadadorId,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('ver-plan-del-entrenador'),
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
                label: Text('Planes'),
                icon: Icon(Icons.description_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Nadadores'),
                icon: Icon(Icons.groups_outlined),
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
              _ListaDePlanes(
                planes: _visibles,
                hayAlguno: widget.planes.isNotEmpty,
                nadadores: _suyos,
                nadadorFiltrado: _nadadorFiltrado,
                versionMetodologia: widget.versionMetodologia,
                asignaciones: widget.asignaciones,
                alEntregar: widget.alEntregar,
                alBuscar: (texto) => setState(() => _busqueda = texto),
                alFiltrar: (id) => setState(() => _nadadorFiltrado = id),
                queMirar: widget.idsQueMirar == null ? null : widget.queMirar,
                alQuitarElFiltro: widget.alQuitarElFiltro,
              ),
              PantallaPerfiles(
                repositorio: widget.nadadores,
                alEmpezarUnMacrociclo: widget.alEmpezarUnMacrociclo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListaDePlanes extends StatelessWidget {
  const _ListaDePlanes({
    required this.planes,
    required this.hayAlguno,
    required this.nadadores,
    required this.nadadorFiltrado,
    required this.versionMetodologia,
    required this.asignaciones,
    required this.alEntregar,
    required this.alBuscar,
    required this.alFiltrar,
    this.queMirar,
    this.alQuitarElFiltro,
  });

  final List<Plan> planes;
  final bool hayAlguno;
  final List<Nadador> nadadores;
  final String? nadadorFiltrado;
  final String versionMetodologia;
  final List<Asignacion> asignaciones;
  final Future<void> Function(Plan, List<String>) alEntregar;
  final ValueChanged<String> alBuscar;
  final ValueChanged<String?> alFiltrar;

  /// El grupo que se vino a mirar desde la portada, si vino alguno.
  final QueMirar? queMirar;
  final VoidCallback? alQuitarElFiltro;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Espaciado.amplio),
      children: [
        // Qué grupo se está mirando, y cómo salir de él. Un filtro que no se
        // ve es un filtro que deja al entrenador preguntándose dónde están
        // sus otros planes.
        if (queMirar != null) ...[
          InputChip(
            key: const Key('filtro-de-la-portada'),
            avatar: const Icon(Icons.filter_alt_outlined, size: 18),
            label: Text(queMirar!.etiqueta),
            onDeleted: alQuitarElFiltro,
          ),
          const SizedBox(height: Espaciado.normal),
        ],
        Campo(
          key: const Key('buscar-plan'),
          etiqueta: 'Buscar un plan',
          ayuda: 'Por nombre o por prueba objetivo',
          alCambiar: alBuscar,
        ),
        if (nadadores.isNotEmpty) ...[
          const SizedBox(height: Espaciado.normal),
          Wrap(
            spacing: Espaciado.corto,
            runSpacing: Espaciado.corto,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: nadadorFiltrado == null,
                onSelected: (_) => alFiltrar(null),
              ),
              for (final nadador in nadadores)
                ChoiceChip(
                  label: Text(nadador.nombre),
                  selected: nadadorFiltrado == nadador.id,
                  onSelected: (_) => alFiltrar(nadador.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: Espaciado.amplio),
        if (planes.isEmpty)
          EstadoVacio(
            icono: Icons.search_off_outlined,
            titulo: hayAlguno
                ? 'Ningún plan coincide'
                : 'Todavía no has generado ningún plan',
            queHacer: hayAlguno
                ? 'Prueba con otro nombre, u quita el filtro de nadador.'
                : 'Empieza en «Generar»: la app devuelve el microciclo '
                      'cuadrado para que lo revises y lo firmes.',
          )
        else
          for (final plan in planes) ...[
            _FilaDePlan(
              plan: plan,
              versionMetodologia: versionMetodologia,
              nadadores: nadadores,
              yaAsignados: [
                for (final a in asignaciones)
                  if (a.planId == plan.id) a.nadadorId,
              ],
              alEntregar: alEntregar,
            ),
            const SizedBox(height: Espaciado.normal),
          ],
      ],
    );
  }
}

class _FilaDePlan extends StatelessWidget {
  const _FilaDePlan({
    required this.plan,
    required this.versionMetodologia,
    required this.nadadores,
    required this.yaAsignados,
    required this.alEntregar,
  });

  final Plan plan;
  final String versionMetodologia;
  final List<Nadador> nadadores;
  final List<String> yaAsignados;
  final Future<void> Function(Plan, List<String>) alEntregar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      alPulsar: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PantallaPlan(
            plan: plan,
            versionMetodologia: versionMetodologia,
            nadadores: nadadores,
            yaAsignados: yaAsignados,
            alEntregar: (publicado, ids) => alEntregar(publicado, ids),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.nombre, style: textos.titleSmall),
                const SizedBox(height: Espaciado.minimo),
                // **Sin contar sesiones aquí.**
                //
                // `listar()` no las trae —una consulta en lugar de una por
                // plan—, así que el número sería siempre «0 sesiones». Un cero
                // que no significa nada es peor que no decir nada: se dice lo
                // que de la lista sí se sabe.
                Text(
                  [
                    plan.categoria.nombre,
                    if (plan.faseAtr != null) plan.faseAtr!.nombre,
                    if (yaAsignados.isNotEmpty)
                      '${yaAsignados.length} '
                          '${yaAsignados.length == 1 ? 'entrega' : 'entregas'}',
                  ].join(' · '),
                  style: textos.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaciado.corto),
          EtiquetaDeEstado(estado: plan.estado),
        ],
      ),
    );
  }
}
