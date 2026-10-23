/// El único sitio que decide si alguien es menor de edad.
///
/// **Uno, y no dos.** Es la precaución que la decisión D2 pedía: desde esta
/// feature hay dos datos que podrían contestar la pregunta —la fecha de
/// nacimiento y la declaración que la feature 004 guardaba—, y dos datos con
/// dos cálculos son dos sitios donde equivocarse.
///
/// Equivocarse aquí no es un fallo de interfaz: significa **no pedir un
/// consentimiento que hacía falta**, y eso lo paga una familia.
///
/// Por eso el cálculo que ya tenía `Nadador` se extrajo aquí en lugar de
/// escribir uno nuevo «para el perfil». `Nadador` y `Perfil` contestan con el
/// mismo código, no con dos que se parecen.
///
/// Contrato: `specs/006-alta-de-cuenta/contracts/alta_de_cuenta.md`, A4 a A6.
library;

/// La mayoría de edad, en años.
///
/// Es la de Colombia, que es donde vive la Ley 1581 bajo la que esta app
/// trata los datos. Si algún día la app distingue por país —hoy no lo hace,
/// decisión D7— este número dejará de ser una constante.
const int mayoriaDeEdad = 18;

/// Edad en años cumplidos a una fecha, si se conoce la de nacimiento.
///
/// Devuelve `null` cuando no hay fecha: **no se supone la edad de nadie**.
int? edadA(DateTime? nacimiento, DateTime referencia) {
  if (nacimiento == null) return null;

  var edad = referencia.year - nacimiento.year;
  final cumpleEsteAno = DateTime(
    referencia.year,
    nacimiento.month,
    nacimiento.day,
  );
  if (referencia.isBefore(cumpleEsteAno)) edad--;
  return edad;
}

/// Si se sabe que es menor de edad.
///
/// `null` cuando no hay fecha de nacimiento. **`null` no es «no»**: es «no se
/// sabe», y quien lo reciba tiene que decidir qué hacer con la duda.
bool? esMenorA(DateTime? nacimiento, DateTime referencia) {
  final edad = edadA(nacimiento, referencia);
  return edad == null ? null : edad < mayoriaDeEdad;
}

/// Si hace falta el consentimiento de un acudiente.
///
/// El orden de preferencia es el de `data-model.md`:
///
/// 1. Si hay **fecha de nacimiento**, manda la fecha. No envejece: el día que
///    alguien cumple 18 deja de ser menor sin que nadie escriba nada.
/// 2. Si no la hay pero hay **declaración**, manda la declaración. Es el
///    respaldo para las cuentas creadas antes de la feature 006, que solo
///    tienen eso (decisión D2).
/// 3. Si no hay ninguna de las dos, **menor**.
///
/// El paso 3 no es cautela decorativa. **El error de pedir un consentimiento
/// que no hacía falta se arregla; el de no pedirlo, no.**
bool necesitaAcudiente({
  required DateTime? nacimiento,
  required bool? declaraSerMayorDeEdad,
  required DateTime referencia,
}) {
  final menor = esMenorA(nacimiento, referencia);

  // 1. La fecha manda cuando la hay, en los dos sentidos.
  if (menor != null) return menor;

  // 2. Sin fecha, vale la declaración.
  if (declaraSerMayorDeEdad == true) return false;

  // 3. Sin nada, menor.
  return true;
}
