/// Validación de la petición, **antes** de empezar a repartir.
///
/// Decisión D8 de `research.md` y FR-005, FR-006. La regla R3 de la metodología
/// prohíbe planificar con datos faltantes, así que se comprueba todo primero y
/// se devuelven **todos los impedimentos a la vez**: el entrenador los ve de
/// una vez y no de uno en uno.
///
/// Validar antes evita dejar a medias un plan que habría que descartar.
library;

import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/generacion/ritmos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

class ValidacionPeticion {
  const ValidacionPeticion();

  /// Devuelve la lista de impedimentos. Vacía significa que se puede generar.
  List<Impedimento> validar(PeticionGeneracion peticion) {
    final impedimentos = <Impedimento>[];

    _datosObligatorios(peticion, impedimentos);
    _faseAdmisible(peticion, impedimentos);
    _frecuencia(peticion, impedimentos);
    _duracion(peticion, impedimentos);
    _componente(peticion, impedimentos);

    return impedimentos;
  }

  void _datosObligatorios(
    PeticionGeneracion peticion,
    List<Impedimento> impedimentos,
  ) {
    if (peticion.pruebaObjetivo.trim().isEmpty) {
      impedimentos.add(
        const Impedimento(
          tipo: TipoImpedimento.datoFaltante,
          campo: 'pruebaObjetivo',
          explicacion:
              'Falta la prueba objetivo. Sin ella no se puede modelar '
              'la exigencia del trabajo (sección 4).',
        ),
      );
    }

    if (peticion.componenteAcentuado.trim().isEmpty) {
      impedimentos.add(
        const Impedimento(
          tipo: TipoImpedimento.datoFaltante,
          campo: 'componenteAcentuado',
          explicacion:
              'Falta el componente acentuado de la semana. Es lo que da '
              'nombre al microciclo y orienta la selección de ejercicios.',
        ),
      );
    }

    if (peticion.diasDisponibles.isEmpty) {
      impedimentos.add(
        const Impedimento(
          tipo: TipoImpedimento.datoFaltante,
          campo: 'diasDisponibles',
          explicacion: 'No se declaró ningún día disponible.',
        ),
      );
    }

    if (peticion.longitudPiscina != 25 && peticion.longitudPiscina != 50) {
      impedimentos.add(
        Impedimento(
          tipo: TipoImpedimento.datoFaltante,
          campo: 'longitudPiscina',
          explicacion:
              'La longitud de piscina debe ser 25 o 50 m, y se declaró '
              '${peticion.longitudPiscina}.',
        ),
      );
    }

    if (peticion.duracionSesionMinutos <= 0) {
      impedimentos.add(
        Impedimento(
          tipo: TipoImpedimento.datoFaltante,
          campo: 'duracionSesionMinutos',
          explicacion:
              'La duración de sesión debe ser positiva, y se declaró '
              '${peticion.duracionSesionMinutos} minutos.',
        ),
      );
    }
  }

  void _faseAdmisible(
    PeticionGeneracion peticion,
    List<Impedimento> impedimentos,
  ) {
    final categoria = peticion.categoria;

    if (peticion.faseAtr != null && !categoria.usaAtr) {
      impedimentos.add(
        Impedimento(
          tipo: TipoImpedimento.faseNoAdmisible,
          campo: 'faseAtr',
          explicacion:
              '${categoria.nombre} no usa el modelo ATR (sección 11), '
              'así que no se le puede asignar la fase '
              '${peticion.faseAtr!.nombre}.',
        ),
      );
    }

    if (peticion.faseAtr == null && categoria.usaAtr) {
      impedimentos.add(
        Impedimento(
          tipo: TipoImpedimento.datoFaltante,
          campo: 'faseAtr',
          explicacion:
              '${categoria.nombre} usa el modelo ATR y no se declaró la '
              'fase. Sin ella no hay distribución de intensidades que aplicar.',
        ),
      );
    }
  }

  void _frecuencia(
    PeticionGeneracion peticion,
    List<Impedimento> impedimentos,
  ) {
    final esperadas = peticion.categoria.sesionesPorSemana;
    final disponibles = peticion.diasEfectivos.length;

    if (disponibles == 0) return;

    // Alto Rendimiento hace dobles sesiones: no necesita un día por sesión.
    final diasMinimos = esperadas > 7 ? (esperadas / 2).ceil() : esperadas;

    if (disponibles < diasMinimos) {
      final porFestivos = peticion.diasDisponibles.length - disponibles;
      impedimentos.add(
        Impedimento(
          tipo: TipoImpedimento.frecuenciaImposible,
          campo: 'diasDisponibles',
          explicacion:
              '${peticion.categoria.nombre} pide $esperadas sesiones '
              'por semana, que necesitan al menos $diasMinimos días, y hay '
              '$disponibles disponibles'
              '${porFestivos > 0 ? ' tras descontar $porFestivos festivos' : ''}.',
        ),
      );
    }
  }

  void _duracion(PeticionGeneracion peticion, List<Impedimento> impedimentos) {
    if (peticion.duracionSesionMinutos <= 0) return;

    final estimacion = EstimacionDuracion(peticion.categoria);
    final rango = peticion.categoria.volumenPorSesion;
    final minimo = rango.minimo;

    if (!estimacion.cabe(minimo, peticion.duracionSesionMinutos)) {
      impedimentos.add(
        Impedimento(
          tipo: TipoImpedimento.duracionInsuficiente,
          campo: 'duracionSesionMinutos',
          explicacion:
              '${peticion.categoria.nombre} exige al menos $minimo m '
              'por sesión, que a un ritmo estimado de '
              '${estimacion.ritmoMetrosPorMinuto} m/min necesitan unos '
              '${estimacion.minutosPara(minimo)} minutos, y se declararon '
              '${peticion.duracionSesionMinutos}.',
        ),
      );
    }
  }

  void _componente(
    PeticionGeneracion peticion,
    List<Impedimento> impedimentos,
  ) {
    final fase = peticion.faseAtr;
    if (fase == null) return;

    final componente = peticion.componenteAcentuado.toLowerCase();

    // La velocidad pura no existe en Acumulación: la fase no le asigna
    // volumen, así que acentuarla sería contradictorio.
    final acentuaVelocidad =
        componente.contains('velocidad') || componente.contains('sprint');

    if (acentuaVelocidad && fase.prescritoPara(Zona.velocidad) == 0) {
      impedimentos.add(
        Impedimento(
          tipo: TipoImpedimento.componenteIncoherente,
          campo: 'componenteAcentuado',
          explicacion:
              'El componente acentuado apunta a velocidad, pero la fase '
              '${fase.nombre} no le asigna volumen en su distribución '
              '(sección 12).',
        ),
      );
    }
  }
}
