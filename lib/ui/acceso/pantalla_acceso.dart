/// Entrar a la app.
///
/// Dos campos y un botón. No hay nada que decidir aquí: quién eres lo resuelve
/// la capa de datos, y qué puedes hacer lo deciden las reglas de acceso.
///
/// **Esta pantalla no distingue edades.** Cualquiera entra. La categoría de un
/// nadador la declara el entrenador y se determina por habilidades, nunca por
/// la edad (sección 11.1 de la metodología 3.6.0), y el consentimiento del
/// acudiente no es una puerta de entrada: es una puerta de salida de datos.
library;

import 'package:flutter/material.dart';

/// Qué hace el botón: entrar con una cuenta que ya existe, o crear una.
enum ModoDeAcceso { entrar, crear }

/// Lo que esta pantalla pide. Quien la monta decide qué hacer con ello.
typedef Credenciales = Future<String?> Function({
  required String correo,
  required String clave,
  required ModoDeAcceso modo,
});

class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key, required this.alEnviar});

  /// Devuelve `null` si salió bien, o el mensaje a mostrar si no.
  final Credenciales alEnviar;

  @override
  State<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends State<PantallaAcceso> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();

  ModoDeAcceso _modo = ModoDeAcceso.entrar;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    final fallo = await widget.alEnviar(
      correo: _correo.text.trim(),
      clave: _clave.text,
      modo: _modo,
    );

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = fallo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final creando = _modo == ModoDeAcceso.crear;

    return Scaffold(
      appBar: AppBar(title: const Text('Planificación de natación')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formulario,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    creando ? 'Crea tu cuenta' : 'Entra a tu entrenamiento',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _correo,
                    key: const Key('campo-correo'),
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (valor) {
                      final texto = (valor ?? '').trim();
                      if (texto.isEmpty) return 'Escribe tu correo';
                      if (!texto.contains('@')) return 'Falta el @';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clave,
                    key: const Key('campo-clave'),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: (valor) {
                      if ((valor ?? '').isEmpty) return 'Escribe tu contraseña';
                      if (creando && valor!.length < 8) {
                        return 'Usa al menos 8 caracteres';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const Key('error-de-acceso'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('boton-acceso'),
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(creando ? 'Crear cuenta' : 'Entrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _enviando
                        ? null
                        : () => setState(() {
                              _modo = creando
                                  ? ModoDeAcceso.entrar
                                  : ModoDeAcceso.crear;
                              _error = null;
                            }),
                    child: Text(
                      creando
                          ? '¿Ya tienes cuenta? Entra'
                          : '¿No tienes cuenta? Créala',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
