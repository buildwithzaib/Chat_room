// ignore_for_file: avoid_print
import 'screens/chat_screen.dart';
import 'services/presence_service.dart';
import 'screens/contacts_screen.dart';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

String formatChatTime(Timestamp? timestamp) {
  if (timestamp == null) return '';

  final date = timestamp.toDate().toLocal();

  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String formatLastSeen(num? timestamp) {
  if (timestamp == null) return 'Last seen recently';

  final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()).toLocal();

  final now = DateTime.now();

  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final seenDate = DateTime(date.year, date.month, date.day);

  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  final time = '$hour:$minute $period';

  if (seenDate == today) {
    return 'Last seen today at $time';
  }

  if (seenDate == yesterday) {
    return 'Last seen yesterday at $time';
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return 'Last seen $day/$month/${date.year} at $time';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyChatApp());
}

class MyChatApp extends StatelessWidget {
  const MyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat Room",

      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthGate(),
    );
  }
}

//cheak weather user is logged in or not

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return LoginScreen();
      },
    );
  }
}

//Login Screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      print("LOGIN SUCCESSFUL");
    } on FirebaseAuthException catch (e) {
      print("FIREBASE ERROR CODE: ${e.code}");
      print("FIREBASE ERROR MESSAGE: ${e.message}");

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? "Login failed")));
    } catch (e) {
      print("OTHER ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Something went wrong")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat, size: 80, color: Colors.blue),

              const SizedBox(height: 20),

              const Text(
                "Welcome Back!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Login"),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    child: const Text("Sign Up"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneNumberController = TextEditingController();

  bool isLoading = false;

  Future<void> createAccount() async {
    // Check empty fields
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        phoneNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 1. Create Firebase Authentication account
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      // 2. Get user UID
      User? user = userCredential.user;

      if (user != null) {
        // 3. Save user information in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phoneNumber': phoneNumberController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        print("USER DATA SAVED SUCCESSFULLY");
      }

      // 4. Return to first screen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      print("AUTH ERROR: ${e.code}");
      print("AUTH MESSAGE: ${e.message}");

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? "Signup failed")));
    } on FirebaseException catch (e) {
      print("FIRESTORE ERROR: ${e.code}");
      print("FIRESTORE MESSAGE: ${e.message}");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Could not save user data")),
      );
    } catch (e) {
      print("OTHER ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Something went wrong")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),

          child: Column(
            children: [
              const Icon(Icons.person_add, size: 80, color: Colors.blue),

              const SizedBox(height: 20),

              const Text(
                'Create Your Account',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              // Name Field
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // Email Field
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+923001234567',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // Password Field
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 25),

              // Create Account Button
              SizedBox(
                width: double.infinity,
                height: 50,

                child: ElevatedButton(
                  onPressed: isLoading ? null : createAccount,

                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Home screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // User ko online karna
    PresenceService.instance.startPresence();
  }

  // contacts permission function
  Future<void> getContacts() async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    if (permission == PermissionStatus.granted ||
        permission == PermissionStatus.limited) {
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      print("Total Contacts: ${contacts.length}");

      for (var contact in contacts) {
        print("Name: ${contact.displayName}");
        print("Phone count: ${contact.phones.length}");

        for (var phone in contact.phones) {
          print("Phone: ${phone.number}");
        }

        print("----------------------");
      }
    } else {
      print("Contacts permission denied!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Room"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactsScreen()),
              );
            },
            icon: const Icon(Icons.contacts),
          ),
          IconButton(
            onPressed: () async {
              // User ko offline karo
              await PresenceService.instance.stopPresence();

              // User logout
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),

        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong!"));
          }

          // No users
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found"));
          }

          // Remove current logged-in user
          final users = snapshot.data!.docs.where((doc) {
            return doc.id != currentUser?.uid;
          }).toList();

          if (users.isEmpty) {
            return const Center(child: Text("No other users available yet"));
          }

          // Display users
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final name = user['name'] ?? 'Unknown User';
              final email = user['email'] ?? '';
              final otherUserId = users[index].id;
              final ids = [currentUser!.uid, otherUserId]..sort();
              final chatId = ids.join('_');

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .snapshots(),
                builder: (context, chatSnapshot) {
                  final chatData = chatSnapshot.data?.data();
                  final lastMessage = chatData?['lastMessage'] ?? '';
                  final timestamp = chatData?['updatedAt'] as Timestamp?;

                  return ListTile(
                    leading: StreamBuilder<DatabaseEvent>(
                      stream: FirebaseDatabase.instanceFor(
                        app: Firebase.app(),
                        databaseURL: 'https://my-chat-app-b3ff3-default-rtdb.firebaseio.com/',
                      ).ref('status/$otherUserId').onValue,

                      builder: (context, statusSnapshot) {
                        bool isOnline = false;

                        if (statusSnapshot.hasData) {
                          final data = statusSnapshot.data!.snapshot.value;

                          if (data is Map) {
                            isOnline = data['state'] == 'online';
                          }
                        }

                        return Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),

                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lastMessage.toString().isNotEmpty
                              ? lastMessage.toString()
                              : email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        StreamBuilder<DatabaseEvent>(
                          stream: FirebaseDatabase.instanceFor(
                            app: Firebase.app(),
                            databaseURL: 'https://my-chat-app-b3ff3-default-rtdb.firebaseio.com/',
                          ).ref('status/$otherUserId').onValue,

                          builder: (context, statusSnapshot) {
                            final data = statusSnapshot.data?.snapshot.value;

                            if (data is Map) {
                              final state = data['state'];
                              final timestamp = data['last_changed'];

                              if (state == 'online') {
                                return const Text(
                                  'Online',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }

                              return Text(
                                formatLastSeen(
                                  timestamp is num ? timestamp : null,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              );
                            }

                            return const Text(
                              'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatChatTime(timestamp),

                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Icon(Icons.arrow_forward_ios, size: 14),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: otherUserId,
                            otherUserName: name,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
