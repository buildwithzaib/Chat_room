import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

String formatChatLastSeen(num? timestamp) {
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

  return 'Last seen ${date.day}/${date.month}/${date.year} at $time';
}

String formatMessageTime(Timestamp? timestamp) {
  if (timestamp == null) return '';

  final date = timestamp.toDate().toLocal();

  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();

  bool isSending = false;

  String get chatId {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final ids = [currentUserId, widget.otherUserId];

    ids.sort();

    return ids.join('_');
  }

  Future<void> sendMessage() async {
    final message = messageController.text.trim();

    if (message.isEmpty || isSending) return;

    setState(() {
      isSending = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;

      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);

      // Create or update chat information
      await chatRef.set({
        'participants': [currentUser.uid, widget.otherUserId],
        'lastMessage': message,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save message
      await chatRef.collection('messages').add({
        'senderId': currentUser.uid,
        'receiverId': widget.otherUserId,
        'text': message,
        'createdAt': FieldValue.serverTimestamp(),
      });

      messageController.clear();
    } catch (e) {
      print("MESSAGE ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message could not be sent")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,

        title: StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL:
                'https://my-chat-app-b3ff3-default-rtdb.firebaseio.com/',
          ).ref('status/${widget.otherUserId}').onValue,

          builder: (context, snapshot) {
            final data = snapshot.data?.snapshot.value;

            String statusText = 'Checking status...';
            Color statusColor = Colors.white70;

            if (data is Map) {
              final state = data['state'];
              final timestamp = data['last_changed'];

              if (state == 'online') {
                statusText = 'Online';
                statusColor = Colors.lightGreenAccent;
              } else {
                statusText = formatChatLastSeen(
                  timestamp is num ? timestamp : null,
                );
              }
            } else if (snapshot.hasData) {
              statusText = 'Offline';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  statusText,
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ],
            );
          },
        ),
      ),

      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesRef.snapshots(),

              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading messages"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text("Say hello! Start your conversation."),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,

                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;

                    final isMe = data['senderId'] == currentUserId;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,

                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),

                        padding: const EdgeInsets.all(12),

                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),

                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(15),
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data['text'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              formatMessageTime(
                                data['createdAt'] as Timestamp?,
                              ),
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(10),

            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: isSending ? null : sendMessage,
                  icon: const Icon(Icons.send, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
