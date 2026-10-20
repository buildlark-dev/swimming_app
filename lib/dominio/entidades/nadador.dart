/// Perfil de nadador.
///
/// Datos mínimos para planificar. El principio V de la constitución exige
/// recolectar solo lo que tiene un uso declarado en la feature.
///
/// **Restricción vigente**: mientras no exista el registro de consentimiento
/// del acudiente, solo deben cargarse perfiles de prueba o del propio
/// entrenador. Ver `spec.md`, sección Assumptions.
library;

import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Marca registrada de un nadador.
class Marca {
  const Marca({
    required this.distancia,
    required this.estilo,
    required this.tiempo,
    required this.fecha,
  });

  final int distancia;
  final Estilo estilo;
  final Duration tiempo;
  final DateTime fecha;

  /// Formato `mm:ss.cc`.
  String get tiempoLegible {
    final minutos = tiempo.inMinutes;
    final segundos = tiempo.inSeconds % 60;
    final centesimas = (tiempo.inMilliseconds % 1000) ~/ 10;
    return '$minutos:${segundos.toString().padLeft(2, '0')}'
        '.${centesimas.toString().padLeft(2, '0')}';
  }
}

/// Lo que impide dar el perfil por completo.
class FaltaEnPerfil {
  const FaltaEnPerfil(this.campo, this.descripcion);

  final String campo;
  final String descripcion;

  @override
  String toString() => descripcion;
}

class Nadador {
  const Nadador({
    this.id,
    required this.nombre,
    this.fechaNacimiento,
    this.declaraSerMayorDeEdad,
    this.categoria,
    this.estiloObjetivo,
    this.pruebaObjetivo = '',
    this.marcas = const <Marca>[],
    this.diagnosticoTecnico = const <String>[],
  });

  final String? id;
  final String nombre;
  final DateTime? fechaNacimiento;

  /// Lo que el nadador declaró sobre su mayoría de edad (FR-008).
  ///
  /// Es **el dato mínimo suficiente** para saber si hace falta el
  /// consentimiento de un acudiente, y por eso se prefiere a la fecha de
  /// nacimiento, que dice bastante más de lo que hace falta (minimización,
  /// principio V).
  ///
  /// `null` significa **que todavía no lo declaró**, que no es lo mismo que
  /// ser menor. Ante `null` se trata como menor, porque el error de pedir un
  /// consentimiento que no hacía falta se arregla; el de no pedirlo, no.
  final bool? declaraSerMayorDeEdad;

  /// Si hace falta el consentimiento de un acudiente.
  ///
  /// Nada de esto determina la **categoría** del nadador. La categoría se
  /// declara por habilidades y nunca por la edad (sección 11.1 de la
  /// metodología 3.6.0): un niño y un adulto pueden entrenar en Iniciación.
  bool necesitaAcudienteEn(DateTime referencia) {
    if (declaraSerMayorDeEdad == true) return false;

    // Si consta la fecha de nacimiento y dice que es mayor, se respeta: es un
    // dato más fuerte que la ausencia de declaración.
    if (esMenorEn(referencia) == false) return false;

    return true;
  }

  /// Obligatoria para dar el perfil por completo: sin ella no se puede validar
  /// el volumen de sus sesiones.
  final Categoria? categoria;

  /// Obligatorio para dar el perfil por completo: sin él no se puede validar
  /// la distribución de estilos.
  final Estilo? estiloObjetivo;

  final String pruebaObjetivo;
  final List<Marca> marcas;

  /// Errores técnicos observados. Alimenta el criterio C10.
  final List<String> diagnosticoTecnico;

  /// Edad en años cumplidos, si se conoce la fecha de nacimiento.
  int? edadEn(DateTime referencia) {
    final nacimiento = fechaNacimiento;
    if (nacimiento == null) return null;

    var edad = referencia.year - nacimiento.year;
    final cumpleEsteAno = DateTime(referencia.year, nacimiento.month, nacimiento.day);
    if (referencia.isBefore(cumpleEsteAno)) edad--;
    return edad;
  }

  /// Verdadero si se sabe que es menor de edad.
  ///
  /// Devuelve `null` cuando no hay fecha de nacimiento: no se supone la edad.
  bool? esMenorEn(DateTime referencia) {
    final edad = edadEn(referencia);
    return edad == null ? null : edad < 18;
  }

  List<FaltaEnPerfil> get faltas {
    final faltas = <FaltaEnPerfil>[];

    if (nombre.trim().isEmpty) {
      faltas.add(const FaltaEnPerfil('nombre', 'Falta el nombre del nadador'));
    }
    if (categoria == null) {
      faltas.add(const FaltaEnPerfil(
        'categoria',
        'Falta la categoría: sin ella no se puede validar el volumen',
      ));
    }
    if (estiloObjetivo == null) {
      faltas.add(const FaltaEnPerfil(
        'estiloObjetivo',
        'Falta el estilo objetivo: sin él no se puede validar la '
            'distribución de estilos',
      ));
    }

    return faltas;
  }

  bool get estaCompleto => faltas.isEmpty;

  Nadador copiarCon({
    String? id,
    String? nombre,
    DateTime? fechaNacimiento,
    bool? declaraSerMayorDeEdad,
    Categoria? categoria,
    Estilo? estiloObjetivo,
    String? pruebaObjetivo,
    List<Marca>? marcas,
    List<String>? diagnosticoTecnico,
  }) {
    return Nadador(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      declaraSerMayorDeEdad:
          declaraSerMayorDeEdad ?? this.declaraSerMayorDeEdad,
      categoria: categoria ?? this.categoria,
      estiloObjetivo: estiloObjetivo ?? this.estiloObjetivo,
      pruebaObjetivo: pruebaObjetivo ?? this.pruebaObjetivo,
      marcas: marcas ?? this.marcas,
      diagnosticoTecnico: diagnosticoTecnico ?? this.diagnosticoTecnico,
    );
  }
}
