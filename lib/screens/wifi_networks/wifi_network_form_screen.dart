// lib/screens/wifi_networks/wifi_network_form_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/wifi_network.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';

class WifiNetworkFormScreen extends StatefulWidget {
  final WifiNetwork? network;
  const WifiNetworkFormScreen({super.key, this.network});

  @override
  State<WifiNetworkFormScreen> createState() => _WifiNetworkFormScreenState();
}

class _WifiNetworkFormScreenState extends State<WifiNetworkFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  bool _obscureWifiPassword = true;
  bool _obscureAdminPassword = true;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _adminUserCtrl;
  late final TextEditingController _adminPassCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final n = widget.network;
    _nameCtrl = TextEditingController(text: n?.networkName ?? '');
    _passCtrl = TextEditingController(text: n?.password ?? '');
    _phoneCtrl = TextEditingController(text: n?.phoneNumber ?? '');
    _locCtrl = TextEditingController(text: n?.locationDevice ?? '');
    _adminUserCtrl = TextEditingController(text: n?.adminUsername ?? '');
    _adminPassCtrl = TextEditingController(text: n?.adminPassword ?? '');
    _notesCtrl = TextEditingController(text: n?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _locCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      AppHaptics.tap(context, HapticStrength.heavy);
      return;
    }
    setState(() => _saving = true);
    AppHaptics.tap(context, HapticStrength.medium);

    try {
      final item = WifiNetwork(
        id: widget.network?.id,
        networkName: _nameCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        locationDevice: _locCtrl.text.trim(),
        adminUsername: _adminUserCtrl.text.trim(),
        adminPassword: _adminPassCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        createdAt: widget.network?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (widget.network == null) {
        final id = await _db.insertWifiNetwork(item);
        await _db.logAuditActivity(
          'CREATE',
          'WifiNetwork',
          entityId: id,
          description: 'Registered Wi-Fi network "${item.networkName}"',
        );
      } else {
        await _db.updateWifiNetwork(item);
        await _db.logAuditActivity(
          'UPDATE',
          'WifiNetwork',
          entityId: item.id,
          description: 'Updated Wi-Fi network "${item.networkName}"',
        );
      }

      if (!mounted) return;
      showSnack(context, 'Wi-Fi network saved successfully');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error saving Wi-Fi network: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.network != null;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Wi-Fi Network' : 'Add Wi-Fi Network',
        subtitle: isEdit ? 'Update wireless credentials' : 'Register standalone wireless network',
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _key,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              children: [
                const SectionLabel('WIRELESS ACCESS CREDENTIALS'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Network Name (SSID) *',
                        prefixIcon: Icon(Icons.wifi_rounded, size: 20),
                        hintText: 'e.g. Headquarters-Guest-5G',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Network name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _passCtrl,
                      obscureText: _obscureWifiPassword,
                      style: credentialFont(fontSize: 15, color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Wi-Fi Password',
                        prefixIcon: const Icon(Icons.password_rounded, size: 20),
                        hintText: 'Network security passphrase',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureWifiPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _obscureWifiPassword = !_obscureWifiPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (SIM / Line)',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        hintText: 'e.g. +20 100 000 0000',
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _locCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location / Device Info',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                        hintText: 'e.g. Executive Boardroom / AP-02',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionLabel('HARDWARE ADMIN MANAGEMENT'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _adminUserCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Admin Username',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined, size: 20),
                        hintText: 'e.g. admin',
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _adminPassCtrl,
                      obscureText: _obscureAdminPassword,
                      style: credentialFont(fontSize: 15, color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Admin Password',
                        prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                        hintText: 'e.g. SecretAdminPass123!',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureAdminPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _obscureAdminPassword = !_obscureAdminPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Operational Notes',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        hintText: 'ISP fiber plan, bandwidth limit, renewal date...',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    isEdit ? 'Save Changes' : 'Save Wi-Fi Network',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
