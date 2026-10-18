// lib/screens/visa_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/user_visa_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/visa_provider.dart';
import 'package:provider/provider.dart';

class VisaScreen extends StatefulWidget {
  const VisaScreen({super.key});

  @override
  State<VisaScreen> createState() => _VisaScreenState();
}

class _VisaScreenState extends State<VisaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visaCountryController = TextEditingController();
  final _visaTypeController = TextEditingController();
  final _visaExpiryController = TextEditingController();
  final _visaNoteController = TextEditingController();

  static const Color _mintColor = Color(0xFF00CDB5);
  static const Color _darkMint = Color(0xFF00A99D);

  @override
  void dispose() {
    _visaCountryController.dispose();
    _visaTypeController.dispose();
    _visaExpiryController.dispose();
    _visaNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _buildMyVisasContent(context),
      ),
    );
  }

  Widget _buildMyVisasContent(BuildContext context) {
    return Consumer2<CountryProvider, VisaProvider>(
      builder: (context, countryProvider, visaProvider, child) {
        if (countryProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: _mintColor));
        }
        final countryNames = countryProvider.allCountries.map((c) => c.name).toList();
        final userVisas = visaProvider.visas;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inline Header Replacement for AppBar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child:  Text(
                    tr('My Visas'),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.black87
                    ),
                  ),
                ),
              ),
              _buildUserVisaInputSection(context, countryNames),
              const SizedBox(height: 30),

              Row(
                children: [
                  Icon(Icons.folder_shared_outlined, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    tr("Saved Visas"),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800]
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildUserVisaList(context, userVisas),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserVisaInputSection(BuildContext context, List<String> countryNames) {
    return Card(
      elevation: 4,
      shadowColor: _mintColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _mintColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_card_rounded, color: _mintColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('Add New Visa'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 1. Country Input
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return countryNames.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _visaCountryController.text = selection;
                },
                fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                  if (_visaCountryController != fieldController) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      fieldController.text = _visaCountryController.text;
                    });
                  }
                  return TextFormField(
                    controller: fieldController,
                    focusNode: focusNode,
                    decoration: _inputDecoration('Country', Icons.flag_rounded),
                    validator: (value) {
                      if (value == null || value.isEmpty) return tr('Please enter a country');
                      if (!countryNames.contains(value)) return tr('Please select a valid country');
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // 2. Visa Type
              TextFormField(
                controller: _visaTypeController,
                decoration: _inputDecoration('Visa Type (Optional)', Icons.branding_watermark_rounded),
              ),
              const SizedBox(height: 16),

              // 3. Expiry Date
              TextFormField(
                controller: _visaExpiryController,
                decoration: _inputDecoration('Expiry Date', Icons.event_available_rounded),
                readOnly: true,
                onTap: _selectExpiryDate,
                validator: (value) => (value == null || value.isEmpty) ? 'Please select an expiry date' : null,
              ),
              const SizedBox(height: 16),

              // 4. Note
              TextFormField(
                controller: _visaNoteController,
                decoration: _inputDecoration('Notes (Optional)', Icons.edit_note_rounded),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveUserVisa,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mintColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  elevation: 2,
                  shadowColor: _mintColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:  Text(
                  tr('Save Visa Info'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: tr(label),
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      floatingLabelStyle: const TextStyle(color: _darkMint, fontWeight: FontWeight.bold),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _mintColor, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      prefixIcon: Icon(icon, color: _mintColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _selectExpiryDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _mintColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _visaExpiryController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _saveUserVisa() {
    if (_formKey.currentState!.validate()) {
      final newVisa = UserVisaInfo(
        country: _visaCountryController.text,
        visaType: _visaTypeController.text,
        expiryDate: _visaExpiryController.text,
        note: _visaNoteController.text,
      );

      Provider.of<VisaProvider>(context, listen: false).addVisa(newVisa);

      _visaCountryController.clear();
      _visaTypeController.clear();
      _visaExpiryController.clear();
      _visaNoteController.clear();
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:  Text(tr('Visa added successfully!')),
          backgroundColor: _mintColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildUserVisaList(BuildContext context, List<UserVisaInfo> userVisas) {
    if (userVisas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.folder_off_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              tr('No visas saved yet.'),
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: userVisas.length,
      itemBuilder: (context, index) {
        final visa = userVisas[index];
        final bool hasVisaType = visa.visaType.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _mintColor.withOpacity(0.08),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _mintColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.flag, color: _darkMint, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr(visa.country),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Colors.black87
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.sticky_note_2_rounded,
                            color: visa.note.isNotEmpty ? Colors.amber[800] : Colors.grey[300],
                            size: 26,
                          ),
                          onPressed: () => _showNoteViewDialog(context, index, visa),
                          tooltip: tr('View Notes'),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: Colors.grey[400], size: 24),
                          onPressed: () => _deleteVisa(context, index),
                          tooltip: tr('Delete'),
                        ),
                      ],
                    )
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1, thickness: 0.5),
                ),

                if (hasVisaType) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        const Icon(Icons.class_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          tr(visa.visaType),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Row(
                  children: [
                    Icon(Icons.event_busy, size: 16, color: Colors.red[300]),
                    const SizedBox(width: 8),
                    Text(
                      tr('Expires: ${visa.expiryDate}'),
                      style: TextStyle(
                        color: Colors.red[400],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoteViewDialog(BuildContext context, int index, UserVisaInfo visa) {
    final bool hasNote = visa.note.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr(visa.country),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasNote)
                   Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      tr('No notes added.'),
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  Text(
                    tr(visa.note),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:  Text(tr('Close'), style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _mintColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.edit, size: 16, color: Colors.white),
            label:  Text(tr('Edit'), style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(context).pop();
              _showEditNoteDialog(context, index, visa);
            },
          ),
        ],
      ),
    );
  }

  void _showEditNoteDialog(BuildContext context, int index, UserVisaInfo visa) {
    final TextEditingController editController = TextEditingController(text: visa.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr(visa.country),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              tr('Edit Note'),
              style: TextStyle(fontSize: 12, color: _darkMint, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: editController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: tr('Enter your notes here...'),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _mintColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:  Text(tr('Cancel'), style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _mintColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final updatedVisa = UserVisaInfo(
                country: visa.country,
                visaType: visa.visaType,
                expiryDate: visa.expiryDate,
                note: editController.text,
              );
              Provider.of<VisaProvider>(context, listen: false).updateVisa(index, updatedVisa);

              Navigator.of(context).pop();
            },
            child:  Text(tr('Save'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteVisa(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text(tr('Remove Visa?')),
        content:  Text(tr('This action cannot be undone.')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:  Text(tr('Cancel'), style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Provider.of<VisaProvider>(context, listen: false).removeVisa(index);
              Navigator.of(context).pop();
            },
            child:  Text(tr('Delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}