// home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'create_event_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _allEvents = [];
  List<dynamic> _events = [];
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _errorMessage;

  bool _showFilterPanel = false;
  String _searchKeyword = '';
  String _selectedCategory = '';
  String _selectedDate = '';

  List<String> _categories = [];

  final Color primaryBlue = const Color(0xFF1976D2);
  final Color lightBlue = const Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadEvents();
  }

  void _loadUserData() async {
    final userData = await ApiService.getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
      });
    }
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getEvents(sorted: true);

    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] ?? [];
      setState(() {
        _allEvents = List<Map<String, dynamic>>.from(data);
        _categories = _extractCategories(_allEvents);
        _applyFilters();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message'] ?? 'Failed to load events';
      });

      final msg = (_errorMessage ?? '').toLowerCase();
      if ((msg.contains('unauth') || msg.contains('session')) && mounted) {
        await ApiService.logout();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
          );
        }
      }
    }
  }

  List<String> _extractCategories(List<dynamic> events) {
    final set = <String>{};
    for (var e in events) {
      if (e['category'] != null && e['category'].toString().trim().isNotEmpty) {
        set.add(e['category'].toString());
      }
    }
    return set.toList()..sort();
  }

  void _applyFilters() {
    List<dynamic> filtered = _allEvents;

    if (_searchKeyword.isNotEmpty) {
      filtered = filtered.where((e) {
        final title = (e['title'] ?? e['name'] ?? '').toString().toLowerCase();
        return title.contains(_searchKeyword.toLowerCase());
      }).toList();
    }

    if (_selectedCategory.isNotEmpty) {
      filtered = filtered.where((e) {
        return (e['category'] ?? '').toString().toLowerCase() ==
            _selectedCategory.toLowerCase();
      }).toList();
    }

    if (_selectedDate.isNotEmpty) {
      filtered = filtered.where((e) {
        return (e['start_date'] ?? '').toString().startsWith(_selectedDate);
      }).toList();
    }

    setState(() {
      _events = filtered;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _searchKeyword = '';
      _selectedCategory = '';
      _selectedDate = '';
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Event Zone',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryBlue, // pakai warna biru yang kita definisikan
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_userData != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryBlue, primaryBlue.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_userData!['name'] ?? 'User'}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_userData!['student_number'] ?? ''} - ${_userData!['major'] ?? ''}',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

          SizedBox(height: 8),

          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.search, color: Colors.white),
              label: Text(
                _showFilterPanel
                    ? 'Sembunyikan Kolom Pencarian'
                    : 'Tampilkan Kolom Pencarian',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                setState(() {
                  _showFilterPanel = !_showFilterPanel;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),

          if (_showFilterPanel) _buildFilterPanel(),

          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.event, color: primaryBlue),
                SizedBox(width: 8),
                Text(
                  'Daftar Event (${_events.length})',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryBlue))
                : _errorMessage != null
                ? _buildErrorView()
                : _events.isEmpty
                ? _buildEmptyView()
                : RefreshIndicator(
              onRefresh: _loadEvents,
              color: primaryBlue,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final raw = _events[index];
                  final Map<String, dynamic> event =
                  (raw is Map<String, dynamic>)
                      ? raw
                      : (raw is Map
                      ? Map<String, dynamic>.from(raw)
                      : <String, dynamic>{});
                  return _buildEventCard(event);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateEventScreen()),
          );
          if (result == true) {
            await _loadEvents();
          }
        },
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Create Event',
          style: TextStyle(color: Colors.white), // teks jadi putih
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Search by name',
              prefixIcon: Icon(Icons.search, color: primaryBlue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (value) {
              _searchKeyword = value;
              _applyFilters();
            },
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Filter by Category',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            value: _selectedCategory.isEmpty ? null : _selectedCategory,
            items: _categories
                .map((cat) =>
                DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (value) {
              _selectedCategory = value ?? '';
              _applyFilters();
            },
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDate.isEmpty
                      ? 'No date selected'
                      : 'Date: $_selectedDate',
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.date_range, color: Colors.white),
                label: Text('Pick Date', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _pickDate,
              ),
            ],
          ),
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: Icon(Icons.clear, color: primaryBlue),
              label: Text('Clear Filters', style: TextStyle(color: primaryBlue)),
              onPressed: _clearFilters,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final String name =
        (event['name'] ?? event['title'])?.toString() ?? 'Unnamed Event';
    final String description = (event['description'] ?? '')?.toString() ?? '';
    final String location = (event['location'] ?? '')?.toString() ?? '';
    final String category = (event['category'] ?? '')?.toString() ?? ''; // ✅ ambil category
    final rawDate = (event['date'] ?? event['start_date'])?.toString();
    final rawTime = (event['time'] ?? event['start_time'])?.toString() ?? '';
    final displayDate = (rawDate != null && rawDate.isNotEmpty)
        ? _formatDate(rawDate)
        : 'No date';
    final displayTime = (rawTime.isNotEmpty) ? rawTime : 'No time';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: detail event
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul Event
              Text(
                name,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
              ),

              // Category
              if (category.isNotEmpty) ...[
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.category, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      category,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 4),
              Text(
                description.isNotEmpty ? description : 'No description',
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 12),

              // Lokasi
              Row(children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                      location.isNotEmpty ? location : 'No location',
                      style: TextStyle(color: Colors.grey[600])),
                ),
              ]),
              SizedBox(height: 8),

              // Tanggal & Waktu
              Row(children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(displayDate, style: TextStyle(color: Colors.grey[600])),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(displayTime, style: TextStyle(color: Colors.grey[600])),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Text('Error loading events', style: TextStyle(color: Colors.red)),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Text('No events found', style: TextStyle(color: Colors.grey[600])),
    );
  }

  String _formatDate(String raw) {
    try {
      final dateOnly = raw.contains('T') ? raw.split('T').first : raw;
      final dt = DateTime.parse(dateOnly);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      return raw;
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ApiService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false);
              }
            },
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
