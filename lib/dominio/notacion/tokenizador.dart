/// Tokenizador de la notación del entrenador.
///
/// Convierte el texto libre en tokens conservando la posición exacta de cada
/// uno dentro del original, que es lo que permite resaltar después el
/// fragmento que no se supo interpretar (FR-036).
library;

enum TipoToken {
  /// Un número entero: `200`, `4`, `50`.
  numero,

  /// `x` o `×` entre repeticiones y distancia.
  por,

  /// `/` que precede al tiempo de salida.
  barra,

  /// Tiempo: `2'`, `1'30"`, `45"`.
  tiempo,

  /// `(` y `)`.
  abreParentesis,
  cierraParentesis,

  /// `+` que compone tramos dentro de una repetición.
  mas,

  /// `-` o `−` usado como separador de tramos.
  guion,

  /// `=` en construcciones como `75N=25 Prog`.
  igual,

  /// Palabra: implemento, modificador, estilo o nombre de ejercicio.
  palabra,

  /// Separador de series: salto de línea, `+` al inicio, numeración `1)`.
  separador,

  /// Cualquier otra cosa.
  desconocido,
}

class Token {
  const Token({
    required this.tipo,
    required this.texto,
    required this.inicio,
    required this.fin,
    this.valorNumerico,
    this.duracion,
  });

  final TipoToken tipo;
  final String texto;
  final int inicio;
  final int fin;
  final int? valorNumerico;
  final Duration? duracion;

  @override
  String toString() => '${tipo.name}("$texto")@$inicio';
}

class Tokenizador {
  /// Divide el texto en tokens. Nunca falla: lo que no reconoce se emite como
  /// [TipoToken.desconocido] para que el analizador decida qué hacer.
  List<Token> tokenizar(String texto) {
    final tokens = <Token>[];
    var i = 0;

    while (i < texto.length) {
      final caracter = texto[i];

      // Espacios: se saltan, pero un salto de línea separa series.
      if (caracter == '\n' || caracter == '\r') {
        tokens.add(
          Token(tipo: TipoToken.separador, texto: '\n', inicio: i, fin: i + 1),
        );
        i++;
        continue;
      }
      if (caracter.trim().isEmpty) {
        i++;
        continue;
      }

      // Números, posiblemente seguidos de una marca de tiempo.
      if (_esDigito(caracter)) {
        final inicio = i;
        while (i < texto.length && _esDigito(texto[i])) {
          i++;
        }
        final digitos = texto.substring(inicio, i);

        // ¿Es un tiempo? `2'`, `2'30"`, `45"`.
        if (i < texto.length && (texto[i] == "'" || texto[i] == '"')) {
          final marca = texto[i];
          i++;
          if (marca == "'") {
            // Puede seguir con segundos: `1'30"`.
            final trasComilla = i;
            var segundos = 0;
            while (i < texto.length && _esDigito(texto[i])) {
              i++;
            }
            if (i > trasComilla) {
              segundos = int.parse(texto.substring(trasComilla, i));
              if (i < texto.length && texto[i] == '"') i++;
            }
            tokens.add(
              Token(
                tipo: TipoToken.tiempo,
                texto: texto.substring(inicio, i),
                inicio: inicio,
                fin: i,
                duracion: Duration(
                  minutes: int.parse(digitos),
                  seconds: segundos,
                ),
              ),
            );
          } else {
            tokens.add(
              Token(
                tipo: TipoToken.tiempo,
                texto: texto.substring(inicio, i),
                inicio: inicio,
                fin: i,
                duracion: Duration(seconds: int.parse(digitos)),
              ),
            );
          }
          continue;
        }

        // Numeración de serie: `1)` al inicio de una línea.
        if (i < texto.length && texto[i] == ')') {
          final esNumeracion = _soloEspaciosDesdeInicioDeLinea(texto, inicio);
          if (esNumeracion) {
            i++;
            tokens.add(
              Token(
                tipo: TipoToken.separador,
                texto: texto.substring(inicio, i),
                inicio: inicio,
                fin: i,
              ),
            );
            continue;
          }
        }

        tokens.add(
          Token(
            tipo: TipoToken.numero,
            texto: digitos,
            inicio: inicio,
            fin: i,
            valorNumerico: int.parse(digitos),
          ),
        );
        continue;
      }

      // Progresivo y regresivo: `1<4`, `1>4` ya se habrían leído como número;
      // aquí se captan los signos sueltos.
      if (caracter == '<' || caracter == '>') {
        tokens.add(
          Token(
            tipo: TipoToken.palabra,
            texto: caracter,
            inicio: i,
            fin: i + 1,
          ),
        );
        i++;
        continue;
      }

      const simples = <String, TipoToken>{
        '(': TipoToken.abreParentesis,
        ')': TipoToken.cierraParentesis,
        '+': TipoToken.mas,
        '-': TipoToken.guion,
        '−': TipoToken.guion,
        '–': TipoToken.guion,
        '=': TipoToken.igual,
        '/': TipoToken.barra,
        '^': TipoToken.palabra,
      };
      if (simples.containsKey(caracter)) {
        tokens.add(
          Token(
            tipo: simples[caracter]!,
            texto: caracter,
            inicio: i,
            fin: i + 1,
          ),
        );
        i++;
        continue;
      }

      // `x` o `×` entre número y número es multiplicación de serie.
      if ((caracter == 'x' || caracter == 'X' || caracter == '×') &&
          tokens.isNotEmpty &&
          tokens.last.tipo == TipoToken.numero) {
        tokens.add(
          Token(tipo: TipoToken.por, texto: caracter, inicio: i, fin: i + 1),
        );
        i++;
        continue;
      }

      // Palabra: letras, dígitos internos, puntos y acentos.
      if (_esLetra(caracter)) {
        final inicio = i;
        while (i < texto.length &&
            (_esLetra(texto[i]) ||
                _esDigito(texto[i]) ||
                texto[i] == '.' ||
                texto[i] == '/')) {
          i++;
        }
        tokens.add(
          Token(
            tipo: TipoToken.palabra,
            texto: texto.substring(inicio, i),
            inicio: inicio,
            fin: i,
          ),
        );
        continue;
      }

      // Puntuación que separa tareas dentro de una celda.
      if (caracter == ',' ||
          caracter == ';' ||
          caracter == '·' ||
          caracter == '→' ||
          caracter == '▸') {
        tokens.add(
          Token(
            tipo: TipoToken.separador,
            texto: caracter,
            inicio: i,
            fin: i + 1,
          ),
        );
        i++;
        continue;
      }

      tokens.add(
        Token(
          tipo: TipoToken.desconocido,
          texto: caracter,
          inicio: i,
          fin: i + 1,
        ),
      );
      i++;
    }

    return tokens;
  }

  static bool _esDigito(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  static bool _esLetra(String c) {
    final codigo = c.codeUnitAt(0);
    if (codigo >= 65 && codigo <= 90) return true; // A-Z
    if (codigo >= 97 && codigo <= 122) return true; // a-z
    // Acentos y eñe del castellano.
    return 'áéíóúüñÁÉÍÓÚÜÑ'.contains(c);
  }

  static bool _soloEspaciosDesdeInicioDeLinea(String texto, int posicion) {
    var i = posicion - 1;
    while (i >= 0) {
      final c = texto[i];
      if (c == '\n') return true;
      if (c.trim().isNotEmpty) return false;
      i--;
    }
    return true;
  }
}
