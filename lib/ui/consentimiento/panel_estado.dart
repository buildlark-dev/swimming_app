/// Lo que el entrenador ve del consentimiento de cada nadador.
///
/// Y desde donde pide uno. **El canal lo escribe él**, de su matrícula: es la
/// garantía C1, la que cierra el agujero de que un menor designe quién
/// consiente por él, y la que hace que el resto de la cadena signifique algo.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';

/// En qué punto va cada nadador.
enum EstadoDeConsentimiento {
  sinPedir('Sin pedir', Icons.radio_button_unchecked),
  pedido('Solicitud enviada', Icons.schedule),
  vigente('Vigente', Icons.verified_user_outlined),
  revocado('Revocado', Icons.gpp_bad_outlined);

  const EstadoDeConsentimiento(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;
}

/// Un nadador y su situación, para pintar la lista.
class EstadoDelNadador {
  const EstadoDelNadador({
    required this.nadadorId,
    required this.nombre,
    required this.estado,
    this.alcances = const <Alcance>{},
  });

  final String nadadorId;
  final String nombre;
  final EstadoDeConsentimiento estado;
  final Set<Alcance> alcances;

  /// Si se le puede publicar un plan. Es la puerta, vista desde la pantalla.
  ///
  /// Quien la hace cumplir son las reglas de acceso; esto solo evita ofrecer
  /// un botón que el servidor va a rechazar, y explicar por qué.
  bool get puedeRecibirUnPlan => estado == EstadoDeConsentimiento.vigente;
}

class PanelEstadoConsentimiento extends StatelessWidget {
  const PanelEstadoConsentimiento({
    super.key,
    required this.nadadores,
    required this.alPedir,
  });

  final List<EstadoDelNadador> nadadores;

  /// Pide el consentimiento al canal que escriba el entrenador.
  final Future<void> Function(String nadadorId, String canal) alPedir;

  @override
  Widget build(BuildContext context) {
    if (nadadores.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavía no hay nadadores. Créalos en la pestaña Nadadores.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: nadadores.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final nadador = nadadores[i];
        final esquema = Theme.of(context).colorScheme;

        return ListTile(
          key: Key('consentimiento-${nadador.nadadorId}'),
          leading: Icon(
            nadador.estado.icono,
            color: nadador.puedeRecibirUnPlan ? esquema.primary : esquema.error,
          ),
          title: Text(nadador.nombre),
          subtitle: Text(
            nadador.puedeRecibirUnPlan
                ? '${nadador.estado.etiqueta} · '
                    '${nadador.alcances.map((a) => a.clave).join(', ')}'
                : '${nadador.estado.etiqueta} · no se le puede publicar un plan',
          ),
          trailing: nadador.puedeRecibirUnPlan
              ? null
              : TextButton(
                  key: Key('pedir-${nadador.nadadorId}'),
                  onPressed: () => _pedir(context, nadador),
                  child: const Text('Pedir'),
                ),
        );
      },
    );
  }

  Future<void> _pedir(BuildContext context, EstadoDelNadador nadador) async {
    final canal = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoCanal(nombre: nadador.nombre),
    );

    if (canal == null || canal.trim().isEmpty) return;
    await alPedir(nadador.nadadorId, canal.trim());
  }
}

class _DialogoCanal extends StatefulWidget {
  const _DialogoCanal({required this.nombre});

  final String nombre;

  @override
  State<_DialogoCanal> createState() => _DialogoCanalState();
}

class _DialogoCanalState extends State<_DialogoCanal> {
  final _canal = TextEditingController();

  @override
  void dispose() {
    _canal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pedir autorización para ${widget.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Escribe el contacto del acudiente tal como lo tienes en tu '
            'matrícula. El enlace va ahí, sirve una sola vez y vence en siete '
            'días.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _canal,
            key: const Key('campo-canal'),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Correo del acudiente',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton-enviar-solicitud'),
          onPressed: () => Navigator.of(context).pop(_canal.text),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
