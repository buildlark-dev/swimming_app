/// Lo que hace falta para montar las pantallas del macrociclo.
///
/// En un archivo aparte porque lo usan cuatro pruebas y porque montar estas
/// pantallas tiene bastante andamiaje —biblioteca real, tres repositorios,
/// una ficha— como para no escribirlo cuatro veces.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/macrociclo/derivar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/ui/macrociclo/estructura.dart';
import 'package:natacion_app/ui/macrociclo/revisar_macrociclo.dart';
import 'package:natacion_app/ui/tema/tema.dart';

/// Hoy, fijo. Una prueba que depende del día real se pone roja sola: pasó en
/// la feature 007 con cuatro pruebas del HUB.
final DateTime hoyDePrueba = DateTime(2026, 11, 4);

final DateTime competenciaDePrueba = hoyDePrueba.add(
  const Duration(days: 98),
);

Biblioteca bibliotecaReal() => Biblioteca.desdeJson(
  jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Una ficha completa, con lo que el entrenador ya observó.
const Nadador fichaCompleta = Nadador(
  id: 'n-ana',
  nombre: 'Ana María Restrepo',
  categoria: Categoria.precompetitivo,
  estiloObjetivo: Estilo.libre,
  pruebaObjetivo: '200 Libre',
  diagnosticoTecnico: ['pierde el agarre al fatigarse'],
);

/// Los tres repositorios, en memoria y sembrables.
class RepositoriosDelMacrociclo {
  RepositoriosDelMacrociclo();

  final planes = RepositorioPlanesMemoria();
  final sesiones = RepositorioSesionesMemoria();
  final macrociclos = RepositorioMacrociclosMemoria();
  final asignaciones = RepositorioAsignacionesMemoria();
}

/// Monta la pantalla de estructura.
Widget montarEstructura({
  required RepositoriosDelMacrociclo repos,
  Nadador ficha = fichaCompleta,
  void Function(MacrocicloGuardado)? alConfirmar,
}) => MaterialApp(
  theme: Tema.claro(),
  home: PantallaEstructura(
    ficha: ficha,
    biblioteca: bibliotecaReal(),
    versionMetodologia: '3.6.0',
    hoy: hoyDePrueba,
    planes: repos.planes,
    sesiones: repos.sesiones,
    macrociclos: repos.macrociclos,
    alConfirmar: alConfirmar ?? (_) {},
  ),
);

/// La estructura ya confirmada, para montar la revisión sin pasar por la
/// pantalla anterior.
EstructuraConfirmada estructuraDePrueba({
  Categoria categoria = Categoria.precompetitivo,
  List<int> dias = const [1, 3, 5],
}) {
  final propuesto = esqueletoParaMacrociclo(
    fechaDeCompetencia: competenciaDePrueba,
    hoy: hoyDePrueba,
    categoria: categoria,
  );

  return EstructuraConfirmada(
    modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
    modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
    bloques: propuesto.bloques,
    confirmadaEn: hoyDePrueba,
    diasPorSemana: dias,
    duracionSesionMinutos: 90,
    longitudPiscina: 25,
  );
}

/// Deriva y guarda un macrociclo completo, como si él ya hubiera confirmado.
Future<MacrocicloGuardado> macrocicloGuardado(
  RepositoriosDelMacrociclo repos, {
  Nadador ficha = fichaCompleta,
}) async {
  final derivado = derivarMacrociclo(
    estructura: estructuraDePrueba(),
    ficha: ficha,
    biblioteca: bibliotecaReal(),
    versionMetodologia: '3.6.0',
    nombre: 'Hacia el Departamental',
    fechaDeCompetencia: competenciaDePrueba,
  );

  if (derivado is DerivacionImposible) {
    fail('no se pudo derivar: ${derivado.enQueBloque}');
  }

  return guardarElMacrociclo(
    derivado: derivado as MacrocicloDerivado,
    planes: repos.planes,
    sesiones: repos.sesiones,
    macrociclos: repos.macrociclos,
  );
}

/// Monta la pantalla de revisión con un macrociclo ya guardado.
Widget montarRevision({
  required RepositoriosDelMacrociclo repos,
  required MacrocicloGuardado guardado,
  VoidCallback? alEntregar,
}) => MaterialApp(
  theme: Tema.claro(),
  home: PantallaRevisarMacrociclo(
    guardado: guardado,
    hoy: hoyDePrueba,
    planes: repos.planes,
    asignaciones: repos.asignaciones,
    macrociclos: repos.macrociclos,
    alEntregar: alEntregar,
  ),
);

/// Una superficie alta, para que el `ListView` construya la página entera.
///
/// **No es trampa y conviene decir por qué.** Estas pruebas miden
/// comportamiento: que un bloque se pueda editar, que la razón cambie, que el
/// botón siga activo. En la ventana de 800×600 que `flutter_test` da por
/// omisión, el `ListView` no construye lo que queda debajo del pliegue, y la
/// prueba fallaría por maquetación en lugar de por la regla que vigila.
///
/// Que la pantalla **quepa** en un teléfono con la letra al 200% es otra
/// pregunta, y tiene su propio sitio: el banco de la feature 005, en
/// `test/ui/tema/ayuda_pantallas.dart`, que la mide a tamaño de teléfono.
void conPantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Elige la competencia por semanas, que es el camino principal.
///
/// Catorce semanas: la cifra que la sección 12 asocia al rendimiento máximo y
/// la del macrociclo real del entrenador. Da los tres bloques.
Future<void> elegirLaFecha(WidgetTester tester, {int semanas = 14}) async {
  await tester.ensureVisible(find.byKey(Key('competencia-$semanas')));
  await tester.tap(find.byKey(Key('competencia-$semanas')));
  await tester.pumpAndSettle();
}
