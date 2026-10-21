/// Los colores de la app.
///
/// **Este es el único archivo del proyecto autorizado a contener un literal de
/// color**, y `test/ui/tema/frontera_tema_test.dart` lo hace cumplir leyendo el
/// código fuente de `lib/`.
///
/// No es purismo. Un color escrito en una pantalla es un color que no se
/// adapta al modo oscuro, que nadie comprueba contra el contraste y que hay que
/// ir a buscar para cambiarlo. Con un solo sitio, cambiar la identidad de la
/// app es cambiar este archivo.
///
/// Decisión D1 de `specs/005-tema-visual/research.md`.
library;

import 'package:flutter/material.dart';

/// La identidad: azules marinos.
///
/// De aquí deriva Material el esquema completo, en claro y en oscuro. Partir de
/// una semilla y no de treinta colores escritos a mano es lo que hace que la
/// paleta sea armónica sin que nadie la afine a ojo.
abstract final class Paleta {
  /// El azul marino del que sale todo.
  static const Color marino = Color(0xFF13395E);

  /// Acento para lo que acompaña sin competir.
  static const Color marinoClaro = Color(0xFF3E7CA6);

  // --- Tonos de aviso -------------------------------------------------
  //
  // Cuatro, porque hoy la app solo tiene uno. De los cincuenta y cuatro usos
  // de color semántico, treinta y cuatro son de la familia de error: la app
  // pinta de rojo todo lo que pide atención, y un rojo que sale siempre deja
  // de significar nada.
  //
  // Decisión D5. El inventario completo está en research.md, D6.

  /// Algo que conviene saber. Sin urgencia y sin que nadie haya fallado.
  static const Color informativo = Color(0xFF1A6E8E);
  static const Color informativoOscuro = Color(0xFF7FC4DE);

  /// Algo salió bien. **Aquí va «guardado, se enviará cuando tengas
  /// internet»**: es una buena noticia, no una alarma.
  static const Color exito = Color(0xFF2E7D52);
  static const Color exitoOscuro = Color(0xFF7FC8A0);

  /// Algo que mirar, sin que nada se haya roto. Avisos de auditoría, modo
  /// local, y **el reporte de molestia**: visible para encontrarlo, nunca con
  /// cara de emergencia médica (principio IV).
  static const Color cuidado = Color(0xFF8A5A0B);
  static const Color cuidadoOscuro = Color(0xFFE0B072);

  /// Algo falló y hay que actuar. Solo dos sitios de la app lo son de verdad:
  /// no se pudo entrar, y no se pudo escribir en el dispositivo.
  static const Color error = Color(0xFFA3271F);
  static const Color errorOscuro = Color(0xFFF2B4AE);

  // --- Las siete zonas de intensidad -----------------------------------
  //
  // Rampa por **claridad**, no por tono (decisión D4).
  //
  // Una rampa por tono —azul, verde, amarillo, naranja, rojo— se convierte en
  // siete grises casi iguales para quien no distingue colores, que es alrededor
  // del 8% de los hombres. Entre un grupo de nadadores es cuestión de tiempo.
  //
  // Variando la claridad, la escala sobrevive al gris **y** al daltonismo, y
  // además el orden visual coincide con el de intensidad sin que nadie tenga
  // que aprendérselo: más intenso, más oscuro.
  //
  // El orden es el de la sección 9: A1, A2, A3, AT, Máx, Velocidad, Exp.

  static const List<Color> zonas = <Color>[
    // A1 era `#DCE9F2`, y se oscureció una pizca en la fase 5.
    //
    // Contra un blanco puro cumplía. Pero el fondo claro de la app no es
    // blanco: Material lo deriva de la semilla marina y sale `#F8F9FF`. Contra
    // ese fondo de verdad, A1 daba 1.177 y hacía falta 1.2, así que la zona más
    // suave se diluía en la página.
    //
    // Este valor es **el único que cumple las dos cosas a la vez**: 1.211 contra
    // el fondo, y 6.9 de salto en L* hasta A2, que necesita 6. Oscurecerla más
    // separaría mejor del fondo y juntaría demasiado con A2. El extremo claro de
    // la rampa va apretado entre esas dos exigencias, y conviene saberlo antes
    // de tocarlo.
    Color(0xFFD8E6F0), // A1
    Color(0xFFBBD4E6), // A2
    Color(0xFF93B8D4), // A3
    Color(0xFF6B9CC2), // AT
    Color(0xFF4A7FA8), // Máx
    Color(0xFF2E5F85), // Velocidad
    Color(0xFF17405E), // Exp
  ];

  static const List<Color> zonasOscuro = <Color>[
    Color(0xFF1C3347), // A1
    Color(0xFF26475F), // A2
    Color(0xFF335C78), // A3
    Color(0xFF427391), // AT
    Color(0xFF5A8CAA), // Máx
    Color(0xFF7CA8C2), // Velocidad
    Color(0xFFA4C6DA), // Exp
  ];

  // --- Los tres estados del plan ---------------------------------------
  //
  // `aprobado` NO puede verse como `publicado`. Aprobar no es entregar, y
  // confundirlos borraría la distinción que el principio IV protege.

  /// Todavía no es de nadie.
  static const Color borrador = Color(0xFF5F6B75);

  /// Firmado por el entrenador, pero no entregado.
  static const Color aprobado = Color(0xFF8A5A0B);

  /// Es el entrenamiento de alguien.
  static const Color publicado = Color(0xFF2E7D52);

  static const Color borradorOscuro = Color(0xFFA8B4BD);
  static const Color aprobadoOscuro = Color(0xFFE0B072);
  static const Color publicadoOscuro = Color(0xFF7FC8A0);
}
