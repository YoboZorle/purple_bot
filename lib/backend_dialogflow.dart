import 'package:flutter_dialogflow/dialogflow_v2.dart';
import 'backend.dart';
import 'model.dart';

class DialogFlowChatManager extends ChatManager {
  Map<String, ChatSession> _cache = {};

  @override
  ChatSession getNamedSession(String name) {
    var session = _cache[name];
    if (session == null) {
      session = DialogFlowChatSession(name);
      _cache[name] = session;
    }
    return session;
  }
}

class DialogFlowChatSession extends ChatSession {

  Dialogflow dialogflow;

  List<ChatMessage> _messages = <ChatMessage>[];

  @override
  ChatMessage operator [](int index) => _messages[index];

  @override
  int get messageCount => _messages.length;

  DialogFlowChatSession(String name) : super(name);

  @override
  void start() async {
    AuthGoogle authGoogle = await AuthGoogle(fileJson: "assets/gc-service-account.json").build();
    this.dialogflow = Dialogflow(authGoogle: authGoogle,language: Language.english);
    _sendToServer("Hi");
  }

  @override
  void close() {
    // TODO: End session
  }

  @override
  void sendMessage(String text) {
    if (text == null) {
      return;
    }
    _insertMessage(ChatMessage.fromMyself(text));
    _sendToServer(text);
  }

  void _insertMessage(ChatMessage message) {
    _messages.insert(0, message);

    if (onMessageInserted != null) {
      onMessageInserted(0, message);
    }

    if (message.from == ChatMessageFrom.Myself && _messages.length >= 2) {
        final previousMessage = _messages[1];

        if(previousMessage.from != ChatMessageFrom.AutoReply) {
          return;
        }

        _messages.removeAt(1);
        if(onMessageRemoved != null) {
          onMessageRemoved(1, previousMessage);
        }
    }
  }

  void _sendToServer(String text) async {
    AIResponse response = await dialogflow.detectIntent(text);

    if(response.getListMessage().length >= 2) {
      final payloadMap = response.getListMessage()[1]['payload'];
      final messageTypeString = (payloadMap['messageType'] ?? '').toString().toLowerCase();
      final images = payloadMap['images'] != null ? List<String>.from(payloadMap['images']) : null;
      var messageType = MessageType.Text;


      switch(messageTypeString) {
        case 'video':
          messageType = MessageType.Video;
          break;
        case 'image':
          messageType = MessageType.Image;
          break;
      }

      _insertMessage(ChatMessage.fromServer(response.getMessage(), payloadMap['link'], messageType, images));

      final replyOptions = payloadMap['replyOptions'];
      if(replyOptions != null) {
          _insertMessage(ChatMessage.forAutoReply(List<String>.from(replyOptions)));
      }
    } else if(response.getMessage() != null) {
      _insertMessage(ChatMessage.fromServer(response.getMessage()));
    }
  }
}
