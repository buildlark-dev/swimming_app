/// De la estructura confirmada al macrociclo entero, en una sola operación.
///
/// **No hay un segundo motor.** Esto conduce al generador determinista de la
/// feature 002, una vez por microciclo, y agrupa lo que sale en mesociclos.
/// Un camino que produjera sesiones de otra manera sería una segunda
/// metodología, que es lo que el principio I prohíbe en sustancia. Ningún
/// modelo de lenguaje interviene en ningún campo (M9, FR-014).
///
/// **Una confirmación y nada más** (M8, FR-003). De aquí salen mesociclos,
/// microciclos y sesiones de una vez, sin preguntar nada entre niveles: con un
/// motor determinista no queda criterio que delegar por debajo de la
/// estructura, y eso es lo que la enmienda de la constitución v2.0.0
/// reformuló.
///
/// **O sale entero o no sale.** Si una semana cualquiera no se puede generar,
/// la derivación falla con los impedimentos del motor en lugar de devolver un
/// macrociclo con un hueco. Un mesociclo que al nadador le aparece vacío es
/// peor que un mensaje que dice qué falta (mismo razonamiento que M16).
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/componente_por_fase.dart';

sealed class ResultadoDerivacion {
  const ResultadoDerivacion();
}

/// El macrociclo derivado, todavía sin guardar.
///
/// **No lleva un `Macrociclo` dentro, y la razón importa.** `Macrociclo`
/// guarda ids de planes, y los planes no tienen id hasta que se guardan. Poner
/// aquí ids provisionales sería dejar en el dominio unos identificadores que
/// parecen reales y que alguien podría llegar a almacenar. Así que la lista de
/// mesociclos se guarda primero, y con sus ids se arma el macrociclo con
/// [macrocicloConLosIds].
class MacrocicloDerivado extends ResultadoDerivacion {
  const MacrocicloDerivado({
    required this.nadadorId,
    required this.nombre,
    required this.estructura,
    required this.mesociclos,
    required this.fechaDeCompetencia,
    required this.versionMetodologia,
    required this.supuestos,
    required this.vaciosDeBiblioteca,
    required this.avisos,
  });

  final String nadadorId;
  final String nombre;
  final EstructuraConfirmada estructura;

  /// Un mesociclo por bloque, en el orden del esqueleto, cada uno con su fase,
  /// sus microciclos y sus sesiones. Todos en `borrador`.
  final List<Plan> mesociclos;

  final DateTime fechaDeCompetencia;
  final String versionMetodologia;

  final List<Supuesto> supuestos;
  final List<VacioDeBiblioteca> vaciosDeBiblioteca;
  final List<String> avisos;

  /// Cuántas veces se llamó al motor. Un macrociclo de catorce semanas son
  /// catorce llamadas, y corren en el teléfono del entrenador.
  int get llamadasAlMotor =>
      mesociclos.fold(0, (total, m) => total + m.microciclos.length);

  /// El macrociclo, una vez que sus mesociclos ya tienen identificador.
  Macrociclo macrocicloConLosIds(List<String> ids) => Macrociclo(
    nadadorId: nadadorId,
    nombre: nombre,
    estructura: estructura,
    mesociclos: ids,
    fechaDeCompetencia: fechaDeCompetencia,
    versionMetodologia: versionMetodologia,
  );
}

/// No se pudo derivar, y se dice por qué.
class DerivacionImposible extends ResultadoDerivacion {
  const DerivacionImposible({
    required this.impedimentos,
    required this.enQueBloque,
  });

  final List<Impedimento> impedimentos;

  /// Qué bloque del esqueleto no salió, para que el entrenador sepa dónde
  /// mirar en lugar de recibir un «no se pudo».
  final String enQueBloque;
}

DateTime _soloLaFecha(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

/// Las ventanas semanales de un bloque.
///
/// Un bloque de 57 días da 8 semanas, no 9: el resto de un día **se suma a la
/// última** en lugar de quedarse como microciclo de un día. Un microciclo de
/// un día no es una semana de entrenamiento, y el motor repartiría en él el
/// volumen de una.
List<({DateTime desde, DateTime hasta})> _semanasDe(BloqueConfirmado bloque) {
  final desde = _soloLaFecha(bloque.desde);
  final hasta = _soloLaFecha(bloque.hasta);
  final dias = hasta.difference(desde).inDays + 1;

  final cuantas = dias ~/ 7;
  if (cuantas <= 1) {
    return [(desde: desde, hasta: hasta)];
  }

  return [
    for (var i = 0; i < cuantas; i++)
      (
        desde: desde.add(Duration(days: i * 7)),
        // La última se queda con lo que sobre.
        hasta: i == cuantas - 1 ? hasta : desde.add(Duration(days: i * 7 + 6)),
      ),
  ];
}

/// Los días de entrenamiento dentro de una ventana.
///
/// **El día de la competencia no se entrena.** Con la carrera en un día de
/// piscina —un viernes, con los viernes en el calendario— la derivación le
/// ponía sesión el mismo día: el camino de la nadadora terminaba en «Viernes
/// 1/1» y el 1/1 era la competencia. La última sesión es la de antes.
///
/// Se quita aquí y no acortando el último bloque a propósito. El bloque sigue
/// llegando hasta la competencia, que es lo que el entrenador confirmó y lo
/// que el macrociclo significa: va hacia ella. Mover esa frontera cambiaría
/// la estructura y las duraciones de fase por una razón que no es
/// metodológica.
List<DateTime> _diasDeLaSemana(
  ({DateTime desde, DateTime hasta}) semana,
  List<int> diasPorSemana,
  DateTime fechaDeCompetencia,
) {
  final dias = <DateTime>[];
  final carrera = _soloLaFecha(fechaDeCompetencia);
  var dia = semana.desde;

  while (!dia.isAfter(semana.hasta)) {
    if (diasPorSemana.contains(dia.weekday) && dia != carrera) dias.add(dia);
    dia = dia.add(const Duration(days: 1));
  }

  return dias;
}

/// Deriva el macrociclo completo desde la estructura confirmada.
ResultadoDerivacion derivarMacrociclo({
  required EstructuraConfirmada estructura,
  required Nadador ficha,
  required Biblioteca biblioteca,
  required String versionMetodologia,
  required String nombre,
  required DateTime fechaDeCompetencia,
  IndiceTerminos? indice,
}) {
  final categoria = ficha.categoria ?? Categoria.iniciacion;
  final generador = Generador(biblioteca: biblioteca, indice: indice);

  final mesociclos = <Plan>[];
  final supuestos = <Supuesto>[];
  final vacios = <VacioDeBiblioteca>[];
  final avisos = <String>[];

  for (var i = 0; i < estructura.bloques.length; i++) {
    final bloque = estructura.bloques[i];
    final semanas = _semanasDe(bloque);

    final microciclos = <Microciclo>[];
    final sesiones = <Sesion>[];

    for (var s = 0; s < semanas.length; s++) {
      final dias = _diasDeLaSemana(
        semanas[s],
        estructura.diasPorSemana,
        fechaDeCompetencia,
      );

      final peticion = PeticionGeneracion(
        // De la ficha: es del entrenador, no del nadador.
        categoria: categoria,
        estiloObjetivo: ficha.estiloObjetivo ?? Estilo.libre,
        pruebaObjetivo: ficha.pruebaObjetivo,
        // Del bloque que él confirmó.
        faseAtr: bloque.fase,
        // Derivado de la fase, así que la comprobación de coherencia del
        // motor pasa **por construcción** (feature 008, componente por fase).
        componenteAcentuado: componenteParaFase(
          fase: bloque.fase,
          categoria: categoria,
        ),
        diasDisponibles: dias,
        longitudPiscina: estructura.longitudPiscina,
        duracionSesionMinutos: estructura.duracionSesionMinutos,
        // De la ficha. Vacío aplica la progresión estándar y **no se inventan
        // errores** (sección 7 del prompt maestro).
        diagnosticoTecnico: ficha.diagnosticoTecnico,
        nadadoresIds: [if (ficha.id != null) ficha.id!],
      );

      final resultado = generador.generar(peticion);

      switch (resultado) {
        case GeneracionImposible(impedimentos: final impedimentos):
          // **Entero o nada.** Devolver el resto dejaría un macrociclo con un
          // agujero, y el agujero no se vería hasta que el nadador abriera esa
          // semana.
          return DerivacionImposible(
            impedimentos: impedimentos,
            enQueBloque:
                '${bloque.fase?.nombre ?? 'Sin fase'}, semana ${s + 1} de '
                '${semanas.length}',
          );

        case MicrocicloGenerado(plan: final plan):
          supuestos.addAll(resultado.supuestos);
          vacios.addAll(resultado.vaciosDeBiblioteca);
          avisos.addAll(resultado.avisos);

          // El motor numera su microciclo como `mc-1` porque genera uno solo.
          // Dentro del mesociclo hacen falta identificadores propios, y las
          // sesiones tienen que seguir apuntando al suyo.
          final orden = microciclos.length + 1;
          final idDelMicrociclo = 'mc-$orden';
          final original = plan.microciclos.single;

          microciclos.add(
            Microciclo(
              id: idDelMicrociclo,
              // El componente acentuado va delante, que es lo que la
              // metodología exige nombrar; la semana solo lo sitúa. Nueve
              // microciclos llamados igual no le dicen al nadador dónde está.
              nombre: '${original.nombre}, semana $orden',
              orden: orden,
              objetivo: original.objetivo,
            ),
          );

          for (final sesion in plan.sesiones) {
            sesiones.add(sesion.copiarCon(microcicloId: idDelMicrociclo));
          }
      }
    }

    mesociclos.add(
      Plan(
        nombre: bloque.fase == null
            ? 'Mesociclo ${i + 1}: ${microciclos.first.nombre.split(',').first}'
            : 'Mesociclo ${i + 1}: ${bloque.fase!.nombre}',
        categoria: categoria,
        estiloObjetivo: ficha.estiloObjetivo ?? Estilo.libre,
        pruebaObjetivo: ficha.pruebaObjetivo,
        longitudPiscina: estructura.longitudPiscina,
        fechaInicio: _soloLaFecha(bloque.desde),
        fechaFin: _soloLaFecha(bloque.hasta),
        faseAtr: bloque.fase,
        microciclos: microciclos,
        sesiones: sesiones,
        origen: OrigenPlan.automatico,
        // FR-011, M11: cada nivel registra bajo qué metodología se construyó.
        versionMetodologia: versionMetodologia,
        ordenEnElMacrociclo: i,
      ),
    );
  }

  return MacrocicloDerivado(
    nadadorId: ficha.id ?? '',
    nombre: nombre,
    estructura: estructura,
    mesociclos: List.unmodifiable(mesociclos),
    fechaDeCompetencia: fechaDeCompetencia,
    versionMetodologia: versionMetodologia,
    supuestos: List.unmodifiable(supuestos),
    vaciosDeBiblioteca: List.unmodifiable(vacios),
    avisos: List.unmodifiable(avisos),
  );
}
