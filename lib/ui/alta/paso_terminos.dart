/// Paso 4: los términos y condiciones.
///
/// **El texto va delante, legible en la propia pantalla, no detrás de un
/// enlace** (FR-005). Es la misma regla que la feature 004 aplicó al texto de
/// consentimiento, y por la misma razón: aceptar algo que no se ha leído porque
/// estaba a un toque de distancia no es aceptarlo.
///
/// La casilla **no viene marcada**. Premarcarla sería un patrón oscuro.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/recursos/textos_legales.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

class PasoTerminos extends StatefulWidget {
  const PasoTerminos({super.key, this.textos = const CargadorTextosLegales()});

  final CargadorTextosLegales textos;

  @override
  State<PasoTerminos> createState() => _PasoTerminosState();
}

class _PasoTerminosState extends State<PasoTerminos> {
  late final Future<String> _texto = widget.textos.terminos();

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoAlta>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Términos y condiciones',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Espaciado.normal),

        Container(
          key: const Key('alta-texto-terminos'),
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Espaciado.radioNormal),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.all(Espaciado.normal),
          child: FutureBuilder<String>(
            future: _texto,
            builder: (context, instantanea) {
              if (instantanea.hasError) {
                // Sin el texto **no se puede aceptar nada**. Enseñar la
                // casilla sin él sería pedir un sí a ciegas.
                return const Text(
                  'No se pudo cargar el texto. Inténtalo otra vez en un '
                  'momento: sin leerlo no tiene sentido aceptarlo.',
                );
              }
              if (!instantanea.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return SingleChildScrollView(
                child: SelectableText(instantanea.data!),
              );
            },
          ),
        ),

        const SizedBox(height: Espaciado.amplio),

        FutureBuilder<String>(
          future: _texto,
          builder: (context, instantanea) => CheckboxListTile(
            key: const Key('alta-casilla-terminos'),
            value: estado.perfil.terminos != null,
            // Sin texto cargado no hay nada que aceptar.
            onChanged: instantanea.hasData
                ? (valor) => estado.aceptarTerminos(aceptados: valor ?? false)
                : null,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('He leído y acepto los términos y condiciones'),
          ),
        ),
      ],
    );
  }
}
