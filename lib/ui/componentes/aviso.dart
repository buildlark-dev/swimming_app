/// El aviso, decidido una vez.
///
/// Es el componente que más se repite en la app y el que peor estaba: de los
/// cincuenta y cuatro usos de color semántico que había, treinta y cuatro eran
/// de la familia de error, y **solo dos sitios eran errores de verdad**. La app
/// pintaba de rojo el modo local, los avisos de auditoría, el reporte de
/// molestia y «guardado, se enviará cuando tengas internet», que es una buena
/// noticia.
///
/// Un rojo que sale siempre deja de significar nada. Cuando aparezca uno real,
/// nadie lo mirará.
///
/// Quien lo usa **tiene que decir de qué tono es**. No hay valor por omisión a
/// propósito: el tono es la decisión, y un valor por omisión la escondería.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.tono,
    required this.mensaje,
    this.titulo,
    this.icono,
    this.claveDelMensaje,
    this.detalles = const <Widget>[],
    this.acciones = const <Widget>[],
  });

  /// De qué clase es. Lo decide quien lo muestra, siempre.
  final TonoDeAviso tono;

  final String mensaje;

  /// Encabezado opcional, para los avisos que llevan varias líneas debajo.
  final String? titulo;

  /// Un icono propio, cuando el del tono no describe bien el caso.
  ///
  /// Sigue siendo un icono: lo que no se puede quitar es **que haya uno**. El
  /// color no es nunca la única señal (FR-015).
  final IconData? icono;

  /// Para las pruebas que ya buscaban el texto por clave antes de que este
  /// componente existiera.
  final Key? claveDelMensaje;

  /// Líneas adicionales, cuando el aviso desglosa.
  final List<Widget> detalles;

  /// Lo que se puede hacer al respecto, si hay algo.
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final color = context.colores.deTono(tono);

    // El **texto va en el color normal de la superficie**, no en el del tono.
    //
    // Los cuatro tonos están comprobados como color de texto sobre blanco, pero
    // un párrafo entero de color se lee peor que uno negro, y este es el sitio
    // donde la app explica algo. El tono se ve en el icono y en la barra de la
    // izquierda, que son elementos, no texto.
    return Container(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Espaciado.radioNormal),
        border: Border(left: BorderSide(color: color, width: Espaciado.minimo)),
      ),
      padding: const EdgeInsets.all(Espaciado.normal),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono ?? tono.icono, color: color),
          const SizedBox(width: Espaciado.normal),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null) ...[
                  Text(
                    titulo!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Espaciado.minimo),
                ],
                Text(mensaje, key: claveDelMensaje),
                if (detalles.isNotEmpty) ...[
                  const SizedBox(height: Espaciado.corto),
                  ...detalles,
                ],
                if (acciones.isNotEmpty) ...[
                  const SizedBox(height: Espaciado.corto),
                  Wrap(spacing: Espaciado.corto, children: acciones),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una línea dentro de un aviso que desglosa.
///
/// Sale de `PanelAvisos`, donde el entrenador ve volumen, reparto, metros sin
/// zona y fragmentos sin interpretar como una lista de líneas con icono.
class LineaDeAviso extends StatelessWidget {
  const LineaDeAviso({
    super.key,
    required this.icono,
    required this.texto,
    this.destacada = false,
  });

  final IconData icono;
  final String texto;

  /// Lo que impide dar algo por completo, frente a lo que solo informa.
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: Espaciado.iconoEnLinea),
          const SizedBox(width: Espaciado.corto),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontWeight: destacada ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
