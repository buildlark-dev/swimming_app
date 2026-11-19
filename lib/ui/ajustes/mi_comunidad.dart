/// Donde el entrenador le pone nombre a lo suyo (feature 012, US1).
///
/// **Es lo primero que tiene que existir en esta feature.** Una nadadora no
/// puede pedir entrar a algo que no tiene nombre, y el nombre es lo único que
/// ella tendrá para reconocerlo.
///
/// Vive en ajustes, junto a lo demás que él gobierna de su propia cuenta:
/// apariencia, mis datos, mis derechos, lo que acepté y supresión.
///
/// **Cambiarle el nombre no mueve a nadie** (FR-003). Es cierto por cómo está
/// guardado —el nombre aquí, la pertenencia en la ficha de cada nadadora— y no
/// porque esta pantalla se acuerde de serlo.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/comunidad/comunidad.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/boton.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class MiComunidad extends StatefulWidget {
  const MiComunidad({
    super.key,
    required this.entrenadorId,
    required this.comunidades,
  });

  final String entrenadorId;

  /// Nulo sin servidor: entonces esto no se pinta, porque no hay dónde
  /// guardarlo y un campo que no puede terminar lo que empieza es peor que
  /// ningún campo (H12).
  final RepositorioComunidades? comunidades;

  @override
  State<MiComunidad> createState() => _MiComunidadState();
}

class _MiComunidadState extends State<MiComunidad> {
  final _nombre = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  String? _problema;
  String? _guardado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final repo = widget.comunidades;
    if (repo == null) {
      setState(() => _cargando = false);
      return;
    }

    try {
      final suya = await repo.deEntrenador(widget.entrenadorId);
      if (!mounted) return;
      setState(() {
        _nombre.text = suya?.nombre ?? '';
        _cargando = false;
      });
    } on FalloDeDatos catch (e) {
      if (!mounted) return;
      setState(() {
        _problema = e.mensaje;
        _cargando = false;
      });
    }
  }

  Future<void> _guardar() async {
    final repo = widget.comunidades;
    if (repo == null) return;

    setState(() {
      _guardando = true;
      _problema = null;
      _guardado = null;
    });

    try {
      // **La validación es del dominio**, no de esta pantalla: un nombre en
      // blanco lo rechaza `Comunidad` en su constructor, y aquí solo se
      // traduce a algo que él pueda hacer.
      final comunidad = Comunidad(
        id: widget.entrenadorId,
        entrenadorId: widget.entrenadorId,
        nombre: _nombre.text,
      );
      await repo.guardar(comunidad);

      if (!mounted) return;
      setState(() {
        _guardando = false;
        _guardado = 'Guardado. Tus nadadores verán «${comunidad.nombre}».';
      });
    } on NombreDeComunidadInvalido catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _problema = _enPalabrasSuyas(e);
      });
    } on FalloDeDatos catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _problema = e.mensaje;
      });
    }
  }

  /// Lo que el dominio rechaza, dicho para quien lo está escribiendo.
  String _enPalabrasSuyas(NombreDeComunidadInvalido e) =>
      e.porQue.contains('blanco')
      ? 'Ponle un nombre: es lo que verán tus nadadores al buscarte.'
      : 'El nombre es muy largo. Máximo $largoMaximoDelNombre caracteres.';

  @override
  Widget build(BuildContext context) {
    if (widget.comunidades == null) return const SizedBox.shrink();

    final texto = Theme.of(context).textTheme;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mi comunidad', style: texto.titleMedium),
          const SizedBox(height: Espaciado.corto),
          Text(
            'El nombre que verán tus nadadores cuando pidan unirse a ti.',
            style: texto.bodySmall,
          ),
          const SizedBox(height: Espaciado.normal),

          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else ...[
            TextField(
              key: const Key('nombre-de-la-comunidad'),
              controller: _nombre,
              maxLength: largoMaximoDelNombre,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Nombre',
                hintText: 'Tu club, tu grupo o tu nombre',
              ),
            ),
            const SizedBox(height: Espaciado.corto),
            BotonPrincipal(
              etiqueta: 'Guardar el nombre',
              icono: Icons.group_outlined,
              trabajando: _guardando,
              alPulsar: _guardar,
            ),
          ],

          if (_problema != null) ...[
            const SizedBox(height: Espaciado.normal),
            Aviso(
              tono: TonoDeAviso.cuidado,
              icono: Icons.info_outline,
              claveDelMensaje: const Key('comunidad-problema'),
              mensaje: _problema!,
            ),
          ],
          if (_guardado != null) ...[
            const SizedBox(height: Espaciado.normal),
            Aviso(
              tono: TonoDeAviso.exito,
              icono: Icons.check_circle_outline,
              claveDelMensaje: const Key('comunidad-guardada'),
              mensaje: _guardado!,
            ),
          ],
        ],
      ),
    );
  }
}
