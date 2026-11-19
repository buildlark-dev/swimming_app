/// Los cuatro estados de una lectura, y que no se puedan confundir.
///
/// El cerrojo del tercer defecto: un `null` que significaba a la vez «todavía
/// no ha llegado» y «no hay», y una pantalla que elegía el significado más
/// contundente de los dos y se lo decía a la nadadora durante veinte segundos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/lectura/lectura.dart';

void main() {
  test('cargando no es lo mismo que no hay', () {
    const cargando = Cargando<int>();
    const noHay = NoHay<int>();

    expect(cargando.cargando, isTrue);
    expect(noHay.cargando, isFalse);
    expect(
      cargando.valor,
      isNull,
      reason: 'las dos dan nulo, y por eso un nulo no podía distinguirlas',
    );
    expect(noHay.valor, isNull);
    expect(cargando, isNot(isA<NoHay<int>>()));
  });

  test('hay trae el valor', () {
    const lectura = Hay<int>(7);

    expect(lectura.valor, 7);
    expect(lectura.cargando, isFalse);
  });

  test('no se pudo leer trae un motivo, y no es una ausencia', () {
    const lectura = NoSePudo<int>('el servidor no contestó');

    expect(lectura.valor, isNull);
    expect(lectura.cargando, isFalse);
    expect(lectura.motivo, 'el servidor no contestó');
    expect(
      lectura,
      isNot(isA<NoHay<int>>()),
      reason:
          'un fallo y una ausencia se le veían igual a la nadadora. Con el '
          'nulo no había manera de decir «no lo sé»',
    );
  });

  test('los cuatro casos son exhaustivos al usarlos', () {
    // **Esto es lo que un `bool cargando` al lado de un nulo no da.** El
    // `switch` no compila si falta un caso, así que una pantalla no puede
    // atender tres y olvidarse del cuarto, que es exactamente como nació el
    // defecto.
    String comoSeCuenta(Lectura<String> lectura) => switch (lectura) {
      Cargando() => 'todavía buscando',
      Hay(:final valor) => 'hay: $valor',
      NoHay() => 'no hay',
      NoSePudo(:final motivo) => 'no se pudo: $motivo',
    };

    expect(comoSeCuenta(const Cargando()), 'todavía buscando');
    expect(comoSeCuenta(const Hay('plan')), 'hay: plan');
    expect(comoSeCuenta(const NoHay()), 'no hay');
    expect(comoSeCuenta(const NoSePudo('sin respuesta')),
        'no se pudo: sin respuesta');
  });

  test('no trae palabras para el nadador', () {
    // Las frases son de la pantalla. Si este archivo empezara a traerlas, dos
    // sitios dirían lo mismo y acabarían diciéndolo distinto.
    const motivo = 'lo que sea que pasara';
    expect(const NoSePudo<int>(motivo).motivo, motivo);
  });
}
