/// Dónde está el nadador dentro del macrociclo (decisión D7).
///
/// **Se calcula al leer y no se guarda.** `ProgresoDelNadador` ya hace esto
/// para un plan; esto lo extiende un nivel hacia arriba, y es aritmética.
/// Guardarlo crearía una segunda cosa que puede discrepar de la primera, y la
/// primera es la que el nadador escribió.
///
/// Todo lo que sale de aquí se compara **por fecha y no por instante**. Sin
/// eso, la sesión de hoy pasaría a «pendiente» por la tarde y el nadador vería
/// el plan cambiar según la hora a la que abriera la app.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';

DateTime _soloLaFecha(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

class ProgresoEnElMacrociclo {
  ProgresoEnElMacrociclo({
    required List<Plan> mesociclos,
    required List<RegistroDeSesion> registros,
    required DateTime hoy,
  }) : _mesociclos = List.unmodifiable(mesociclos),
       _hoy = _soloLaFecha(hoy),
       hechas = Set.unmodifiable({
         for (final registro in registros)
           if (registro.realizada) registro.sesionId,
       }),
       dijoQueNo = Set.unmodifiable({
         for (final registro in registros)
           if (!registro.realizada) registro.sesionId,
       });

  final List<Plan> _mesociclos;
  final DateTime _hoy;

  /// Los identificadores de las sesiones que el nadador marcó como hechas.
  final Set<String> hechas;

  /// Las que el nadador contestó diciendo que **no** las hizo.
  ///
  /// **No es lo mismo que no haber contestado**, y la diferencia es lo que el
  /// reajuste va a leer (M29, FR-028). «No la hice» es un dato: el nadador
  /// estuvo ahí y dijo lo que pasó. «No contestó» es la ausencia de un dato, y
  /// puede significar que se le olvidó, que no tuvo señal o que dejó de abrir
  /// la app. Mezclarlas le enseñaría al entrenador un hueco donde hay una
  /// respuesta, o una respuesta donde hay un hueco.
  final Set<String> dijoQueNo;

  /// Las que ya pasaron y el nadador no contestó de ninguna manera.
  Set<String> get sinContestar => {
    for (final sesion in todasLasSesiones)
      if (sesion.id != null &&
          sesion.fecha != null &&
          _soloLaFecha(sesion.fecha!).isBefore(_hoy) &&
          !hechas.contains(sesion.id) &&
          !dijoQueNo.contains(sesion.id))
        sesion.id!,
  };

  /// El mesociclo cuyas fechas contienen hoy. **Nulo cuando no hay ninguno**,
  /// que es la respuesta correcta antes de empezar, después de terminar y en
  /// un hueco: suponer que es el primero abriría la vista en una semana que
  /// todavía no llegó.
  Plan? get mesocicloActual {
    for (final mesociclo in _mesociclos) {
      final desde = mesociclo.fechaInicio;
      final hasta = mesociclo.fechaFin;
      if (desde == null || hasta == null) continue;

      if (!_hoy.isBefore(_soloLaFecha(desde)) &&
          !_hoy.isAfter(_soloLaFecha(hasta))) {
        return mesociclo;
      }
    }
    return null;
  }

  /// «2 de 3», como el nadador lo lee. Vacío si todavía no está en ninguno.
  String get comoSeLee {
    final actual = mesocicloActual;
    if (actual == null) return '';
    final posicion = (actual.ordenEnElMacrociclo ?? 0) + 1;
    return '$posicion de ${_mesociclos.length}';
  }

  bool get yaEmpezo {
    final primera = _todasLasFechas.isEmpty ? null : _todasLasFechas.first;
    return primera != null && !_hoy.isBefore(primera);
  }

  bool get yaTermino {
    final ultima = _todasLasFechas.isEmpty ? null : _todasLasFechas.last;
    return ultima != null && _hoy.isAfter(ultima);
  }

  List<DateTime> get _todasLasFechas {
    final fechas = <DateTime>[
      for (final mesociclo in _mesociclos)
        for (final sesion in mesociclo.sesiones)
          if (sesion.fecha != null) _soloLaFecha(sesion.fecha!),
    ]..sort();
    return fechas;
  }

  /// Todas las sesiones del macrociclo, en el orden en que llegan.
  List<Sesion> get todasLasSesiones => List.unmodifiable([
    for (final mesociclo in _mesociclos) ...mesociclo.sesiones,
  ]);

  /// Lo que quedó atrás sin marcar, de la más antigua a la más reciente.
  ///
  /// **Se muestra, no se obliga** (decisión D6). Es la lista que el nadador lee
  /// cuando marca una sesión con otras atrás sin marcar, y la que su entrenador
  /// lee como huecos y no como falta de datos.
  ///
  /// La de **hoy no cuenta**: el día no ha acabado. Y una sesión sin fecha
  /// tampoco: no se adivina cuándo se iba a hacer.
  List<Sesion> get pendientes {
    final atrasadas = <Sesion>[
      for (final mesociclo in _mesociclos)
        for (final sesion in mesociclo.sesiones)
          if (sesion.fecha != null &&
              _soloLaFecha(sesion.fecha!).isBefore(_hoy) &&
              !(sesion.id != null && hechas.contains(sesion.id)))
            sesion,
    ]..sort((a, b) => a.fecha!.compareTo(b.fecha!));

    return List.unmodifiable(atrasadas);
  }

  /// La primera de hoy en adelante que no esté hecha.
  Sesion? get proxima {
    final siguientes = <Sesion>[
      for (final mesociclo in _mesociclos)
        for (final sesion in mesociclo.sesiones)
          if (sesion.fecha != null &&
              !_soloLaFecha(sesion.fecha!).isBefore(_hoy) &&
              !(sesion.id != null && hechas.contains(sesion.id)))
            sesion,
    ]..sort((a, b) => a.fecha!.compareTo(b.fecha!));

    return siguientes.isEmpty ? null : siguientes.first;
  }

  /// Cuántas de las programadas se completaron, en todo el macrociclo.
  ///
  /// **Cuenta sesiones. Punto.** No pondera por metros ni por RPE: el
  /// principio VIII prohíbe combinar carga externa e interna en un mismo
  /// indicador, y la feature 003 ya dejó una prueba que lo fija.
  Adherencia get adherencia => Adherencia(
    realizadas: todasLasSesiones
        .where((s) => s.id != null && hechas.contains(s.id))
        .length,
    programadas: todasLasSesiones.length,
  );

  /// La adherencia de cada mesociclo, para que se vea dónde se cayó.
  Map<String, Adherencia> get adherenciaPorMesociclo => {
    for (final mesociclo in _mesociclos)
      if (mesociclo.id != null)
        mesociclo.id!: Adherencia(
          realizadas: mesociclo.sesiones
              .where((s) => s.id != null && hechas.contains(s.id))
              .length,
          programadas: mesociclo.sesiones.length,
        ),
  };
}
