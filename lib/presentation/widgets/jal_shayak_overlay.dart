import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/providers/language_provider.dart';
import '../../core/services/rag_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';

class JalShayakOverlay extends StatefulWidget {
  const JalShayakOverlay({Key? key}) : super(key: key);

  @override
  State<JalShayakOverlay> createState() => _JalShayakOverlayState();
}

class _JalShayakOverlayState extends State<JalShayakOverlay> {
  bool _isExpanded = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  // Speech & TTS Variables
  bool _isListening = false;
  bool _isMuted = false;
  String _sttLocale = 'en-IN'; // independent mic language toggle
  late stt.SpeechToText _speechToText;
  late FlutterTts _flutterTts;

  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initTts();
    _messages = []; // will be populated in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _messages = [
        ChatMessage(
          text: AppLocalizations.of(context)!.get('jal_shayak_greeting'),
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
    }
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  String _getTtsLocale(String langCode) => langCode == 'hi' ? 'hi-IN' : 'en-IN';

  Future<void> _speak(String text) async {
    if (!_isMuted) {
      final langCode = Provider.of<LanguageProvider>(
        context,
        listen: false,
      ).currentLanguage;
      await _flutterTts.setLanguage(_getTtsLocale(langCode));
      String cleanText = text.replaceAll('*', '').replaceAll('#', '');
      await _flutterTts.speak(cleanText);
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speechToText.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  // --- REVERTED & FIXED SPEECH_TO_TEXT LOGIC ---
  void _listen() async {
    // If currently listening, stop it manually
    if (_isListening) {
      setState(() => _isListening = false);
      _speechToText.stop();
      return;
    }

    _stopSpeaking(); // Stop AI talking when user clicks mic

    bool available = await _speechToText.initialize(
      onStatus: (val) {
        // Automatically update UI when listening stops on its own
        if (val == 'done' || val == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (val) {
        debugPrint('STT Error: $val');
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speechToText.listen(
        localeId: _sttLocale,
        onResult: (val) {
          setState(() {
            _messageController.text = val.recognizedWords;
          });

          // Auto-send when the user finishes speaking
          if (val.finalResult) {
            setState(() => _isListening = false);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_messageController.text.isNotEmpty) {
                _sendMessage(_messageController.text);
              }
            });
          }
        },
      );
    } else {
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied.')),
      );
    }
  }
  // ---------------------------------------------

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    _stopSpeaking();

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    _fetchAIResponse(text);
  }

  Future<void> _fetchAIResponse(String userMessage) async {
    try {
      final response = await RAGService.sendMessage(userMessage);

      if (mounted) {
        final aiResponse = ChatMessage(
          text: response.reply,
          isUser: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(aiResponse);
          _isLoading = false;
        });

        _scrollToBottom();
        _speak(response.reply);
      }
    } catch (e) {
      if (mounted) {
        final errorResponse = ChatMessage(
          text:
              '⚠️ Error: ${e.toString()}\n\nTroubleshooting:\n• Check internet connection\n• Ensure backend server is running',
          isUser: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(errorResponse);
          _isLoading = false;
        });

        _scrollToBottom();
        _speak("I'm sorry, I encountered an error connecting to the server.");
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    return Positioned(
      bottom: 20,
      right: 16,
      width: _isExpanded ? MediaQuery.of(context).size.width - 32 : 72,
      height: _isExpanded ? 420 : 72,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _isExpanded ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isExpanded
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: _isExpanded ? _buildExpandedView() : _buildCollapsedView(),
      ),
    );
  }

  Widget _buildCollapsedView() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = true;
        });
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.get('jal_shayak'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.get('jal_shayak'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.get('jal_shayak_help'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMuted = !_isMuted;
                      if (_isMuted) _stopSpeaking();
                    });
                  },
                  child: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = false;
                      _stopSpeaking();
                      if (_isListening) {
                        _isListening = false;
                        _speechToText.stop();
                      }
                    });
                  },
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Messages Area
          Expanded(
            child: Container(
              color: AppColors.lightGrey,
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.get('ask_question'),
                        style: const TextStyle(
                          color: AppColors.mediumGrey,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final message = _messages[index];
                        return Align(
                          alignment: message.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: message.isUser
                                  ? AppColors.primary
                                  : AppColors.lightGrey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: message.isUser
                                    ? Colors.white
                                    : AppColors.darkGrey,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(
                        context,
                      )!.get('ask_question'),
                      hintStyle: const TextStyle(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 11),
                    onSubmitted: (value) => _sendMessage(value),
                  ),
                ),
                const SizedBox(width: 6),

                // --- STT LANGUAGE TOGGLE ---
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _sttLocale = _sttLocale == 'en-IN' ? 'hi-IN' : 'en-IN';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _sttLocale == 'hi-IN'
                          ? AppColors.warning
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _sttLocale == 'hi-IN' ? 'HI' : 'EN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // --- MIC BUTTON ---
                GestureDetector(
                  onTap: _listen,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors
                                .red // Turns red while recording
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _sendMessage(_messageController.text),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      size: 14,
                      color: Colors.white,
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

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
