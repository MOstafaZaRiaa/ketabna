import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:full_screen_image_null_safe/full_screen_image_null_safe.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ketabna/core/widgets/components.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'constants.dart';
import 'media_for_chat.dart';

final _firestore = FirebaseFirestore.instance;
final String? _auth = FirebaseAuth.instance.currentUser?.uid.toString();
List<String> imagesUrl = [];
int numberOfMessages = 0;
int readedMessages = 0;
int totalMessages = 0;

class ChatScreen extends StatefulWidget {
  final String ownerName;
  final String ownerUid;
  final String conversationDocId;

  const ChatScreen(
      {required this.ownerName,
      required this.ownerUid,
      required this.conversationDocId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageTextController = TextEditingController();

  late String message;

  @override
  void initState() {
    super.initState();
    // checkForOldConversation();
  }

  @override
  void dispose() {
    //numberOfMessages = 0;
    super.dispose();
  }

  sendMessage(message) async {
    await _firestore.collection('chats').doc(widget.conversationDocId).update(
      {
        'messages': FieldValue.arrayUnion([
          {
            'sender': _auth,
            'text': message,
            'time': DateTime.now().toIso8601String().toString(),
          }
        ])
      },
    );
  }

  pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    final path = 'files/${image?.name}';
    final _image = File(image!.path);
    final ref = FirebaseStorage.instance.ref().child(path);
    final uploadedTask = ref.putFile(_image);
    final snapHot = await uploadedTask.whenComplete(() => {});
    final urlDownload = await snapHot.ref.getDownloadURL();
    print('urlDownload : ' + urlDownload);
    sendMessage(urlDownload);
  }

  // Future<bool> checkForOldConversation() async {
  //   String ids;
  //   bool containUid_1 = false;
  //   bool containUid_2 = false;
  //   bool oldchat = false;
  //   try {
  //     await FirebaseFirestore.instance
  //         .collection("chats")
  //         .get()
  //         .then((value) => {
  //               value.docs.forEach((element) {
  //                 ids = element.data()['ids'].toString();
  //                 containUid_1 = ids.contains(widget.ownerUid);
  //                 containUid_2 = ids.contains(_auth!);
  //                 if (containUid_1 && containUid_2) {
  //                   print("element.id : "+element.id);
  //                   widget.conversationDocId = element.id;
  //                 }
  //                 oldchat = true;
  //               })
  //             });
  //   } catch (error) {
  //     print(error.toString());
  //   }
  //   if (!oldchat) {
  //     setNewConversation();
  //   }
  //   return containUid_1;
  // }

  // Future getMessages() async {
  //   await FirebaseFirestore.instance.collection("chats").get().then((value) => {
  //         value.docs.forEach((element) {
  //           try {
  //             numberOfMessages = element.data()['messages'].length;
  //             print("numberOfMessages : " + numberOfMessages.toString());
  //             readedMessages = element.data()['readedMessages'];
  //             totalMessages = element.data()['totalMessages'];
  //             for (int i = 0; i < numberOfMessages; i++) {
  //               final text = element.data()['messages'][i]['text'];
  //               final sender = element.data()['messages'][i]['sender'];
  //               final time =
  //                   DateTime.parse(element.data()['messages'][i]['time']);
  //
  //               messagesWidget.add(MessageBuble(
  //                 text: text,
  //                 sender: sender,
  //                 time: time,
  //                 isMe: element.data()['messages'][i]['sender'] == _auth,
  //               ));
  //             }
  //             messagesWidget.sort((a, b) => a.time.compareTo(b.time));
  //             print("sender : " + messagesWidget[0].text);
  //           } catch (error) {
  //             print(error.toString());
  //             return;
  //           }
  //         })
  //       });
  // }

  // Future setNewConversation() async {
  //   await _firestore.collection("chats").add({
  //     'ids': [
  //       widget.ownerUid,
  //       _auth,
  //     ],
  //     'messages': [],
  //     'readedMessages': 0,
  //     'totalMessages': 0,
  //   }).then((documentSnapshot) => {
  //         print("Added Data with ID: ${documentSnapshot.id}"),
  //         conversationDocId = documentSnapshot.id,
  //       });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: InkWell(
          onTap: (){
            Navigator.push(context, MaterialPageRoute(builder: (context)=>MediaForChat(imagesUrl: imagesUrl,),),);
          },
          child: Text(widget.ownerName),
        ),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MessageStream(conversationDocId: widget.conversationDocId),
            Container(
              decoration: kMessageContainerDecoration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    onPressed: () {
                      pickImage();
                    },
                    icon: const Icon(Icons.photo_size_select_actual),
                  ),
                  Expanded(
                    child: TextField(
                      controller: messageTextController,
                      onChanged: (value) {
                        //Do something with the user input.
                        message = value;
                      },
                      decoration: kMessageTextFieldDecoration,
                    ),
                  ),
                  FlatButton(
                    onPressed: () async {
                      messageTextController.clear();
                      //Implement send functionality.
                      sendMessage(message);
                    },
                    child: const Text(
                      'Send',
                      style: kSendButtonTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageStream extends StatelessWidget {
  MessageStream({required this.conversationDocId});

  final String conversationDocId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream:
            _firestore.collection('chats').doc(conversationDocId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                backgroundColor: Colors.lightBlueAccent,
              ),
            );
          }
          final conversationDoc = snapshot.data!;
          List<MessageBuble> messagesWidget = [];
          imagesUrl = [];
          print("snapshot : " + conversationDoc['ids'][0]);
          numberOfMessages = conversationDoc['messages'].length;
          readedMessages = conversationDoc['readedMessages'];
          totalMessages = conversationDoc['totalMessages'];
          for (int i = 0; i < numberOfMessages; i++) {
            final text = conversationDoc['messages'][i]['text'];
            final sender = conversationDoc['messages'][i]['sender'];
            final time = DateTime.parse(conversationDoc['messages'][i]['time']);
            if (text.contains('firebasestorage.googleapis.com')) {

              imagesUrl.add(text);
              print('imagesUrl : ' + imagesUrl.length.toString());
            }
            messagesWidget.add(MessageBuble(
              text: text,
              sender: sender,
              time: time,
              isMe: conversationDoc['messages'][i]['sender'] == _auth,
            ));
          }
          messagesWidget.sort((a, b) => a.time.compareTo(b.time));

          return Expanded(
            child: ListView(
              children: messagesWidget,
            ),
          );
        });
  }
}

class MessageBuble extends StatelessWidget {
  final String sender;
  final String text;
  final DateTime time;
  final bool isMe;

  MessageBuble(
      {required this.sender,
      required this.text,
      required this.isMe,
      required this.time});
launchUri(Uri url)async{
  if(!text.contains('firebasestorage.googleapis.com') && text.contains('http')&& await canLaunchUrl(url)){
    // ignore: deprecated_member_use
    await launchUrl(url,mode: LaunchMode.inAppWebView);
  }
}
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Material(
            elevation: 5.0,
            borderRadius: isMe
                ? const BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    bottomLeft: Radius.circular(30.0),
                    bottomRight: Radius.circular(30.0),
                  )
                : const BorderRadius.only(
                    topRight: Radius.circular(30.0),
                    bottomLeft: Radius.circular(30.0),
                    bottomRight: Radius.circular(30.0),
                  ),
            child: Padding(
              padding: text.contains('firebasestorage.googleapis.com')
                  ? const EdgeInsets.symmetric(horizontal: 5, vertical: 5)
                  : const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: text.contains('firebasestorage.googleapis.com')
                  ? FullScreenWidget(
                      child: Hero(
                        tag: "customTag",
                        child: Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            image: DecorationImage(
                              image: NetworkImage(text),
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ),
                    )
                  : InkWell(
                    onTap: (){
                      Uri url = Uri.parse(text);
                      launchUri(url);
                    },
                    onLongPress: (){
                      Clipboard.setData(ClipboardData(text: text)).then((value) => {
                        buildSnackBar(context, 'Copied to clipboard.')
                      });
                    },
                    child: Text(
                        text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black45,
                          fontSize: 15.0,
                        ),
                      ),
                  ),
            ),
            color: isMe ? Colors.lightBlueAccent : Colors.white,
          ),
        ],
      ),
    );
  }
}
