/// Panel de avisos del editor.
///
/// Muestra lo que impide dar la sesión por completa: fragmentos que la app no
/// supo interpretar, volumen fuera del rango de la categoría y datos
/// obligatorios que faltan. Los avisos nombran siempre el dato concreto y la
/// diferencia exacta; nunca sugieren un ejercicio de reemplazo.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class PanelAvisos extends StatelessWidget {
  const PanelAvisos({super.key, required this.estado});

  final EstadoEditor estado;

  @override
  Widget build(BuildContext context) {
    final pendientes = estado.pendientes;
    final volumen = estado.volumen;
    final faltas = estado.sesion.faltas;

    final completa = estado.sesion.estaCompleta;

    // **Cuidado, no error.**
    //
    // Una sesión incompleta no es una avería: es una sesión a medio escribir,
    // que es el estado normal mientras el entrenador la escribe. Pintar de rojo
    // el trabajo en curso era decirle que algo se había roto cada vez que
    // empezaba una sesión nueva.
    //
    // Cuando sí está completa, el tono es de éxito, que es lo que es.
    return Aviso(
      tono: completa ? TonoDeAviso.exito : TonoDeAviso.cuidado,
      icono: completa ? Icons.check_circle_outline : Icons.pending_outlined,
      titulo: completa ? 'Sesión completa' : 'Sesión incompleta',
      mensaje: completa
          ? 'No queda nada por resolver.'
          : 'Lo que falta para darla por completa:',
      detalles: [
        // Volumen frente a la categoría.
        LineaDeAviso(
          icono: volumen.dentroDelRango
              ? Icons.check
              : Icons.report_problem_outlined,
          texto: volumen.descripcion,
          destacada: !volumen.dentroDelRango,
        ),

        // Reparto entre partes.
        for (final desviacion in estado.calculo.repartoDePartes)
          if (estado.sesion.metros > 0 && desviacion.diferencia.abs() > 10)
            LineaDeAviso(
              icono: Icons.percent,
              texto: '${desviacion.tipo.nombre}: '
                  '${desviacion.porcentajeReal.toStringAsFixed(0)}% '
                  'frente al ${desviacion.porcentajePrescrito}% prescrito',
              destacada: true,
            ),

        // Metros sin zona asignada.
        if (estado.calculo.metrosSinZona > 0)
          LineaDeAviso(
            icono: Icons.help_outline,
            texto: '${estado.calculo.metrosSinZona} m sin zona asignada. '
                'La zona la asigna el entrenador, la app no la supone.',
            destacada: true,
          ),

        // Fragmentos pendientes.
        if (pendientes.isNotEmpty) ...[
          const SizedBox(height: Espaciado.corto),
          Text(
            'Sin interpretar (${pendientes.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final pendiente in pendientes)
            LineaDeAviso(
              icono: _iconoDe(pendiente.motivo),
              texto: '"${pendiente.texto}" — '
                  '${pendiente.motivo.descripcion}'
                  '${pendiente.detalle.isEmpty ? '' : '. ${pendiente.detalle}'}',
              destacada: true,
            ),
        ],

        // Datos obligatorios que faltan.
        for (final falta in faltas)
          if (falta.campo != 'pendientes')
            LineaDeAviso(
              icono: Icons.edit_note,
              texto: falta.descripcion,
              destacada: true,
            ),

        // Notación en desuso y otros avisos que no bloquean.
        for (final aviso in estado.avisos)
          LineaDeAviso(
            icono: Icons.info_outline,
            texto: aviso,
            destacada: false,
          ),
      ],
    );
  }

  static IconData _iconoDe(MotivoPendiente motivo) {
    switch (motivo) {
      case MotivoPendiente.ejercicioFueraDeBiblioteca:
        return Icons.block;
      case MotivoPendiente.ambiguo:
        return Icons.help_outline;
      case MotivoPendiente.nomenclaturaProhibida:
        return Icons.do_not_disturb_on_outlined;
      case MotivoPendiente.terminoDesconocido:
      case MotivoPendiente.estructuraNoReconocida:
        return Icons.question_mark;
    }
  }
}
