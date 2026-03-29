import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotit/features/chat/data/models/chat_message_model.dart';
import 'package:spotit/features/chat/domain/repositories/chat_repository.dart';
import 'package:spotit/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:spotit/main.dart';

// ChatScreen is the full-screen chat window where a citizen and an official
// can exchange messages in real-time. It works for both sides:
//   - When isOfficial is true  → the government official is chatting
//   - When isOfficial is false → the citizen is chatting
//
// Both sides see the same messages; the bubble alignment flips based on whose
// message it is (left = other person, right = you).
class ChatScreen extends StatefulWidget {
  final String chatId;        // identifies which chat session to load
  final String otherUserName; // the name shown in the top bar header
  final bool isOfficial;      // true if the current user is a government official

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.isOfficial,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatRepository _chatRepository;
  late String _currentUserId;
  bool _hasInitialized = false; // prevents running setup more than once

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We use didChangeDependencies (not initState) because we need context
    // to access the ChatRepositoryProvider higher up the widget tree
    if (!_hasInitialized) {
      _chatRepository = ChatRepositoryProvider.of(context);
      _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // As soon as the chat opens, mark it as read for the current user
      // so the unread badge on the nav tab goes away
      if (widget.isOfficial) {
        _chatRepository.markReadByOfficial(widget.chatId);
      } else {
        _chatRepository.markReadByCitizen(widget.chatId);
      }
      _hasInitialized = true;
    }
  }

  @override
  void dispose() {
    // Always dispose controllers to free memory when the screen is closed
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Sends the typed message to Firestore and clears the input field
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return; // don't send blank messages

    _messageController.clear(); // clear before the async call for snappy UX
    _chatRepository.sendMessage(
      chatId: widget.chatId,
      senderId: _currentUserId,
      text: text,
      isOfficialSender: widget.isOfficial, // used to set the correct read flags
    );
  }

  // Scrolls to the bottom of the message list after a new message is loaded.
  // addPostFrameCallback waits until the frame has rendered before scrolling,
  // otherwise the scroll position might not reflect the latest messages yet.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputBg = isDark ? const Color(0xFF1E2124) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Small icon showing whether we're chatting with a citizen or official
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2B2D31)
                    : Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.isOfficial ? Icons.person : Icons.shield,
                color: const Color(0xFFF9A825), // gold
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The other person's name
                  Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName
                        : 'Chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Their role label below the name
                  Text(
                    widget.isOfficial ? 'Citizen' : 'Government Official',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [

          // Message list — streams new messages in real-time from Firestore
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatRepository.streamMessages(widget.chatId),
              builder: (context, snapshot) {
                // Show spinner on first load
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF9A825),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                // Empty state — shown before either person has sent anything
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 56,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll down whenever the list updates with new messages
                _scrollToBottom();

                // Build one ChatBubble widget per message
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return ChatBubble(
                      message: msg,
                      isMe: msg.senderId == _currentUserId, // am I the sender?
                    );
                  },
                );
              },
            ),
          ),

          // Message input bar at the bottom
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.black.withAlpha(20),
                ),
              ),
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              // Extra bottom padding so the input bar sits above the phone's home indicator
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                // The text input field
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        border: InputBorder.none, // remove the underline
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,  // grows up to 4 lines before scrolling
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(), // send on keyboard return
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button — green circle with a send icon
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2EAA5E), // SpotIT green
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
