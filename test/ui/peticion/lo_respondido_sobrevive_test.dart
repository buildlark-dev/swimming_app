/// Garantía P5 — lo respondido a medias sobrevive a cerrar la app.
///
/// La lista se contesta a pie de piscina, con el teléfono de un chico de nueve
/// años y la conexión que haya. Que una llamada entrante borre cinco respuestas
/// no es un detalle: es la diferencia entre pedir y no pedir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/ui/peticion/peticion_del_nadador.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayuda_peticion.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lo tocado sigue ahí al volver a abrir', (tester) async {
    final almacen = AlmacenPreferencias(cuentaId: 'u-ana');

    await montarPeticion(tester, almacen: almacen);

    // Cambia tres respuestas de las que venían propuestas.
    await tester.tap(find.byKey(const Key('estilo-espalda')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('duracion-120')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('piscina-50')));
    await tester.pumpAndSettle();

    // Y se vuelve a montar la pantalla, como si la app se hubiera cerrado.
    final peticiones = await montarPeticion(tester, almacen: almacen);

    await tester.tap(find.byKey(const Key('enviar-peticion')));
    await tester.pumpAndSettle();

    final enviadas = peticiones.enviadas.single;
    expect(enviadas.estiloObjetivo.nombre, 'Espalda');
    expect(enviadas.duracionSesionMinutos, 120);
    expect(enviadas.longitudPiscina, 50);
  });

  testWidgets('al mandarla, lo guardado se limpia', (tester) async {
    // Si no se limpiara, la siguiente petición empezaría con las respuestas de
    // la anterior, y quien pide dos cosas distintas pediría dos veces la
    // misma sin darse cuenta.
    final almacen = AlmacenPreferencias(cuentaId: 'u-ana');

    final peticiones = await montarPeticion(tester, almacen: almacen);

    await tester.tap(find.byKey(const Key('piscina-50')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enviar-peticion')));
    await tester.pumpAndSettle();

    expect(await almacen.leer(coleccionDeLoRespondido, 'n-ana'), isNull);
    expect(peticiones.enviadas.single.longitudPiscina, 50);
  });

  testWidgets('**control negativo**: sin almacén no se recuerda nada', (
    tester,
  ) async {
    // Para que la prueba de arriba no pase por casualidad: si el estado
    // sobreviviera por otro motivo, esta también lo haría.
    await montarPeticion(tester);

    await tester.tap(find.byKey(const Key('piscina-50')));
    await tester.pumpAndSettle();

    final peticiones = await montarPeticion(tester);

    await tester.tap(find.byKey(const Key('enviar-peticion')));
    await tester.pumpAndSettle();

    expect(peticiones.enviadas.single.longitudPiscina, 25);
  });
}
