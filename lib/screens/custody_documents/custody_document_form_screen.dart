// lib/screens/custody_documents/custody_document_form_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import '../../database/database_helper.dart';
import '../../models/custody_document.dart';
import '../../models/employee.dart';
import '../../services/custody_pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class _EditableCustodyItem {
  String deviceType;
  final TextEditingController nameCtrl;
  final TextEditingController numberCtrl;
  final TextEditingController serialCtrl;
  String condition;
  final List<(TextEditingController, TextEditingController)> specs;

  _EditableCustodyItem({
    this.deviceType = 'Laptop',
    String name = '',
    String number = '',
    String serial = '',
    this.condition = 'Good / Verified',
    Map<String, String> extraSpecs = const {},
  })  : nameCtrl = TextEditingController(text: name),
        numberCtrl = TextEditingController(text: number),
        serialCtrl = TextEditingController(text: serial),
        specs = extraSpecs.entries
            .map((e) => (TextEditingController(text: e.key), TextEditingController(text: e.value)))
            .toList();

  void dispose() {
    nameCtrl.dispose();
    numberCtrl.dispose();
    serialCtrl.dispose();
    for (final pair in specs) {
      pair.$1.dispose();
      pair.$2.dispose();
    }
  }

  CustodyItem toCustodyItem() {
    final map = <String, String>{};
    for (final pair in specs) {
      final k = pair.$1.text.trim();
      final v = pair.$2.text.trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        map[k] = v;
      }
    }
    return CustodyItem(
      deviceType: deviceType,
      deviceName: nameCtrl.text.trim(),
      deviceNumber: numberCtrl.text.trim(),
      serialNumber: serialCtrl.text.trim(),
      condition: condition,
      extraSpecs: map,
    );
  }
}

class CustodyDocumentFormScreen extends StatefulWidget {
  final CustodyDocument? existing;
  const CustodyDocumentFormScreen({super.key, this.existing});

  @override
  State<CustodyDocumentFormScreen> createState() => _CustodyDocumentFormScreenState();
}

class _CustodyDocumentFormScreenState extends State<CustodyDocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();

  late final TextEditingController _docNumCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _empNameCtrl;
  late final TextEditingController _empPhoneCtrl;
  late final TextEditingController _empEmailCtrl;
  late final TextEditingController _handoverCtrl;
  late final TextEditingController _dueCtrl;
  late final TextEditingController _agreementCtrl;
  late final TextEditingController _notesCtrl;
  late final SignatureController _sigCtrl;

  List<Employee> _employees = [];
  bool _useCustomRecipient = true;
  int? _selectedEmpId;
  bool _saving = false;
  final List<_EditableCustodyItem> _items = [];

  static const _deviceTypes = [
    'Laptop',
    'Router',
    'MiFi',
    'Access Point',
    'Printer',
    'Electronic',
    'Other',
    'Access Badge / Key',
  ];

  static const _conditions = [
    'New / Sealed',
    'Good / Verified',
    'Fair / Operational',
    'Needs Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _docNumCtrl = TextEditingController(
      text: ex?.documentNumber ?? CustodyDocument.generateDocumentNumber(),
    );
    _titleCtrl = TextEditingController(
      text: ex?.title ?? 'Equipment Custody Receipt',
    );
    _empNameCtrl = TextEditingController(text: ex?.employeeName ?? '');
    _empPhoneCtrl = TextEditingController(text: ex?.employeePhone ?? '');
    _empEmailCtrl = TextEditingController(text: ex?.employeeEmail ?? '');
    _handoverCtrl = TextEditingController(
      text: ex?.handoverDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _dueCtrl = TextEditingController(text: ex?.dueDate ?? '');
    _agreementCtrl = TextEditingController(
      text: (ex != null && ex.agreementText.isNotEmpty)
          ? ex.agreementText
          : CustodyDocument.defaultAgreementText,
    );
    _notesCtrl = TextEditingController(text: ex?.adminNotes ?? '');
    _sigCtrl = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    if (ex != null && ex.items.isNotEmpty) {
      for (final item in ex.items) {
        _items.add(_EditableCustodyItem(
          deviceType: _deviceTypes.contains(item.deviceType) ? item.deviceType : 'Other',
          name: item.deviceName,
          number: item.deviceNumber,
          serial: item.serialNumber,
          condition: _conditions.contains(item.condition) ? item.condition : 'Good / Verified',
          extraSpecs: item.extraSpecs,
        ));
      }
    } else {
      _items.add(_EditableCustodyItem());
    }

    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final emps = await _db.getEmployees();
    if (!mounted) {
      return;
    }
    setState(() {
      _employees = emps;
      if (widget.existing == null && emps.isNotEmpty) {
        _useCustomRecipient = false;
      } else if (widget.existing != null) {
        final match = emps
            .where((e) => e.name.toLowerCase() == widget.existing!.employeeName.toLowerCase())
            .firstOrNull;
        if (match != null) {
          _useCustomRecipient = false;
          _selectedEmpId = match.id;
        }
      }
    });
  }

  Future<void> _onEmployeeSelected(int? empId) async {
    if (empId == null) {
      return;
    }
    final emp = _employees.where((e) => e.id == empId).firstOrNull;
    if (emp == null) {
      return;
    }
    final emails = await _db.getEmailAccounts();
    final emailAcc = emails
        .where((ea) => ea.employeeId == emp.id || ea.employeeName.toLowerCase() == emp.name.toLowerCase())
        .firstOrNull;
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedEmpId = emp.id;
      _empNameCtrl.text = emp.name;
      _empPhoneCtrl.text = emp.phoneNumber;
      _empEmailCtrl.text = emailAcc?.email ?? '';
    });
  }

  Future<void> _pickInventoryItem() async {
    final results = await Future.wait([
      _db.getLaptops(),
      _db.getNetworkDevices(),
      _db.getMiFis(),
      _db.getAccessPoints(),
      _db.getPrinters(),
      _db.getElectronics(),
      _db.getOtherDevices(),
    ]);
    if (!mounted) {
      return;
    }

    final candidates = <_EditableCustodyItem>[];
    for (final l in results[0] as List) {
      candidates.add(_EditableCustodyItem(
        deviceType: 'Laptop',
        name: l.model,
        number: l.laptopNumber,
        serial: l.laptopNumber,
        condition: _conditions.contains(l.condition) ? l.condition : 'Good / Verified',
        extraSpecs: {
          if ((l.cpu as String).isNotEmpty) 'CPU': l.cpu,
          if ((l.ram as String).isNotEmpty) 'RAM': l.ram,
          if ((l.storage as String).isNotEmpty) 'Storage': l.storage,
        },
      ));
    }
    for (final d in results[1] as List) {
      candidates.add(_EditableCustodyItem(
        deviceType: 'Router',
        name: d.model,
        number: d.deviceNumber,
        serial: d.deviceNumber,
        extraSpecs: {
          if ((d.deviceLocation as String).isNotEmpty) 'Location': d.deviceLocation,
          if ((d.serviceProvider as String).isNotEmpty) 'Provider': d.serviceProvider,
        },
      ));
    }
    for (final m in results[2] as List) {
      candidates.add(_EditableCustodyItem(
        deviceType: 'MiFi',
        name: m.model,
        number: m.deviceNumber,
        serial: m.tag,
        extraSpecs: {
          if ((m.phoneNumber as String).isNotEmpty) 'Phone': m.phoneNumber,
          if ((m.serviceProvider as String).isNotEmpty) 'Provider': m.serviceProvider,
        },
      ));
    }
    for (final ap in results[3] as List) {
      candidates.add(_EditableCustodyItem(
        deviceType: 'Access Point',
        name: ap.model,
        number: ap.deviceNumber,
        serial: ap.deviceNumber,
        extraSpecs: {
          if ((ap.location as String).isNotEmpty) 'Location': ap.location,
        },
      ));
    }
    for (final p in results[4] as List) {
      candidates.add(_EditableCustodyItem(
        deviceType: 'Printer',
        name: p.model,
        number: p.printerNumber,
        serial: p.printerNumber,
        extraSpecs: {
          if ((p.location as String).isNotEmpty) 'Location': p.location,
        },
      ));
    }
    for (final e in results[5] as List) {
      candidates.add(_EditableCustodyItem(
        deviceType: 'Electronic',
        name: e.deviceName,
        number: e.deviceNumber,
        serial: e.deviceNumber,
        extraSpecs: {
          if ((e.details as String).isNotEmpty) 'Details': e.details,
        },
      ));
    }
    for (final o in results[6] as List) {
      candidates.add(_EditableCustodyItem(
        deviceType: 'Other',
        name: o.deviceName,
        number: o.model,
        serial: o.model,
        extraSpecs: {
          if ((o.deviceType as String).isNotEmpty) 'Category': o.deviceType,
        },
      ));
    }

    if (candidates.isEmpty) {
      for (final c in candidates) {
        c.dispose();
      }
      showSnack(context, 'No inventory hardware found to pick from.', error: true);
      return;
    }

    final searchCtrl = TextEditingController();
    final picked = await showFintechBottomSheet<_EditableCustodyItem>(
      context: context,
      title: 'Pick from Inventory',
      subtitle: 'Auto-fill hardware details & specifications',
      child: StatefulBuilder(
        builder: (ctx, setS) {
          final q = searchCtrl.text.trim().toLowerCase();
          final list = q.isEmpty
              ? candidates
              : candidates
                  .where((c) =>
                      c.nameCtrl.text.toLowerCase().contains(q) ||
                      c.numberCtrl.text.toLowerCase().contains(q) ||
                      c.deviceType.toLowerCase().contains(q))
                  .toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Search inventory...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setS(() {}),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No matching inventory hardware found.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.35,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final item = list[i];
                          final typeColor = switch (item.deviceType) {
                            'Laptop' => AppColors.laptopColor,
                            'Router' => AppColors.networkColor,
                            'MiFi' => const Color(0xFF0EA5E9),
                            'Access Point' => const Color(0xFF0891B2),
                            'Printer' => AppColors.printerColor,
                            'Electronic' => AppColors.electronicColor,
                            _ => const Color(0xFF0D9488),
                          };
                          final typeIcon = switch (item.deviceType) {
                            'Laptop' => Icons.laptop_mac_rounded,
                            'Router' => Icons.router_rounded,
                            'MiFi' => Icons.wifi_tethering_rounded,
                            'Access Point' => Icons.cell_tower_rounded,
                            'Printer' => Icons.print_rounded,
                            'Electronic' => Icons.devices_rounded,
                            _ => Icons.devices_other_rounded,
                          };
                          return InventoryGridCard(
                            selected: false,
                            leading: IconBox(
                              icon: typeIcon,
                              color: typeColor,
                              size: 32,
                            ),
                            title: item.nameCtrl.text,
                            subtitle: item.numberCtrl.text.isNotEmpty
                                ? '# ${item.numberCtrl.text}'
                                : item.deviceType,
                            extra: item.deviceType,
                            onTap: () => Navigator.pop(ctx, item),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
    Future.delayed(const Duration(milliseconds: 350), searchCtrl.dispose);

    for (final c in candidates) {
      if (c != picked) {
        c.dispose();
      }
    }
    if (picked != null && mounted) {
      setState(() {
        if (_items.length == 1 &&
            _items.first.nameCtrl.text.trim().isEmpty &&
            _items.first.numberCtrl.text.trim().isEmpty) {
          _items.first.dispose();
          _items[0] = picked;
        } else {
          _items.add(picked);
        }
      });
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final initial = DateTime.tryParse(ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final validItems = _items
        .map((e) => e.toCustodyItem())
        .where((it) => it.deviceName.isNotEmpty)
        .toList();
    if (validItems.isEmpty) {
      showSnack(context, 'Add at least one equipment item with a name.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      String sigB64 = widget.existing?.signatureBase64 ?? '';
      if (_sigCtrl.isNotEmpty) {
        final sigBytes = await _sigCtrl.toPngBytes();
        if (sigBytes != null) {
          sigB64 = base64Encode(sigBytes);
        }
      }

      var doc = CustodyDocument(
        id: widget.existing?.id,
        documentNumber: _docNumCtrl.text.trim(),
        title: _titleCtrl.text.trim().isEmpty ? 'Equipment Custody Receipt' : _titleCtrl.text.trim(),
        sourceType: widget.existing?.sourceType ?? 'custom',
        sourceId: widget.existing?.sourceId,
        employeeName: _empNameCtrl.text.trim(),
        employeePhone: _empPhoneCtrl.text.trim(),
        employeeEmail: _empEmailCtrl.text.trim(),
        handoverDate: _handoverCtrl.text.trim(),
        dueDate: _dueCtrl.text.trim(),
        itemsJson: CustodyDocument.encodeItems(validItems),
        agreementText: _agreementCtrl.text.trim(),
        adminNotes: _notesCtrl.text.trim(),
        signatureBase64: sigB64,
        createdAt: widget.existing?.createdAt ?? DateTime.now().toIso8601String(),
      );

      final pdfFile = await CustodyPdfService.generateAndSaveCustodyDocumentPdf(doc);
      doc = doc.copyWith(pdfPath: pdfFile.path);

      if (doc.id == null) {
        await _db.insertCustodyDocument(doc);
      } else {
        await _db.updateCustodyDocument(doc);
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to save custody document: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _docNumCtrl.dispose();
    _titleCtrl.dispose();
    _empNameCtrl.dispose();
    _empPhoneCtrl.dispose();
    _empEmailCtrl.dispose();
    _handoverCtrl.dispose();
    _dueCtrl.dispose();
    _agreementCtrl.dispose();
    _notesCtrl.dispose();
    _sigCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: FintechAppBar(
        title: widget.existing == null ? 'New Custody Document' : 'Edit Custody Document',
        subtitle: 'Custom or inventory-linked receipt',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            const SectionLabel('DOCUMENT METADATA'),
            AppTextField(
              controller: _docNumCtrl,
              decoration: const InputDecoration(
                labelText: 'Document Number *',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
              style: credentialFont(),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Document Title *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel('RECIPIENT INFORMATION'),
                if (_employees.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _useCustomRecipient = !_useCustomRecipient),
                    child: Text(_useCustomRecipient ? 'Pick Employee' : 'Custom Recipient'),
                  ),
              ],
            ),
            if (!_useCustomRecipient && _employees.isNotEmpty) ...[
              InkWell(
                onTap: () async {
                  final picked = await showFintechEmployeePicker(
                    context: context,
                    employees: _employees,
                    selectedEmployeeId: _selectedEmpId,
                    title: 'Select Recipient (Employee)',
                  );
                  if (picked?.employee != null && mounted) {
                    await _onEmployeeSelected(picked!.employee!.id);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Select Employee *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    suffixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                  child: Text(
                    () {
                      final emp = _employees.where((e) => e.id == _selectedEmpId).firstOrNull;
                      if (emp != null) {
                        return emp.phoneNumber.isNotEmpty
                            ? '${emp.name} (${emp.phoneNumber})'
                            : emp.name;
                      }
                      return 'Tap to search employee directory...';
                    }(),
                    style: TextStyle(
                      fontWeight: _selectedEmpId != null ? FontWeight.w700 : FontWeight.normal,
                      color: _selectedEmpId != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            AppTextField(
              controller: _empNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Recipient Full Name *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Recipient name is required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _empPhoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: _empEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: credentialFont(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel('EQUIPMENT ITEMS (${_items.length})'),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _pickInventoryItem,
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('Inventory'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _items.add(_EditableCustodyItem())),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Custom'),
                    ),
                  ],
                ),
              ],
            ),
            for (int i = 0; i < _items.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Item #${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        if (_items.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                final removed = _items.removeAt(i);
                                removed.dispose();
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FintechDropdown<String>(
                      value: _items[i].deviceType,
                      labelText: 'Category',
                      items: _deviceTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _items[i].deviceType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: _items[i].nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Model / Item Name *',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _items[i].numberCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Asset Tag / #',
                            ),
                            style: credentialFont(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField(
                            controller: _items[i].serialCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Serial Number',
                            ),
                            style: credentialFont(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FintechDropdown<String>(
                      value: _items[i].condition,
                      labelText: 'Condition',
                      items: _conditions
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _items[i].condition = v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Custom Specs (${_items[i].specs.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _items[i].specs.add((
                                TextEditingController(),
                                TextEditingController(),
                              ));
                            });
                          },
                          icon: const Icon(Icons.add_rounded, size: 15),
                          label: const Text('Add Spec'),
                        ),
                      ],
                    ),
                    for (int s = 0; s < _items[i].specs.length; s++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _items[i].specs[s].$1,
                                decoration: const InputDecoration(
                                  labelText: 'Key (e.g. RAM)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppTextField(
                                controller: _items[i].specs[s].$2,
                                decoration: const InputDecoration(
                                  labelText: 'Value (e.g. 16GB)',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  final removed = _items[i].specs.removeAt(s);
                                  removed.$1.dispose();
                                  removed.$2.dispose();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            const SectionLabel('DATES, TERMS & SIGNATURE'),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _handoverCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Handover Date *',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    readOnly: true,
                    onTap: () => _pickDate(_handoverCtrl),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: _dueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Due Date (Optional)',
                      prefixIcon: Icon(Icons.event_rounded),
                    ),
                    readOnly: true,
                    onTap: () => _pickDate(_dueCtrl),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _agreementCtrl,
              decoration: const InputDecoration(
                labelText: 'Compliance & Agreement Text',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Administrator Notes (Optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recipient Signature (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                TextButton.icon(
                  onPressed: () => _sigCtrl.clear(),
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Signature(
                  controller: _sigCtrl,
                  height: 150,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_saving ? 'Generating PDF...' : 'Save & Generate PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
