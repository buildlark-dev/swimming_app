/// Mi progreso: historial de sesiones y adherencia.
///
/// El entrenador eligió el alcance al aclarar la especificación: historial más
/// adherencia **como recuento**, sin gráficas (FR-005a, FR-005b).
///
/// **Funciona sin conexión**, como todo lo que el nadador lee (FR-005).
///
/// Lo que aquí no hay, y es deliberado: ningún número que mezcle lo programado
/// con lo percibido. La adherencia cuenta sesiones; el RPE se muestra al lado,
/// sesión por sesión. El principio VIII prohíbe combinarlos en un mismo
/// indicador.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/puede_marcarse.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/nadador/aviso_sincronizacion.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:provider/provider.dart';

class PantallaMiProgreso extends StatelessWidget {
  const PantallaMiProgreso({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoNadador>();
    final progreso = estado.progreso;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi progreso')),
      body: progreso == null
          ? const Padding(
              padding: EdgeInsets.all(Espaciado.amplio),
              child: EstadoVacio(
                icono: Icons.event_busy_outlined,
                titulo: 'Todavía no tienes un plan asignado',
                queHacer:
                    'Cuando tu entrenador te asigne uno, tu progreso '
                    'aparecerá aquí.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AvisoSincronizacion(estado: estado),
                const SizedBox(height: 8),
                _Adherencia(progreso: progreso),
                const SizedBox(height: 16),
                Text(
                  'Historial',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final entrada in progreso.historial)
                  _Entrada(entrada: entrada),
                const SizedBox(height: 60),
              ],
            ),
    );
  }
}

class _Adherencia extends StatelessWidget {
  const _Adherencia({required this.progreso});

  final ProgresoDelNadador progreso;

  @override
  Widget build(BuildContext context) {
    final delPlan = progreso.adherenciaDelPlan;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesiones completadas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              delPlan.descripcion,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'en todo el plan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (progreso.adherenciaPorSemana.isNotEmpty) ...[
              const Divider(height: 24),
              for (final microciclo in progreso.plan.microciclos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(microciclo.nombre)),
                      Text(
                        progreso
                                .adherenciaPorSemana[microciclo.id]
                                ?.descripcion ??
                            '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  const _Entrada({required this.entrada});

  final SesionConRegistro entrada;

  @override
  Widget build(BuildContext context) {
    final registro = entrada.registro;
    final esquema = Theme.of(context).colorScheme;
    final fecha = entrada.sesion.fecha;
    final sesionId = entrada.sesion.id ?? '';

    return Card(
      child: ListTile(
        leading: Icon(
          entrada.realizada
              ? Icons.check_circle_outline
              : entrada.tieneRespuesta
              ? Icons.cancel_outlined
              : Icons.radio_button_unchecked,
          color: entrada.realizada ? esquema.primary : esquema.outline,
        ),
        title: Text(entrada.sesion.objetivoTecnico),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (fecha != null)
                  '${fecha.day.toString().padLeft(2, '0')}/'
                      '${fecha.month.toString().padLeft(2, '0')}',
                // Carga externa y carga interna, una al lado de la otra pero
                // **nunca combinadas en un mismo número** (principio VIII).
                '${entrada.sesion.metros} m',
                if (registro?.rpePercibido != null)
                  'RPE ${registro!.rpePercibido}',
              ].join(' · '),
            ),
            if (registro != null && registro.observaciones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  registro.observaciones,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (entrada.tieneMolestia)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.healing_outlined,
                      size: 16,
                      color: context.colores.cuidado,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        registro!.molestia!.descripcion,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colores.cuidado,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _Feedback(sesion: entrada.sesion, sesionId: sesionId),
          ],
        ),
        isThreeLine: registro != null,
      ),
    );
  }
}

/// Pedirle a su entrenador que mire esta sesión, y saber si la vio.
///
/// **Solo de una sesión que ya pasó**, y cuando no se puede el control no se
/// ofrece en absoluto: no se ofrece deshabilitado. La feature 007 lo prohibió
/// —un control que no lleva a ninguna parte es un señuelo (H12)— y aquí el
/// motivo es más concreto todavía: preguntar «¿cómo me salió?» de una sesión
/// que no ha ocurrido no es una operación que falle, es una frase sin sentido.
///
/// El cerrojo de verdad vive en `EstadoNadador.pedirFeedback`, donde se
/// construye la petición. Esto es la pantalla no ofreciendo lo que el dominio
/// va a rechazar.
///
/// **No hay respuesta escrita** (aclaración Q2). Lo que ella puede saber es si
/// él la vio; lo que él le diga, lo dice en la piscina. Un canal de mensajes
/// prometido es un canal que alguien tiene que atender, y nadie va a atenderlo
/// a las once de la noche.
class _Feedback extends StatefulWidget {
  const _Feedback({required this.sesion, required this.sesionId});

  final Sesion sesion;
  final String sesionId;

  @override
  State<_Feedback> createState() => _FeedbackState();
}

class _FeedbackState extends State<_Feedback> {
  SePudoPedir? _loQuePaso;

  Future<void> _preguntar(EstadoNadador estado) async {
    final pregunta = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoDeLaPregunta(),
    );

    if (pregunta == null || !mounted) return;

    final resultado = await estado.pedirFeedback(
      sesion: widget.sesion,
      pregunta: pregunta,
    );

    if (!mounted) return;
    setState(() => _loQuePaso = resultado);
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoNadador>();
    final peticion = estado.peticionDe(widget.sesionId);
    final texto = Theme.of(context).textTheme;
    final paso = _loQuePaso;

    // Sin repositorio no hay dónde guardarla, y sin día cumplido no hay nada
    // que preguntar.
    //
    // **Y si ya la vio, tampoco se ofrece cambiarla.** La regla del servidor
    // lo dejaría —el documento es suyo—, pero cambiarle la pregunta a alguien
    // que ya la leyó no es editar: es dejarle respondida otra cosa.
    final puedePreguntar =
        estado.puedePedirFeedback &&
        puedeMarcarse(sesion: widget.sesion, hoy: estado.ahora).si &&
        !(peticion?.laVio ?? false);

    if (peticion == null && !puedePreguntar) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Espaciado.corto),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ya preguntó: su pregunta, y si él la vio.
          if (peticion != null) ...[
            Text(peticion.pregunta, style: texto.bodySmall),
            const SizedBox(height: Espaciado.minimo),
            if (peticion.laVio)
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: Espaciado.iconoEnLinea,
                    color: context.colores.exito,
                  ),
                  const SizedBox(width: Espaciado.minimo),
                  Flexible(
                    child: Text(
                      key: Key('ya-la-vio-${widget.sesionId}'),
                      'Tu entrenador la vio',
                      style: texto.bodySmall?.copyWith(
                        color: context.colores.exito,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                key: Key('esperando-que-la-vea-${widget.sesionId}'),
                'Tu entrenador todavía no la ha visto',
                style: texto.bodySmall,
              ),
          ],

          if (puedePreguntar)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('pedir-feedback-${widget.sesionId}'),
                onPressed: () => _preguntar(estado),
                icon: const Icon(Icons.help_outline),
                label: Text(
                  peticion == null
                      ? 'Preguntarle a mi entrenador'
                      : 'Cambiar mi pregunta',
                ),
              ),
            ),

          // **Guardada, que no es enviada.** Es lo que la garantía G1 compra:
          // su pregunta está a salvo en el teléfono y sube cuando haya señal.
          if (paso is SePidio)
            Text(
              key: const Key('pregunta-guardada'),
              'Guardada. Se la mandaremos cuando tengas internet.',
              style: texto.bodySmall?.copyWith(color: context.colores.exito),
            )
          else if (paso != null)
            Text(
              key: const Key('no-se-pudo-preguntar'),
              paso.comoSeLeExplica,
              style: texto.bodySmall?.copyWith(color: context.colores.cuidado),
            ),
        ],
      ),
    );
  }
}

/// Donde escribe la pregunta. Un campo y nada más.
class _DialogoDeLaPregunta extends StatefulWidget {
  const _DialogoDeLaPregunta();

  @override
  State<_DialogoDeLaPregunta> createState() => _DialogoDeLaPreguntaState();
}

class _DialogoDeLaPreguntaState extends State<_DialogoDeLaPregunta> {
  final _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Preguntarle a mi entrenador'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Él la verá junto a esta sesión. Te contesta en la piscina: aquí '
            'solo verás que la leyó.',
          ),
          const SizedBox(height: Espaciado.normal),
          TextField(
            key: const Key('campo-de-la-pregunta'),
            controller: _controlador,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Tu pregunta',
              hintText: '¿El viraje del tercer 50 lo hice bien?',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('dejarlo'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Dejarlo'),
        ),
        FilledButton(
          key: const Key('mandar-la-pregunta'),
          onPressed: () => Navigator.of(context).pop(_controlador.text),
          child: const Text('Mandarla'),
        ),
      ],
    );
  }
}
