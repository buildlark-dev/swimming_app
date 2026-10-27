import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/auditoria/criterio.dart';
import 'package:natacion_app/dominio/entidades/ciclo_vida_plan.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';

import '../notacion/ayuda_pruebas.dart';

/// Historias US2 (revisar y ajustar) y US4 (aprobar lo generado).
void main() {
  late Generador generador;

  setUpAll(() {
    generador = Generador(
      biblioteca: cargarBibliotecaReal(),
      indice: cargarIndiceReal(),
    );
  });

  PeticionGeneracion peticion() => PeticionGeneracion(
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '100 Libre',
    faseAtr: FaseAtr.acumulacion,
    componenteAcentuado: 'Técnica de eficiencia',
    diasDisponibles: [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 7),
      DateTime(2026, 10, 9),
    ],
    longitudPiscina: 25,
    duracionSesionMinutos: 120,
  );

  Plan generado() => (generador.generar(peticion()) as MicrocicloGenerado).plan;

  group('US2: el editor recibe lo generado', () {
    test('abre la primera sesión del microciclo', () {
      final estado = EstadoEditor(biblioteca: cargarBibliotecaReal());
      final plan = generado();

      estado.abrirGenerado(plan);

      expect(estado.revisandoGenerado, isTrue);
      expect(estado.sesionesDelPlan, hasLength(3));
      expect(estado.sesion.metros, plan.sesiones.first.metros);
    });

    test('hereda la categoría del plan, para validar el volumen', () {
      final estado = EstadoEditor(biblioteca: cargarBibliotecaReal());
      estado.abrirGenerado(generado());

      expect(estado.categoria, Categoria.precompetitivo);
      expect(estado.volumen.dentroDelRango, isTrue);
    });

    test('se puede cambiar de sesión sin perder lo editado', () {
      final estado = EstadoEditor(biblioteca: cargarBibliotecaReal());
      estado.abrirGenerado(generado());

      estado.cambiarObjetivoTecnico('Ajuste mío de la primera sesión');
      estado.abrirSesion(1);
      estado.abrirSesion(0);

      expect(estado.sesion.objetivoTecnico, 'Ajuste mío de la primera sesión');
    });

    test('cambiar de sesión muestra otra sesión', () {
      final estado = EstadoEditor(biblioteca: cargarBibliotecaReal());
      estado.abrirGenerado(generado());

      final primera = estado.sesion.fecha;
      estado.abrirSesion(1);

      expect(estado.sesion.fecha, isNot(primera));
    });
  });

  group('US2: editar recalcula', () {
    test('cambiar una serie cambia los metros de la sesión', () {
      final estado = EstadoEditor(biblioteca: cargarBibliotecaReal());
      estado.abrirGenerado(generado());

      final antes = estado.sesion.metros;
      estado.escribirParte(TipoParte.cierre, '100 N');

      expect(estado.sesion.metros, isNot(antes));
    });

    test('una corrección manual sobre una serie generada prevalece', () {
      final estado = EstadoEditor(biblioteca: cargarBibliotecaReal());
      estado.abrirGenerado(generado());

      estado.escribirParte(TipoParte.inicial, '4x100 N');
      estado.corregirSerie(TipoParte.inicial, 0, 'distancia', valorEntero: 150);

      final serie = estado.sesion.parteDe(TipoParte.inicial).series.first;
      expect(serie.origen, OrigenDato.corregidoAMano);
      expect(serie.distancia, 150);
    });

    test('editar hasta romper el cumplimiento lo señala pero no lo impide', () {
      final estado = EstadoEditor(biblioteca: cargarBibliotecaReal());
      estado.abrirGenerado(generado());

      estado.escribirParte(TipoParte.inicial, '100 N');
      estado.escribirParte(TipoParte.central, '');
      estado.escribirParte(TipoParte.cierre, '');

      expect(
        estado.volumen.dentroDelRango,
        isFalse,
        reason: 'La app lo señala',
      );
      expect(
        estado.sesion.metros,
        100,
        reason: 'Pero no le impide hacerlo: él decide',
      );
    });
  });

  group('US2: el origen sobrevive a la edición', () {
    test('un plan generado y editado sigue siendo automático', () async {
      final repositorio = RepositorioPlanesMemoria();
      final plan = generado();

      final id = await repositorio.guardarBorrador(plan);
      final recuperado = await repositorio.obtener(id);

      expect(recuperado!.origen, OrigenPlan.automatico);
    });

    test('tampoco lo pierde al exportarse', () async {
      final repositorio = RepositorioPlanesMemoria();
      final id = await repositorio.guardarBorrador(generado());

      final exportado = await repositorio.exportar(id);

      expect(exportado['origen'], 'automatico');
    });
  });

  group('US4: la puerta de aprobación no se relaja', () {
    late Auditoria auditoria;
    late CicloVidaPlan ciclo;

    setUp(() {
      auditoria = Auditoria();
      ciclo = CicloVidaPlan(
        auditoria: auditoria,
        versionMetodologia: '3.4.1',
        ahora: () => DateTime(2026, 9, 29),
      );
    });

    test('un plan generado nace en borrador y marcado', () {
      final plan = generado();

      expect(plan.estado, EstadoPlan.borrador);
      expect(plan.origen, OrigenPlan.automatico);
    });

    test('se evalúan los once criterios, como en un plan manual', () {
      final resultado = auditoria.evaluar(generado());

      expect(resultado.criterios, hasLength(11));
      expect(
        resultado.criterios.where((c) => c.severidad == Severidad.bloqueante),
        hasLength(4),
      );
    });

    test('un plan generado limpio se aprueba', () {
      final plan = generado();
      final resultado = ciclo.aprobar(plan);

      expect(
        resultado,
        isA<TransicionHecha>(),
        reason: auditoria
            .impedimentosPara(plan)
            .map((i) => i.toString())
            .join('\n'),
      );
    });

    test('al aprobar estampa versión y fecha, y conserva el origen', () {
      final aprobado = (ciclo.aprobar(generado()) as TransicionHecha).plan;

      expect(aprobado.estado, EstadoPlan.aprobado);
      expect(aprobado.versionMetodologia, '3.4.1');
      expect(aprobado.fechaAprobacion, DateTime(2026, 9, 29));
      expect(aprobado.origen, OrigenPlan.automatico);
    });

    test('roto un criterio bloqueante, no se aprueba', () {
      final plan = generado();

      // Se le quita la zona a una serie: C08 es bloqueante.
      final sesion = plan.sesiones.first;
      final parte = sesion.parteDe(TipoParte.inicial);
      final sinZona = parte.series
          .map(
            (s) => Serie(
              repeticiones: s.repeticiones,
              distancia: s.distancia,
              estilo: s.estilo,
              ejercicio: s.ejercicio,
            ),
          )
          .toList();

      final roto = plan.copiarCon(
        sesiones: [
          sesion.conParte(parte.copiarCon(series: sinZona)),
          ...plan.sesiones.skip(1),
        ],
      );

      expect(auditoria.puedeAprobarse(roto), isFalse);
    });

    test('un plan generado aprobado ya no se puede volver a aprobar', () {
      final aprobado = (ciclo.aprobar(generado()) as TransicionHecha).plan;

      expect(auditoria.puedeAprobarse(aprobado), isFalse);
    });

    test('una versión nueva de un plan generado sigue siendo generada', () {
      final aprobado = (ciclo.aprobar(generado()) as TransicionHecha).plan;

      expect(ciclo.crearVersionDesde(aprobado).origen, OrigenPlan.automatico);
    });
  });

  group('US4: la instantánea de auditoría se guarda', () {
    test('un plan generado aprobado guarda su auditoría', () async {
      final repositorio = RepositorioPlanesMemoria();
      final plan = generado().copiarCon(id: 'plan-generado');

      final auditoria = Auditoria().evaluar(plan);
      await repositorio.guardarAprobado(
        plan.copiarCon(estado: EstadoPlan.aprobado),
        {
          'criterios': [
            for (final criterio in auditoria.criterios)
              {'id': criterio.id, 'cumple': criterio.cumple},
          ],
        },
      );

      final guardada = repositorio.auditoriaDe('plan-generado');
      expect(guardada, isNotNull);
      expect((guardada!['criterios'] as List<dynamic>), hasLength(11));
    });
  });
}
