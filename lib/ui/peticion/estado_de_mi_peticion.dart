/// En qué va lo que el nadador pidió.
///
/// **Sin prometer fechas** (FR-027). Una app que dice «en 24 horas» y no
/// cumple enseña a no creerle, y aquí quien espera puede tener nueve años.
/// Lo que se dice es el estado, y cuando hay algo que leer —un rechazo con su
/// motivo—, se lee tal como lo escribió el entrenador.
///
/// **Lo que no aparece es el borrador.** Antes de la firma, el nadador no ve
/// su contenido: lo que ve es en qué va su solicitud (P16).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class EstadoDeMiPeticion extends StatelessWidget {
  const EstadoDeMiPeticion({
    super.key,
    required this.peticion,
    this.alPedirDeNuevo,
  });

  final PeticionDePlan peticion;

  /// Solo cuando la anterior ya se cerró: con una abierta no se manda otra.
  final VoidCallback? alPedirDeNuevo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return ListView(
      key: const Key('estado-de-mi-peticion'),
      padding: const EdgeInsets.all(Espaciado.amplio),
      children: [
        Text('Tu solicitud', style: textos.headlineSmall),
        const SizedBox(height: Espaciado.amplio),

        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconoDe(peticion.estado)),
                  const SizedBox(width: Espaciado.corto),
                  Expanded(
                    child: Text(
                      peticion.estado.comoLoLeeElNadador,
                      key: const Key('estado-actual'),
                      style: textos.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espaciado.corto),
              Text(_queSignifica(peticion.estado), style: textos.bodyMedium),
            ],
          ),
        ),

        if (peticion.motivoDelRechazo != null) ...[
          const SizedBox(height: Espaciado.amplio),
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lo que te dijo', style: textos.titleMedium),
                const SizedBox(height: Espaciado.corto),
                // Tal como lo escribió él. Ni resumido ni suavizado: es su
                // respuesta a su nadador.
                Text(
                  peticion.motivoDelRechazo!,
                  key: const Key('motivo-del-rechazo'),
                  style: textos.bodyLarge,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: Espaciado.amplio),
        _LoQuePediste(respuestas: peticion.respuestas),

        if (peticion.estaAbierta) ...[
          const SizedBox(height: Espaciado.amplio),
          const Aviso(
            tono: TonoDeAviso.informativo,
            icono: Icons.hourglass_empty,
            claveDelMensaje: Key('una-a-la-vez'),
            mensaje:
                'Mientras esta esté sin responder no puedes mandar otra. '
                'Cuando tu entrenador te conteste, podrás pedir de nuevo.',
          ),
        ],

        if (!peticion.estaAbierta && alPedirDeNuevo != null) ...[
          const SizedBox(height: Espaciado.amplio),
          FilledButton.icon(
            key: const Key('pedir-de-nuevo'),
            onPressed: alPedirDeNuevo,
            icon: const Icon(Icons.refresh),
            label: const Text('Pedir otro entrenamiento'),
          ),
        ],

        const SizedBox(height: Espaciado.generoso),
      ],
    );
  }

  IconData _iconoDe(EstadoDePeticion estado) => switch (estado) {
    EstadoDePeticion.esperando => Icons.hourglass_empty,
    EstadoDePeticion.enRevision => Icons.visibility_outlined,
    EstadoDePeticion.aprobada => Icons.check_circle_outline,
    EstadoDePeticion.rechazada => Icons.mark_email_read_outlined,
  };

  /// Qué significa cada estado, **sin decir cuándo**.
  String _queSignifica(EstadoDePeticion estado) => switch (estado) {
    EstadoDePeticion.esperando =>
      'Le llegó. Él la revisa cuando pueda y te responde por aquí.',
    EstadoDePeticion.enRevision =>
      'Está preparándote el entrenamiento o decidiendo qué te conviene.',
    EstadoDePeticion.aprobada =>
      'Tu entrenador lo firmó. Cuando te lo entregue, lo verás en Ver Plan.',
    EstadoDePeticion.rechazada =>
      'Te escribió por qué. Léelo y, si quieres, pídele otra vez.',
  };
}

/// Lo que él respondió, para que pueda verlo sin tener que recordarlo.
class _LoQuePediste extends StatelessWidget {
  const _LoQuePediste({required this.respuestas});

  final RespuestasDePeticion respuestas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lo que pediste', style: textos.titleMedium),
          const SizedBox(height: Espaciado.corto),
          _Linea('Prueba', respuestas.pruebaObjetivo),
          _Linea('Estilo', respuestas.estiloObjetivo.nombre),
          _Linea('Días por semana', '${respuestas.diasDisponibles.length}'),
          _Linea('Cada entrenamiento', '${respuestas.duracionSesionMinutos} min'),
          _Linea('Piscina', '${respuestas.longitudPiscina} metros'),
          _Linea(
            'Competencia',
            respuestas.fechaDeCompetencia == null
                ? 'No lo sabías'
                : _comoFecha(respuestas.fechaDeCompetencia!),
          ),
        ],
      ),
    );
  }

  static String _comoFecha(DateTime cuando) =>
      '${cuando.day}/${cuando.month}/${cuando.year}';
}

class _Linea extends StatelessWidget {
  const _Linea(this.que, this.valor);

  final String que;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Espaciado.minimo),
    child: Row(
      children: [
        Expanded(child: Text(que)),
        Text(valor, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}
