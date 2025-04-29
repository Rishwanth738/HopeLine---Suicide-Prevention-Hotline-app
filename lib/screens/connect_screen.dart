import 'dart:io';
import 'package:flutter/material.dart';

class ConnectScreen extends StatefulWidget {
  @override
  _ConnectScreenState createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  Socket? socket;
  TextEditingController messageController = TextEditingController();
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  void _connectToServer() async {
    try {
      socket = await Socket.connect('YOUR_SERVER_IP', 4040);
      socket!.listen((data) {
        final message = String.fromCharCodes(data);
        setState(() => messages.add("Therapist: $message"));
      });
    } catch (e) {
      setState(() => messages.add("❌ Could not connect: $e"));
    }
  }

  void _sendMessage(String text) {
    if (socket != null) {
      socket!.write(text);
      setState(() => messages.add("You: $text"));
      messageController.clear();
    }
  }

  @override
  void dispose() {
    socket?.close();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Live Therapist Connection")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) => Text(messages[index]),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendMessage(messageController.text),
                  child: Text("Send"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
