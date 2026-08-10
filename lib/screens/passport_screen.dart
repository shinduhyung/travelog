// lib/screens/passport_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jidoapp/models/visa_data_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/passport_provider.dart';
import 'package:jidoapp/screens/passport_visa_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _UserPassportInfo {
  final String surname;
  final String givenNames;
  final String passportNumber;
  final String dob;
  final String sex;
  final String issueDate;
  final String expiryDate;

  _UserPassportInfo({
    required this.surname,
    required this.givenNames,
    required this.passportNumber,
    required this.dob,
    required this.sex,
    required this.issueDate,
    required this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
    'surname': surname,
    'givenNames': givenNames,
    'passportNumber': passportNumber,
    'dob': dob,
    'sex': sex,
    'issueDate': issueDate,
    'expiryDate': expiryDate,
  };

  factory _UserPassportInfo.fromJson(Map<String, dynamic> json) =>
      _UserPassportInfo(
        surname: json['surname'] ?? '',
        givenNames: json['givenNames'] ?? '',
        passportNumber: json['passportNumber'] ?? '',
        dob: json['dob'] ?? '',
        sex: json['sex'] ?? '',
        issueDate: json['issueDate'] ?? '',
        expiryDate: json['expiryDate'] ?? '',
      );
}

class _RankedPassportItem {
  final int rank;
  final String iso;
  final PassportData data;

  _RankedPassportItem({
    required this.rank,
    required this.iso,
    required this.data,
  });
}

class _PassportScreenState extends State<PassportScreen> {
  static const Color purple = Color(0xFF8B5CF6);
  static const Color darkPurple = Color(0xFF7C3AED);
  static const String _prefsKey = 'userPassports';

  final _formKey = GlobalKey<FormState>();
  final _surnameController = TextEditingController();
  final _givenNamesController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _issueDateController = TextEditingController();
  final _expiryController = TextEditingController();
  String? _selectedSex;

  final List<_UserPassportInfo> _userPassports = [];

  final _searchController = TextEditingController();
  String _searchQuery = '';

  // [Update] Added FRO (Faroe Islands) and GRL (Greenland) to DNK (Denmark)
  static const Map<String, Set<String>> _sovereignTerritories = {
    'USA': {'GUM', 'MNP', 'PRI', 'VIR'},
    'FRA': {'BLM', 'MAF', 'NCL', 'PYF', 'SPM', 'WLF'},
    'NLD': {'ABW', 'CUW', 'SXM'},
    'NZL': {'COK', 'NIU'},
    'AUS': {'NFK'},
    'FIN': {'ALA'},
    'GBR': {'GGY', 'IMN', 'JEY', 'GIB'},
    'DNK': {'FRO', 'GRL'}, // [Added] Danish territories
  };

  @override
  void initState() {
    super.initState();
    _loadSavedPassports();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _givenNamesController.dispose();
    _passportNumberController.dispose();
    _dobController.dispose();
    _issueDateController.dispose();
    _expiryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── SharedPreferences + Firestore Load ────────────────────────────────────
  Future<void> _loadSavedPassports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;

      List<_UserPassportInfo> loaded = [];

      if (user != null) {
        // 로그인 상태: Firestore 우선, 실패 시 로컬 fallback
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 5));

          if (doc.exists && doc.data()!.containsKey('userPassports')) {
            final String serverJson = doc.data()!['userPassports'];
            final List<dynamic> decoded = jsonDecode(serverJson);
            loaded = decoded
                .map((e) => _UserPassportInfo.fromJson(e as Map<String, dynamic>))
                .toList();
            // 서버 데이터를 로컬에도 동기화
            await prefs.setString(_prefsKey, serverJson);
          } else {
            // Firestore에 없으면 로컬에서 로드 후 서버에 업로드
            final String? localJson = prefs.getString(_prefsKey);
            if (localJson != null) {
              final List<dynamic> decoded = jsonDecode(localJson);
              loaded = decoded
                  .map((e) => _UserPassportInfo.fromJson(e as Map<String, dynamic>))
                  .toList();
            }
          }
        } catch (e) {
          print('Firestore passport load failed, using local: $e');
          final String? localJson = prefs.getString(_prefsKey);
          if (localJson != null) {
            final List<dynamic> decoded = jsonDecode(localJson);
            loaded = decoded
                .map((e) => _UserPassportInfo.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } else {
        // 비로그인: 로컬만
        final String? localJson = prefs.getString(_prefsKey);
        if (localJson != null) {
          final List<dynamic> decoded = jsonDecode(localJson);
          loaded = decoded
              .map((e) => _UserPassportInfo.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _userPassports.addAll(loaded);
        });
      }
    } catch (e) {
      print('Error loading saved passports: $e');
    }
  }

  // ── SharedPreferences + Firestore Save ────────────────────────────────────
  Future<void> _persistPassports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_userPassports.map((p) => p.toJson()).toList());

      // 로컬 저장
      await prefs.setString(_prefsKey, encoded);

      // Firestore 저장 (로그인 상태일 때만, 백그라운드)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'userPassports': encoded,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e) {
          print('Firestore passport save failed: $e');
        });
      }
    } catch (e) {
      print('Error persisting passports: $e');
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: purple),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: purple, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const TabBar(
                labelColor: purple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: purple,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: [
                  Tab(text: 'My Passport'),
                  Tab(text: 'Global Rankings'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMyPassportTab(context),
                    _buildPassportRankingTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Tab 1: My Passport ---

  Widget _buildMyPassportTab(BuildContext context) {
    return Consumer2<PassportProvider, CountryProvider>(
      builder: (context, passportProvider, countryProvider, child) {
        if (passportProvider.isLoading || countryProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: purple));
        }

        final selectedPassportData = passportProvider.selectedPassportData;
        final allCountries = countryProvider.allCountries;

        final Map<String, DestinationVisaInfo> visaInfoMap = {
          for (var info in selectedPassportData?.visaRequirements ?? [])
            info.destinationIsoA3.toUpperCase(): info
        };

        final selectedIso = passportProvider.selectedPassportIso;
        final displayName = countryProvider.isoToCountryNameMap[selectedIso] ??
            selectedPassportData?.passportName ??
            selectedIso;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPassportInfoSection(
                context,
                passportProvider,
                countryProvider,
                selectedPassportData,
                displayName,
                allCountries,
                visaInfoMap,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(thickness: 1, height: 40, color: Colors.grey[200]),
              ),
              _buildUserPassportInputSection(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(thickness: 1, height: 40, color: Colors.grey[200]),
              ),
              _buildUserPassportList(context),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPassportInfoSection(
      BuildContext context,
      PassportProvider provider,
      CountryProvider countryProvider,
      PassportData? data,
      String displayName,
      List<Country> allCountries,
      Map<String, DestinationVisaInfo> visaInfoMap,
      ) {
    final dropdownItems = provider.passportDataMap.entries.map((entry) {
      final name = countryProvider.isoToCountryNameMap[entry.key] ?? entry.value.passportName;
      return MapEntry(entry.key, name);
    }).toList();

    dropdownItems.sort((a, b) => a.value.compareTo(b.value));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nationality',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.selectedPassportIso,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: purple),
                menuMaxHeight: 400,
                items: dropdownItems.map((item) {
                  return DropdownMenuItem<String>(
                    value: item.key,
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    provider.setSelectedPassport(newValue);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: purple.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 90,
                    height: 125,
                    color: Colors.grey[100],
                    child: CachedNetworkImage(
                      imageUrl:
                      'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/passports%2F${provider.selectedPassportIso}.png?alt=media',
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.menu_book_rounded, size: 30, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow('Power Rank', '#${data?.powerRank ?? '-'}'),
                      const SizedBox(height: 6),
                      _buildStatRow('Visa-Free', '${data?.visaFreeCountries ?? '-'} countries'),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.map_outlined, color: Colors.white),
              label: const Text(
                'View Visa Map',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PassportVisaDetailScreen(
                      passportName: displayName,
                      allCountries: allCountries,
                      visaInfoMap: visaInfoMap,
                      selectedPassportIso: provider.selectedPassportIso,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildUserPassportInputSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _surnameController,
              decoration: _inputDecoration('Surname', Icons.person_outline),
              validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _givenNamesController,
              decoration: _inputDecoration('Given Names', Icons.person_outline),
              validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passportNumberController,
              decoration: _inputDecoration('Passport No.', Icons.badge_outlined),
              validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dobController,
                    decoration: _inputDecoration('Birth', Icons.cake_outlined),
                    readOnly: true,
                    onTap: () => _selectDate(_dobController, isDob: true),
                    validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSex,
                    decoration: _inputDecoration('Sex', Icons.wc_outlined),
                    items: ['Male', 'Female', 'Other'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedSex = newValue;
                      });
                    },
                    validator: (value) => (value == null) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _issueDateController,
                    decoration: _inputDecoration('Issue', Icons.calendar_today_outlined),
                    readOnly: true,
                    onTap: () => _selectDate(_issueDateController, isIssueDate: true),
                    validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    decoration: _inputDecoration('Expiry', Icons.event_busy_outlined),
                    readOnly: true,
                    onTap: () => _selectDate(_expiryController),
                    validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_rounded, color: Colors.white),
                label: const Text(
                  'Save Details',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saveUserPassport,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(
      TextEditingController controller, {
        bool isDob = false,
        bool isIssueDate = false,
      }) async {
    DateTime initial;
    DateTime first;
    DateTime last;

    if (isDob) {
      initial = DateTime.now().subtract(const Duration(days: 365 * 25));
      first = DateTime(1900);
      last = DateTime.now();
    } else if (isIssueDate) {
      initial = DateTime.now().subtract(const Duration(days: 365 * 2));
      first = DateTime(2000);
      last = DateTime.now();
    } else {
      initial = DateTime.now().add(const Duration(days: 365 * 10));
      first = DateTime.now();
      last = DateTime(2100);
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: purple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text =
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _saveUserPassport() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _userPassports.add(
          _UserPassportInfo(
            surname: _surnameController.text,
            givenNames: _givenNamesController.text,
            passportNumber: _passportNumberController.text,
            dob: _dobController.text,
            sex: _selectedSex!,
            issueDate: _issueDateController.text,
            expiryDate: _expiryController.text,
          ),
        );
        _surnameController.clear();
        _givenNamesController.clear();
        _passportNumberController.clear();
        _dobController.clear();
        _issueDateController.clear();
        _expiryController.clear();
        _selectedSex = null;
        FocusScope.of(context).unfocus();
      });
      _persistPassports(); // ← 저장
    }
  }

  Widget _buildUserPassportList(BuildContext context) {
    if (_userPassports.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.credit_card_off_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'No saved details',
                style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userPassports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final passport = _userPassports[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded, color: purple),
            ),
            title: Text(
              passport.passportNumber,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${passport.surname.toUpperCase()}, ${passport.givenNames}\nExpires: ${passport.expiryDate}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red[300]),
              onPressed: () {
                setState(() {
                  _userPassports.removeAt(index);
                });
                _persistPassports(); // ← 삭제 후 저장
              },
            ),
          ),
        );
      },
    );
  }

  // --- Tab 2: Rankings ---

  Widget _buildPassportRankingTab(BuildContext context) {
    return Consumer2<PassportProvider, CountryProvider>(
      builder: (context, passportProvider, countryProvider, child) {
        if (passportProvider.isLoading || countryProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: purple));
        }

        final allCountries = countryProvider.allCountries;
        final myPassportIso = passportProvider.selectedPassportIso;

        final hiddenTerritories = _sovereignTerritories.values.expand((e) => e).toSet();

        final filteredPassportList = passportProvider.passportDataMap.entries.where((entry) {
          if (hiddenTerritories.contains(entry.key)) return false;

          final name = countryProvider.isoToCountryNameMap[entry.key] ?? entry.value.passportName;
          final query = _searchQuery.toLowerCase();
          return name.toLowerCase().contains(query);
        }).toList();

        filteredPassportList.sort((a, b) {
          int scoreCompare = b.value.visaFreeCountries.compareTo(a.value.visaFreeCountries);
          if (scoreCompare != 0) {
            return scoreCompare;
          } else {
            final nameA = countryProvider.isoToCountryNameMap[a.key] ?? a.value.passportName;
            final nameB = countryProvider.isoToCountryNameMap[b.key] ?? b.value.passportName;
            return nameA.compareTo(nameB);
          }
        });

        List<_RankedPassportItem> displayList = [];
        int currentRank = 0;
        int lastScore = -1;

        for (var entry in filteredPassportList) {
          int score = entry.value.visaFreeCountries;
          if (score != lastScore) {
            currentRank++;
            lastScore = score;
          }
          displayList.add(_RankedPassportItem(
            rank: currentRank,
            iso: entry.key,
            data: entry.value,
          ));
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search country...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final item = displayList[index];
                  final passportIso = item.iso;
                  final passportData = item.data;
                  final rank = item.rank;

                  final displayName =
                      countryProvider.isoToCountryNameMap[passportIso] ?? passportData.passportName;

                  bool isMyPassport = (passportIso == myPassportIso);

                  if (!isMyPassport) {
                    final territorySet = _sovereignTerritories[passportIso];
                    if (territorySet != null && territorySet.contains(myPassportIso)) {
                      isMyPassport = true;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isMyPassport
                          ? Border.all(color: purple.withOpacity(0.5), width: 1.5)
                          : Border.all(color: Colors.transparent),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isMyPassport
                              ? purple.withOpacity(0.1)
                              : (rank <= 3
                              ? const Color(0xFFFBBF24).withOpacity(0.1)
                              : Colors.grey[50]),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isMyPassport
                                ? purple
                                : (rank <= 3 ? const Color(0xFFD97706) : Colors.grey[600]),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMyPassport) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ME',
                                style: TextStyle(
                                    color: purple, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]
                        ],
                      ),
                      subtitle: Text(
                        '${passportData.visaFreeCountries} visa-free destinations',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      trailing:
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[300]),
                      onTap: () {
                        final Map<String, DestinationVisaInfo> visaInfoMap = {
                          for (var info in passportData.visaRequirements)
                            info.destinationIsoA3.toUpperCase(): info
                        };

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PassportVisaDetailScreen(
                              passportName: displayName,
                              allCountries: allCountries,
                              visaInfoMap: visaInfoMap,
                              selectedPassportIso: passportIso,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}