import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Current logged-in user
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),

      body: currentUser == null
          ? const Center(child: Text('Please login first'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),

              builder: (context, snapshot) {
                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Error state
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong!'));
                }

                // Document check
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Profile not found'));
                }

                // Get user data
                final userData = snapshot.data!.data()!;

                final name = userData['name'] ?? 'No Name';
                final email = userData['email'] ?? 'No Email';
                final phone = userData['phoneNumber'] ?? 'No Phone';

                return Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      // Profile Avatar
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.blue,
                        child: Text(
                          name.toString().isNotEmpty
                              ? name.toString()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Name
                      Text(
                        name.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Email
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: Text(email.toString()),
                      ),

                      // Phone
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: const Text('Phone Number'),
                        subtitle: Text(phone.toString()),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
