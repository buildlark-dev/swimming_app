/// Generador determinista de microciclos.
///
/// Contrato: `specs/002-generador-microciclos/contracts/generacion.md`.
///
/// Compone el plan a partir de las reglas ya codificadas, de arriba hacia
/// abajo: volumen, zonas, técnica, estilos, partes y finalmente ejercicios.
/// El cumplimiento sale del reparto, no de comprobar al final.
///
/// **Sin azar.** Ninguna decisión depende de una semilla, del reloj ni del
/// orden de un mapa. Misma petición, mismo plan.
library;

import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/ejercicio.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/generacion/compositor_sesion.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/presupuesto.dart';
import 'package:natacion_app/dominio/generacion/reparto.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/generacion/ritmos.dart';
import 'package:natacion_app/dominio/generacion/selector_ejercicios.dart';
import 'package:natacion_app/dominio/generacion/validacion_peticion.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/dominio/notacion/renderizador.dart';

class Generador {
  Generador({required this.biblioteca, IndiceTerminos? indice})
      : indice = indice ?? IndiceTerminos.vacio(),
        _selector = SelectorEjercicios(
          biblioteca,
          indice: indice ?? IndiceTerminos.vacio(),
        );

  final Biblioteca biblioteca;

  /// Vocabulario de diagnóstico del entrenador. Sin él, un diagnóstico se
  /// reporta como vacío en lugar de resolverse con un ejercicio aproximado.
  final IndiceTerminos indice;

  final SelectorEjercicios _selector;

  static const ValidacionPeticion _validacion = ValidacionPeticion();
  static const Renderizador _renderizador = Renderizador();

  /// Genera el microciclo, o explica por qué no se puede.
  ///
  /// Valida **antes** de repartir, para que ningún plan a medias llegue a
  /// existir.
  ResultadoGeneracion generar(PeticionGeneracion peticion) {
    final impedimentos = _validacion.validar(peticion);
    if (impedimentos.isNotEmpty) {
      return GeneracionImposible(impedimentos);
    }

    final presupuesto = calcularPresupuesto(peticion);
    final supuestos = <Supuesto>[];
    final vacios = <VacioDeBiblioteca>[];
    final avisos = <String>[];

    // La comprobación de duración se apoya en una estimación nuestra, no en
    // una regla del entrenador: queda declarada dentro del plan.
    supuestos.add(const Supuesto(
      descripcion: 'Ritmo medio estimado por categoría',
      motivo: descripcionDelSupuesto,
    ));

    for (final lesion in peticion.lesiones) {
      avisos.add(
        'Lesión o limitación declarada: «$lesion». El plan NO se adaptó por '
        'ella: la Biblioteca declara qué corrige cada ejercicio, no qué está '
        'contraindicado.',
      );
    }

    final microciclo = Microciclo(
      id: 'mc-1',
      nombre: peticion.componenteAcentuado.trim(),
      orden: 1,
      objetivo: _objetivoDelMicrociclo(peticion),
    );

    final sesiones = <Sesion>[];
    for (var i = 0; i < presupuesto.sesiones; i++) {
      final resultado = _componerSesion(peticion, presupuesto, i, microciclo.id);
      sesiones.add(resultado.sesion);
      vacios.addAll(resultado.vacios);
    }

    final plan = Plan(
      nombre: 'Microciclo: ${microciclo.nombre}',
      categoria: peticion.categoria,
      estiloObjetivo: peticion.estiloObjetivo,
      pruebaObjetivo: peticion.pruebaObjetivo,
      longitudPiscina: peticion.longitudPiscina,
      fechaInicio: peticion.diasEfectivos.isEmpty
          ? null
          : peticion.diasEfectivos.first,
      fechaFin:
          peticion.diasEfectivos.isEmpty ? null : peticion.diasEfectivos.last,
      faseAtr: peticion.faseAtr,
      microciclos: [microciclo],
      sesiones: sesiones,
      origen: OrigenPlan.automatico,
    );

    return MicrocicloGenerado(
      plan: plan,
      supuestos: supuestos,
      vaciosDeBiblioteca: _sinRepetir(vacios),
      avisos: avisos,
    );
  }

  _SesionCompuesta _componerSesion(
    PeticionGeneracion peticion,
    Presupuesto presupuesto,
    int indice,
    String microcicloId,
  ) {
    final unidad = peticion.longitudPiscina;
    final volumen = presupuesto.metrosPorSesion[indice];
    final zonas = presupuesto.zonasDeSesion(indice);

    final estilo = _estiloDeSesion(peticion, presupuesto, indice);

    final bloques = componerSesion(
      volumenSesion: volumen,
      zonasDeSesion: zonas,
      unidad: unidad,
    );

    // Presupuesto técnico de esta sesión, proporcional al total.
    final tecnicosSesion = cuantizar(
      (presupuesto.metrosTecnicos / presupuesto.sesiones).round(),
      unidad,
    );

    final vacios = <VacioDeBiblioteca>[];
    var tecnicosColocados = 0;

    final partes = <TipoParte, List<Serie>>{
      TipoParte.inicial: [],
      TipoParte.central: [],
      TipoParte.cierre: [],
    };

    for (final bloque in bloques) {
      final admiteTecnica =
          bloque.tipo == TipoParte.inicial || bloque.esPreSet;
      final faltanTecnicos = tecnicosSesion - tecnicosColocados;

      final seleccion = admiteTecnica && faltanTecnicos > 0
          ? _selector.elegir(
              estilo: estilo,
              diagnostico: peticion.diagnosticoTecnico,
              cuantos: 2,
              desplazamiento: indice * 2 + (bloque.esPreSet ? 1 : 0),
            )
          : const SeleccionEjercicios(ejercicios: []);

      vacios.addAll(seleccion.vacios);

      final series = _seriesDeBloque(
        bloque: bloque,
        estilo: estilo,
        complementario: _complementario(peticion),
        porcentajeComplementario: _porcentajeComplementario(peticion),
        unidad: unidad,
        ejercicios: seleccion.ejercicios,
        metrosTecnicosPendientes: faltanTecnicos,
        esCierre: bloque.tipo == TipoParte.cierre,
      );

      for (final serie in series) {
        if (serie.esTecnica) tecnicosColocados += serie.metros;
      }

      partes[bloque.tipo]!.addAll(series);
    }

    final sesion = Sesion(
      microcicloId: microcicloId,
      fecha: indice < peticion.diasEfectivos.length
          ? peticion.diasEfectivos[indice]
          : null,
      objetivoTecnico: _objetivoTecnico(peticion, estilo),
      objetivoFisiologico: _objetivoFisiologico(peticion, zonas),
      rpePrevisto: _rpePrevisto(zonas),
      variablesMonitoreo: const [
        'Cuenta de brazadas',
        'Splits parejos',
        'Técnica bajo fatiga',
      ],
      partes: [
        for (final tipo in TipoParte.values)
          Parte(
            tipo: tipo,
            textoOriginal: _renderizador.series(partes[tipo]!),
            series: partes[tipo]!,
          ),
      ],
    );

    return _SesionCompuesta(sesion, vacios);
  }

  /// Convierte los metros por zona de un bloque en series concretas.
  ///
  /// **El reparto de estilos ocurre dentro de la sesión, no entre sesiones.**
  /// Asignar un estilo a cada sesión completa hacía imposible el 80-85% que la
  /// sección 13 prescribe: el 82% de tres sesiones no es un número entero de
  /// sesiones, y salía el 100% del estilo objetivo. Sus propias sesiones
  /// mezclan los dos estilos en la misma serie central.
  List<Serie> _seriesDeBloque({
    required ReparteParte bloque,
    required Estilo estilo,
    required Estilo? complementario,
    required int porcentajeComplementario,
    required int unidad,
    required List<Ejercicio> ejercicios,
    required int metrosTecnicosPendientes,
    required bool esCierre,
  }) {
    final series = <Serie>[];
    var tecnicosRestantes = metrosTecnicosPendientes;
    var indiceEjercicio = 0;

    for (final zona in ordenDeZonas) {
      final metros = bloque.metrosPorZona[zona] ?? 0;
      if (metros <= 0) continue;

      // Parte de los metros de esta zona van al estilo complementario.
      final paraComplementario = complementario == null
          ? 0
          : cuantizar((metros * porcentajeComplementario / 100).round(), unidad);
      final paraObjetivo = metros - paraComplementario;

      for (final tramo in [
        (estilo, paraObjetivo),
        if (paraComplementario > 0) (complementario!, paraComplementario),
      ]) {
        final estiloTramo = tramo.$1;
        final metrosTramo = tramo.$2;
        if (metrosTramo <= 0) continue;

        // Los metros técnicos se cubren con ejercicios de la Biblioteca; el
        // resto es nado completo.
        final tecnicos = ejercicios.isEmpty
            ? 0
            : (tecnicosRestantes < metrosTramo
                ? tecnicosRestantes
                : metrosTramo);

        if (tecnicos > 0) {
          final ejercicio = ejercicios[indiceEjercicio % ejercicios.length];
          indiceEjercicio++;
          tecnicosRestantes -= tecnicos;

          series.add(_serie(
            metros: tecnicos,
            unidad: unidad,
            zona: zona,
            estilo: estiloTramo,
            ejercicio: ejercicio,
          ));
        }

        final restantes = metrosTramo - tecnicos;
        if (restantes > 0) {
          series.add(_serie(
            metros: restantes,
            unidad: unidad,
            zona: zona,
            estilo: estiloTramo,
            modificadores:
                esCierre ? const [Modificador.recuperacion] : const [],
          ));
        }
      }
    }

    return series;
  }

  /// Convierte unos metros en una serie con repeticiones razonables.
  ///
  /// Prefiere repeticiones de distancias habituales, en orden descendente, sin
  /// azar: la primera que divide exacto.
  Serie _serie({
    required int metros,
    required int unidad,
    required Zona zona,
    required Estilo estilo,
    Ejercicio? ejercicio,
    List<Modificador> modificadores = const [],
  }) {
    const distanciasHabituales = [400, 200, 100, 50, 25];

    for (final distancia in distanciasHabituales) {
      if (distancia < unidad) continue;
      if (distancia % unidad != 0) continue;
      if (metros % distancia != 0) continue;

      final repeticiones = metros ~/ distancia;
      if (repeticiones > 12) continue;

      return Serie(
        repeticiones: repeticiones,
        distancia: distancia,
        zona: zona,
        estilo: estilo,
        ejercicio: ejercicio,
        modificadores: modificadores,
      );
    }

    // Si nada divide bien, una sola repetición con la distancia completa.
    return Serie(
      distancia: metros,
      zona: zona,
      estilo: estilo,
      ejercicio: ejercicio,
      modificadores: modificadores,
    );
  }

  /// Estilo dominante de una sesión.
  ///
  /// Solo Tecnificación impone el estilo por sesión, por su regla de
  /// alternancia. En el resto, el estilo dominante es el objetivo y el
  /// complementario se reparte **dentro** de cada sesión.
  Estilo _estiloDeSesion(
    PeticionGeneracion peticion,
    Presupuesto presupuesto,
    int indice,
  ) {
    if (peticion.categoria.tieneAlternanciaObligatoria) {
      const secuencia = [Estilo.pecho, Estilo.mariposa];
      return secuencia[indice % secuencia.length];
    }

    return peticion.estiloObjetivo;
  }

  /// Estilo complementario del objetivo, según la sección 13.
  ///
  /// Nulo cuando la categoría no está sujeta a la priorización, o cuando el
  /// estilo objetivo no tiene una definida.
  Estilo? _complementario(PeticionGeneracion peticion) {
    if (peticion.categoria.tieneAlternanciaObligatoria) return null;
    if (!peticion.categoria.usaAtr) return null;

    final prioridad = PriorizacionEstilos.para(peticion.estiloObjetivo);
    if (prioridad == null || prioridad.estilosComplementarios.isEmpty) {
      return null;
    }

    return prioridad.estilosComplementarios.first;
  }

  /// Punto medio del rango complementario prescrito.
  int _porcentajeComplementario(PeticionGeneracion peticion) {
    final prioridad = PriorizacionEstilos.para(peticion.estiloObjetivo);
    if (prioridad == null) return 0;

    return ((prioridad.rangoComplementario.minimo +
                prioridad.rangoComplementario.maximo) /
            2)
        .round();
  }

  String _objetivoDelMicrociclo(PeticionGeneracion peticion) =>
      'Componente acentuado: ${peticion.componenteAcentuado.trim()}. '
      'Prueba objetivo: ${peticion.pruebaObjetivo.trim()}.';

  String _objetivoTecnico(PeticionGeneracion peticion, Estilo estilo) {
    if (peticion.tieneDiagnostico) {
      return 'Corregir ${peticion.diagnosticoTecnico.first} en '
          '${estilo.nombre}';
    }
    return '${peticion.componenteAcentuado.trim()} en ${estilo.nombre}';
  }

  String _objetivoFisiologico(
    PeticionGeneracion peticion,
    Map<Zona, int> zonas,
  ) {
    final dominante = _zonaDominante(zonas);
    final fase = peticion.faseAtr;
    return '${dominante.descripcion}'
        '${fase == null ? '' : ' · Fase ${fase.nombre}'}';
  }

  int _rpePrevisto(Map<Zona, int> zonas) {
    final dominante = _zonaDominante(zonas);
    return ((dominante.rpeMinimo + dominante.rpeMaximo) / 2).round();
  }

  Zona _zonaDominante(Map<Zona, int> zonas) {
    var dominante = Zona.a1;
    var maximo = -1;

    for (final zona in ordenDeZonas) {
      final metros = zonas[zona] ?? 0;
      if (metros > maximo) {
        maximo = metros;
        dominante = zona;
      }
    }

    return dominante;
  }

  List<VacioDeBiblioteca> _sinRepetir(List<VacioDeBiblioteca> vacios) {
    final vistos = <String>{};
    final resultado = <VacioDeBiblioteca>[];

    for (final vacio in vacios) {
      final clave = '${vacio.errorDiagnosticado}|${vacio.estilo.name}';
      if (vistos.add(clave)) resultado.add(vacio);
    }

    return resultado;
  }
}

class _SesionCompuesta {
  const _SesionCompuesta(this.sesion, this.vacios);

  final Sesion sesion;
  final List<VacioDeBiblioteca> vacios;
}
