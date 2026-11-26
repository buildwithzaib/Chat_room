import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'contact_details_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> contacts = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  List<Contact> filteredContacts = [];

  @override
  void initState() {
    super.initState();

    print("🔥 CONTACT SCREEN OPENED");

    loadContacts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String normalizePhone(String phone) {
    // Sirf digits rakhein
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    // 0092 ko 92 mein convert karein
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    // Pakistani local number ko international format mein convert karein
    if (digits.startsWith('0')) {
      digits = '92${digits.substring(1)}';
    } else if (digits.length == 10 && !digits.startsWith('92')) {
      digits = '92$digits';
    }

    return digits;
  }

  Future<void> loadContacts() async {
    print("🔥 LOAD CONTACTS FUNCTION STARTED");
    try {
      // Step 1: Request permission
      final permission = await FlutterContacts.permissions.request(
        PermissionType.read,
      );

      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.limited) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Step 2: Retrieve contacts
      final result = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      // Step 3: Keep contacts with phone numbers
      final filteredContacts = result
          .where((contact) => contact.phones.isNotEmpty)
          .toList();

      // Sort contacts alphabetically (A to Z)
      filteredContacts.sort((a, b) {
        final nameA = (a.displayName ?? '').trim().toLowerCase();
        final nameB = (b.displayName ?? '').trim().toLowerCase();

        return nameA.compareTo(nameB);
      });

      // Debug counts
      print("TOTAL FETCHED CONTACTS: ${result.length}");
      print("CONTACTS WITH PHONE NUMBERS: ${filteredContacts.length}");

      // Print only first 10 contacts
      for (int i = 0; i < filteredContacts.length && i < 10; i++) {
        print("${i + 1}. ${filteredContacts[i].displayName}");
      }
      print("TOTAL PHONE CONTACTS: ${filteredContacts.length}");
      // Fetch registered users from Firestore
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      print("Total Registered Users: ${usersSnapshot.docs.length}");

      // Store registered phone numbers
      Set<String> registeredNumbers = {};

      for (var user in usersSnapshot.docs) {
        final userData = user.data();

        final phone = userData['phoneNumber'];

        if (phone != null && phone.toString().isNotEmpty) {
          final normalizedNumber = normalizePhone(phone.toString());

          registeredNumbers.add(normalizedNumber);
        }
      }

      print("Registered Phone Numbers: ${registeredNumbers.length}");

      // Match phone contacts with registered users
      final matchedContacts = filteredContacts.where((contact) {
        return contact.phones.any((phone) {
          final normalizedNumber = normalizePhone(phone.number);

          return registeredNumbers.contains(normalizedNumber);
        });
      }).toList();

      print("Matched Contacts: ${matchedContacts.length}");

      // Step 4: Normalize phone numbers and print
      print("Total Contacts: ${filteredContacts.length}");

      // for (var contact in filteredContacts) {
      //   for (var phone in contact.phones) {
      //     final originalNumber = phone.number;
      //     final normalizedNumber = normalizePhone(originalNumber);

      //     print('Name: ${contact.displayName}');
      //     print('Original: $originalNumber');
      //     print('Normalized: $normalizedNumber');
      //     print('----------------------');
      //   }
      // }

      // Step 5: Update UI
      if (!mounted) return;

      setState(() {
        contacts = filteredContacts;
        this.filteredContacts = filteredContacts;
        isLoading = false;
      });
    } catch (e) {
      print("CONTACT ERROR: $e");

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  void searchContacts(String query) {
    final results = contacts.where((contact) {
      final name = (contact.displayName ?? '').toLowerCase();

      final phone = contact.phones.map((p) => p.number).join(' ').toLowerCase();

      return name.contains(query.toLowerCase()) ||
          phone.contains(query.toLowerCase());
    }).toList();

    setState(() {
      filteredContacts = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Contact"), centerTitle: true),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Field
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: searchController,
                    onChanged: searchContacts,
                    decoration: InputDecoration(
                      hintText: "Search name or number...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          searchContacts('');
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Contacts List
                Expanded(
                  child: filteredContacts.isEmpty
                      ? const Center(child: Text("No contacts found"))
                      : ListView.builder(
                          itemCount: filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = filteredContacts[index];

                            final name =
                                (contact.displayName ?? '').trim().isEmpty
                                ? (contact.phones.isNotEmpty
                                      ? contact.phones.first.number
                                      : 'Unknown Contact')
                                : contact.displayName!.trim();

                            final phone = contact.phones
                                .map((p) => p.number)
                                .join(', ');

                            return ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ContactDetailsScreen(contact: contact),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(phone),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
