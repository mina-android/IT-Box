import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/mifi.dart';
import '../../widgets/common_widgets.dart';

const Color _mifiColor = Color(0xFFD97706);

class MiFiFormScreen extends StatefulWidget {
  final MiFi? mifi;
  const MiFiFormScreen({super.key, this.mifi});
  @override
  State<MiFiFormScreen> createState() => _MiFiFormScreenState();
}

class _MiFiFormScreenState extends State<MiFiFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  bool _showWifi = false;
  bool _showAdmin = false;

  late final _num =
      TextEditingController(text: widget.mifi?.deviceNumber ?? '');
  late final _model = TextEditingController(text: widget.mifi?.model ?? '');
  late final _phone =
      TextEditingController(text: widget.mifi?.phoneNumber ?? '');
  late final _wifi = TextEditingController(text: widget.mifi?.wifiName ?? '');
  late final _wifiPass =
      TextEditingController(text: widget.mifi?.wifiPassword ?? '');
  late final _quota = TextEditingController(text: widget.mifi?.quota ?? '');
  late final _provider =
      TextEditingController(text: widget.mifi?.serviceProvider ?? '');
  late final _gateway =
      TextEditingController(text: widget.mifi?.gateway ?? '');
  late final _adminPass =
      TextEditingController(text: widget.mifi?.adminPassword ?? '');
  late final _tag = TextEditingController(text: widget.mifi?.tag ?? '');
  late bool _excludeBorrowing = widget.mifi?.excludeFromBorrowing ?? false;

  @override
  void dispose() {
    for (final c in [
      _num,
      _model,
      _phone,
      _wifi,
      _wifiPass,
      _quota,
      _provider,
      _gateway,
      _adminPass,
      _tag
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _saving = true);
    try {
      final tag = _num.text.trim();
      final existing = await _db.getMiFis();
      if (existing.any((e) => e.id != widget.mifi?.id && e.deviceNumber.trim().toLowerCase() == tag.toLowerCase())) {
        if (!mounted) {
          return;
        }
        _shakeKey.currentState?.shake();
        showSnack(context, 'MiFi number "$tag" already exists.', error: true);
        setState(() => _saving = false);
        return;
      }

      final m = MiFi(
        id: widget.mifi?.id,
        deviceNumber: tag,
        model: _model.text.trim(),
        phoneNumber: _phone.text.trim(),
        wifiName: _wifi.text.trim(),
        wifiPassword: _wifiPass.text,
        quota: _quota.text.trim(),
        serviceProvider: _provider.text.trim(),
        gateway: _gateway.text.trim(),
        adminPassword: _adminPass.text,
        status: widget.mifi?.status ?? 'Available',
        excludeFromBorrowing: _excludeBorrowing,
        tag: _tag.text.trim(),
        notes: widget.mifi?.notes ?? '',
      );
      if (widget.mifi == null) {
        await _db.insertMiFi(m);
      } else {
        await _db.updateMiFi(m);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'MiFi saved successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.mifi == null;

    return Scaffold(
      appBar: FintechAppBar(
        title: isNew ? 'Add MiFi' : 'Edit MiFi',
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _key,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const SectionLabel('DEVICE IDENTITY'),
                FintechGroupedCard(
                  children: [
                    _buildField(
                      controller: _num,
                      label: 'Device Tag / Number *',
                      icon: Icons.tag_rounded,
                      required: true,
                    ),
                    _buildField(
                      controller: _model,
                      label: 'Model *',
                      icon: Icons.wifi_tethering_rounded,
                      required: true,
                    ),
                    _buildField(
                      controller: _tag,
                      label: 'Identifier Tag (Optional)',
                      icon: Icons.label_outline_rounded,
                    ),
                  ],
                ),

                const SectionLabel('SIM & CARRIER'),
                FintechGroupedCard(
                  children: [
                    _buildField(
                      controller: _phone,
                      label: 'SIM / Phone Number',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    _buildField(
                      controller: _provider,
                      label: 'Network Carrier / ISP',
                      icon: Icons.cell_tower_rounded,
                    ),
                    _buildField(
                      controller: _quota,
                      label: 'Monthly Data Quota (e.g. 50 GB)',
                      icon: Icons.data_usage_rounded,
                    ),
                    _buildField(
                      controller: _gateway,
                      label: 'Management Gateway IP',
                      icon: Icons.alt_route_rounded,
                    ),
                  ],
                ),

                const SectionLabel('WIFI CREDENTIALS'),
                FintechGroupedCard(
                  children: [
                    _buildField(
                      controller: _wifi,
                      label: 'Hotspot SSID Name',
                      icon: Icons.wifi_rounded,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppTextField(
                        controller: _wifiPass,
                        obscureText: !_showWifi,
                        decoration: InputDecoration(
                          labelText: 'Hotspot WiFi Password',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showWifi
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                            ),
                            onPressed: () =>
                                setState(() => _showWifi = !_showWifi),
                          ),
                        ),
                      ),
                    ),
                    AppTextField(
                      controller: _adminPass,
                      obscureText: !_showAdmin,
                      decoration: InputDecoration(
                        labelText: 'Admin Web Console Password',
                        prefixIcon: const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showAdmin
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                          ),
                          onPressed: () =>
                              setState(() => _showAdmin = !_showAdmin),
                        ),
                      ),
                    ),
                  ],
                ),

                const SectionLabel('BORROWING POLICY'),
                FintechGroupedCard(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Exclude from Borrowing',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Keep as permanent office hotspot, not available for employee checkout',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _excludeBorrowing,
                      onChanged: (v) => setState(() => _excludeBorrowing = v),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      isNew ? 'Save MiFi' : 'Update MiFi',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _mifiColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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
