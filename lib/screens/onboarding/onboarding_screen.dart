import 'package:flutter/material.dart';
import '../../services/company_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = TextEditingController();
  final _key  = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _done() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    await CompanyService().completeOnboarding(_ctrl.text.trim());
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Logo
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    size: 52, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 28),
              Text('Welcome to Inventorya',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Enter your company name to get started',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 40),
              Form(
                key: _key,
                child: TextFormField(
                  controller: _ctrl,
                  enableSuggestions: false,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Company Name *',
                    hintText: 'e.g. RADA Technology',
                    prefixIcon: Icon(Icons.business_outlined,
                        color: theme.colorScheme.primary),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter your company name' : null,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _done,
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward_outlined),
                  label: const Text('Get Started'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
