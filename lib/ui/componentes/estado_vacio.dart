/// Cuando no hay nada que mostrar.
///
/// «Todavía no tienes un plan asignado», «Todavía no hay perfiles», «Hoy
/// descansas». Siete sitios de la app dicen algo así, y lo decían de siete
/// maneras: unos con tarjeta, otros con un `Text` centrado y suelto.
///
/// **Un estado vacío no es un error**, y por eso no lleva tono de aviso. Que no
/// haya plan todavía no es un fallo de nadie: es que el entrenador no lo ha
/// asignado. Lo que sí lleva siempre es **qué hacer a continuación**, porque un
/// nadador de nueve años mirando una pantalla vacía no deduce el siguiente
/// paso.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.queHacer,
    this.accion,
  });

  final IconData icono;
  final String titulo;

  /// El siguiente paso, en palabras. **Obligatorio.**
  ///
  /// Sin esto el componente sería un cartel de «no hay nada», que es justo lo
  /// que no queremos: deja al nadador sin saber si falta algo suyo o del
  /// entrenador.
  final String queHacer;

  /// Un botón, cuando el siguiente paso se puede dar desde aquí.
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      holgada: true,
      child: Column(
        children: [
          Icon(
            icono,
            size: Espaciado.iconoGrande,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Espaciado.normal),
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaciado.minimo),
          Text(queHacer, textAlign: TextAlign.center),
          if (accion != null) ...[
            const SizedBox(height: Espaciado.amplio),
            accion!,
          ],
        ],
      ),
    );
  }
}
