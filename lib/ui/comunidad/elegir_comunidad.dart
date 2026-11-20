/// Elegir comunidad y pedir entrar, después del alta (feature 012, FR-005).
///
/// **El alta ya lo prometía.** Su último paso dice, con todas las letras,
/// «puedes pedirlo más adelante desde Ajustes», y hasta que el recorrido del
/// quickstart lo leyó en voz alta no había ningún sitio donde hacerlo: quien
/// se saltara el paso, o a quien le dijeran que no, se quedaba sin puerta.
///
/// Es el mismo contenido que `PasoComunidad` y deliberadamente no es el mismo
/// widget: aquel vive dentro de una máquina de pasos con su propio «Continuar»
/// y su propio estado, y éste es una hoja que se abre y se cierra. Lo que
/// comparten —qué se ofrece, y que se puede no elegir— vive donde debe, en el
/// repositorio y en la regla.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/comunidad/comunidad.dart';
import 'package:natacion_app/dominio/comunidad/solicitud_de_ingreso.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

/// Abre la hoja y devuelve `true` si pidió entrar en alguna.
Future<bool> pedirEntrarEnUnaComunidad(
  BuildContext context, {
  required RepositorioComunidades comunidades,
  required RepositorioSolicitudes solicitudes,
  required String nadadorId,
  required String miNombre,
}) async {
  final pedida = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ElegirComunidad(
      comunidades: comunidades,
      solicitudes: solicitudes,
      nadadorId: nadadorId,
      miNombre: miNombre,
    ),
  );
  return pedida ?? false;
}

class ElegirComunidad extends StatefulWidget {
  const ElegirComunidad({
    super.key,
    required this.comunidades,
    required this.solicitudes,
    required this.nadadorId,
    required this.miNombre,
  });

  final RepositorioComunidades comunidades;
  final RepositorioSolicitudes solicitudes;
  final String nadadorId;

  /// Como se llama, para que viaje con la solicitud: el entrenador no puede
  /// leer su ficha hasta aceptarla (garantia F3).
  final String miNombre;

  @override
  State<ElegirComunidad> createState() => _ElegirComunidadState();
}

class _ElegirComunidadState extends State<ElegirComunidad> {
  List<Comunidad> _comunidades = const [];
  bool _cargando = true;
  String? _problema;
  String? _pidiendo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final leidas = await widget.comunidades.lasQueSePuedenOfrecer();
      if (!mounted) return;
      setState(() {
        _comunidades = leidas;
        _cargando = false;
      });
    } catch (problema) {
      // **No se pudo leer no es «no hay ninguna».** Es el mismo defecto que
      // este proyecto ya pagó tres veces, y aquí dejaría a alguien creyendo
      // que no existe ningún entrenador al que pedir.
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _problema =
            'No se pudo leer la lista de comunidades. Vuelve a intentarlo en '
            'un momento ($problema).';
      });
    }
  }

  Future<void> _pedir(Comunidad comunidad) async {
    setState(() => _pidiendo = comunidad.id);

    try {
      await widget.solicitudes.pedir(
        SolicitudDeIngreso(
          nadadorId: widget.nadadorId,
          comunidadId: comunidad.id,
          pedidaEn: DateTime.now(),
          nombre: widget.miNombre,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (problema) {
      if (!mounted) return;
      setState(() {
        _pidiendo = null;
        _problema = 'No se pudo pedir el ingreso ($problema).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.amplio),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Con quién entrenas?', style: texto.titleMedium),
            const SizedBox(height: Espaciado.minimo),
            const Text(
              'Tu entrenador tendrá que aceptarte. Mientras tanto puedes usar '
              'la app igual.',
            ),
            const SizedBox(height: Espaciado.corto),

            if (_cargando)
              const Padding(
                padding: EdgeInsets.all(Espaciado.amplio),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_problema != null)
              Aviso(
                tono: TonoDeAviso.cuidado,
                icono: Icons.cloud_off_outlined,
                claveDelMensaje: const Key('comunidades-no-se-pudieron-leer'),
                mensaje: _problema!,
              )
            else if (_comunidades.isEmpty)
              // FR-006: una lista en blanco es un callejón sin salida
              // disfrazado de pantalla. Se le dice en palabras.
              const Padding(
                key: Key('no-hay-comunidades'),
                padding: EdgeInsets.symmetric(vertical: Espaciado.corto),
                child: Text(
                  'Todavía no hay ningún entrenador al que pedir entrar. '
                  'Puedes usar la app igual y volver cuando lo haya.',
                ),
              )
            else
              for (final comunidad in _comunidades)
                ListTile(
                  key: Key('comunidad-${comunidad.id}'),
                  title: Text(comunidad.nombre),
                  trailing: _pidiendo == comunidad.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _pidiendo == null ? () => _pedir(comunidad) : null,
                ),

            const SizedBox(height: Espaciado.corto),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('ahora-no'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Ahora no'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
