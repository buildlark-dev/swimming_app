/// `Análisis` del entrenador: sus nadadores, y quién contó una molestia.
///
/// **El destino llevaba desde la feature 007 con un «todavía no» que nombraba
/// a la 010 por su número.** Esta es la pantalla que lo cumple.
///
/// Dos decisiones que se leen aquí:
///
/// 1. **Quién reportó una molestia se ve sin abrir a nadie** (FR-010, SC-004).
///    Un reporte de dolor que solo se encuentra entrando en cada ficha está
///    enterrado, y el principio VIII dice que no puede estarlo. Se pregunta
///    con **una consulta** y no una por nadador, igual que la feature 008
///    contó los planes «en uso» (decisión D10).
/// 2. **Un nadador sin macrociclo no desaparece de la lista.** Que no tenga
///    ninguno es justamente lo que el entrenador necesita saber para decidir
///    qué hacer con él; esconderlo dejaría la pantalla «limpia» y la decisión
///    sin tomar.
///
/// Lo que aquí **no** hay: ninguna sugerencia, ningún orden por gravedad y
/// ningún control que cambie un plan. El principio IV reserva eso al
/// entrenador, y ordenar la lista por «importancia» sería tomar la primera
/// mitad de esa decisión por él.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/peticiones/molestias_enlazadas.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/analisis/lectura_de_un_nadador.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

/// Hasta dónde se mira atrás para marcar una molestia en la lista.
///
/// Seis semanas: lo de hace tres meses ya no describe cómo está hoy, y dejarlo
/// marcado para siempre convertiría la marca en parte del nombre.
const Duration molestiasRecientes = Duration(days: 42);

class PantallaAnalisis extends StatefulWidget {
  const PantallaAnalisis({
    super.key,
    required this.nadadores,
    required this.macrociclos,
    required this.planes,
    required this.registros,
    required this.hoy,
    this.molestias,
    this.peticiones,
  });

  final RepositorioNadadores nadadores;
  final RepositorioMacrociclos macrociclos;
  final RepositorioPlanes planes;

  /// **El lector del servidor** (decisión D3).
  final RepositorioRegistros registros;

  /// Quién contó algo, de una sola consulta. Nulo sin servidor: entonces la
  /// lista no marca a nadie en lugar de inventarse que nadie contó nada.
  final LectorDeMolestias? molestias;

  final DateTime hoy;

  /// Lo que sus nadadores le preguntaron (US4). Nulo sin servidor.
  final RepositorioPeticionesDeFeedback? peticiones;

  @override
  State<PantallaAnalisis> createState() => _PantallaAnalisisState();
}

class _PantallaAnalisisState extends State<PantallaAnalisis> {
  List<Nadador> _nadadores = const [];
  Map<String, String> _macrocicloDe = const {};
  Set<String> _conMolestia = const {};

  bool _cargando = true;
  String? _problema;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final nadadores = await widget.nadadores.listar();
      final macrocicloDe = await widget.macrociclos.macrocicloPorNadador();

      final conMolestia =
          await widget.molestias?.quienesReportaron(
            desde: widget.hoy.subtract(molestiasRecientes),
          ) ??
          const <String>{};

      if (!mounted) return;
      setState(() {
        _nadadores = nadadores;
        _macrocicloDe = macrocicloDe;
        _conMolestia = conMolestia;
        _cargando = false;
      });
    } on Object catch (problema) {
      if (!mounted) return;
      setState(() {
        _problema = problema.toString();
        _cargando = false;
      });
    }
  }

  void _abrir(Nadador nadador) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Análisis')),
          body: LecturaDeUnNadador(
            nadador: nadador,
            macrocicloId: _macrocicloDe[nadador.id] ?? '',
            macrociclos: widget.macrociclos,
            planes: widget.planes,
            registros: widget.registros,
            hoy: widget.hoy,
            peticiones: widget.peticiones,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_problema != null) {
      return Padding(
        padding: const EdgeInsets.all(Espaciado.amplio),
        child: Aviso(
          tono: TonoDeAviso.error,
          titulo: 'No se pudo cargar el análisis',
          mensaje: _problema!,
          claveDelMensaje: const Key('no-se-pudo-cargar-el-analisis'),
        ),
      );
    }

    if (_nadadores.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(Espaciado.amplio),
        child: EstadoVacio(
          key: Key('sin-nadadores-en-analisis'),
          icono: Icons.group_outlined,
          titulo: 'Todavía no hay nadadores',
          queHacer:
              'Crea una ficha en «Ver Plan» y aquí verás lo que vaya '
              'contestando.',
        ),
      );
    }

    return ListView(
      key: const Key('analisis-del-entrenador'),
      padding: const EdgeInsets.all(Espaciado.amplio),
      children: [
        const CabeceraSeccion(titulo: 'Lo que respondieron tus nadadores'),
        const SizedBox(height: Espaciado.corto),
        for (final nadador in _nadadores)
          _TarjetaDeNadador(
            nadador: nadador,
            tieneMacrociclo: _macrocicloDe.containsKey(nadador.id),
            contoMolestia: _conMolestia.contains(nadador.id),
            alAbrir: () => _abrir(nadador),
          ),
      ],
    );
  }
}

class _TarjetaDeNadador extends StatelessWidget {
  const _TarjetaDeNadador({
    required this.nadador,
    required this.tieneMacrociclo,
    required this.contoMolestia,
    required this.alAbrir,
  });

  final Nadador nadador;
  final bool tieneMacrociclo;
  final bool contoMolestia;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final id = nadador.id ?? '';
    final texto = Theme.of(context).textTheme;

    return Card(
      child: ListTile(
        key: Key('nadador-en-analisis-$id'),
        onTap: alAbrir,
        leading: const Icon(Icons.person_outline),
        title: Text(nadador.nombre.isEmpty ? 'Sin nombre' : nadador.nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!tieneMacrociclo)
              Text(
                key: Key('sin-macrociclo-$id'),
                'Todavía no tiene macrociclo',
                style: texto.bodySmall?.copyWith(
                  color: context.colores.informativo,
                ),
              ),
            // **La molestia se ve desde aquí.** Tono `cuidado` y no `error`:
            // el tema ya lo dejó decidido —«tiene que encontrarse sin leer
            // todas las observaciones, y a la vez no parecer una alarma
            // médica»—. Y es una marca, no un juicio: no dice qué hacer, no
            // dice cuán grave es, y no ordena la lista.
            if (contoMolestia) ...[
              const SizedBox(height: Espaciado.minimo),
              Row(
                children: [
                  Icon(
                    TonoDeAviso.cuidado.icono,
                    size: Espaciado.iconoEnLinea,
                    color: context.colores.cuidado,
                  ),
                  const SizedBox(width: Espaciado.corto),
                  Flexible(
                    child: Text(
                      key: Key('reporto-molestia-$id'),
                      'Contó una molestia',
                      style: texto.bodySmall?.copyWith(
                        color: context.colores.cuidado,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Espaciado.corto),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('abrir-lectura-$id'),
                onPressed: alAbrir,
                icon: const Icon(Icons.timeline_outlined),
                label: const Text('Ver lo que respondió'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
