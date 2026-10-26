// lib/screens/search/global_search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/global_search_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchService = GlobalSearchService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<SearchResultItem> _results = [];
  bool _searching = false;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _executeSearch();
    });
  }

  Future<void> _executeSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _searching = false;
        });
      }
      return;
    }

    setState(() => _searching = true);
    final items = await _searchService.search(query);
    if (!mounted) return;
    setState(() {
      _results = items;
      _searching = false;
    });
  }

  Color _categoryColor(SearchCategory cat) {
    switch (cat) {
      case SearchCategory.laptop: return AppColors.laptopColor;
      case SearchCategory.networkDevice: return AppColors.networkColor;
      case SearchCategory.printer: return AppColors.printerColor;
      case SearchCategory.mifi: return const Color(0xFFD97706);
      case SearchCategory.electronic: return AppColors.electronicColor;
      case SearchCategory.employee: return AppColors.employeeColor;
      case SearchCategory.email: return const Color(0xFF0EA5E9);
      case SearchCategory.staticIp: return const Color(0xFF06B6D4);
      case SearchCategory.vendorContact: return AppColors.vendorColor;
    }
  }

  IconData _categoryIcon(SearchCategory cat) {
    switch (cat) {
      case SearchCategory.laptop: return Icons.laptop_mac_rounded;
      case SearchCategory.networkDevice: return Icons.router_rounded;
      case SearchCategory.printer: return Icons.print_rounded;
      case SearchCategory.mifi: return Icons.wifi_tethering_rounded;
      case SearchCategory.electronic: return Icons.devices_other_rounded;
      case SearchCategory.employee: return Icons.person_rounded;
      case SearchCategory.email: return Icons.email_rounded;
      case SearchCategory.staticIp: return Icons.lan_rounded;
      case SearchCategory.vendorContact: return Icons.contact_phone_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final categories = ['All', ..._results.map((r) => r.categoryLabel).toSet()];

    final filteredResults = _selectedCategory == 'All'
        ? _results
        : _results.where((r) => r.categoryLabel == _selectedCategory).toList();

    return Scaffold(
      appBar: const FintechAppBar(
        title: 'Global Search',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar2(
              hint: 'Search laptops, IPs, staff, vendors, serials…',
              controller: _searchCtrl,
            ),
          ),
          if (_results.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  final count = cat == 'All'
                      ? _results.length
                      : _results.where((r) => r.categoryLabel == cat).length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('$cat ($count)'),
                      selected: isSelected,
                      onSelected: (_) {
                        AppHaptics.tap(context, HapticStrength.selection);
                        setState(() => _selectedCategory = cat);
                      },
                      selectedColor: cs.primary.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? cs.primary : cs.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: _searching
                ? const ShimmerListLoader()
                : _searchCtrl.text.trim().isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.manage_search_rounded, size: 72, color: cs.primary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Type anywhere to search across all 21 IT tables.',
                              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      )
                    : filteredResults.isEmpty
                        ? Center(
                            child: Text(
                              'No matching assets or records found.',
                              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredResults.length,
                            itemBuilder: (ctx, i) {
                              final item = filteredResults[i];
                              final color = _categoryColor(item.category);
                              final icon = _categoryIcon(item.category);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardSurface(context),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(icon, color: color, size: 22),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.categoryLabel,
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.subtitle,
                                            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
                                          ),
                                          if (item.extraInfo.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              item.extraInfo,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: cs.onSurface.withValues(alpha: 0.5),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
