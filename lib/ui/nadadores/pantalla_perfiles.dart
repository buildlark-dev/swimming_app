/// Pantalla de perfiles de nadador.
///
/// Señala los datos obligatorios que faltan: categoría y estilo objetivo, sin
/// los cuales no se puede validar ni el volumen ni la distribución de estilos.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class PantallaPerfiles extends StatefulWidget {
  const PantallaPerfiles({super.key, required this.repositorio});

  final RepositorioNadadores repositorio;

  @override
  State<PantallaPerfiles> createState() => _PantallaPerfilesState();
}

class _PantallaPerfilesState extends State<PantallaPerfiles> {
  List<Nadador> _nadadores = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _recargar() async {
    final nadadores = await widget.repositorio.listar();
    if (!mounted) return;
    setState(() {
      _nadadores = nadadores;
      _cargando = false;
    });
  }

  Future<void> _nuevoPerfil() async {
    final nadador = await showDialog<Nadador>(
      context: context,
      builder: (_) => const _DialogoPerfil(),
    );
    if (nadador == null) return;

    await widget.repositorio.guardar(nadador);
    await _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nadadores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoPerfil,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo perfil'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_nadadores.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Todavía no hay perfiles')),
                  ),
                for (final nadador in _nadadores)
                  _TarjetaPerfil(nadador: nadador),
              ],
            ),
    );
  }
}

class _TarjetaPerfil extends StatelessWidget {
  const _TarjetaPerfil({required this.nadador});

  final Nadador nadador;

  @override
  Widget build(BuildContext context) {
    final faltas = nadador.faltas;

    return Card(
      child: ListTile(
        leading: Icon(
          nadador.estaCompleto ? Icons.person : Icons.person_outline,
          color: nadador.estaCompleto
              ? null
              : Theme.of(context).colorScheme.error,
        ),
        title: Text(nadador.nombre.isEmpty ? 'Sin nombre' : nadador.nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (nadador.categoria != null) nadador.categoria!.nombre,
                if (nadador.estiloObjetivo != null)
                  nadador.estiloObjetivo!.nombre,
                if (nadador.pruebaObjetivo.isNotEmpty) nadador.pruebaObjetivo,
              ].join(' · '),
            ),
            for (final falta in faltas)
              Text(
                falta.descripcion,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogoPerfil extends StatefulWidget {
  const _DialogoPerfil();

  @override
  State<_DialogoPerfil> createState() => _DialogoPerfilState();
}

class _DialogoPerfilState extends State<_DialogoPerfil> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _prueba = TextEditingController();
  Categoria? _categoria;
  Estilo? _estilo;

  @override
  void dispose() {
    _nombre.dispose();
    _prueba.dispose();
    super.dispose();
  }

  Nadador get _nadador => Nadador(
        nombre: _nombre.text.trim(),
        categoria: _categoria,
        estiloObjetivo: _estilo,
        pruebaObjetivo: _prueba.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final faltas = _nadador.faltas;

    return AlertDialog(
      title: const Text('Nuevo perfil'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Categoria>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final categoria in Categoria.values)
                  DropdownMenuItem(
                    value: categoria,
                    child: Text(categoria.nombre),
                  ),
              ],
              onChanged: (valor) => setState(() => _categoria = valor),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Estilo>(
              initialValue: _estilo,
              decoration: const InputDecoration(labelText: 'Estilo objetivo'),
              items: [
                for (final estilo in [
                  Estilo.libre,
                  Estilo.espalda,
                  Estilo.pecho,
                  Estilo.mariposa,
                  Estilo.combinado,
                ])
                  DropdownMenuItem(value: estilo, child: Text(estilo.nombre)),
              ],
              onChanged: (valor) => setState(() => _estilo = valor),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prueba,
              decoration: const InputDecoration(
                labelText: 'Prueba objetivo',
                hintText: '100 Libre',
              ),
            ),
            const SizedBox(height: 12),
            for (final falta in faltas)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  falta.descripcion,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              faltas.isEmpty ? () => Navigator.of(context).pop(_nadador) : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
