import 'dart:convert';
import 'dart:io';

import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';

/// Biblioteca real del proyecto, cargada desde el recurso empaquetado.
///
/// Las pruebas del analizador se hacen contra la biblioteca de verdad, no
/// contra una inventada: la regla de no invención solo se puede comprobar
/// frente a la fuente normativa.
Biblioteca cargarBibliotecaReal() {
  final json =
      jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
          as Map<String, dynamic>;
  return Biblioteca.desdeJson(json);
}

/// Índice de términos real, el mismo que empaqueta la app.
///
/// Las pruebas de generación lo usan para que lo que se prueba sea lo que el
/// entrenador va a ver. Con un índice inventado, una correspondencia que él
/// confirmó podría romperse sin que ninguna prueba se enterara.
IndiceTerminos cargarIndiceReal() {
  final json =
      jsonDecode(
            File(
              'assets/biblioteca/terminos_diagnostico.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return IndiceTerminos.desdeJson(json);
}

Analizador crearAnalizador() => Analizador(biblioteca: cargarBibliotecaReal());
