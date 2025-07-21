import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uyg/services/db_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<Map<String, String>> _contacts = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('emergency_contacts');
    if (saved != null) {
      final decoded = jsonDecode(saved) as List;
      setState(() {
        _contacts.clear();
        _contacts.addAll(
          decoded.map((e) => Map<String, String>.from(e)).toList(),
        );
      });
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_contacts', jsonEncode(_contacts));
  }

  void _addContact() async {
    if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
      final name = _nameController.text;
      final phone = _phoneController.text;

      setState(() {
        _contacts.add({"name": name, "phone": phone});
        _nameController.clear();
        _phoneController.clear();
      });

      await _saveContacts();
      await DBService.insertEmergencyContact(name, phone);
    }
  }

  void _removeContact(int index) async {
    final removedPhone = _contacts[index]['phone'];
    setState(() {
      _contacts.removeAt(index);
    });
    await _saveContacts();
    if (removedPhone != null) {
      await DBService.deleteEmergencyContactByPhone(removedPhone);
    }
  }

  Future<void> _selectFromContacts() async {
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rehber erişim izni reddedildi.")),
      );
      return;
    }

    final Contact? contact = await ContactsService.openDeviceContactPicker();
    if (contact != null && contact.phones!.isNotEmpty) {
      final name = contact.displayName ?? "İsimsiz";
      final phone = contact.phones!.first.value!.replaceAll(' ', '');

      setState(() {
        _contacts.add({"name": name, "phone": phone});
      });
      await _saveContacts();
      await DBService.insertEmergencyContact(name, phone);
    }
  }

  Future<void> _sendMessageToContact(String phone) async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Konum izni verilmedi.")));
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    final message =
        "🆘 Acil Durum! Konum: https://maps.google.com/?q=${position.latitude},${position.longitude}";

    await sendSMS(message: message, recipients: [phone], sendDirect: false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Mesaj gönderildi.")));
  }

  Future<bool> _ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B4C),
      appBar: AppBar(
        title: const Text("🆘 Acil Durum Kişileri"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Ad",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
              ),
            ),
            TextField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Telefon",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text("Elle Kişi Ekle"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  _contacts.isEmpty
                      ? const Center(
                        child: Text(
                          "Hiç kişi eklenmedi.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return Card(
                            color: Colors.indigo[700],
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                              title: Text(
                                contact['name']!,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                contact['phone']!,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.message,
                                      color: Colors.orange,
                                    ),
                                    onPressed:
                                        () => _sendMessageToContact(
                                          contact['phone']!,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeContact(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
