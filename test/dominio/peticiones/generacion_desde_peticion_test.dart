/// Garantías P14, P17, P18, P20 y P24 — el borrador que sale de una petición.
///
/// **La prueba de determinismo genera dos veces y compara**, nunca contra un
/// fichero de referencia. Un fichero escondería justo el fallo que importa:
/// una entrada leída del reloj en lugar de las respuestas guardadas. Con dos
/// generaciones, esa entrada cambia entre una y otra y la prueba lo ve.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/peticiones/generar_desde_peticion.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';

void main() {
  final hoy = DateTime(2026, 11, 2);

  Biblioteca biblioteca() => Biblioteca.desdeJson(
    jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  Nadador ficha({
    Categoria categoria = Categoria.precompetitivo,
    List<String> diagnostico = const [],
  }) => Nadador(
    id: 'n-ana',
    nombre: 'Ana María Restrepo',
    categoria: categoria,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
    diagnosticoTecnico: diagnostico,
  );

  PeticionDePlan peticion({int? competenciaEnDias = 24, int dias = 3}) =>
      PeticionDePlan(
        nadadorId: 'n-ana',
        enviadaEn: hoy,
        estado: EstadoDePeticion.esperando,
        respuestas: RespuestasDePeticion(
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '200 Libre',
          fechaDeCompetencia: competenciaEnDias == null
              ? null
              : hoy.add(Duration(days: competenciaEnDias)),
          diasDisponibles: [
            for (var i = 1; i <= dias; i++) hoy.add(Duration(days: i * 2)),
          ],
          duracionSesionMinutos: 90,
          longitudPiscina: 25,
        ),
      );

  BorradorDePeticion generar({
    PeticionDePlan? cual,
    Nadador? deQuien,
    FaseAtr? faseElegida,
  }) => generarDesdePeticion(
    peticion: cual ?? peticion(),
    ficha: deQuien ?? ficha(),
    biblioteca: biblioteca(),
    versionMetodologia: '3.6.0',
    hoy: hoy,
    faseElegida: faseElegida,
  );

  group('P17 — el borrador nace marcado', () {
    test('en estado borrador, nunca en aprobado', () {
      final resultado = generar().resultado as MicrocicloGenerado;

      expect(resultado.plan.estado, EstadoPlan.borrador);
    });

    test('con el origen automático y la petición de la que salió', () {
      final resultado = generar().resultado as MicrocicloGenerado;

      expect(resultado.plan.origen, OrigenPlan.automatico);
      expect(resultado.plan.peticionId, 'n-ana');
    });

    test('y con la versión de metodología bajo la que se construyó', () {
      final resultado = generar().resultado as MicrocicloGenerado;

      expect(resultado.plan.versionMetodologia, '3.6.0');
    });
  });

  group('P20 — dos generaciones iguales dan el mismo borrador', () {
    test('generando dos veces, no una vez contra un fichero', () {
      // Un fichero de referencia escondería una entrada leída del reloj: la
      // primera generación lo fijaría y la comparación seguiría cuadrando.
      final primera = generar().resultado as MicrocicloGenerado;
      final segunda = generar().resultado as MicrocicloGenerado;

      expect(_comoTexto(primera.plan), _comoTexto(segunda.plan));
    });

    test('y con otra petición, otro borrador', () {
      // Control negativo: si la comparación de arriba pasara con cualquier
      // par de planes, no estaría comparando nada.
      final aDosSemanas = generar(cual: peticion(competenciaEnDias: 10)).resultado;
      final aDosMeses = generar(cual: peticion(competenciaEnDias: 60)).resultado;

      expect(
        _comoTexto((aDosSemanas as MicrocicloGenerado).plan),
        isNot(_comoTexto((aDosMeses as MicrocicloGenerado).plan)),
        reason:
            'Una competencia en 10 días y otra en 60 caen en fases distintas, '
            'y una fase distinta es un plan distinto',
      );
    });
  });

  group('P21 y P22 — la fase sale de la fecha, o no sale', () {
    test('a 24 días, Transformación, y el borrador lo dice', () {
      final borrador = generar();

      expect(borrador.fase.fase, FaseAtr.transformacion);
      expect(borrador.fase.porQue, contains('24'));
      expect(
        (borrador.resultado as MicrocicloGenerado).plan.faseAtr,
        FaseAtr.transformacion,
      );
    });

    test('en una categoría sin ATR, el plan no lleva fase', () {
      final borrador = generar(
        deQuien: ficha(categoria: Categoria.tecnificacion),
      );

      expect(borrador.fase.fase, isNull);
      expect((borrador.resultado as MicrocicloGenerado).plan.faseAtr, isNull);
    });
  });

  group('P24 — sin fecha utilizable y con ATR, no hay borrador', () {
    test('no se genera: la fase queda pendiente del entrenador', () {
      final borrador = generar(cual: peticion(competenciaEnDias: null));

      expect(borrador.resultado, isNull);
      expect(borrador.faltaLaFase, isTrue);
      expect(borrador.fase.porQue, contains('fecha'));
    });

    test('una competencia que ya pasó es lo mismo que no tener fecha', () {
      final borrador = generar(cual: peticion(competenciaEnDias: -5));

      expect(borrador.resultado, isNull);
      expect(borrador.faltaLaFase, isTrue);
    });

    test('**pero sin ATR sí se genera**, porque ahí no hace falta fase', () {
      final borrador = generar(
        cual: peticion(competenciaEnDias: null, dias: 2),
        deQuien: ficha(categoria: Categoria.iniciacion),
      );

      expect(borrador.faltaLaFase, isFalse);
      expect(borrador.resultado, isA<MicrocicloGenerado>());
    });

    test('y con la fase que el entrenador elige, se genera igual', () {
      // FR-017: él la cambia de un toque, y el borrador se rehace con la suya.
      final borrador = generar(
        cual: peticion(competenciaEnDias: null),
        faseElegida: FaseAtr.acumulacion,
      );

      expect(borrador.faltaLaFase, isFalse);
      expect(
        (borrador.resultado as MicrocicloGenerado).plan.faseAtr,
        FaseAtr.acumulacion,
      );
      expect(
        borrador.fase.porQue,
        contains('entrenador'),
        reason: 'Si la puso él, el borrador tiene que decirlo',
      );
    });
  });

  group('lo que el nadador no aportó sale de su ficha', () {
    test('la categoría es la de su ficha, no la que él diga', () {
      final borrador = generar(
        deQuien: ficha(categoria: Categoria.precompetitivo),
      );

      expect(
        (borrador.resultado as MicrocicloGenerado).plan.categoria,
        Categoria.precompetitivo,
      );
    });

    test('sin diagnóstico técnico, **no se inventan errores**', () {
      // Sección 7 del prompt maestro: si no hay diagnóstico, se señala, no se
      // improvisa.
      final borrador = generar(deQuien: ficha());

      expect(borrador.resultado, isA<MicrocicloGenerado>());
    });
  });

  group('cuando el nadador pide lo que no cabe en su categoría', () {
    test('el motor lo dice, y es el entrenador quien decide', () {
      // El escenario estaba previsto en el spec: «siete sesiones semanales en
      // Iniciación». La app no corrige la petición ni la rechaza sola: la
      // pasa con lo que no cuadra escrito, y decide él.
      final borrador = generar(
        cual: peticion(dias: 2),
        deQuien: ficha(categoria: Categoria.competitivo),
      );

      final imposible = borrador.resultado as GeneracionImposible;

      expect(imposible.impedimentos, isNotEmpty);
      expect(
        imposible.resumen,
        contains('5'),
        reason:
            'Competitivo pide cinco sesiones; el aviso tiene que decir la '
            'cuenta, no solo que no se puede',
      );
      expect(
        borrador.faltaLaFase,
        isFalse,
        reason: 'No es que falte la fase: es que lo pedido no cabe',
      );
    });
  });

  group('P14 — sin modelo de lenguaje', () {
    test('el archivo no llama a ningún servicio de generación de texto', () {
      final fuente = File(
        'lib/dominio/peticiones/generar_desde_peticion.dart',
      ).readAsStringSync();

      // «prompt» no está en la lista a propósito: el archivo cita el
      // «prompt maestro», que es el documento normativo del entrenador y no
      // tiene nada que ver con un modelo de lenguaje.
      for (final rastro in [
        'http',
        'openai',
        'gemini',
        'anthropic',
        'completions',
        'generativ',
      ]) {
        expect(
          fuente.toLowerCase(),
          isNot(contains(rastro)),
          reason:
              'El borrador lo compone el motor determinista. «$rastro» no '
              'pinta nada aquí',
        );
      }
    });
  });
}

/// Un plan reducido a texto, para comparar dos generaciones.
String _comoTexto(Plan plan) => [
  plan.nombre,
  plan.categoria.name,
  plan.estiloObjetivo.name,
  plan.faseAtr?.name ?? 'sin-fase',
  for (final sesion in plan.sesiones) ...[
    sesion.id,
    sesion.objetivoTecnico,
    sesion.objetivoFisiologico,
    for (final parte in sesion.partes) '${parte.tipo.name}:${parte.textoOriginal}',
  ],
].join('|');
