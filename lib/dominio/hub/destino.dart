/// Los cinco destinos de la barra, y de quién es cada contenido.
///
/// **Esto sustituye a dos listas paralelas con un índice compartido.** Lo que
/// había en `main.dart` llevaba su propio aviso al lado: «hacerlo con dos
/// listas paralelas y un índice compartido es la forma clásica de acabar
/// enseñando el editor al pulsar "Mi progreso"». Con tres pestañas y un rol era
/// un riesgo; con cinco destinos y dos recorridos se duplica.
///
/// Está en el dominio, en Dart puro, porque así «ningún contenido del otro rol
/// aparece en un recorrido» es una propiedad de una estructura de datos y se
/// comprueba sin pintar nada (decisión D2).
///
/// **El icono no está aquí.** Un `IconData` es de Flutter, y el dominio no
/// importa Flutter: la interfaz empareja cada destino con el suyo.
library;

import 'package:natacion_app/dominio/cuentas/cuenta.dart';

/// Una de las cinco posiciones de la barra.
///
/// El orden de declaración **es** el orden de la barra, y es el mismo para los
/// dos roles: lo que cambia es lo que hay dentro, no dónde está.
enum Destino {
  generar('Generar'),
  verPlan('Ver Plan'),
  home('Home'),
  analisis('Análisis'),
  ajustes('Ajustes');

  const Destino(this.etiqueta);

  /// Como se lee en la barra. En español, sin abreviar: si una etiqueta no cabe
  /// en una pantalla angosta, lo que cambia es la barra y no la palabra.
  final String etiqueta;

  /// Dónde está. `Home` ocupa la central, que es la única posición con
  /// significado propio.
  int get posicion => index;
}

/// Lo que un destino puede contener.
///
/// Son identificadores, no widgets: el dominio dice **qué** le toca a cada rol
/// y la interfaz decide con qué pantalla se pinta.
enum Contenido {
  /// El generador de microciclos y el editor de sesiones, juntos: un plan
  /// recién generado se revisa sin cambiar de destino.
  generadorYEditor,

  /// Sus planes, con búsqueda y filtro por nadador, y el panel de nadadores.
  planesDelEntrenador,

  /// Los cuatro números del entrenador.
  homeDelEntrenador,

  /// La sesión de hoy: cumplida, esfuerzo, observaciones, molestia aparte.
  sesionDelDia,

  /// El recorrido del nadador, que la feature 003 entregó como «Mi progreso».
  miProgreso,

  /// Cómo va su entrenamiento, en corto.
  homeDelNadador,

  /// La cuenta de quien está dentro. **El único contenido de los dos
  /// recorridos**, porque es el mismo con datos distintos.
  ajustes,
}

/// Qué hay en un destino para un rol. Siempre una de las dos cosas.
sealed class QueHay {
  const QueHay();
}

/// Hay contenido.
final class Contiene extends QueHay {
  const Contiene(this.contenido);

  final Contenido contenido;
}

/// Todavía no, y se dice qué llegará y cuándo.
///
/// No es un hueco: es una promesa acotada. Lo que no puede llevar es ningún
/// control pulsable, ni deshabilitado como señuelo (H12).
final class TodaviaNo extends QueHay {
  const TodaviaNo({required this.loQueLlegara, required this.feature});

  /// Dicho en una frase, para quien lo abra.
  final String loQueLlegara;

  /// Qué feature lo trae. Que esté escrito evita que un destino se quede
  /// esperando a nadie.
  final String feature;
}

/// El reparto: para cada destino y cada rol, **exactamente una** respuesta.
///
/// Es una función total a propósito. Un mapa con huecos obligaría a cada sitio
/// que lo consulta a decidir qué hacer cuando falta, y de esas decisiones
/// repartidas salen las pantallas en blanco.
QueHay reparto(Destino destino, Rol rol) {
  final esEntrenador = rol == Rol.entrenador;

  switch (destino) {
    case Destino.generar:
      return esEntrenador
          ? const Contiene(Contenido.generadorYEditor)
          : const TodaviaNo(
              loQueLlegara:
                  'Desde aquí podrás pedir tu entrenamiento: '
                  'responderás unas preguntas y tu entrenador recibirá la '
                  'solicitud para prepararlo y firmarlo.',
              feature: '008',
            );

    case Destino.verPlan:
      return esEntrenador
          ? const Contiene(Contenido.planesDelEntrenador)
          : const Contiene(Contenido.sesionDelDia);

    case Destino.home:
      return esEntrenador
          ? const Contiene(Contenido.homeDelEntrenador)
          : const Contiene(Contenido.homeDelNadador);

    case Destino.analisis:
      return esEntrenador
          ? const TodaviaNo(
              loQueLlegara:
                  'Aquí verás lo que tus nadadores han hecho: qué '
                  'cumplieron, qué anotaron y cómo sintieron el esfuerzo.',
              feature: '010',
            )
          : const Contiene(Contenido.miProgreso);

    case Destino.ajustes:
      return const Contiene(Contenido.ajustes);
  }
}
