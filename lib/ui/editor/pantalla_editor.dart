/// Pantalla del editor de sesión.
///
/// A la izquierda, las tres partes como áreas de texto libre, donde el
/// entrenador escribe con su notación de siempre. A la derecha, lo que la app
/// entendió, en campos editables, más los totales en vivo y los avisos.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';
import 'package:natacion_app/ui/editor/panel_avisos.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/tema/tipografia.dart';
import 'package:provider/provider.dart';

class PantallaEditor extends StatelessWidget {
  const PantallaEditor({super.key, this.alRevisarPlan});

  /// Abre el plan completo para auditarlo, aprobarlo y entregarlo.
  ///
  /// Nulo cuando no hay a dónde ir, como en las pruebas de esta pantalla.
  final VoidCallback? alRevisarPlan;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoEditor>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de sesión'),
        bottom: estado.revisandoGenerado
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _SelectorSesiones(estado: estado),
              )
            : null,
        actions: [
          // Los totales en vivo **no van aquí**. Una barra de herramientas
          // tiene una altura fija, y con la letra del sistema al 200% el texto
          // se salía 49 píxeles por la derecha: el entrenador que agranda la
          // letra es justo el que deja de ver los metros. Viven en la cabecera
          // de la sesión, donde pueden ocupar dos líneas si hace falta.
          //
          // Lo destapó la garantía V7.

          // Sin esto, lo revisado se quedaba en el editor: no había por dónde
          // aprobarlo, publicarlo ni entregárselo a nadie (tarea T006).
          if (estado.revisandoGenerado && alRevisarPlan != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: alRevisarPlan,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Revisar y entregar'),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, restricciones) {
          final enColumna = restricciones.maxWidth < 900;
          final izquierda = _ColumnaEscritura(estado: estado);
          final derecha = _ColumnaInterpretacion(estado: estado);

          if (enColumna) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [izquierda, const SizedBox(height: 24), derecha],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: izquierda,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: derecha,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ColumnaEscritura extends StatelessWidget {
  const _ColumnaEscritura({required this.estado});

  final EstadoEditor estado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CabeceraSesion(estado: estado),
        const SizedBox(height: 16),
        for (final tipo in TipoParte.values) ...[
          _CampoParte(estado: estado, tipo: tipo),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _CabeceraSesion extends StatelessWidget {
  const _CabeceraSesion({required this.estado});

  final EstadoEditor estado;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Los totales en vivo, que antes estaban en la barra de arriba.
            // Aquí caben: si no entran en una línea, bajan a la siguiente.
            CabeceraSeccion(
              titulo: '${estado.sesion.metros} m',
              cifra: '${estado.sesion.porcentajeTecnico.toStringAsFixed(0)}% '
                  'técnico',
              estiloDeCifra: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Espaciado.corto),
            CampoDeOpciones<Categoria>(
              etiqueta: 'Categoría',
              valor: estado.categoria,
              opciones: Categoria.values,
              nombreDe: (c) => '${c.nombre} · ${c.volumenPorSesion}',
              alCambiar: (valor) {
                if (valor != null) estado.cambiarCategoria(valor);
              },
            ),
            const SizedBox(height: 8),
            Campo(
              etiqueta: 'Objetivo técnico',
              pista: 'Mejoramiento técnica de Espalda',
              alCambiar: estado.cambiarObjetivoTecnico,
            ),
            const SizedBox(height: 8),
            Campo(
              etiqueta: 'Objetivo fisiológico',
              pista: 'Base aeróbica',
              alCambiar: estado.cambiarObjetivoFisiologico,
            ),
            const SizedBox(height: 8),
            _SelectorRpe(estado: estado),
          ],
        ),
      ),
    );
  }
}

class _SelectorRpe extends StatelessWidget {
  const _SelectorRpe({required this.estado});

  final EstadoEditor estado;

  @override
  Widget build(BuildContext context) {
    // La etiqueta encima y el control debajo, no al lado.
    //
    // Con la letra al 200% el texto medía más que la pantalla y el deslizador
    // se salía 402 píxeles. Un control de una fila solo cabe si el texto que
    // lo acompaña es corto, y este no lo es en ningún idioma.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RPE previsto (Borg 0-10):'),
        Slider(
          value: (estado.sesion.rpePrevisto ?? 0).toDouble(),
          max: 10,
          divisions: 10,
          label: '${estado.sesion.rpePrevisto ?? 0}',
          onChanged: (valor) => estado.cambiarRpe(valor.round()),
        ),
      ],
    );
  }
}

class _CampoParte extends StatelessWidget {
  const _CampoParte({required this.estado, required this.tipo});

  final EstadoEditor estado;
  final TipoParte tipo;

  @override
  Widget build(BuildContext context) {
    final parte = estado.sesion.parteDe(tipo);
    final porcentaje = estado.sesion.porcentajeDe(tipo);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CabeceraSeccion(
              titulo: tipo.nombre,
              cifra: '${parte.metros} m · ${porcentaje.toStringAsFixed(0)}% '
                  '(prescrito ${tipo.porcentajePrescrito}%)',
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '200 N + 4x100 AL SNK PN / 2\'',
              ),
              onChanged: (texto) => estado.escribirParte(tipo, texto),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnaInterpretacion extends StatelessWidget {
  const _ColumnaInterpretacion({required this.estado});

  final EstadoEditor estado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelAvisos(estado: estado),
        const SizedBox(height: 16),
        for (final tipo in TipoParte.values)
          _SeriesInterpretadas(estado: estado, tipo: tipo),
      ],
    );
  }
}

class _SeriesInterpretadas extends StatelessWidget {
  const _SeriesInterpretadas({required this.estado, required this.tipo});

  final EstadoEditor estado;
  final TipoParte tipo;

  @override
  Widget build(BuildContext context) {
    final parte = estado.sesion.parteDe(tipo);
    if (parte.series.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tipo.nombre, style: Theme.of(context).textTheme.titleSmall),
            const Divider(),
            for (var i = 0; i < parte.series.length; i++)
              _FilaSerie(
                estado: estado,
                tipo: tipo,
                indice: i,
                serie: parte.series[i],
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaSerie extends StatelessWidget {
  const _FilaSerie({
    required this.estado,
    required this.tipo,
    required this.indice,
    required this.serie,
  });

  final EstadoEditor estado;
  final TipoParte tipo;
  final int indice;
  final Serie serie;

  @override
  Widget build(BuildContext context) {
    final corregida = serie.origen == OrigenDato.corregidoAMano;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            // Cifras tabulares (FR-008): esta es la columna donde el
            // entrenador compara lo que escribió con lo que la app entendió, y
            // compararlas exige que se alineen.
            child: Text(
              '${serie.repeticiones}x${serie.distancia} m'
              '${serie.ejercicio != null ? ' · ${serie.ejercicio!.nombreParaPlan}' : ''}',
              style: Tipografia.notacion(
                TextStyle(
                  fontWeight: corregida ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButton<Zona>(
              isExpanded: true,
              value: serie.zona,
              hint: const Text('Zona'),
              items: [
                for (final zona in Zona.values)
                  DropdownMenuItem(
                    value: zona,
                    child: Text(zona.abreviatura),
                  ),
              ],
              onChanged: (zona) {
                if (zona != null) estado.asignarZona(tipo, indice, zona);
              },
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${serie.metros} m',
              textAlign: TextAlign.end,
              style: Tipografia.notacion(const TextStyle()),
            ),
          ),
          if (corregida)
            const Tooltip(
              message: 'Corregido a mano: prevalece sobre la interpretación',
              child: Icon(Icons.edit, size: 16),
            ),
        ],
      ),
    );
  }
}

/// Estilos declarados, usados por el panel de avisos.
extension EstiloLegible on Estilo {
  String get etiqueta => nombre;
}

/// Navegación entre las sesiones de un microciclo generado.
///
/// Aparece solo cuando el entrenador está revisando algo generado: cuando
/// escribe a mano, no hay varias sesiones entre las que moverse.
class _SelectorSesiones extends StatelessWidget {
  const _SelectorSesiones({required this.estado});

  final EstadoEditor estado;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.auto_awesome, size: 16),
          const SizedBox(width: 8),
          const Text('Generado:'),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: estado.sesionesDelPlan.length,
              itemBuilder: (context, indice) {
                final seleccionada = indice == estado.indiceAbierta;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('Sesión ${indice + 1}'),
                    selected: seleccionada,
                    onSelected: (_) => estado.abrirSesion(indice),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
