import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class AddCheckInScreen extends StatefulWidget {
  const AddCheckInScreen({super.key});

  @override
  State<AddCheckInScreen> createState() => _AddCheckInScreenState();
}

class _AddCheckInScreenState extends State<AddCheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _noteController = TextEditingController();
  final _stockIssueController = TextEditingController();
  final _itemsServedController = TextEditingController();

  File? _selectedImage;
  double? _lat;
  double? _lng;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  final _uuid = const Uuid();

  String get _proofLabel {
    final now = DateTime.now();
    final formatted = DateFormat('MMdd').format(now);
    return 'Barcinas-BurgerShop-$formatted';
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Photo',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imageSourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _imageSourceButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0x1AD62828),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFD62828), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Please enable location services!');
        setState(() => _isGettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied!');
          setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied!');
        setState(() => _isGettingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _isGettingLocation = false;
      });
      _showSnack('Location captured!');
    } catch (e) {
      _showSnack('Error getting location: $e');
      setState(() => _isGettingLocation = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveCheckIn() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      _showSnack('Please select a photo!');
      return;
    }

    if (_lat == null || _lng == null) {
      _showSnack('Please get your location first!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docId = _uuid.v4();

      await FirebaseFirestore.instance
          .collection('checkins')
          .doc(docId)
          .set({
        'businessName': _businessNameController.text.trim(),
        'note': _noteController.text.trim(),
        'stockIssue': _stockIssueController.text.trim(),
        'itemsServed': _itemsServedController.text.trim(),
        'lat': _lat,
        'lng': _lng,
        'photoPath': _selectedImage!.path,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'Barcinas',
        'proofLabel': _proofLabel,
      });

      if (mounted) {
        _showSnack('Check-in saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Error saving: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _noteController.dispose();
    _stockIssueController.dispose();
    _itemsServedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Check-In'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Business Info'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _businessNameController,
                label: 'Business Name',
                hint: "Ate Eve's Burgers & Fries",
                icon: Icons.storefront,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _noteController,
                label: 'Note',
                hint: 'e.g. Checked store opening, restocked ingredients',
                icon: Icons.notes,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _sectionLabel('Business-Specific Fields'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _stockIssueController,
                label: 'Stock Issue',
                hint: 'e.g. Low on buns, Sufficient, Out of hotdog',
                icon: Icons.warning_amber,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _itemsServedController,
                label: 'Items Served Today',
                hint: 'e.g. Burger, Fries, Softdrinks',
                icon: Icons.lunch_dining,
              ),
              const SizedBox(height: 20),
              _sectionLabel('Photo'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to capture or pick photo',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Location'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGettingLocation ? null : _getLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _isGettingLocation
                        ? 'Getting location...'
                        : _lat != null
                            ? 'Location captured!'
                            : 'Get My Location',
                    style: GoogleFonts.poppins(),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFD62828)),
                    foregroundColor: const Color(0xFFD62828),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_lat != null && _lng != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lat: $_lat',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      Text(
                        'Lng: $_lng',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.label, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Proof: $_proofLabel',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Save Check-In',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: const Color(0xFFD62828),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFFD62828)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD62828)),
        ),
        labelStyle: GoogleFonts.poppins(fontSize: 13),
        hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
      ),
      style: GoogleFonts.poppins(fontSize: 13),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }
}