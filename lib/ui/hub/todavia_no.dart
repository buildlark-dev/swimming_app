/// Lo que muestra un destino que espera su feature.
///
/// Dos reglas, y la segunda es la que importa (H11, H12):
///
/// - Dice **en una frase** qué llegará ahí, y qué feature lo trae.
/// - **No tiene ni un control pulsable.** Ni uno apagado como señuelo de algo
///   futuro: un botón que no hace nada enseña que la app no responde, y eso se
///   aprende una vez y no se olvida.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/hub/destino.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class TodaviaNoHay extends StatelessWidget {
  const TodaviaNoHay({super.key, required this.destino, required this.queHay});

  final Destino destino;
  final TodaviaNo queHay;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Center(
      key: const Key('todavia-no'),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.amplio),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty_outlined,
                size: 40,
                color: esquema.outline,
              ),
              const SizedBox(height: Espaciado.amplio),
              Text(
                destino.etiqueta,
                style: textos.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Espaciado.corto),
              Text(
                queHay.loQueLlegara,
                style: textos.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Espaciado.amplio),
              Text(
                'Llega en la feature ${queHay.feature}.',
                style: textos.bodySmall?.copyWith(color: esquema.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
