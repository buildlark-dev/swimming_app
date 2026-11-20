/// Qué se le enseña cuando no tiene plan (feature 012, US4).
///
/// **Un solo sitio para las cuatro respuestas**, y ese es todo el punto.
///
/// La frase «todavía no tienes un plan asignado» vivía copiada en tres
/// pantallas, y la feature 011 ya tuvo que arreglarla en dos a la vez dejando
/// escrito que arreglar una y dejar la otra es dejársela al siguiente
/// recorrido. Ahora son tres, y la respuesta correcta depende de algo que
/// ninguna de las tres sabía: si ella pertenece a alguna comunidad.
///
/// ## Las dos preguntas son independientes
///
/// «¿Tengo plan?» la contesta `Lectura<ProgresoDelNadador>` desde la feature
/// 011. «¿Pertenezco a algo?» la contesta `DondeEsta`. Esto solo se consulta
/// cuando la primera ya dijo que no hay plan, y entonces la segunda decide qué
/// explicación es la verdadera.
///
/// Decirle «cuando tu entrenador te asigne uno, aparecerá aquí» a quien
/// **todavía no tiene entrenador** es mandarla a esperar algo que nadie va a
/// hacer. Es el mismo defecto que la 011 arregló para «todavía no sé» contra
/// «no hay», con otro disfraz (research D6).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/comunidad/membresia.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';

/// El vacío que le corresponde, según dónde esté.
///
/// [dondeEsta] nulo significa que nadie lo averiguó —modo local, o sin
/// servidor—, y entonces se dice lo de siempre: inventarse una pertenencia que
/// nadie comprobó sería peor que no mencionarla.
class SinPlanTodavia extends StatelessWidget {
  const SinPlanTodavia({
    super.key,
    required this.dondeEsta,
    this.corta = false,
    this.terminadaEn,
  });

  final DondeEsta? dondeEsta;

  /// Cuándo dejó de pertenecer, si le pasó (FR-026).
  ///
  /// **No es un quinto caso de `DondeEsta`**, y por lo mismo que esperar no es
  /// un quinto caso de `Lectura`: dónde está ella ahora —en ninguna parte— y
  /// cómo llegó ahí son dos hechos distintos. Uno decide la frase, el otro la
  /// matiza.
  final DateTime? terminadaEn;

  /// La sesión del día tiene menos sitio que `Mi progreso`. Cambia el texto de
  /// apoyo, nunca el titular: lo que se le dice es lo mismo en las tres.
  final bool corta;

  @override
  Widget build(BuildContext context) {
    return switch (dondeEsta) {
      // **La casilla que esta feature existe para arreglar** (FR-020).
      //
      // El texto es el que pidió el entrenador, palabra por palabra. No se le
      // da un botón para «comprobar»: no hay nada que ella pueda hacer, y un
      // botón que no cambia nada es una forma de culparla de la espera.
      Esperando() => EstadoVacio(
        key: const Key('esperando-que-te-acepten'),
        icono: Icons.hourglass_empty_outlined,
        titulo: 'Esperando que el entrenador acepte tu ingreso',
        queHacer: corta
            ? 'Cuando te acepte, tu plan aparecerá aquí.'
            : 'Puedes usar la app con normalidad mientras tanto. Cuando te '
                  'acepte, tu plan y tu progreso aparecerán aquí.',
      ),

      // **Si la sacaron, se le dice** (FR-026). «Todavía no te has unido a
      // ningún entrenador» es falso para quien estuvo en uno hasta ayer, y la
      // dejaría buscando un plan que ya no le va a llegar sin saber por qué.
      //
      // No dice quién ni por qué: es un dato sobre su cuenta, no sobre él.
      NoHaPedido() when terminadaEn != null => EstadoVacio(
        key: const Key('ya-no-estas-en-la-comunidad'),
        icono: Icons.group_remove_outlined,
        titulo: 'Ya no estás en la comunidad',
        queHacer:
            'Desde el ${terminadaEn!.day}/${terminadaEn!.month}/'
            '${terminadaEn!.year}. Lo que anotaste sigue siendo tuyo y lo '
            'sigues viendo. Puedes pedir entrar en otra cuando quieras.',
      ),

      // FR-021. No está esperando nada, y decirle que espera sería mentirle.
      NoHaPedido() => const EstadoVacio(
        key: Key('todavia-no-pediste'),
        icono: Icons.group_add_outlined,
        titulo: 'Todavía no te has unido a ningún entrenador',
        queHacer:
            'Para recibir un plan tienes que pedir entrar en la comunidad '
            'de tu entrenador.',
      ),

      // FR-012. Un rechazo es una respuesta, no una prohibición, y la pantalla
      // no la deja sin salida.
      LeDijeronQueNo() => const EstadoVacio(
        key: Key('puedes-volver-a-pedir'),
        icono: Icons.replay_outlined,
        titulo: 'Tu solicitud no fue aceptada',
        queHacer:
            'Puedes volver a pedir entrar, aquí o en la comunidad de otro '
            'entrenador.',
      ),

      // Pertenece y no tiene plan: la frase de siempre, que aquí sí es verdad.
      // Y lo mismo cuando no se sabe nada de pertenencias (modo local).
      Pertenece() || null => EstadoVacio(
        key: const Key('sin-plan-asignado'),
        icono: Icons.event_busy_outlined,
        titulo: 'Todavía no tienes un plan asignado',
        queHacer: corta
            ? 'Cuando tu entrenador te asigne uno, aparecerá aquí.'
            : 'Cuando tu entrenador te asigne uno, tu progreso aparecerá aquí.',
      ),
    };
  }
}
