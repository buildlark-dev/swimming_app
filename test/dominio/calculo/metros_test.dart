import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/calculo/calculo_sesion.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';

import '../notacion/ayuda_pruebas.dart';

/// Invariantes 1, 2 y 3 de `data-model.md`.
void main() {
  late Analizador analizador;

  setUpAll(() {
    analizador = crearAnalizador();
  });

  Sesion construir({
    String inicial = '',
    String central = '',
    String cierre = '',
    String objetivoTecnico = 'Objetivo técnico',
    String objetivoFisiologico = 'Objetivo fisiológico',
  }) {
    Parte armar(TipoParte tipo, String texto) {
      final resultado = analizador.analizar(texto);
      return Parte(
        tipo: tipo,
        textoOriginal: texto,
        series: resultado.series,
        fragmentosPendientes: resultado.pendientes,
      );
    }

    return Sesion(
      objetivoTecnico: objetivoTecnico,
      objetivoFisiologico: objetivoFisiologico,
      partes: [
        armar(TipoParte.inicial, inicial),
        armar(TipoParte.central, central),
        armar(TipoParte.cierre, cierre),
      ],
    );
  }

  group('metros de una serie', () {
    test('son repeticiones por distancia', () {
      const serie = Serie(repeticiones: 4, distancia: 100);
      expect(serie.metros, 400);
    });

    test('una serie sin repeticiones declaradas cuenta una vez', () {
      const serie = Serie(distancia: 200);
      expect(serie.repeticiones, 1);
      expect(serie.metros, 200);
    });

    test('8x50 son 400 m', () {
      expect(const Serie(repeticiones: 8, distancia: 50).metros, 400);
    });
  });

  group('metros de una parte', () {
    test('son la suma de sus series', () {
      const parte = Parte(
        tipo: TipoParte.central,
        series: [
          Serie(repeticiones: 4, distancia: 100),
          Serie(distancia: 200),
          Serie(repeticiones: 8, distancia: 50),
        ],
      );
      expect(parte.metros, 400 + 200 + 400);
    });

    test('una parte vacía suma cero', () {
      expect(const Parte(tipo: TipoParte.inicial).metros, 0);
    });
  });

  group('metros de una sesión', () {
    test('son la suma de las tres partes', () {
      final sesion = construir(
        inicial: '400 N',
        central: '8x100 N',
        cierre: '200 REC',
      );
      expect(sesion.metros, 400 + 800 + 200);
    });

    test('una sesión sin series suma cero', () {
      expect(construir().metros, 0);
    });
  });

  group('porcentaje de trabajo técnico', () {
    test('son los metros con ejercicio sobre los metros totales', () {
      final sesion = construir(
        inicial: '400 N',
        central: '400 VADEO',
        cierre: '200 N',
      );

      expect(sesion.metros, 1000);
      expect(sesion.metrosTecnicos, 400);
      expect(sesion.porcentajeTecnico, 40.0);
    });

    test('el nado completo no cuenta como técnico', () {
      final sesion = construir(inicial: '1000 N');
      expect(sesion.metrosTecnicos, 0);
      expect(sesion.porcentajeTecnico, 0);
    });

    test('una sesión solo de ejercicios da el 100% técnico', () {
      final sesion = construir(inicial: '200 VADEO', central: '200 PUÑOS');
      expect(sesion.porcentajeTecnico, 100.0);
    });

    test('una sesión vacía no divide por cero', () {
      expect(construir().porcentajeTecnico, 0);
    });

    test('una etiqueta de bloque técnico cuenta como técnica', () {
      final sesion = construir(inicial: '300 TEC L', central: '700 N');
      expect(sesion.metrosTecnicos, 300);
      expect(sesion.porcentajeTecnico, 30.0);
    });
  });

  group('reparto entre partes', () {
    test('calcula el porcentaje real de cada parte', () {
      final sesion = construir(
        inicial: '400 N',
        central: '500 N',
        cierre: '100 N',
      );

      expect(sesion.porcentajeDe(TipoParte.inicial), 40.0);
      expect(sesion.porcentajeDe(TipoParte.central), 50.0);
      expect(sesion.porcentajeDe(TipoParte.cierre), 10.0);
    });

    test('informa la desviación frente al 40/50/10 prescrito', () {
      final sesion = construir(
        inicial: '600 N',
        central: '300 N',
        cierre: '100 N',
      );

      final calculo = CalculoSesion(sesion);
      final inicial = calculo.repartoDePartes.first;

      expect(inicial.porcentajeReal, 60.0);
      expect(inicial.porcentajePrescrito, 40);
      expect(inicial.diferencia, 20.0);
    });
  });

  group('metros por zona y por estilo', () {
    test('las series sin zona se agrupan aparte, no se reparten', () {
      final sesion = construir(inicial: '400 N', central: '600 N');
      final calculo = CalculoSesion(sesion);

      expect(
        calculo.metrosSinZona,
        1000,
        reason: 'Nadie asignó zona: no se puede suponer cuál es',
      );
    });

    test('agrupa los metros por estilo cuando el estilo está declarado', () {
      final sesion = construir(inicial: '400 L', central: '600 E');
      final calculo = CalculoSesion(sesion);

      expect(calculo.metrosPorEstilo[Estilo.libre], 400);
      expect(calculo.metrosPorEstilo[Estilo.espalda], 600);
    });
  });

  group('volumen frente a la categoría', () {
    test('2.000 m están dentro de Precompetitivo', () {
      final sesion = construir(
        inicial: '800 N',
        central: '1000 N',
        cierre: '200 N',
      );
      final comprobacion = CalculoSesion(
        sesion,
      ).comprobarVolumen(Categoria.precompetitivo);

      expect(comprobacion.dentroDelRango, isTrue);
      expect(comprobacion.diferencia, 0);
    });

    test('2.600 m exceden Precompetitivo en 400 m', () {
      final sesion = construir(
        inicial: '1000 N',
        central: '1400 N',
        cierre: '200 N',
      );
      final comprobacion = CalculoSesion(
        sesion,
      ).comprobarVolumen(Categoria.precompetitivo);

      expect(comprobacion.dentroDelRango, isFalse);
      expect(comprobacion.diferencia, 400);
      expect(comprobacion.descripcion, contains('excede en 400 m'));
    });

    test('1.400 m se quedan 400 m cortos en Precompetitivo', () {
      final sesion = construir(
        inicial: '600 N',
        central: '600 N',
        cierre: '200 N',
      );
      final comprobacion = CalculoSesion(
        sesion,
      ).comprobarVolumen(Categoria.precompetitivo);

      expect(comprobacion.dentroDelRango, isFalse);
      expect(comprobacion.diferencia, -400);
      expect(comprobacion.descripcion, contains('faltan 400 m'));
    });

    test('los extremos exactos del rango son válidos', () {
      final minimo = construir(inicial: '1800 N');
      final maximo = construir(inicial: '2200 N');

      expect(
        CalculoSesion(
          minimo,
        ).comprobarVolumen(Categoria.precompetitivo).dentroDelRango,
        isTrue,
      );
      expect(
        CalculoSesion(
          maximo,
        ).comprobarVolumen(Categoria.precompetitivo).dentroDelRango,
        isTrue,
      );
    });
  });
}
