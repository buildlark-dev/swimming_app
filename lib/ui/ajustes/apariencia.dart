/// Claro, oscuro, o lo del teléfono.
///
/// La elección **sobrevive al cierre de sesión** (H29), porque es del
/// dispositivo y no de la persona: quien tiene el teléfono al sol lo quiere
/// claro, y el hermano que entra después, también. Por eso no vive en el
/// almacén por cuenta, que `cerrarSesion()` vacía (decisión D4).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/preferencias/apariencia.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class SeccionApariencia extends StatefulWidget {
  const SeccionApariencia({
    super.key,
    this.preferencias = const PreferenciasDelDispositivo(),
    this.alElegir,
  });

  final PreferenciasDelDispositivo preferencias;

  /// Para que la app entera se repinte con la elección.
  final ValueChanged<Apariencia>? alElegir;

  @override
  State<SeccionApariencia> createState() => _SeccionAparienciaState();
}

class _SeccionAparienciaState extends State<SeccionApariencia> {
  Apariencia _elegida = Apariencia.delSistema;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final guardada = await widget.preferencias.apariencia();
    if (mounted) setState(() => _elegida = guardada);
  }

  Future<void> _elegir(Apariencia apariencia) async {
    setState(() => _elegida = apariencia);
    await widget.preferencias.guardarApariencia(apariencia);
    widget.alElegir?.call(apariencia);
  }

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      key: const Key('ajustes-apariencia'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabeceraSeccion(titulo: 'Apariencia'),
          const SizedBox(height: Espaciado.normal),
          Wrap(
            spacing: Espaciado.corto,
            runSpacing: Espaciado.corto,
            children: [
              for (final apariencia in Apariencia.values)
                ChoiceChip(
                  key: Key('apariencia-${apariencia.clave}'),
                  label: Text(apariencia.etiqueta),
                  selected: _elegida == apariencia,
                  onSelected: (_) => _elegir(apariencia),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
