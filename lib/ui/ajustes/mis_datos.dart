/// Mis datos: verlos y corregirlos.
///
/// **No usa `guardarPerfil`.** Esa operación exige la versión de los términos y
/// escribe `terminos.aceptadaEn` con la hora del servidor: corregir un apellido
/// por ahí diría que la persona aceptó hoy la versión vigente, cuando aceptó
/// otra hace un mes y nadie le ha mostrado la nueva. Eso es falsificar una
/// constancia legal, y por eso hay una operación aparte (decisión D5, H21).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class MisDatos extends StatefulWidget {
  const MisDatos({
    super.key,
    required this.perfil,
    required this.operaciones,
    required this.alCorregir,
  });

  final Perfil perfil;

  /// Nulas sin servidor: entonces los datos se ven pero no se corrigen, y se
  /// dice, en lugar de ofrecer un botón que no va a ninguna parte.
  final OperacionesDelServidor? operaciones;

  final Future<void> Function() alCorregir;

  @override
  State<MisDatos> createState() => _MisDatosState();
}

class _MisDatosState extends State<MisDatos> {
  bool _corrigiendo = false;
  bool _guardando = false;
  String? _problema;

  late String _nombre = widget.perfil.nombre;
  late DateTime? _nacimiento = widget.perfil.fechaNacimiento;
  late String? _pais = widget.perfil.pais;

  Future<void> _guardar() async {
    final operaciones = widget.operaciones;
    final nacimiento = _nacimiento;

    if (_nombre.trim().isEmpty) {
      setState(() => _problema = 'Hace falta tu nombre.');
      return;
    }
    if (nacimiento == null) {
      setState(() => _problema = 'Hace falta tu fecha de nacimiento.');
      return;
    }
    if (operaciones == null) {
      setState(() => _problema = 'Sin servidor no se puede guardar.');
      return;
    }

    setState(() {
      _guardando = true;
      _problema = null;
    });

    try {
      await operaciones.corregirPerfil(
        nombre: _nombre.trim(),
        fechaNacimiento: nacimiento,
        pais: _pais,
      );
      await widget.alCorregir();
      if (mounted) setState(() => _corrigiendo = false);
    } on FalloDelServidor catch (e) {
      if (mounted) setState(() => _problema = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      key: const Key('ajustes-mis-datos'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabeceraSeccion(titulo: 'Mis datos'),
          const SizedBox(height: Espaciado.normal),
          if (!_corrigiendo) ...[
            _Dato(etiqueta: 'Nombre', valor: widget.perfil.nombre),
            _Dato(
              etiqueta: 'Fecha de nacimiento',
              valor: _comoFecha(widget.perfil.fechaNacimiento),
            ),
            _Dato(etiqueta: 'País', valor: widget.perfil.pais ?? 'No consta'),
            const SizedBox(height: Espaciado.normal),
            if (widget.operaciones == null)
              const Aviso(
                tono: TonoDeAviso.cuidado,
                icono: Icons.cloud_off_outlined,
                mensaje: 'Sin servidor no se pueden corregir los datos.',
              )
            else
              OutlinedButton.icon(
                key: const Key('ajustes-corregir'),
                onPressed: () => setState(() => _corrigiendo = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corregir'),
              ),
          ] else ...[
            Campo(
              key: const Key('ajustes-campo-nombre'),
              etiqueta: 'Nombre completo',
              valorInicial: _nombre,
              alCambiar: (valor) => _nombre = valor,
            ),
            const SizedBox(height: Espaciado.normal),
            _ElegirFecha(
              valor: _nacimiento,
              alElegir: (fecha) => setState(() => _nacimiento = fecha),
            ),
            const SizedBox(height: Espaciado.normal),
            Campo(
              key: const Key('ajustes-campo-pais'),
              etiqueta: 'País de residencia',
              ayuda: 'Dos letras, como CO. Puede quedar vacío.',
              valorInicial: _pais ?? '',
              alCambiar: (valor) => _pais = valor.trim().isEmpty
                  ? null
                  : valor.trim().toUpperCase(),
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
                  key: const Key('ajustes-guardar'),
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando…' : 'Guardar'),
                ),
                const SizedBox(width: Espaciado.corto),
                TextButton(
                  onPressed: _guardando
                      ? null
                      : () => setState(() {
                          _corrigiendo = false;
                          _problema = null;
                          _nombre = widget.perfil.nombre;
                          _nacimiento = widget.perfil.fechaNacimiento;
                          _pais = widget.perfil.pais;
                        }),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.corto),
            Text(
              'Corregir tus datos no cambia lo que aceptaste ni cuándo.',
              style: textos.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

String _comoFecha(DateTime? fecha) =>
    fecha == null ? 'No consta' : '${fecha.day}/${fecha.month}/${fecha.year}';

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.corto),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          Text(valor, style: textos.bodyLarge),
        ],
      ),
    );
  }
}

class _ElegirFecha extends StatelessWidget {
  const _ElegirFecha({required this.valor, required this.alElegir});

  final DateTime? valor;
  final ValueChanged<DateTime> alElegir;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('ajustes-campo-nacimiento'),
      onPressed: () async {
        final ahora = DateTime.now();
        final elegida = await showDatePicker(
          context: context,
          initialDate: valor ?? DateTime(ahora.year - 12),
          firstDate: DateTime(1900),
          lastDate: ahora,
          // El calendario en español y con formato dd/mm/aaaa: 03/05 significa
          // cosas distintas a los dos lados del Atlántico, y de esta fecha
          // depende si se pide el consentimiento de un acudiente.
          locale: const Locale('es'),
        );
        if (elegida != null) alElegir(elegida);
      },
      icon: const Icon(Icons.cake_outlined),
      label: Text('Nacimiento: ${_comoFecha(valor)}'),
    );
  }
}
