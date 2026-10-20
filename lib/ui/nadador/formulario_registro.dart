/// Donde el nadador responde.
///
/// Marcar como realizada, RPE de Borg 0-10, observaciones y —**en un campo
/// propio**— el reporte de molestia.
///
/// **Solo marcar es obligatorio** (FR-010, principio VIII): «el registro de la
/// carga interna NO DEBE ser obligatorio para usar la app». Un nadador que solo
/// marca y se va ha usado la app bien. Lo que no se permite es que la app no
/// ofrezca dónde anotarlo.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/componentes/boton.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class FormularioRegistro extends StatefulWidget {
  const FormularioRegistro({
    super.key,
    required this.sesion,
    required this.estado,
  });

  final Sesion sesion;
  final EstadoNadador estado;

  @override
  State<FormularioRegistro> createState() => _FormularioRegistroState();
}

class _FormularioRegistroState extends State<FormularioRegistro> {
  late final TextEditingController _observaciones;
  late final TextEditingController _molestia;
  late final TextEditingController _zona;

  int? _rpe;
  bool _reportaMolestia = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final previo = widget.estado.registroDe(widget.sesion.id);

    _observaciones = TextEditingController(text: previo?.observaciones ?? '');
    _molestia =
        TextEditingController(text: previo?.molestia?.descripcion ?? '');
    _zona = TextEditingController(text: previo?.molestia?.zonaDelCuerpo ?? '');
    _rpe = previo?.rpePercibido;
    _reportaMolestia = previo?.tieneMolestia ?? false;
  }

  @override
  void dispose() {
    _observaciones.dispose();
    _molestia.dispose();
    _zona.dispose();
    super.dispose();
  }

  Future<void> _guardar({required bool realizada}) async {
    setState(() => _guardando = true);

    await widget.estado.responder(
      sesion: widget.sesion,
      realizada: realizada,
      rpePercibido: _rpe,
      observaciones: _observaciones.text,
      molestia: _reportaMolestia && _molestia.text.trim().isNotEmpty
          ? ReporteDeMolestia(
              descripcion: _molestia.text,
              zonaDelCuerpo: _zona.text,
            )
          : null,
    );

    if (!mounted) return;
    setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Cómo te fue?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Anotar es opcional. Puedes marcar la sesión y ya.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            _SelectorRpe(
              valor: _rpe,
              alCambiar: (v) => setState(() => _rpe = v),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _observaciones,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Observaciones',
                hintText: 'Lo que quieras contarle a tu entrenador',
              ),
            ),
            const SizedBox(height: 16),

            // La molestia va **separada** de las observaciones (FR-009): si
            // viviera dentro del texto libre, encontrarla dependería de leer
            // todas las observaciones de todas las sesiones.
            SwitchListTile(
              value: _reportaMolestia,
              onChanged: (v) => setState(() => _reportaMolestia = v),
              title: const Text('Tuve una molestia o dolor'),
              subtitle: const Text('Se lo marcamos aparte a tu entrenador'),
              contentPadding: EdgeInsets.zero,
            ),

            if (_reportaMolestia) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _molestia,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Qué sentiste',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _zona,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Dónde',
                  hintText: 'hombro derecho, rodilla, costado...',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu entrenador lo verá señalado. La app no decide nada por él.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 20),
            BotonPrincipal(
              etiqueta: 'Marcar como realizada',
              icono: Icons.check,
              trabajando: _guardando,
              alPulsar: () => _guardar(realizada: true),
            ),
            const SizedBox(height: 8),
            // «No pude ir» también es información (escenario R3).
            TextButton(
              onPressed: _guardando ? null : () => _guardar(realizada: false),
              child: const Text('No pude hacerla'),
            ),
          ],
        ),
      ),
    );
  }
}

/// RPE en la escala de Borg 0-10 (sección 9 de la metodología).
///
/// Se puede dejar sin responder: `null` es un valor válido.
class _SelectorRpe extends StatelessWidget {
  const _SelectorRpe({required this.valor, required this.alCambiar});

  final int? valor;
  final void Function(int?) alCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La etiqueta y el «Quitar» en un `Wrap`: con la letra grande no caben
        // en una línea, y el botón bajando es mejor que el botón invisible.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Espaciado.corto,
            children: [
              const Text('Esfuerzo percibido (0-10)'),
              // Un `TextButton` suelto y no `BotonSecundario`: este no es una
              // acción de la pantalla, es deshacer una elección de al lado.
              if (valor != null)
                TextButton(
                  onPressed: () => alCambiar(null),
                  child: const Text('Quitar'),
                ),
            ],
          ),
        ),
        OpcionesEnFila<int>(
          opciones: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          nombreDe: (n) => '$n',
          elegida: valor,
          alElegir: alCambiar,
        ),
      ],
    );
  }
}
