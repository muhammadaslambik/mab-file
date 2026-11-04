import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../file_manager/application/file_manager_state.dart';
import 'vault_service.dart';

final vaultProvider = Provider<VaultService>((_) => VaultService());

class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});
  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final _pin = TextEditingController();
  bool? _setUp;
  List<VaultEntry> _entries = [];
  String? _msg;

  VaultService get _v => ref.read(vaultProvider);

  @override
  void initState() {
    super.initState();
    _v.isSetUp.then((v) => setState(() => _setUp = v));
  }

  Future<void> _reload() async {
    final l = await _v.list();
    setState(() => _entries = l);
  }

  Future<void> _submit() async {
    try {
      if (_setUp == false) {
        await _v.setUp(_pin.text);
        _setUp = true;
      } else if (!await _v.unlockWithPin(_pin.text)) {
        setState(() => _msg = 'PIN salah');
        return;
      }
      _pin.clear();
      _msg = null;
      await _reload();
    } catch (e) {
      setState(() => _msg = '$e');
    }
  }

  Future<void> _bio() async {
    if (await _v.unlockWithBiometric()) {
      await _reload();
    } else {
      setState(() => _msg = 'Biometrik gagal / belum diaktifkan');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_setUp == null) return const Center(child: CircularProgressIndicator());
    if (!_v.unlocked) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text(_setUp! ? 'Buka Secure Vault' : 'Buat PIN Vault',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                    border: const OutlineInputBorder(), labelText: 'PIN', errorText: _msg),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _submit, child: Text(_setUp! ? 'Buka' : 'Buat')),
              if (_setUp!)
                TextButton.icon(
                    onPressed: _bio,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Biometrik')),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Vault'), actions: [
        IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () {
              _v.lock();
              setState(() => _entries = []);
            }),
      ]),
      body: _entries.isEmpty
          ? const Center(child: Text('Kosong. Pilih file di Files lalu "Pindah ke Vault".'))
          : ListView(children: [
              for (final e in _entries)
                ListTile(
                  leading: const Icon(Icons.enhanced_encryption_outlined),
                  title: Text(e.name),
                  trailing: Wrap(children: [
                    IconButton(
                      tooltip: 'Keluarkan',
                      icon: const Icon(Icons.output),
                      onPressed: () async {
                        await _v.export(e, ref.read(fmProvider).path);
                        await ref.read(fmProvider.notifier).refresh();
                      },
                    ),
                    IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _v.remove(e);
                        await _reload();
                      },
                    ),
                  ]),
                ),
            ]),
    );
  }
}
