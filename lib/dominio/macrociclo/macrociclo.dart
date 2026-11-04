/// El macrociclo: el nivel que la feature 009 añade por encima del plan.
///
/// **Lea primero la decisión D1.** Un `Plan` ya es un mesociclo: una fase ATR,
/// varios microciclos, sus sesiones, su ciclo de vida, su auditoría, su linaje
/// de versiones y su sello de metodología. Así que esta feature añade el nivel
/// de **encima**, no el de dentro.
///
/// Por eso el macrociclo **guarda referencias y no contenido**: las sesiones
/// viven en sus mesociclos, que son planes. Si guardara una copia, habría dos
/// sitios donde está la misma sesión y uno de los dos acabaría desactualizado.
///
/// Dominio puro: ni Flutter ni Firebase (principio II). Lo vigila
/// `test/dominio/arquitectura_test.dart`.
///
/// Contrato: `specs/009-plan-progression/contracts/macrociclo_y_progresion.md`.
library;

import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

/// Un macrociclo que no se sostiene.
class MacrocicloInvalido implements Exception {
  const MacrocicloInvalido(this.campo, this.porQue);

  final String campo;
  final String porQue;

  @override
  String toString() => 'Macrociclo inválido — $campo: $porQue';
}

/// Una estructura confirmada que no se sostiene.
class EstructuraInvalida implements Exception {
  const EstructuraInvalida(this.campo, this.porQue);

  final String campo;
  final String porQue;

  @override
  String toString() => 'Estructura inválida — $campo: $porQue';
}

/// Una fecha es un día, no un instante.
///
/// Sin esto, un bloque que termina a las 00:00 y el siguiente que empieza a
/// las 23:59 del día siguiente «no serían contiguos», y la estructura se
/// rechazaría por la hora a la que alguien abrió la app. Es la misma trampa
/// que `_diasEnteros` evita en la feature 008.
DateTime _soloLaFecha(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

/// Un bloque de la estructura: una fase, sus fechas y **por qué** salió así.
///
/// El `porQue` no es un adorno ni es opcional. La propuesta del esqueleto
/// decide metodología sin que el entrenador esté delante, y un bloque cuya
/// razón no se puede leer es metodología decidida en silencio (M2). Mismo
/// listón que `FaseDerivada.porQue` en la feature 008.
class BloqueConfirmado {
  factory BloqueConfirmado({
    required FaseAtr? fase,
    required DateTime desde,
    required DateTime hasta,
    required String porQue,
  }) {
    if (!_soloLaFecha(hasta).isAfter(_soloLaFecha(desde))) {
      throw const EstructuraInvalida(
        'bloque',
        'tiene que terminar después de empezar',
      );
    }

    if (porQue.trim().isEmpty) {
      throw const EstructuraInvalida(
        'porQue',
        'un bloque sin razón escrita es metodología decidida en silencio',
      );
    }

    return BloqueConfirmado._(
      fase: fase,
      desde: desde,
      hasta: hasta,
      porQue: porQue.trim(),
    );
  }

  const BloqueConfirmado._({
    required this.fase,
    required this.desde,
    required this.hasta,
    required this.porQue,
  });

  /// Nula **solo** en las categorías que no usan ATR. Ahí no es un hueco por
  /// rellenar: el motor prohíbe la fase, así que nula es la respuesta correcta
  /// (M6).
  final FaseAtr? fase;

  /// Los dos días incluidos. Un bloque de `desde` a `hasta` cubre ambos, así
  /// que el bloque siguiente empieza **al día siguiente** de `hasta`.
  final DateTime desde;
  final DateTime hasta;

  /// Siempre presente y siempre legible, en español y sin jerga:
  /// «Realización, las últimas 2 semanas antes de la competencia».
  final String porQue;

  /// Semanas enteras que cubre, para compararlas con las duraciones
  /// publicadas de la sección 12.
  int get semanas {
    final dias =
        _soloLaFecha(hasta).difference(_soloLaFecha(desde)).inDays + 1;
    return (dias / 7).ceil();
  }

  /// Verdadero si su duración cae dentro de la ventana publicada de su fase.
  ///
  /// **No suspende nada**: la sección 12 dice que la natación usa fases más
  /// largas que la literatura general, así que esto avisa y decide él (M5).
  bool get cabeEnLaVentanaPublicada =>
      fase == null || fase!.duracionSegunIssurin(semanas);
}

/// Lo que el entrenador decidió: el modelo de la prueba, el del nadador y el
/// esqueleto tal como lo dejó.
///
/// Se guarda por dos razones distintas: es la entrada desde la que la
/// derivación es reproducible, y es el registro de lo que **él** decidió, que
/// no es lo mismo que lo que la app propuso.
class EstructuraConfirmada {
  factory EstructuraConfirmada({
    required String modeloDeLaPrueba,
    required String modeloDelNadador,
    required List<BloqueConfirmado> bloques,
    required DateTime confirmadaEn,
  }) {
    if (modeloDeLaPrueba.trim().isEmpty) {
      throw const EstructuraInvalida(
        'modeloDeLaPrueba',
        'lo aporta el entrenador y ninguna fórmula lo deriva (FR-007)',
      );
    }

    if (modeloDelNadador.trim().isEmpty) {
      throw const EstructuraInvalida(
        'modeloDelNadador',
        'lo aporta el entrenador y ninguna fórmula lo deriva (FR-007)',
      );
    }

    if (bloques.isEmpty) {
      throw const EstructuraInvalida(
        'bloques',
        'hace falta al menos un bloque',
      );
    }

    // Ni solapes ni huecos, y en orden. **Reordenarlos en silencio esconderia
    // el error de quien los pasó**, y un hueco sería una semana de la
    // preparación sin fase y sin sesiones que el nadador vería en blanco.
    for (var i = 1; i < bloques.length; i++) {
      final anterior = _soloLaFecha(bloques[i - 1].hasta);
      final siguiente = _soloLaFecha(bloques[i].desde);
      final diferencia = siguiente.difference(anterior).inDays;

      if (diferencia <= 0) {
        throw const EstructuraInvalida(
          'bloques',
          'hay dos bloques que se solapan, o vienen fuera de orden',
        );
      }
      if (diferencia > 1) {
        throw const EstructuraInvalida(
          'bloques',
          'hay un hueco entre dos bloques: sería una parte de la preparación '
              'sin fase y sin sesiones',
        );
      }
    }

    return EstructuraConfirmada._(
      modeloDeLaPrueba: modeloDeLaPrueba.trim(),
      modeloDelNadador: modeloDelNadador.trim(),
      bloques: List.unmodifiable(bloques),
      confirmadaEn: confirmadaEn,
    );
  }

  const EstructuraConfirmada._({
    required this.modeloDeLaPrueba,
    required this.modeloDelNadador,
    required this.bloques,
    required this.confirmadaEn,
  });

  /// Las exigencias reales de la prueba objetivo (sección 4, paso 2).
  ///
  /// **Es suyo.** La app puede ofrecerle de vuelta lo que ya escribió en la
  /// ficha del nadador —`diagnosticoTecnico`, `pruebaObjetivo`, `marcas`— y
  /// nada más. Derivarlo de una fórmula está prohibido (FR-007, FR-008,
  /// constitución v2.0.0).
  final String modeloDeLaPrueba;

  /// Estilo dominante, errores observados, ritmo, tolerancia a la fatiga,
  /// recuperación, motivación (sección 4, paso 3). También suyo.
  final String modeloDelNadador;

  /// El esqueleto tal como lo dejó, con la razón de cada bloque.
  final List<BloqueConfirmado> bloques;

  /// Cuándo confirmó. **La hora del servidor, no la del dispositivo**: es el
  /// registro de un acto suyo, y un reloj de teléfono se puede mover.
  final DateTime confirmadaEn;

  /// Los bloques cuya duración se sale de la ventana publicada de su fase.
  ///
  /// Para avisar, nunca para suspender (M5, FR-012).
  List<BloqueConfirmado> get bloquesFueraDeLaVentana =>
      bloques.where((b) => !b.cabeEnLaVentanaPublicada).toList();
}

class Macrociclo {
  factory Macrociclo({
    String? id,
    required String nadadorId,
    required String nombre,
    required EstructuraConfirmada estructura,
    required List<String> mesociclos,
    required DateTime fechaDeCompetencia,
    required String versionMetodologia,
    EstadoPlan estado = EstadoPlan.borrador,
  }) {
    if (nadadorId.trim().isEmpty) {
      throw const MacrocicloInvalido(
        'nadadorId',
        'un macrociclo es de un nadador',
      );
    }

    if (nombre.trim().isEmpty) {
      throw const MacrocicloInvalido('nombre', 'no puede quedar vacío');
    }

    if (versionMetodologia.trim().isEmpty) {
      throw const MacrocicloInvalido(
        'versionMetodologia',
        'cada nivel registra bajo qué metodología se construyó (FR-013)',
      );
    }

    if (mesociclos.isEmpty) {
      throw const MacrocicloInvalido(
        'mesociclos',
        'un macrociclo sin mesociclos sería un nombre con nada dentro',
      );
    }

    if (mesociclos.toSet().length != mesociclos.length) {
      throw const MacrocicloInvalido(
        'mesociclos',
        'hay un mesociclo repetido',
      );
    }

    return Macrociclo._(
      id: id,
      nadadorId: nadadorId.trim(),
      nombre: nombre.trim(),
      estructura: estructura,
      mesociclos: List.unmodifiable(mesociclos),
      fechaDeCompetencia: fechaDeCompetencia,
      versionMetodologia: versionMetodologia.trim(),
      estado: estado,
    );
  }

  const Macrociclo._({
    required this.id,
    required this.nadadorId,
    required this.nombre,
    required this.estructura,
    required this.mesociclos,
    required this.fechaDeCompetencia,
    required this.versionMetodologia,
    required this.estado,
  });

  /// Nulo hasta que se guarda, como en `Plan`.
  final String? id;

  /// De un nadador. Los grupos quedan fuera de alcance en esta feature.
  final String nadadorId;

  final String nombre;

  /// Lo que el entrenador confirmó. Se guarda porque la derivación es
  /// reproducible desde aquí.
  final EstructuraConfirmada estructura;

  /// Ids de planes, **en orden**. El orden es el de la preparación, no un
  /// accidente del almacenamiento, y la lista no se puede modificar por fuera:
  /// quien recibiera el macrociclo podría reordenar la preparación sin pasar
  /// por ninguna invariante.
  final List<String> mesociclos;

  /// El ancla desde la que el esqueleto cuenta hacia atrás.
  final DateTime fechaDeCompetencia;

  /// FR-013. Se estampa en el macrociclo y en cada uno de sus mesociclos.
  final String versionMetodologia;

  /// Reutiliza el ciclo de vida que ya existe: `borrador → aprobado →
  /// publicado`. No hay un ciclo nuevo porque no hace falta uno nuevo.
  final EstadoPlan estado;

  Macrociclo copiarCon({
    String? id,
    String? nombre,
    EstructuraConfirmada? estructura,
    List<String>? mesociclos,
    DateTime? fechaDeCompetencia,
    String? versionMetodologia,
    EstadoPlan? estado,
  }) => Macrociclo(
    id: id ?? this.id,
    nadadorId: nadadorId,
    nombre: nombre ?? this.nombre,
    estructura: estructura ?? this.estructura,
    mesociclos: mesociclos ?? this.mesociclos,
    fechaDeCompetencia: fechaDeCompetencia ?? this.fechaDeCompetencia,
    versionMetodologia: versionMetodologia ?? this.versionMetodologia,
    estado: estado ?? this.estado,
  );
}

/// Lo que impide firmar el macrociclo.
class ImpedimentoDelMacrociclo {
  const ImpedimentoDelMacrociclo(this.mesocicloId, this.porQue);

  final String mesocicloId;
  final String porQue;

  @override
  String toString() => '$mesocicloId: $porQue';
}

/// Por qué todavía no se puede firmar este macrociclo (M14).
///
/// **Un mesociclo que no viene en la lista cuenta como impedimento.**
/// Comprobar solo que los presentes están aprobados pasaría en vacío con una
/// lista incompleta, y el macrociclo quedaría firmado señalando a un mesociclo
/// que nadie miró. Es la misma clase de fallo que la feature 008 encontró tres
/// veces: verde por la razón equivocada.
List<ImpedimentoDelMacrociclo> impedimentosParaAprobar({
  required Macrociclo macrociclo,
  required List<Plan> mesociclos,
}) {
  final porId = {
    for (final plan in mesociclos)
      if (plan.id != null) plan.id!: plan,
  };

  final impedimentos = <ImpedimentoDelMacrociclo>[];

  for (final id in macrociclo.mesociclos) {
    final plan = porId[id];

    if (plan == null) {
      impedimentos.add(
        ImpedimentoDelMacrociclo(
          id,
          'no se pudo leer el mesociclo, así que no se sabe si está aprobado',
        ),
      );
      continue;
    }

    if (plan.estado == EstadoPlan.borrador) {
      impedimentos.add(
        ImpedimentoDelMacrociclo(
          id,
          'todavía está en borrador: «${plan.nombre}»',
        ),
      );
    }
  }

  return impedimentos;
}
