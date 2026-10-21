/// Panel de distribución del plan.
///
/// Por cada zona, el valor real, el prescrito y la diferencia. Más el
/// porcentaje técnico y el reparto de estilos.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/dominio/auditoria/tolerancia.dart';
import 'package:natacion_app/dominio/calculo/agregacion_plan.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/modelo_tid.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/etiqueta_de_zona.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/tema/tipografia.dart';

class PanelDistribucion extends StatelessWidget {
  const PanelDistribucion({
    super.key,
    required this.plan,
    this.tolerancia = Tolerancia.predeterminada,
  });

  final Plan plan;
  final Tolerancia tolerancia;

  @override
  Widget build(BuildContext context) {
    final agregacion = AgregacionPlan(plan);
    final porZona = agregacion.repartoPorZona;
    final porEstilo = agregacion.repartoDeEstilos;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabeceraSeccion(
              titulo: 'Distribución del plan',
              cifra: '${plan.metros} m · '
                  '${plan.porcentajeTecnico.toStringAsFixed(1)}% técnico',
            ),

            if (agregacion.metrosSinZona > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${agregacion.metrosSinZona} m sin zona asignada: la '
                  'distribución no es fiable mientras queden series sin zona.',
                  // **Cuidado, no error.** Que falten metros por zonificar
                  // no es un fallo de la app: es trabajo del entrenador que
                  // está a medio hacer, y la frase ya lo dice.
                  style: TextStyle(color: context.colores.cuidado),
                ),
              ),

            if (plan.faseAtr != null) ...[
              const SizedBox(height: 12),
              _ModeloDeLaFase(plan: plan, agregacion: agregacion),
            ],

            if (porZona.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Zonas de intensidad frente a ${plan.faseAtr?.nombre ?? 'la fase'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              // La zona va con su color. `repartoPorZona` se construye
              // recorriendo `Zona.values` en orden, así que la posición dice
              // cuál es: el dominio no guarda colores y la interfaz traduce
              // (principio II).
              for (var i = 0; i < porZona.length; i++)
                _FilaReparto(
                  reparto: porZona[i],
                  tolerancia: tolerancia,
                  zona: i < Zona.values.length ? Zona.values[i] : null,
                ),
            ],

            if (porEstilo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Estilos, con objetivo ${plan.estiloObjetivo.nombre}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final reparto in porEstilo)
                _FilaReparto(reparto: reparto, tolerancia: tolerancia),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaReparto extends StatelessWidget {
  const _FilaReparto({
    required this.reparto,
    required this.tolerancia,
    this.zona,
  });

  final Reparto reparto;
  final Tolerancia tolerancia;

  /// La zona de la fila, cuando la fila es de una zona.
  ///
  /// Nula en el reparto de estilos, que no tiene zonas: ahí la etiqueta es
  /// «Libre» o «Espalda» y no le corresponde ningún color de la rampa.
  final Zona? zona;

  /// Lo que hace falta para que la fila quepa como tabla, con la letra normal.
  ///
  /// Es la suma de los anchos fijos —110 de etiqueta, 70 de metros, 150 de
  /// comparación, más dos separaciones— y un trozo de barra que se pueda leer.
  static const double _anchoDeTabla = 414;

  @override
  Widget build(BuildContext context) {
    final dentro = tolerancia.admite(reparto.diferencia);

    // **Cuidado, no error.** Una desviación de la distribución prescrita es
    // una decisión del entrenador que puede estar justificada: la auditoría la
    // marca para que la mire, no para decirle que se equivocó. Pintarla de
    // rojo opinaba por él (FR-016).
    final color = dentro ? null : context.colores.cuidado;

    // Los anchos de la tabla son fijos, así que **no crecen con la letra**: lo
    // que crece es el texto que va dentro. Se escalan a mano para que siga
    // cabiendo cuando el nadador lleva el teléfono al 200%.
    final escala = MediaQuery.textScalerOf(context).scale(1);

    // Con zona, la marca de color **con su abreviatura dentro**; sin zona, el
    // texto de siempre. El color acompaña al nombre, no lo sustituye.
    final Widget etiqueta = zona == null
        ? Text(reparto.etiqueta, style: TextStyle(color: color))
        : EtiquetaDeZona(zona: zona!);
    // Cifras tabulares en las dos columnas de números (FR-008): siete filas de
    // metros y porcentajes se leen como una tabla, y una tabla cuyas cifras no
    // se alinean deja de ser una tabla.
    final metros = Text(
      '${reparto.metros} m',
      textAlign: TextAlign.end,
      style: Tipografia.notacion(
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
      ),
    );
    final barra = LinearProgressIndicator(
      value: (reparto.porcentajeReal / 100).clamp(0.0, 1.0),
      color: color,
    );
    final comparacion = Text(
      '${reparto.porcentajeReal.toStringAsFixed(1)}% de '
      '${reparto.porcentajePrescrito.toStringAsFixed(0)}% '
      '(${reparto.diferencia >= 0 ? '+' : ''}'
      '${reparto.diferencia.toStringAsFixed(1)})',
      style: Tipografia.notacion(
        (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
            .copyWith(color: color),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          // En un teléfono de 360 puntos esta fila ya se salía 50 píxeles **con
          // la letra normal**: los anchos fijos sumaban más que la pantalla. No
          // se veía porque las pruebas de antes medían en una ventana de 800.
          //
          // Cuando no cabe como tabla, se apila: la cifra sigue a su etiqueta y
          // la barra pasa debajo, a lo ancho. Se pierde la alineación en
          // columnas, que en ese ancho no existía de todos modos.
          if (restricciones.maxWidth < _anchoDeTabla * escala) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: Espaciado.corto,
                    runSpacing: Espaciado.minimo,
                    children: [etiqueta, metros, comparacion],
                  ),
                ),
                const SizedBox(height: Espaciado.minimo),
                barra,
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 110 * escala, child: etiqueta),
              SizedBox(width: 70 * escala, child: metros),
              const SizedBox(width: Espaciado.normal),
              Expanded(child: barra),
              const SizedBox(width: Espaciado.normal),
              SizedBox(
                width: 150 * escala,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: comparacion,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lo que de verdad se audita: las tres zonas contra el envolvente publicado.
///
/// Va arriba del desglose por zona a propósito. El desglose fino es criterio
/// del entrenador y no suspende; esto sí, y por eso lleva la fuente a la vista:
/// tiene derecho a saber qué respalda lo que la app le exige.
class _ModeloDeLaFase extends StatelessWidget {
  const _ModeloDeLaFase({required this.plan, required this.agregacion});

  final Plan plan;
  final AgregacionPlan agregacion;

  @override
  Widget build(BuildContext context) {
    final fase = plan.faseAtr!;
    final modelo = fase.modelo;
    final reales = agregacion.porcentajePorTid;
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CabeceraSeccion(
          titulo: 'Modelo de ${fase.nombre}: ${modelo.nombre}',
          cifra: modelo.patron,
          estilo: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        for (final tid in ZonaTid.values)
          _FilaTid(
            tid: tid,
            real: reales[tid] ?? 0,
            rango: modelo.rangoDe(tid),
          ),
        const SizedBox(height: 6),
        Text(
          'Envolvente de ${modelo.fuente}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _FilaTid extends StatelessWidget {
  const _FilaTid({
    required this.tid,
    required this.real,
    required this.rango,
  });

  final ZonaTid tid;
  final double real;
  final RangoTid rango;

  @override
  Widget build(BuildContext context) {
    final dentro = rango.contiene(real);
    final esquema = Theme.of(context).colorScheme;

    // Esta fila tenía la misma enfermedad que `_FilaReparto`: anchos fijos de
    // 32, 70 y 90, más un icono, más una descripción, todo en una línea. Nadie
    // la había visto desbordarse porque **solo se pinta cuando el plan tiene
    // fase ATR**, y ninguna prueba montaba un plan con fase hasta la fase 6.
    //
    // Se salía 71 píxeles con la letra normal y 316 al 200%. Ahora las cifras
    // van arriba, en un `Wrap`, y la descripción debajo a lo ancho.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Espaciado.corto,
            runSpacing: Espaciado.minimo,
            children: [
              Text(
                tid.abreviatura,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${real.toStringAsFixed(1)}%'),
              Text(
                rango.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              // Fuera de banda es **cuidado**, no error: la envolvente de la
              // fase es una referencia, y salirse de ella es una decisión que
              // el entrenador puede justificar.
              Icon(
                dentro ? Icons.check_circle_outline : Icons.error_outline,
                size: Espaciado.iconoEnLinea,
                color: dentro ? esquema.primary : context.colores.cuidado,
              ),
              if (!dentro)
                Text(
                  '${rango.desviacion(real) >= 0 ? '+' : ''}'
                  '${rango.desviacion(real).toStringAsFixed(1)} puntos',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.colores.cuidado),
                ),
            ],
          ),
          Text(
            tid.descripcion,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
