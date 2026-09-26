import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../app/theme.dart';
import '../services/admin_service.dart';

class AdminSystemSettingsScreen extends StatefulWidget {
  final UserModel user;
  const AdminSystemSettingsScreen({super.key, required this.user});

  @override
  State<AdminSystemSettingsScreen> createState() =>
      _AdminSystemSettingsScreenState();
}

class _AdminSystemSettingsScreenState extends State<AdminSystemSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Modules State
  List<Map<String, dynamic>> _modules = [];
  final Map<String, bool> _updatingModules = {};

  // AI Config State
  String _aiProvider = 'gemini';
  String _selectedModel = 'gemini-1.5-flash';
  final _apiKeyController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _customEndpointController = TextEditingController();
  double _temperature = 0.7;
  int _maxTokens = 2048;
  bool _hasSavedApiKey = false;
  String _maskedApiKey = '';
  bool _obscureApiKey = true;
  bool _isSavingAi = false;
  bool _isTestingAi = false;
  String? _testResultStatus;
  String? _testResultMessage;

  Map<String, List<Map<String, String>>> _availableModels = {
    'gemini': [
      {'id': 'gemini-1.5-flash', 'name': 'Google Gemini 1.5 Flash (Cepat & Hemat Kuota)'},
      {'id': 'gemini-1.5-pro', 'name': 'Google Gemini 1.5 Pro (Kemampuan Analisis Tinggi)'},
      {'id': 'gemini-2.0-flash', 'name': 'Google Gemini 2.0 Flash (Next-Gen Ultrafast)'},
      {'id': 'gemini-2.5-flash', 'name': 'Google Gemini 2.5 Flash'},
    ],
    'openai': [
      {'id': 'gpt-4o-mini', 'name': 'OpenAI GPT-4o Mini (Efisiensi Tinggi)'},
      {'id': 'gpt-4o', 'name': 'OpenAI GPT-4o (Multimodal Flagship)'},
      {'id': 'gpt-3.5-turbo', 'name': 'OpenAI GPT-3.5 Turbo (Klasik)'},
    ],
    'anthropic': [
      {'id': 'claude-3-5-sonnet', 'name': 'Anthropic Claude 3.5 Sonnet (Penulisan Kreatif)'},
      {'id': 'claude-3-haiku', 'name': 'Anthropic Claude 3 Haiku (Kecepatan Tinggi)'},
    ],
    'custom': [
      {'id': 'custom-model', 'name': 'Custom Endpoint / Local LLM (Ollama / vLLM)'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    _customEndpointController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    setState(() => _isLoading = true);

    try {
      final modules = await AdminService.getModules();
      final aiConfig = await AdminService.getAiConfig();

      if (mounted) {
        setState(() {
          _modules = modules;

          if (aiConfig != null) {
            _aiProvider = aiConfig['provider'] ?? 'gemini';
            _selectedModel = aiConfig['model'] ?? 'gemini-1.5-flash';
            _hasSavedApiKey = aiConfig['has_api_key'] == true;
            _maskedApiKey = aiConfig['api_key_masked'] ?? '';
            _temperature = (aiConfig['temperature'] is num)
                ? (aiConfig['temperature'] as num).toDouble()
                : 0.7;
            _maxTokens = (aiConfig['max_tokens'] is int)
                ? aiConfig['max_tokens']
                : 2048;
            _systemPromptController.text = aiConfig['system_prompt'] ?? '';
            _customEndpointController.text = aiConfig['custom_endpoint'] ?? '';

            if (aiConfig['available_models'] is Map) {
              final rawModels = Map<String, dynamic>.from(aiConfig['available_models']);
              _availableModels = rawModels.map((k, v) {
                final list = (v as List)
                    .map((item) => Map<String, String>.from(item))
                    .toList();
                return MapEntry(k, list);
              });
            }

            if (_hasSavedApiKey && _maskedApiKey.isNotEmpty) {
              _apiKeyController.text = _maskedApiKey;
            }
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleModule(String key, bool currentVal) async {
    setState(() {
      _updatingModules[key] = true;
    });

    final newVal = !currentVal;
    final res = await AdminService.updateModule(key, newVal);

    if (mounted) {
      setState(() {
        _updatingModules.remove(key);
        if (res['status'] == true) {
          final idx = _modules.indexWhere((m) => m['key'] == key);
          if (idx != -1) {
            _modules[idx]['enabled'] = newVal;
          }
        }
      });

      if (res['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newVal ? 'Modul diaktifkan.' : 'Modul dinonaktifkan.',
            ),
            backgroundColor: newVal ? Colors.green : Colors.grey.shade800,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal mengubah status modul.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveAiSettings() async {
    setState(() => _isSavingAi = true);

    final rawKey = _apiKeyController.text.trim();
    final isMasked = rawKey.contains('•');

    final res = await AdminService.updateAiConfig(
      provider: _aiProvider,
      apiKey: isMasked ? null : rawKey,
      model: _selectedModel,
      temperature: _temperature,
      maxTokens: _maxTokens,
      systemPrompt: _systemPromptController.text.trim(),
      customEndpoint: _customEndpointController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSavingAi = false);

      if (res['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfigurasi AI Engine berhasil disimpan!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal menyimpan konfigurasi.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _isTestingAi = true;
      _testResultStatus = null;
      _testResultMessage = null;
    });

    final rawKey = _apiKeyController.text.trim();
    final isMasked = rawKey.contains('•');

    final res = await AdminService.testAiConnection(
      provider: _aiProvider,
      model: _selectedModel,
      apiKey: isMasked ? null : rawKey,
      customEndpoint: _customEndpointController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isTestingAi = false;
        _testResultStatus = res['status'] == true ? 'success' : 'error';
        _testResultMessage = res['message']?.toString() ??
            (res['status'] == true
                ? 'Koneksi berhasil!'
                : 'Gagal terhubung ke AI provider.');
      });
    }
  }

  IconData _getIconForModule(String? iconName) {
    switch (iconName) {
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'storefront':
        return Icons.storefront_rounded;
      case 'handshake':
        return Icons.handshake_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'person_add':
        return Icons.person_add_alt_1_rounded;
      case 'verified':
        return Icons.verified_user_rounded;
      case 'build':
        return Icons.build_circle_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pengaturan Sistem & Modul',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
          indicatorColor: AppTheme.primaryPurple,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.toggle_on_rounded),
              text: 'Modul & Fitur Platform',
            ),
            Tab(
              icon: Icon(Icons.auto_awesome_rounded),
              text: 'Konfigurasi AI Engine',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildModulesTab(isDark),
                _buildAiConfigTab(isDark),
              ],
            ),
    );
  }

  Widget _buildModulesTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        color: AppTheme.primaryPurple,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kendali Fitur Platform',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aktifkan atau nonaktifkan modul platform secara instan tanpa perlu restart server atau deploy ulang.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _modules.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final module = _modules[index];
                  final key = module['key'] as String;
                  final isEnabled = module['enabled'] == true;
                  final isUpdating = _updatingModules[key] == true;
                  final isMaintenance = key == 'maintenance_mode';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isMaintenance && isEnabled
                            ? Colors.red.shade400
                            : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
                        width: isMaintenance && isEnabled ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isMaintenance
                                    ? Colors.red
                                    : (isEnabled ? AppTheme.primaryPurple : Colors.grey))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getIconForModule(module['icon']),
                            color: isMaintenance
                                ? Colors.red
                                : (isEnabled ? AppTheme.primaryPurple : Colors.grey),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    module['name'] ?? key,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isEnabled
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isEnabled ? 'AKTIF' : 'NONAKTIF',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isEnabled ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                module['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        isUpdating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch(
                                value: isEnabled,
                                activeThumbColor: isMaintenance ? Colors.red : AppTheme.primaryPurple,
                                onChanged: (val) => _toggleModule(key, isEnabled),
                              ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiConfigTab(bool isDark) {
    final currentModelList = _availableModels[_aiProvider] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Box ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryPurple.withValues(alpha: 0.15),
                      Colors.indigo.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kreavana AI Engine Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Atur provider AI (Google Gemini, OpenAI, Claude), model yang dipakai, dan API key secara terpusat untuk seluruh fitur asisten cerdas.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 1. Provider Selector ──
              _buildSectionTitle('1. Pilih AI Provider', isDark),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildProviderCard(
                    id: 'gemini',
                    title: 'Google Gemini',
                    subtitle: 'Direkomendasikan (Multimodal, Cepat)',
                    icon: Icons.auto_awesome,
                    badge: 'Populer',
                    isDark: isDark,
                  ),
                  _buildProviderCard(
                    id: 'openai',
                    title: 'OpenAI',
                    subtitle: 'GPT-4o, GPT-4o Mini',
                    icon: Icons.psychology_rounded,
                    isDark: isDark,
                  ),
                  _buildProviderCard(
                    id: 'anthropic',
                    title: 'Anthropic Claude',
                    subtitle: 'Claude 3.5 Sonnet',
                    icon: Icons.chat_bubble_outline_rounded,
                    isDark: isDark,
                  ),
                  _buildProviderCard(
                    id: 'custom',
                    title: 'Custom Endpoint',
                    subtitle: 'Local LLM / Ollama',
                    icon: Icons.dns_outlined,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 2. API Key Access ──
              _buildSectionTitle('2. Konfigurasi API Key Access', isDark),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'API Key ($_aiProvider)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_hasSavedApiKey)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TERSIMPAN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        hintText: _hasSavedApiKey
                            ? 'Masukkan key baru jika ingin mengganti...'
                            : 'Contoh: AIzaSy...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiProvider == 'gemini'
                          ? 'Dapatkan API key gratis di Google AI Studio (aistudio.google.com).'
                          : (_aiProvider == 'openai'
                              ? 'Dapatkan API key di OpenAI Developer Platform (platform.openai.com).'
                              : 'Masukkan kredensial otorisasi sesuai provider.'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                    if (_aiProvider == 'custom') ...[
                      const SizedBox(height: 14),
                      Text(
                        'Custom Endpoint URL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customEndpointController,
                        decoration: InputDecoration(
                          hintText: 'http://localhost:11434/v1',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 3. Model AI Selection ──
              _buildSectionTitle('3. Model AI yang Ingin Dipakai', isDark),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Model Mesin AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: currentModelList.any((m) => m['id'] == _selectedModel)
                          ? _selectedModel
                          : (currentModelList.isNotEmpty ? currentModelList.first['id'] : null),
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: currentModelList.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['id'],
                          child: Text(
                            m['name'] ?? m['id']!,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedModel = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kreativitas (Temperature): ${_temperature.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _temperature < 0.4 ? 'Faktual & Presisi' : (_temperature > 0.8 ? 'Sangat Kreatif' : 'Seimbang'),
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryPurple),
                        ),
                      ],
                    ),
                    Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 1.5,
                      divisions: 15,
                      activeColor: AppTheme.primaryPurple,
                      onChanged: (val) => setState(() => _temperature = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 4. System Prompt Persona ──
              _buildSectionTitle('4. Persona & Instruksi Sistem AI (Opsional)', isDark),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _systemPromptController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Instruksi sistem default untuk Kreavana AI...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Test Result Banner ──
              if (_testResultStatus != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _testResultStatus == 'success'
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _testResultStatus == 'success' ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResultStatus == 'success'
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        color: _testResultStatus == 'success' ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _testResultMessage ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _testResultStatus == 'success'
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Action Buttons ──
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: _isTestingAi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_rounded),
                    label: const Text('Uji Koneksi AI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      side: const BorderSide(color: AppTheme.primaryPurple),
                      foregroundColor: AppTheme.primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isTestingAi ? null : _testAiConnection,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isSavingAi
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Simpan Pengaturan AI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSavingAi ? null : _saveAiSettings,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildProviderCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
    required bool isDark,
  }) {
    final isSelected = _aiProvider == id;

    return InkWell(
      onTap: () {
        setState(() {
          _aiProvider = id;
          final models = _availableModels[id] ?? [];
          if (models.isNotEmpty) {
            _selectedModel = models.first['id']!;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 195,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryPurple.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryPurple : Colors.grey,
                  size: 24,
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected
                    ? AppTheme.primaryPurple
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
