import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../guardians/data/guardian_repository.dart';
import '../../../guardians/domain/models/guardian.dart';

class GuardianNetworkScreen extends StatefulWidget {
  const GuardianNetworkScreen({super.key});
  @override
  State<GuardianNetworkScreen> createState() => _GuardianNetworkScreenState();
}

class _GuardianNetworkScreenState extends State<GuardianNetworkScreen> {
  final GuardianRepository _repository = GuardianRepository();
  List<Guardian> _guardians = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    try {
      final guardians = await _repository.watchGuardians().first;
      if (mounted) {
        setState(() {
          _guardians = guardians;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addGuardianDialog() async {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Add App Guardian",
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                "Enter the email of a trusted person using SafeSight. They will be alerted within the app if you trigger an SOS.",
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email Address",
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A)),
            onPressed: () async {
              final email = emailCtrl.text.trim().toLowerCase();
              if (email.isNotEmpty && email.contains('@')) {
                await _repository.pairByEmail(email);
                if (!mounted || !dialogContext.mounted) return;
                await _loadGuardians();
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              }
            },
            child: const Text("Link Guardian"),
          )
        ],
      ),
    );
  }

  Future<void> _removeGuardian(int index) async {
    final guardian = _guardians[index];
    await _repository.remove(guardian.id);
    if (mounted) {
      setState(() => _guardians.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text("Guardian Network",
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _guardians.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.hub_outlined,
                          size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text("No Guardians Linked",
                          style: GoogleFonts.outfit(
                              color: Colors.white54, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text("Add contacts to notify them in-app.",
                          style: TextStyle(color: Colors.white38))
                    ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _guardians.length,
                  itemBuilder: (context, i) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05))),
                      child: ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Color(0xFF34D399),
                            child:
                                Icon(Icons.security, color: Color(0xFF0F172A))),
                        title: Text(_guardians[i].email,
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text("Secured App Connection",
                            style: GoogleFonts.outfit(
                                color: const Color(0xFF34D399), fontSize: 12)),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Color(0xFFF43F5E)),
                            onPressed: () => _removeGuardian(i)),
                      ))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGuardianDialog,
        backgroundColor: const Color(0xFF38BDF8),
        icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF0F172A)),
        label: const Text("Link Guardian",
            style: TextStyle(
                color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
      ),
    );
  }
}
