import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/recommendation_service.dart';
import '../models/recommendation_creator_model.dart';
import 'creator_recommendation_card.dart';
import '../app/theme.dart';
import 'package:intl/intl.dart';

class RecommendedCreatorsSection extends StatefulWidget {
  const RecommendedCreatorsSection({super.key});

  @override
  State<RecommendedCreatorsSection> createState() =>
      _RecommendedCreatorsSectionState();
}

class _RecommendedCreatorsSectionState
    extends State<RecommendedCreatorsSection> {
  final ScrollController _scrollController = ScrollController();

  List<RecommendationCreatorModel> _creators = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _currentPage = 1;
  bool _hasMore = true;
  CancelToken? _cancelToken;

  List<String> _availableCategories = [];
  bool _isLoadingCategories = false;

  // Filter State
  String? _selectedSubRole;
  String? _selectedCategory;
  String? _selectedRegion;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, String>> _subRoleOptions = [
    {'slug': 'event_organizer', 'name': 'Event Organizer'},
    {'slug': 'wedding_organizer', 'name': 'Wedding Organizer'},
    {'slug': 'mc', 'name': 'MC'},
    {'slug': 'singer', 'name': 'Penyanyi'},
    {'slug': 'photographer', 'name': 'Fotografer'},
    {'slug': 'videographer', 'name': 'Videografer'},
    {'slug': 'makeup_artist', 'name': 'Makeup Artist'},
    {'slug': 'editor', 'name': 'Editor'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchRecommendations(isRefresh: true);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await RecommendationService.getServiceCategories();
      if (mounted) {
        setState(() {
          _availableCategories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cancelToken?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetchRecommendations(isRefresh: false);
      }
    }
  }

  Future<void> _fetchRecommendations({required bool isRefresh}) async {
    if (isRefresh) {
      _cancelToken?.cancel();
      _cancelToken = CancelToken();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
    }

    try {
      final response = await RecommendationService.getCreatorRecommendations(
        subRole: _selectedSubRole,
        category: _selectedCategory,
        region: _selectedRegion,
        startDate: _startDate != null
            ? DateFormat('yyyy-MM-dd').format(_startDate!)
            : null,
        endDate: _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
        page: _currentPage,
        perPage: 20,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _creators = response.data;
          } else {
            _creators.addAll(response.data);
          }
          _hasMore = response.hasMore;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return; // Request was cancelled, do nothing
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          if (isRefresh) {
            _errorMessage = 'Gagal memuat rekomendasi creator.';
          } else {
            _currentPage--; // rollback page if load more failed
          }
        });

        if (!isRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memuat halaman selanjutnya.')),
          );
        }
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedSubRole = null;
      _selectedCategory = null;
      _selectedRegion = null;
      _startDate = null;
      _endDate = null;
    });
    _fetchRecommendations(isRefresh: true);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchRecommendations(isRefresh: true);
    }
  }

  Widget _buildFilters() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Kreator',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_selectedSubRole != null ||
                  _selectedRegion != null ||
                  _selectedCategory != null ||
                  _startDate != null)
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset Filter'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Sub Role Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      hint: const Text('Tipe Kreator'),
                      value: _selectedSubRole,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onChanged: (String? newValue) {
                        setState(() => _selectedSubRole = newValue);
                        _fetchRecommendations(isRefresh: true);
                      },
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Semua Tipe'),
                        ),
                        ..._subRoleOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['slug'],
                            child: Text(opt['name']!),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Availability Button
                ActionChip(
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}'
                        : 'Ketersediaan',
                  ),
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  onPressed: () => _selectDateRange(context),
                  backgroundColor: _startDate != null
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : null,
                  side: BorderSide(
                    color: _startDate != null
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 8),
                // Region Dropdown (Static for now as per fallback strategy)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      hint: const Text('Wilayah'),
                      value: _selectedRegion,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onChanged: (String? newValue) {
                        setState(() => _selectedRegion = newValue);
                        _fetchRecommendations(isRefresh: true);
                      },
                      items: const [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('Semua Wilayah'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Jakarta',
                          child: Text('Jakarta'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Bekasi',
                          child: Text('Bekasi'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Tangerang',
                          child: Text('Tangerang'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Depok',
                          child: Text('Depok'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Bogor',
                          child: Text('Bogor'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Bandung',
                          child: Text('Bandung'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Category Dropdown
                if (_availableCategories.isNotEmpty || _isLoadingCategories)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _isLoadingCategories
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              hint: const Text('Kategori'),
                              value: _selectedCategory,
                              icon: const Icon(Icons.arrow_drop_down, size: 20),
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                              onChanged: (String? newValue) {
                                setState(() => _selectedCategory = newValue);
                                _fetchRecommendations(isRefresh: true);
                              },
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Semua Kategori'),
                                ),
                                ..._availableCategories.map((category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  );
                                }),
                              ],
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _fetchRecommendations(isRefresh: true),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _creators.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        (_selectedSubRole != null ||
                                _selectedRegion != null ||
                                _startDate != null)
                            ? 'Belum ada creator yang sesuai dengan filter Anda.'
                            : 'Belum ada creator yang dapat direkomendasikan.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedSubRole != null ||
                          _selectedRegion != null ||
                          _startDate != null) ...[
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _resetFilters,
                          child: const Text('Reset Filter'),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchRecommendations(isRefresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _creators.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _creators.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: CreatorRecommendationCard(
                          creator: _creators[index],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
