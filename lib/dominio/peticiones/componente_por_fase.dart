/// El componente acentuado, derivado de la fase.
///
/// El componente da nombre al microciclo y orienta la selección de ejercicios.
/// El motor lo exige no vacío y **comprueba que cuadre con la fase**: un
/// componente que apunta a velocidad en una fase que no le asigna volumen es
/// una contradicción, y `ValidacionPeticion` la rechaza.
///
/// Derivarlo *de* la fase hace que esa comprobación pase **por construcción**.
/// Es el mismo listón que el principio III pone a los planes generados: que
/// cumplan la auditoría porque están construidos así, no por casualidad.
///
/// Los textos salen de los objetivos que cada fase ya declara en
/// `FaseAtr.objetivos`; no se inventa vocabulario nuevo.
library;

import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

/// Qué acentúa la semana. **Función total**: siempre devuelve algo legible.
String componenteParaFase({
  required FaseAtr? fase,
  required Categoria categoria,
}) => switch (fase) {
  // Acumulación no asigna volumen a velocidad, así que su componente no la
  // nombra. No es estilo: es lo que el motor comprueba.
  FaseAtr.acumulacion => 'Base aeróbica y técnica',
  FaseAtr.transformacion => 'Umbral y ritmo competitivo',
  FaseAtr.realizacion => 'Afinación y ritmo de competencia',
  // Sin fase —Iniciación y Tecnificación, que no trabajan por fases ATR— el
  // acento lo pone la categoría, que es lo único que hay.
  null => _porCategoria(categoria),
};

String _porCategoria(Categoria categoria) => switch (categoria) {
  Categoria.iniciacion => 'Familiarización y técnica básica',
  Categoria.tecnificacion => 'Técnica y coordinación',
  // Una categoría con ATR que llega aquí sin fase es un caso que el motor
  // rechazaría después. Se devuelve algo legible igualmente, porque esta
  // función es total y quedarse sin respuesta sería peor que decirlo.
  _ => 'Trabajo general',
};
