/// Donde ella pide entrar, mientras crea su cuenta (feature 012, US2).
///
/// **Se puede saltar, y eso no es una concesión.** Puede que todavía no haya
/// ninguna comunidad, puede que no sepa a cuál va, y puede que simplemente no
/// quiera decidirlo ahora. Su cuenta es suya desde que la crea; lo que queda
/// pendiente es pertenecer (FR-005).
///
/// Si no hay ninguna comunidad que ofrecer, se le dice en palabras y sigue
/// adelante. Una lista en blanco es un callejón sin salida disfrazado de
/// pantalla (FR-006).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/comunidad/comunidad.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:provider/provider.dart';

class PasoComunidad extends StatefulWidget {
  const PasoComunidad({super.key});

  @override
  State<PasoComunidad> createState() => _PasoComunidadState();
}

class _PasoComunidadState extends State<PasoComunidad> {
  @override
  void initState() {
    super.initState();
    // **Se leen al llegar aquí, no al arrancar el alta.** Quien no va a llegar
    // hasta este paso no tiene por qué pagar la lectura, y quien llega la paga
    // una sola vez.
    //
    // Y después del frame: `cargarComunidades` avisa a quien escucha en cuanto
    // empieza, y avisar en mitad de un build es un error de Flutter, no un
    // detalle de estilo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<EstadoAlta>().cargarComunidades());
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoAlta>();
    final texto = Theme.of(context).textTheme;

    if (estado.cargandoComunidades) {
      return const Center(child: CircularProgressIndicator());
    }

    final comunidades = estado.comunidadesQueSePuedenOfrecer;

    if (comunidades.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Con quién entrenas?', style: texto.titleMedium),
          const SizedBox(height: Espaciado.normal),
          const Aviso(
            tono: TonoDeAviso.informativo,
            icono: Icons.group_outlined,
            claveDelMensaje: Key('sin-comunidades'),
            mensaje:
                'Todavía no hay ningún entrenador al que unirse. Puedes '
                'seguir y pedirlo más adelante desde Ajustes.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Con quién entrenas?', style: texto.titleMedium),
        const SizedBox(height: Espaciado.corto),
        Text(
          'Tu entrenador tendrá que aceptarte. Mientras tanto puedes usar la '
          'app igual.',
          style: texto.bodySmall,
        ),
        const SizedBox(height: Espaciado.normal),

        for (final comunidad in comunidades)
          _Opcion(
            clave: Key('comunidad-${comunidad.id}'),
            titulo: comunidad.nombre,
            elegida: estado.comunidadElegida == comunidad.id,
            alElegir: () => estado.elegirComunidad(comunidad.id),
          ),

        // **Saltárselo es una opción con nombre**, no un botón que se deja sin
        // tocar: una decisión que no se ofrece es una decisión que ella no
        // sabe que puede tomar.
        _Opcion(
          clave: const Key('comunidad-ninguna'),
          titulo: 'Todavía no',
          explicacion: 'Puedes pedirlo más adelante desde Ajustes.',
          elegida: estado.comunidadElegida == null,
          alElegir: () => estado.elegirComunidad(null),
        ),
      ],
    );
  }
}

/// Una de las opciones, elegible tocándola entera.
///
/// Se dibuja a mano en lugar de con `RadioListTile` porque su `groupValue` y
/// su `onChanged` están deprecados en esta versión de Flutter, y el principio
/// VII pide que `flutter analyze` termine sin advertencias nuevas.
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.clave,
    required this.titulo,
    required this.elegida,
    required this.alElegir,
    this.explicacion,
  });

  final Key clave;
  final String titulo;
  final String? explicacion;
  final bool elegida;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return ListTile(
      key: clave,
      onTap: alElegir,
      selected: elegida,
      leading: Icon(
        elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: elegida ? esquema.primary : esquema.onSurfaceVariant,
      ),
      title: Text(titulo),
      subtitle: explicacion == null ? null : Text(explicacion!),
    );
  }
}

/// Lo que ve después de pedir, y cómo se arrepiente (FR-007).
class LoQuePediste extends StatelessWidget {
  const LoQuePediste({
    super.key,
    required this.comunidad,
    required this.alRetirar,
  });

  /// La comunidad a la que pidió entrar.
  final Comunidad comunidad;

  final Future<void> Function() alRetirar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Aviso(
          tono: TonoDeAviso.informativo,
          icono: Icons.hourglass_empty,
          claveDelMensaje: const Key('lo-que-pediste'),
          mensaje:
              'Pediste unirte a «${comunidad.nombre}». Te avisaremos cuando '
              'te acepten.',
        ),
        const SizedBox(height: Espaciado.corto),
        TextButton(
          key: const Key('retirar-solicitud'),
          onPressed: alRetirar,
          child: const Text('Ya no quiero unirme'),
        ),
      ],
    );
  }
}
