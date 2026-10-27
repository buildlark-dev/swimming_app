/// Índice de términos de diagnóstico declarados por el entrenador.
///
/// Sustituye la búsqueda literal sobre la prosa del campo «error que corrige».
/// Esa búsqueda exigía que la frase apareciese tal cual dentro del texto de la
/// ficha, así que `rolido insuficiente` encontraba el ejercicio de libre
/// —cuya ficha dice «Rolido insuficiente/excesivo»— y no el de espalda, donde
/// la misma idea está escrita «Rolido de cadera/hombro insuficiente».
///
/// Dos cosas que este índice **no** hace, y es deliberado:
///
/// - **No compara por parecido de letras.** Esa tolerancia haría coincidir
///   `patada` con `brazada` antes que `dosiflexión` con `dorsiflexión`, y
///   empezaría a prescribir ejercicios equivocados con mucha confianza.
/// - **No deduce términos.** Cada forma de nombrar un error la declara el
///   entrenador. Una frase que no esté en el índice se reporta como vacío de
///   Biblioteca y no se resuelve con un ejercicio aproximado (regla R2).
///
/// La correspondencia se establece por **palabras significativas**: los
/// términos de la entrada tienen que estar todos presentes en la frase
/// diagnosticada. Así `patada desde rodillas` y `patada desde las rodillas`
/// son la misma cosa, mientras que `patada` a secas no alcanza para ninguna
/// entrada y sigue reportándose como vacío, que es lo correcto: es demasiado
/// genérica para elegir un correctivo.
library;

import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Una forma de nombrar un error y los ejercicios que le corresponden.
class EntradaTermino {
  EntradaTermino({
    required this.frase,
    required this.estilo,
    required this.ejercicios,
    this.origen = '',
    this.nota = '',
  }) : palabras = palabrasSignificativas(frase);

  /// La frase tal como la escribe el entrenador.
  final String frase;

  final Estilo estilo;

  /// Nombres de ejercicio **en orden de prioridad**: el primero es el que el
  /// entrenador señaló como principal.
  final List<String> ejercicios;

  /// Fila de `correspondencia_diagnostico.md` de donde sale esta entrada.
  final String origen;

  /// Por qué esta entrada quedó así, cuando hubo una decisión detrás.
  final String nota;

  /// Palabras de [frase] que cuentan para la correspondencia.
  final Set<String> palabras;

  /// Verdadero si esta entrada corresponde a [frase] diagnosticada.
  ///
  /// Corresponde cuando todas las palabras significativas del término están
  /// en la frase. La frase puede decir más —«codo bajo en el recobro» cumple
  /// el término «codo bajo»—, pero no menos.
  bool correspondeA(String fraseDiagnosticada) {
    final deLaFrase = palabrasSignificativas(fraseDiagnosticada);
    if (deLaFrase.isEmpty || palabras.isEmpty) return false;
    return palabras.every(deLaFrase.contains);
  }

  factory EntradaTermino.desdeJson(Map<String, dynamic> json) {
    final nombreEstilo = (json['estilo'] as String? ?? '').trim().toLowerCase();
    final coincidencias = Estilo.values
        .where((e) => e.name == nombreEstilo)
        .toList();

    if (coincidencias.isEmpty) {
      throw FormatException('Estilo desconocido en el índice: «$nombreEstilo»');
    }
    final estilo = coincidencias.first;

    final ejercicios = (json['ejercicios'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList();

    return EntradaTermino(
      frase: json['frase'] as String? ?? '',
      estilo: estilo,
      ejercicios: List.unmodifiable(ejercicios),
      origen: json['origen'] as String? ?? '',
      nota: json['nota'] as String? ?? '',
    );
  }
}

class IndiceTerminos {
  IndiceTerminos(List<EntradaTermino> entradas)
    : entradas = List.unmodifiable(entradas);

  /// Índice vacío: ninguna frase encuentra ejercicio, todas reportan vacío.
  IndiceTerminos.vacio() : entradas = const [];

  final List<EntradaTermino> entradas;

  bool get estaVacio => entradas.isEmpty;

  /// Versión del índice, para poder estampar con qué vocabulario se generó.
  String version = '';

  /// Nombres de ejercicio que corresponden a [frase] en [estilo].
  ///
  /// Devuelve los nombres en el orden declarado por el entrenador, sin
  /// repetir. Vacío si ninguna entrada corresponde: eso es un vacío de
  /// Biblioteca y quien llama debe reportarlo, no sustituirlo.
  List<String> ejerciciosPara({required Estilo estilo, required String frase}) {
    final nombres = <String>[];

    for (final entrada in entradas) {
      if (entrada.estilo != estilo) continue;
      if (!entrada.correspondeA(frase)) continue;

      for (final nombre in entrada.ejercicios) {
        if (!nombres.contains(nombre)) nombres.add(nombre);
      }
    }

    return nombres;
  }

  /// Todas las frases declaradas para un estilo, para poder mostrárselas al
  /// entrenador cuando una suya no encuentra nada.
  List<String> frasesDe(Estilo estilo) => [
    for (final entrada in entradas)
      if (entrada.estilo == estilo) entrada.frase,
  ];

  /// Nombres de ejercicio que el índice menciona, sin repetir.
  ///
  /// Sirve para comprobar que el índice no referencia ejercicios que no
  /// existen en la Biblioteca.
  Set<String> get ejerciciosReferenciados => {
    for (final entrada in entradas) ...entrada.ejercicios,
  };

  factory IndiceTerminos.desdeJson(Map<String, dynamic> json) {
    final lista = (json['entradas'] as List<dynamic>? ?? const [])
        .map((e) => EntradaTermino.desdeJson(e as Map<String, dynamic>))
        .toList();

    return IndiceTerminos(lista)..version = json['version'] as String? ?? '';
  }
}

/// Palabras que no distinguen un error de otro.
///
/// Solo artículos y preposiciones. **Las negaciones y los cuantificadores se
/// quedan**: `no gira la cadera` y `gira la cadera` son errores opuestos, y
/// `poco rolido` dice algo que `rolido` no dice.
const Set<String> palabrasVacias = {
  'el',
  'la',
  'los',
  'las',
  'un',
  'una',
  'unos',
  'unas',
  'de',
  'del',
  'en',
  'al',
  'a',
  'con',
  'y',
  'e',
  'o',
  'por',
  'para',
  'se',
  'su',
  'sus',
  'lo',
  'que',
  'hasta',
};

/// Palabras significativas de un texto, normalizadas.
///
/// Quita tildes y signos, pasa a minúsculas y descarta [palabrasVacias].
Set<String> palabrasSignificativas(String texto) {
  final normalizado = normalizarTexto(texto);
  return {
    for (final palabra in normalizado.split(RegExp(r'[^a-z0-9ñ]+')))
      if (palabra.isNotEmpty && !palabrasVacias.contains(palabra)) palabra,
  };
}

/// Minúsculas sin tildes, para que la grafía no decida la correspondencia.
String normalizarTexto(String texto) => texto
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .trim();
