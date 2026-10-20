/// Lo que el nadador respondió, para el entrenador.
///
/// FR-013: se muestra **junto al plan que lo originó**, no en una bandeja
/// aparte. «Un registro que nadie lee no es control», y un registro que vive en
/// otra pantalla es un registro que nadie lee.
///
/// FR-014: la **carga externa** (lo que programó el entrenador) y la **carga
/// interna** (lo que respondió el nadador) se muestran por separado y **nunca
/// combinadas en un mismo indicador**. Aquí eso es literal: son dos columnas,
/// no un resumen de las dos.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/tema/tipografia.dart';

class RespuestasDelNadador extends StatelessWidget {
  const RespuestasDelNadador({super.key, required this.progreso});

  final ProgresoDelNadador progreso;

  @override
  Widget build(BuildContext context) {
    final conMolestia = progreso.conMolestia;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CabeceraSeccion(
            titulo: 'Respuesta del nadador',
            cifra: 'Completadas ${progreso.adherenciaDelPlan.descripcion}',
          ),

          // Las molestias se listan arriba para que se encuentren **sin leer
          // todas las observaciones de todas las sesiones** (SC-006).
          if (conMolestia.isNotEmpty) ...[
            const SizedBox(height: Espaciado.normal),
            _Molestias(entradas: conMolestia),
          ],

          const Divider(height: Espaciado.seccion),
          for (final entrada in progreso.historial) _Fila(entrada: entrada),
        ],
      ),
    );
  }
}

class _Molestias extends StatelessWidget {
  const _Molestias({required this.entradas});

  final List<SesionConRegistro> entradas;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      color: esquema.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.healing_outlined, color: esquema.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  'Reportes de molestia (${entradas.length})',
                  style: TextStyle(
                    color: esquema.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entrada in entradas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${entrada.sesion.objetivoTecnico}: '
                  '${entrada.registro!.molestia!.descripcion}'
                  '${entrada.registro!.molestia!.zonaDelCuerpo.isEmpty ? '' : ' '
                      '(${entrada.registro!.molestia!.zonaDelCuerpo})'}',
                  style: TextStyle(color: esquema.onErrorContainer),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'La app no propone ninguna conducta: decide usted.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: esquema.onErrorContainer,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.entrada});

  final SesionConRegistro entrada;

  @override
  Widget build(BuildContext context) {
    final registro = entrada.registro;
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Carga externa: lo que programó el entrenador ----------------
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entrada.sesion.objetivoTecnico,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                // Cifras tabulares (FR-008): esta columna se lee de arriba
                // abajo, sesión por sesión, y para eso tiene que alinearse.
                Text(
                  '${entrada.sesion.metros} m · '
                  '${entrada.sesion.porcentajeTecnico.toStringAsFixed(0)}% téc',
                  style: Tipografia.notacion(
                    Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
                  ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 24),

          // --- Carga interna: lo que respondió el nadador -------------------
          Expanded(
            flex: 3,
            child: registro == null
                ? Text(
                    'Sin respuesta',
                    style: TextStyle(color: esquema.outline),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            registro.realizada
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            size: 16,
                            color: registro.realizada
                                ? esquema.primary
                                : esquema.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            registro.realizada ? 'Realizada' : 'No la hizo',
                          ),
                          if (registro.rpePercibido != null) ...[
                            const SizedBox(width: 12),
                            Text('RPE ${registro.rpePercibido}'),
                          ],
                        ],
                      ),
                      if (registro.observaciones.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SelectableText(
                            registro.observaciones,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
