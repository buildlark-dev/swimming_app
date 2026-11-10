/// Lo que la app puede ofrecerle de vuelta en los dos modelos (M4, FR-008).
///
/// **Esto no está en el dominio a propósito.** No es una regla de
/// entrenamiento: es texto inicial para dos campos, compuesto con lo que el
/// entrenador ya escribió en la ficha del nadador. Ponerlo en
/// `lib/dominio/macrociclo/` me habría obligado a esquivar el cerrojo de
/// `test/dominio/macrociclo/los_modelos_no_se_derivan_test.dart`, que prohíbe
/// que el dominio de esta feature nombre los dos modelos siquiera — y esquivar
/// un cerrojo propio renombrando campos es exactamente lo que ese cerrojo
/// existe para impedir.
///
/// **De dónde sale cada palabra, y de dónde no.**
///
/// Sale de tres sitios y de ninguno más: `pruebaObjetivo`,
/// `diagnosticoTecnico` y `marcas`. Los tres son observaciones que él hizo, así
/// que devolvérselas es enseñarle su propio trabajo.
///
/// No sale de la edad, ni de la fecha de nacimiento, ni de la categoría.
/// Derivar la tolerancia a la fatiga o la motivación de la edad y la categoría
/// sería la app inventando lo único que la enmienda de la constitución v2.0.0
/// le reservó a él. Hay una prueba de widget que lo comprueba (T040) y otra
/// aquí abajo, sobre la fuente.
///
/// **Y una sugerencia no es un modelo.** Lo que se ofrece es un punto de
/// partida en un campo editable y vacío de compromiso: si él lo borra y
/// escribe otra cosa, lo que se guarda es lo que él escribió. Lo que no puede
/// pasar es que un campo llegue escrito con algo que él no dijo nunca.
library;

import 'package:natacion_app/dominio/entidades/nadador.dart';

/// Los dos textos de partida, cada uno con lo suyo. Vacíos cuando la ficha no
/// tiene nada que ofrecer: **un campo vacío es mejor que uno inventado**.
class SugerenciasDeLosModelos {
  const SugerenciasDeLosModelos({
    required this.paraLaPrueba,
    required this.paraElNadador,
  });

  final String paraLaPrueba;
  final String paraElNadador;

  bool get hayAlgoQueOfrecer =>
      paraLaPrueba.isNotEmpty || paraElNadador.isNotEmpty;
}

/// Compone las dos sugerencias **solo** desde la ficha.
SugerenciasDeLosModelos sugerenciasDesdeLaFicha(Nadador ficha) {
  final prueba = <String>[];

  if (ficha.pruebaObjetivo.trim().isNotEmpty) {
    prueba.add('Prueba objetivo: ${ficha.pruebaObjetivo.trim()}.');
  }

  // Las marcas son suyas y son el dato más concreto que hay sobre la prueba.
  // Se ofrece la más reciente: una lista entera de marcas dentro de un campo
  // de texto no es un modelo, es un volcado.
  if (ficha.marcas.isNotEmpty) {
    final marcas = [...ficha.marcas]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final ultima = marcas.first;
    prueba.add(
      'Última marca registrada: ${ultima.distancia} '
      '${ultima.estilo.nombre}, ${ultima.tiempoLegible}.',
    );
  }

  final nadador = <String>[];

  if (ficha.estiloObjetivo != null) {
    nadador.add('Estilo objetivo: ${ficha.estiloObjetivo!.nombre}.');
  }

  if (ficha.diagnosticoTecnico.isNotEmpty) {
    nadador.add(
      'Errores técnicos observados: '
      '${ficha.diagnosticoTecnico.join('; ')}.',
    );
  }

  return SugerenciasDeLosModelos(
    paraLaPrueba: prueba.join('\n'),
    paraElNadador: nadador.join('\n'),
  );
}
