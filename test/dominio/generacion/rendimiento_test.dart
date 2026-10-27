import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

import '../notacion/ayuda_pruebas.dart';

/// El caso mayor: Alto Rendimiento, diez sesiones, 55.000 m.
///
/// El plan fija la referencia en 200 ms. Generar debe sentirse instantáneo, o
/// el entrenador percibirá la app como lenta justo en la acción que justifica
/// la feature.
void main() {
  test('el caso mayor se genera por debajo de 200 ms', () {
    final generador = Generador(
      biblioteca: cargarBibliotecaReal(),
      indice: cargarIndiceReal(),
    );

    final peticion = PeticionGeneracion(
      categoria: Categoria.altoRendimiento,
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '400 Libre',
      faseAtr: FaseAtr.transformacion,
      componenteAcentuado: 'Umbral y ritmo competitivo',
      diasDisponibles: List.generate(5, (i) => DateTime(2026, 10, 5 + i)),
      longitudPiscina: 50,
      duracionSesionMinutos: 180,
    );

    // Una pasada previa para no medir la carga inicial.
    generador.generar(peticion);

    final reloj = Stopwatch()..start();
    final resultado = generador.generar(peticion);
    reloj.stop();

    expect(resultado, isA<MicrocicloGenerado>());
    expect((resultado as MicrocicloGenerado).plan.metros, 55000);
    expect(
      reloj.elapsedMilliseconds,
      lessThan(200),
      reason: 'Tardó ${reloj.elapsedMilliseconds} ms',
    );
  });
}
