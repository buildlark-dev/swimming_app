/// Pedir que se borren mis datos.
///
/// **Dos acciones deliberadas** (H27). La primera abre esto; la segunda borra.
/// Y la segunda dice antes qué se borra y **qué sobrevive**, con las palabras
/// que el dominio ya escribió, a la vista y no en letra pequeña.
///
/// Quién la ejecuta en la cuenta de un menor: **ella misma**, igual que un
/// adulto (FR-023). Es decisión del entrenador, del 2026-10-25, contraria a mi
/// recomendación y tomada después de leerla. El derecho es del titular, y la
/// titular es ella. Lo único que se añadió por lo irreversible del borrado es
/// este segundo paso, que no le quita el derecho a nadie.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/datos_personales/derechos_del_titular.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class Supresion extends StatefulWidget {
  const Supresion({
    super.key,
    required this.operaciones,
    required this.alSuprimir,
  });

  final OperacionesDelServidor? operaciones;

  /// Qué hacer cuando ya no hay datos: la app arranca de nuevo.
  final Future<void> Function() alSuprimir;

  @override
  State<Supresion> createState() => _SupresionState();
}

class _SupresionState extends State<Supresion> {
  bool _confirmando = false;
  bool _borrando = false;
  String? _problema;

  Future<void> _suprimir() async {
    final operaciones = widget.operaciones;
    if (operaciones == null) return;

    setState(() {
      _borrando = true;
      _problema = null;
    });

    try {
      await operaciones.suprimirMisDatos();
      await widget.alSuprimir();
    } on FalloDelServidor catch (e) {
      if (mounted) {
        setState(() {
          _problema = e.mensaje;
          _borrando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabeceraSeccion(titulo: 'Borrar mis datos'),
          const SizedBox(height: Espaciado.corto),
          if (widget.operaciones == null)
            const Aviso(
              tono: TonoDeAviso.cuidado,
              icono: Icons.cloud_off_outlined,
              mensaje: 'Sin servidor no se puede pedir el borrado.',
            )
          else if (!_confirmando)
            OutlinedButton.icon(
              key: const Key('ajustes-suprimir'),
              onPressed: () => setState(() => _confirmando = true),
              // **Sin rojo** (FR-016 de la feature 005): el rojo está
              // reservado a lo que falló de verdad, y pedir un borrado no es
              // un fallo. El peso lo llevan las palabras y los dos pasos.
              icon: const Icon(Icons.delete_outline),
              label: const Text('Pedir que se borren mis datos'),
            )
          else ...[
            Text('Esto no se puede deshacer.', style: textos.titleSmall),
            const SizedBox(height: Espaciado.corto),
            Text(
              'Se borran: tus respuestas a las sesiones, lo que escribiste, '
              'los planes que te habían entregado, tu ficha de nadador y tu '
              'cuenta. Después tendrías que empezar de cero.',
              style: textos.bodyMedium,
            ),
            const SizedBox(height: Espaciado.normal),
            // **Lo que sobrevive, con las palabras del dominio.**
            Aviso(
              claveDelMensaje: const Key('ajustes-lo-que-sobrevive'),
              tono: TonoDeAviso.informativo,
              icono: Icons.gavel_outlined,
              mensaje: ResultadoDeEliminacion.loQueSobrevive,
            ),
            if (_problema != null) ...[
              const SizedBox(height: Espaciado.normal),
              Aviso(
                tono: TonoDeAviso.error,
                icono: Icons.error_outline,
                mensaje: _problema!,
              ),
            ],
            const SizedBox(height: Espaciado.amplio),
            Row(
              children: [
                FilledButton(
                  key: const Key('ajustes-suprimir-de-verdad'),
                  onPressed: _borrando ? null : _suprimir,
                  child: Text(_borrando ? 'Borrando…' : 'Sí, borrar todo'),
                ),
                const SizedBox(width: Espaciado.corto),
                TextButton(
                  onPressed: _borrando
                      ? null
                      : () => setState(() => _confirmando = false),
                  child: const Text('No, dejarlo así'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
