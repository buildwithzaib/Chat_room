import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://my-chat-app-b3ff3-default-rtdb.firebaseio.com/',
  );

  // User ko online karna
  Future<void> startPresence() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (_connectionSubscription != null) return;

    final statusRef = _database.ref('status/${user.uid}');
    final connectedRef = _database.ref('.info/connected');

    _connectionSubscription = connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value == true;

      if (!connected) return;

      try {
        // Internet disconnect hone par automatically offline
        await statusRef.onDisconnect().set({
          'state': 'offline',
          'last_changed': ServerValue.timestamp,
        });

        // User online hai
        await statusRef.set({
          'state': 'online',
          'last_changed': ServerValue.timestamp,
        });
      } catch (error) {
        print('Presence Error: $error');
      }
    });
  }

  // Logout ke waqt user ko offline karna
  Future<void> stopPresence() async {
    final user = FirebaseAuth.instance.currentUser;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (user == null) return;

    await _database.ref('status/${user.uid}').set({
      'state': 'offline',
      'last_changed': ServerValue.timestamp,
    });
  }
}
