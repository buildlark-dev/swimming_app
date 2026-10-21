/// Paso 1: cómo se llama.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

class PasoNombre extends StatelessWidget {
  const PasoNombre({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoAlta>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Cómo te llamas?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Espaciado.corto),
        const Text('Es lo que verá tu entrenador.'),
        const SizedBox(height: Espaciado.seccion),
        Campo(
          key: const Key('alta-campo-nombre'),
          etiqueta: 'Tu nombre',
          valorInicial: estado.perfil.nombre,
          alCambiar: estado.escribirNombre,
        ),
      ],
    );
  }
}
