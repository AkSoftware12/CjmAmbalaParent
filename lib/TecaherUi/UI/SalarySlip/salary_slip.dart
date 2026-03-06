import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({Key? key}) : super(key: key);

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _salaryMonths = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _employeeTypes = [];
  List<Map<String, dynamic>> _users = [];

  List<String> _selectedMonths = [];
  int? _selectedAccountId;
  int? _selectedEmployeeTypeId;
  int? _selectedUserId;

  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      final response = await http.get(
        Uri.parse(ApiRoutes.getSalarySlip),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final data = jsonData['data'];

          setState(() {
            _salaryMonths =
            List<Map<String, dynamic>>.from(data['salary_months'] ?? []);
            _accounts =
            List<Map<String, dynamic>>.from(data['accounts'] ?? []);
            _employeeTypes =
            List<Map<String, dynamic>>.from(data['employeeTypes'] ?? []);
            _users = List<Map<String, dynamic>>.from(data['users'] ?? []);
            _filteredUsers = List<Map<String, dynamic>>.from(_users);

            // No auto-select — all start empty
            _selectedMonths = [];
            _selectedAccountId = null;
            _selectedEmployeeTypeId = null;
            _selectedUserId = null;

            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = jsonData['message'] ?? 'Failed to load data';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _toggleMonth(String value) {
    setState(() {
      if (_selectedMonths.contains(value)) {
        _selectedMonths.remove(value);
      } else {
        _selectedMonths.add(value);
      }
    });
  }

  void _onEmployeeTypeChanged(int? typeId) {
    setState(() {
      _selectedEmployeeTypeId = typeId;
      _selectedUserId = null;

      if (typeId == null) {
        _filteredUsers = List<Map<String, dynamic>>.from(_users);
      } else {
        final selectedType = _employeeTypes.firstWhere(
              (t) => t['id'] == typeId,
          orElse: () => {},
        );
        final typeTitle =
        (selectedType['title'] ?? '').toString().toLowerCase();
        _filteredUsers = _users.where((user) {
          final desig =
          (user['designation_title'] ?? '').toString().toLowerCase();
          return desig.contains(typeTitle) || typeTitle.contains(desig);
        }).toList();
      }
    });
  }

  void _onSubmit() {
    if (_selectedMonths.isEmpty || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least a Month and Account'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Only add optional params when actually selected
    final queryParams = <String, String>{
      'account_id': _selectedAccountId.toString(),
    };

    if (_selectedEmployeeTypeId != null) {
      queryParams['employee_type'] = _selectedEmployeeTypeId.toString();
    }

    if (_selectedUserId != null) {
      queryParams['user_names'] = _selectedUserId.toString();
    }

    for (int i = 0; i < _selectedMonths.length; i++) {
      queryParams['salary_months[$i]'] = _selectedMonths[i];
    }

    final uri =
    Uri.parse('https://softcjm.cjmambala.co.in/salaryslip-api')
        .replace(queryParameters: queryParams);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalarySlipWebViewScreen(url: uri.toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFC62828),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Salary Slip',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoader()
          : _errorMessage != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.red.shade700),
          const SizedBox(height: 16),
          Text('Loading salary data...',
              style: TextStyle(color: Colors.red.shade700, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(5.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Months
                  _buildMonthsSection(),
                  const SizedBox(height: 20),

                  // Bank Account
                  _buildDropdownField<int>(
                    label: 'Bank Account',
                    hint: 'Select Account',
                    icon: Icons.account_balance_rounded,
                    value: _selectedAccountId,
                    items: _accounts.map((acc) {
                      return DropdownMenuItem<int>(
                        value: acc['id'],
                        child: Text(acc['title']),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedAccountId = val),
                  ),
                  const SizedBox(height: 16),

                  // Employee Type
                  _buildDropdownField<int>(
                    label: 'Employee Type',
                    hint: 'Select Employee Type',
                    icon: Icons.badge_rounded,
                    value: _selectedEmployeeTypeId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          '-- None --',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ..._employeeTypes.map((type) {
                        return DropdownMenuItem<int>(
                          value: type['id'],
                          child: Text(type['title']),
                        );
                      }).toList(),
                    ],
                    onChanged: _onEmployeeTypeChanged,
                  ),

                  if (_selectedEmployeeTypeId != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.filter_list,
                            size: 14, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text(
                          '${_filteredUsers.length} employee(s) found',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Employee
                  _buildDropdownField<int>(
                    label: 'Employee',
                    hint: 'Select Employee',
                    icon: Icons.person_rounded,
                    value: _selectedUserId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          '-- None --',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ..._filteredUsers.map((user) {
                        return DropdownMenuItem<int>(
                          value: user['id'],
                          child: Text(
                            '${user['first_name']}${user['emp_no'] != null ? ' (${user['emp_no']})' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedUserId = val),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (_selectedMonths.isNotEmpty && _selectedAccountId != null)
            _buildSummaryCard(),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _onSubmit,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Generate Salary Slip',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: Colors.red.withOpacity(0.4),
              ),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedMonths = [];
                  _selectedAccountId = null;
                  _selectedEmployeeTypeId = null;
                  _selectedUserId = null;
                  _filteredUsers =
                  List<Map<String, dynamic>>.from(_users);
                });
              },
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Reset All Filters',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                side:
                const BorderSide(color: Color(0xFFC62828), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMonthsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 16, color: Color(0xFF424242)),
            const SizedBox(width: 6),
            const Text('Salary Month',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF424242))),
            const Spacer(),
            if (_selectedMonths.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _selectedMonths = []),
                child: Text('Clear (${_selectedMonths.length})',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _selectedMonths.isNotEmpty
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedMonths.isNotEmpty
                  ? const Color(0xFFC62828)
                  : const Color(0xFFE0E0E0),
              width: _selectedMonths.isNotEmpty ? 1.5 : 1,
            ),
          ),
          child: _salaryMonths.isEmpty
              ? const Text('No months available',
              style: TextStyle(color: Colors.grey, fontSize: 13))
              : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _salaryMonths.map((month) {
              final value = month['value'] as String;
              final label = month['label'] as String;
              final isSelected = _selectedMonths.contains(value);

              return GestureDetector(
                onTap: () => _toggleMonth(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFC62828)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFC62828)
                          : const Color(0xFFBDBDBD),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                          color: Colors.red.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF616161),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_selectedMonths.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${_selectedMonths.length} month(s) selected',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFC62828),
                fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required String hint,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value != null
                  ? const Color(0xFFC62828)
                  : const Color(0xFFE0E0E0),
              width: value != null ? 1.5 : 1,
            ),
            color: value != null
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFFAFAFA),
          ),
          child: DropdownButtonFormField<T?>(
            value: value,
            decoration: InputDecoration(
              prefixIcon: Icon(icon,
                  color: value != null
                      ? const Color(0xFFC62828)
                      : Colors.grey.shade400,
                  size: 20),
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            hint: Text(hint,
                style:
                TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: value != null
                    ? const Color(0xFFC62828)
                    : Colors.grey.shade400),
            isExpanded: true,
            items: items,
            onChanged: onChanged,
            dropdownColor: Colors.white,
            style: const TextStyle(
                color: Color(0xFF212121),
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final selectedMonthLabels = _selectedMonths.map((v) {
      final m = _salaryMonths.firstWhere((m) => m['value'] == v,
          orElse: () => {'label': v});
      return m['label'] as String;
    }).join(', ');

    final selectedAccount = _accounts.firstWhere(
            (a) => a['id'] == _selectedAccountId,
        orElse: () => {'title': ''})['title'];

    final selectedUser = _selectedUserId != null
        ? _users.firstWhere((u) => u['id'] == _selectedUserId,
        orElse: () => {'first_name': '', 'emp_no': null})
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF9A9A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle_outline,
                  color: Color(0xFFC62828), size: 18),
              SizedBox(width: 8),
              Text('Selection Summary',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC62828),
                      fontSize: 14)),
            ],
          ),
          const Divider(color: Color(0xFFEF9A9A), height: 16),
          _buildSummaryRow(Icons.calendar_today_rounded, 'Month(s)',
              selectedMonthLabels),
          const SizedBox(height: 6),
          _buildSummaryRow(Icons.account_balance_rounded, 'Account',
              selectedAccount ?? ''),
          if (selectedUser != null) ...[
            const SizedBox(height: 6),
            _buildSummaryRow(
              Icons.person_rounded,
              'Employee',
              '${selectedUser['first_name']}${selectedUser['emp_no'] != null ? ' (Emp #${selectedUser['emp_no']})' : ''}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.red.shade400),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF424242),
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── WebView Screen ────────────────────────────────────────────────────────────

class SalarySlipWebViewScreen extends StatefulWidget {
  final String url;
  const SalarySlipWebViewScreen({Key? key, required this.url})
      : super(key: key);

  @override
  State<SalarySlipWebViewScreen> createState() =>
      _SalarySlipWebViewScreenState();
}

class _SalarySlipWebViewScreenState extends State<SalarySlipWebViewScreen> {
  late final WebViewController _controller;
  bool _isPageLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isPageLoading = true),
          onPageFinished: (url) {
            _controller.runJavaScript('''
              (function() {
                var meta = document.querySelector('meta[name="viewport"]');
                if (!meta) {
                  meta = document.createElement('meta');
                  meta.name = 'viewport';
                  document.head.appendChild(meta);
                }
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
              })();
            ''');
            setState(() => _isPageLoading = false);
          },
          onWebResourceError: (error) =>
              setState(() => _isPageLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open browser'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC62828),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Salary Slip',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download in Browser',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: WebViewWidget(controller: _controller),
          ),
          if (_isPageLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.red.shade700),
                    const SizedBox(height: 16),
                    Text('Loading salary slip...',
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}