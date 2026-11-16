import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/network_device.dart';
import '../../widgets/common_widgets.dart';

class NetworkDeviceFormScreen extends StatefulWidget {
  final NetworkDevice? device;
  const NetworkDeviceFormScreen({super.key, this.device});
  @override
  State<NetworkDeviceFormScreen> createState() => _NetworkDeviceFormScreenState();
}

class _NetworkDeviceFormScreenState extends State<NetworkDeviceFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  bool _showWifiPass = false;
  bool _showAdminPass = false;

  late final _num =
      TextEditingController(text: widget.device?.deviceNumber ?? '');
  late final _model = TextEditingController(text: widget.device?.model ?? '');
  late final _phone =
      TextEditingController(text: widget.device?.phoneNumber ?? '');
  late final _loc =
      TextEditingController(text: widget.device?.deviceLocation ?? '');
  late final _provider =
      TextEditingController(text: widget.device?.serviceProvider ?? '');
  late final _wifi =
      TextEditingController(text: widget.device?.wifiName ?? '');
  late final _wifiPass =
      TextEditingController(text: widget.device?.wifiPassword ?? '');
  late final _gateway =
      TextEditingController(text: widget.device?.gateway ?? '');
  late final _adminPass =
      TextEditingController(text: widget.device?.adminPassword ?? '');

  @override
  void dispose() {
    for (final c in [
      _num,
      _model,
      _phone,
      _loc,
      _provider,
      _wifi,
      _wifiPass,
      _gateway,
      _adminPass
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
      final d = NetworkDevice(
        id: widget.device?.id,
        deviceNumber: _num.text.trim(),
        model: _model.text.trim(),
        phoneNumber: _phone.text.trim(),
        deviceLocation: _loc.text.trim(),
        serviceProvider: _provider.text.trim(),
        wifiName: _wifi.text.trim(),
        wifiPassword: _wifiPass.text,
        gateway: _gateway.text.trim(),
        adminPassword: _adminPass.text,
        status: widget.device?.status ?? 'Available',
      );
      if (widget.device == null) {
        await _db.insertNetworkDevice(d);
      } else {
        await _db.updateNetworkDevice(d);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'Device saved successfully!');
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
    final isNew = widget.device == null;

    return Scaffold(
      appBar: FintechAppBar(
        title: isNew ? 'Add Network Device' : 'Edit Network Device',
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
                      label: 'Device Number *',
                      icon: Icons.tag_rounded,
                      required: true,
                    ),
                    _buildField(
                      controller: _model,
                      label: 'Model / Brand *',
                      icon: Icons.router_rounded,
                      required: true,
                    ),
                  ],
                ),

                const SectionLabel('CARRIER & LOCATION'),
                FintechGroupedCard(
                  children: [
                    _buildField(
                      controller: _phone,
                      label: 'SIM / Phone Number',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    _buildField(
                      controller: _loc,
                      label: 'Installation Location',
                      icon: Icons.location_on_outlined,
                    ),
                    _buildField(
                      controller: _provider,
                      label: 'Service Provider / ISP',
                      icon: Icons.cell_tower_rounded,
                    ),
                    _buildField(
                      controller: _gateway,
                      label: 'Default Gateway (e.g. 192.168.1.1)',
                      icon: Icons.alt_route_rounded,
                    ),
                  ],
                ),

                const SectionLabel('WIFI & PASSWORDS'),
                FintechGroupedCard(
                  children: [
                    _buildField(
                      controller: _wifi,
                      label: 'WiFi SSID Name',
                      icon: Icons.wifi_rounded,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppTextField(
                        controller: _wifiPass,
                        obscureText: !_showWifiPass,
                        decoration: InputDecoration(
                          labelText: 'WiFi Password',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showWifiPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                            ),
                            onPressed: () => setState(
                                () => _showWifiPass = !_showWifiPass),
                          ),
                        ),
                      ),
                    ),
                    AppTextField(
                      controller: _adminPass,
                      obscureText: !_showAdminPass,
                      decoration: InputDecoration(
                        labelText: 'Router Admin Password',
                        prefixIcon: const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showAdminPass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                          ),
                          onPressed: () => setState(
                              () => _showAdminPass = !_showAdminPass),
                        ),
                      ),
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
                      isNew ? 'Save Router' : 'Update Router',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
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
