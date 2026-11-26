import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

class ContactDetailsScreen extends StatefulWidget {
  final Contact contact;

  const ContactDetailsScreen({super.key, required this.contact});

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  bool isChecking = false;
  String normalizePhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0')) {
      digits = '92${digits.substring(1)}';
    } else if (digits.length == 10 && !digits.startsWith('92')) {
      digits = '92$digits';
    }

    return digits;
  }

  Future<void> openChat() async {
    setState(() {
      isChecking = true;
    });

    try {
      // Step 1: Current logged-in user ki ID
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null) {
        throw Exception('Please login first.');
      }

      // Step 2: Selected contact ke phone numbers normalize karna
      final contactNumbers = widget.contact.phones
          .map((phone) => normalizePhone(phone.number))
          .where((number) => number.isNotEmpty)
          .toSet();

      // Step 3: Firestore se registered users fetch karna
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Step 4: Matching user find karna
      String? matchedUserId;
      String? matchedUserName;

      for (final user in usersSnapshot.docs) {
        // Apne account ko skip karna
        if (user.id == currentUserId) continue;

        final data = user.data();
        final phone = data['phoneNumber'];

        if (phone == null) continue;

        final normalizedPhone = normalizePhone(phone.toString());

        if (contactNumbers.contains(normalizedPhone)) {
          matchedUserId = user.id;
          matchedUserName = (data['name'] ?? 'Unknown User').toString();
          break;
        }
      }

      // Step 5: Agar user registered nahi hai
      if (matchedUserId == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This contact is not registered on Chat App yet.'),
          ),
        );
        return;
      }

      // Step 6: Registered user ki chat open karna
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            otherUserId: matchedUserId!,
            otherUserName: matchedUserName!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.contact.displayName ?? '').trim().isEmpty
        ? (widget.contact.phones.isNotEmpty
              ? widget.contact.phones.first.number
              : 'Unknown Contact')
        : widget.contact.displayName!.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Info')),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 30),

            // Contact Avatar
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.blue,
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 40),
              ),
            ),

            const SizedBox(height: 15),

            // Contact Name
            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),

            // Phone Numbers
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Phone Numbers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            ...widget.contact.phones.map((phone) {
              return ListTile(
                leading: const Icon(Icons.phone, color: Colors.blue),
                title: Text(phone.number),
              );
            }),

            const Spacer(),

            // Message Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isChecking ? null : openChat,

                icon: isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.message),

                label: Text(isChecking ? 'Checking...' : 'Message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
