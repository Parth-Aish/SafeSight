import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});
  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, String>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data()!.containsKey('emergency_contacts')) {
          final List contactsList = doc.data()!['emergency_contacts'];
          setState(() {
            _contacts =
                contactsList.map((c) => Map<String, String>.from(c)).toList();
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Firebase Fetch Error: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> contactsJson =
          prefs.getStringList('emergency_contacts') ?? [];
      setState(() {
        _contacts = contactsJson.map((c) {
          final d = json.decode(c);
          return {"name": d["name"].toString(), "phone": d["phone"].toString()};
        }).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> contactsJson =
        _contacts.map((c) => json.encode(c)).toList();
    await prefs.setStringList('emergency_contacts', contactsJson);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'emergency_contacts': _contacts}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Firebase Sync Error: $e");
    }
  }

  Future<void> _importFromPhone() async {
    PermissionStatus status = await Permission.contacts.request();

    if (status.isGranted) {
      try {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null && contact.phones.isNotEmpty) {
          final name = contact.displayName;
          final phone = contact.phones.first.number;
          setState(() {
            _contacts.add({"name": name, "phone": phone});
          });
          await _saveContacts();
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error reading contact: $e")));
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text("Permission Required",
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      "SafeSight needs access to your contacts to import them.",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () {
                          openAppSettings();
                          Navigator.pop(context);
                        },
                        child: const Text("Open Settings")),
                  ],
                ));
      }
    }
  }

  void _addContactDialog() {
    final n = TextEditingController();
    final p = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text("Add Contact",
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: n,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Name")),
                const SizedBox(height: 16),
                TextField(
                    controller: p,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Phone")),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () {
                      if (n.text.isNotEmpty && p.text.isNotEmpty) {
                        setState(() =>
                            _contacts.add({"name": n.text, "phone": p.text}));
                        _saveContacts();
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("Save"))
              ],
            ));
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.import_contacts, color: Color(0xFF38BDF8)),
              title: const Text("Import from Address Book",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _importFromPhone();
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF38BDF8)),
              title: const Text("Type Manually",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _addContactDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: Text("Emergency Contacts",
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.contact_phone_outlined,
                          size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text("No Contacts Saved",
                          style: GoogleFonts.outfit(
                              color: Colors.white54, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text("Add contacts to enable SOS features",
                          style: TextStyle(color: Colors.white38))
                    ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _contacts.length,
                  itemBuilder: (context, i) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF38BDF8).withValues(alpha: 0.2),
                            child: Text(_contacts[i]['name']![0].toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold))),
                        title: Text(_contacts[i]['name']!,
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(_contacts[i]['phone']!,
                            style: GoogleFonts.outfit(color: Colors.white54)),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Color(0xFFF43F5E)),
                            onPressed: () {
                              setState(() => _contacts.removeAt(i));
                              _saveContacts();
                            }),
                      ))),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddOptions,
          backgroundColor: const Color(0xFF38BDF8),
          icon: const Icon(Icons.add, color: Color(0xFF0F172A)),
          label: const Text("Add Contact",
              style: TextStyle(
                  color: Color(0xFF0F172A), fontWeight: FontWeight.bold))),
    );
  }
}
