import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/typewriter_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ollama_dart/ollama_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as md;
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';

class HomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final double fontSize;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;

  const HomePage({
    Key? key,
    required this.themeMode,
    required this.fontSize,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final List<List<Map<String, dynamic>>> _chatSessions =
      []; // All chat sessions
  List<Map<String, dynamic>> _currentChat = []; // Current chat session
  final List<Map<String, dynamic>> _chatHistory = [];
  List<List<Map<String, dynamic>>> _filteredChatSessions =
      []; // Filtered chat sessions
  final TextEditingController _controller = TextEditingController();
  late final double _fontSize;
  final ScrollController _scrollController = ScrollController();
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _loadChatHistory();
    _loadSavedChats(); // Load saved chats on app start
    _filteredChatSessions =
        List.from(_chatSessions); // Initialize with all chats
    _searchController.addListener(_filterChatSummaries);
    // _initializeAnimation();
    _loadChatHistory();
    _filteredChatSessions =
        List.from(_chatSessions); // Initialize with all chats
    _searchController.addListener(_filterChatSummaries);
    // Initialize AnimationController
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Animation duration
    );

    // Define sliding animation from left (-1.0) to the screen (0.0)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // Start off-screen to the left
      end: Offset.zero, // End at the screen's edge
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    )); // Smooth animation curve
  }

  void _startNewChat() {
    if (_currentChat.isNotEmpty) {
      setState(() async {
        _chatSessions.add(List.from(_currentChat)); // Add the current chat
        _currentChat.clear(); // Clear the current chat
        _controller.clear(); // Clear the input box

        await _clearChatHistory();
      });
      _saveChatSessions(); // Save updated sessions
    }
  }

  Future<void> _saveChatSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedChats', jsonEncode(_chatSessions));
  }

  Future<void> _loadSavedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final savedChats = prefs.getString('savedChats');
    if (savedChats != null) {
      setState(() {
        _chatSessions
          ..clear()
          ..addAll(
            (jsonDecode(savedChats) as List<dynamic>).map((session) {
              return (session as List<dynamic>).map((message) {
                return Map<String, dynamic>.from(message);
              }).toList();
            }).toList(),
          );
        _filteredChatSessions = List.from(_chatSessions);
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chatSessions', jsonEncode(_chatSessions));
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = prefs.getString('chatSessions');
    if (sessions != null) {
      setState(() {
        _chatSessions.clear();
        _chatSessions.addAll(
          (jsonDecode(sessions) as List<dynamic>).map((session) {
            return (session as List<dynamic>).map((message) {
              return Map<String, dynamic>.from(message);
            }).toList();
          }).toList(),
        );
      });
    }
  }

  void _filterChatSummaries() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredChatSessions = List.from(_chatSessions);
      } else {
        _filteredChatSessions = _chatSessions.where((session) {
          final summary =
              session.isNotEmpty ? session.first['content'] ?? '' : '';
          return summary.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // void _changeFontSize(double newSize) {
  //   setState(() {
  //     _fontSize = newSize;
  //   });
  // }
  @override
  void dispose() {
    _searchController.dispose(); // Dispose search controller
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search chats...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }

  Widget _buildChatSummaries() {
    return Expanded(
      child: _filteredChatSessions.isEmpty
          ? const Center(child: Text('No chats found'))
          : ListView.builder(
              itemCount: _filteredChatSessions.length,
              itemBuilder: (context, index) {
                final session = _filteredChatSessions[index];
                final summary = session.isNotEmpty
                    ? session.first['content'] ?? 'No messages in this session'
                    : 'No messages in this session';

                return ListTile(
                  title: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    // Update current chat with the selected session
                    setState(() {
                      _currentChat = List.from(_filteredChatSessions[index]);
                      _scrollController
                          .jumpTo(0); // Scroll to top of the session
                    });

                    // Close the sliding menu (if applicable)
                    _closeMenu();
                  },
                );
              },
            ),
    );
  }

  Future<void> _clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chatHistory');
    setState(() {
      _chatHistory.clear();
    });
  }

  Future<void> _exportChatHistory(BuildContext context) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/chat_history.json');
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getString('chatHistory') ?? '[]';

    // Write chat history to file
    await file.writeAsString(history);

    // Convert to XFile and share
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: 'Chat history exported');
  }

  void _sendMessage(String message) async {
    if (message.isEmpty) return;

    final timestamp = DateFormat('hh:mm a').format(DateTime.now());

    // Add user's message to current chat and chat history
    setState(() {
      // Add to `_currentChat`
      _currentChat
          .add({'role': 'user', 'content': message, 'timestamp': timestamp});

      // Add or update the session in `_chatSessions`
      final sessionIndex =
          _chatSessions.indexWhere((session) => session == _currentChat);
      if (sessionIndex >= 0) {
        _chatSessions[sessionIndex] = List.from(_currentChat);
      } else {
        _chatSessions.add(List.from(_currentChat));
      }
    });

    // Save the updated sessions
    await _saveChatSessions();

    // Simulate or fetch AI response
    final prefs = await SharedPreferences.getInstance();
    final selectedModel = prefs.getString('selectedModel') ?? "llama3.2:1b";
    final chatCompletionType =
        prefs.getString('chat_completion_type') ?? "generated_response";

    // Process response based on the type
    if (chatCompletionType == "streamed_response") {
      try {
        final client = OllamaClient();
        final stream = client.generateChatCompletionStream(
          request: GenerateChatCompletionRequest(
            model: selectedModel,
            messages: [
              Message(role: MessageRole.user, content: message),
            ],
            keepAlive: 1,
          ),
        );

        String currentContent = "";

        await for (final res in stream) {
          final content = res.message?.content?.trim() ?? "";
          if (content.isNotEmpty) {
            currentContent = content;

            setState(() {
              if (_currentChat.isNotEmpty &&
                  _currentChat.last['role'] == 'assistant') {
                _currentChat.last['content'] = currentContent;
              } else {
                _currentChat.add({
                  'role': 'assistant',
                  'content': currentContent,
                  'timestamp': timestamp,
                });
              }

              // Update `_chatSessions` with the new content
              final sessionIndex = _chatSessions
                  .indexWhere((session) => session == _currentChat);
              if (sessionIndex >= 0) {
                _chatSessions[sessionIndex] = List.from(_currentChat);
              }
            });
          }
        }
      } catch (e) {
        setState(() {
          _currentChat.add({
            'role': 'error',
            'content': 'Error: $e',
            'timestamp': timestamp,
          });
        });
      } finally {
        await _saveChatSessions();
      }
    } else if (chatCompletionType == "generated_response") {
      try {
        final client = OllamaClient();
        final res = await client.generateChatCompletion(
          request: GenerateChatCompletionRequest(
            model: selectedModel,
            messages: [
              Message(role: MessageRole.user, content: message),
            ],
            keepAlive: 1,
          ),
        );

        final content = res.message?.content?.trim() ?? "";
        if (content.isNotEmpty) {
          setState(() {
            _currentChat.add({
              'role': 'assistant',
              'content': content,
              'timestamp': timestamp,
            });

            // Update `_chatSessions` with the new content
            final sessionIndex =
                _chatSessions.indexWhere((session) => session == _currentChat);
            if (sessionIndex >= 0) {
              _chatSessions[sessionIndex] = List.from(_currentChat);
            } else {
              _chatSessions.add(List.from(_currentChat));
            }
          });

          // Save updated sessions
          await _saveChatSessions();
        }
      } catch (e) {
        setState(() {
          _currentChat.add({
            'role': 'error',
            'content': 'Error: $e',
            'timestamp': timestamp,
          });
        });
      } finally {
        await _saveChatSessions();
      }
    }

    // Scroll to the bottom of the chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleMenu() {
    setState(() {
      if (_isMenuOpen) {
        _animationController.reverse(); // Slide out
      } else {
        _animationController.forward(); // Slide in
      }
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      _animationController.reverse(); // Slide out
      setState(() {
        _isMenuOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              // Close the menu if open when tapping outside
              if (_isMenuOpen) {
                _closeMenu();
              }
            },
            child: Column(
              children: [
                const SizedBox(height: 30),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRect(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 30.0),
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _currentChat.length,
                              itemBuilder: (context, index) {
                                final message = _currentChat[index];
                                final isUser = message['role'] == 'user';

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4.0, horizontal: 8.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: isUser
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: GestureDetector(
                                          onLongPress: () {
                                            Clipboard.setData(ClipboardData(
                                                text: message['content']));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Message copied to clipboard'),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isUser
                                                  ? Colors.blueAccent
                                                  : const Color.fromARGB(
                                                      255, 136, 85, 198),
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                            ),
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                isUser
                                                    ? Text(
                                                        message['content'],
                                                        style: TextStyle(
                                                          fontSize:
                                                              widget.fontSize,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      )
                                                    : _formatContent(
                                                        message['content'],
                                                        context,
                                                        widget.fontSize,
                                                      ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  message['timestamp'],
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isUser
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                //
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: null,
                          decoration: const InputDecoration(
                            labelText: 'Enter your message',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          final message = _controller.text;
                          _sendMessage(message);
                          _controller.clear();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 35,
            right: 10, // Align to top-right corner
            child: PopupMenuButton(
              icon: const Icon(Icons.more_vert), // Three-dot menu icon
              onSelected: (value) {
                if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(
                        themeMode: widget.themeMode,
                        fontSize: widget.fontSize,
                        onThemeModeChanged: widget.onThemeChanged,
                        onFontSizeChanged: widget.onFontSizeChanged,
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Settings'),
                ),
              ],
            ),
          ),

          // Transparent "+" Button

          Positioned(
            top: 35,
            right: 40,
            child: FloatingActionButton.small(
              onPressed: () async {
                // Clear chat history first
                await _clearChatHistory();

                // Add new chat session logic
                if (_currentChat.isNotEmpty) {
                  setState(() {
                    _chatSessions.add(List.from(
                        _currentChat)); // Add current chat to sessions
                    _filteredChatSessions =
                        List.from(_chatSessions); // Update the filtered list
                    _currentChat.clear(); // Clear in-memory chats
                  });

                  // Save all chats to persistent storage
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                      'savedChats', jsonEncode(_chatSessions));

                  // Show feedback to the user
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New chat session started!')),
                  );
                } else {
                  // Notify the user if there is no content in the current chat
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No messages to save!')),
                  );
                }
              },
              backgroundColor: Colors.transparent, // Make the button visible
              child: const Icon(Icons.add),
            ),
          ),

          // Sliding Menu
          // Simplified Menu Button
          Positioned(
            top: 32,
            left: 16,
            child: FloatingActionButton(
                onPressed: _toggleMenu,
                elevation: 0.0,
                backgroundColor: Colors.transparent),
          ),
          // Menu Bar with Summaries of Chat Sessions
          SlideTransition(
            position: _slideAnimation, // Bind sliding animation
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller:
                          _searchController, // Use the search controller
                      decoration: InputDecoration(
                        hintText: 'Search chats...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color.fromARGB(255, 45, 5, 189),
                      ),
                    ),
                  ),

                  // Summary of Chat Sessions
                  Expanded(
                    child: _filteredChatSessions.isEmpty
                        ? const Center(child: Text('No chats found'))
                        : ListView.builder(
                            itemCount: _filteredChatSessions.length,
                            itemBuilder: (context, index) {
                              final session = _filteredChatSessions[index];
                              final summary = session.isNotEmpty
                                  ? session.first['content'] ??
                                      'No messages in this session'
                                  : 'No messages in this session';

                              return ListTile(
                                title: Text(
                                  summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  setState(() {
                                    _currentChat =
                                        List.from(_filteredChatSessions[index]);
                                    _toggleMenu(); // Close the menu
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Clear History'),
                    onTap: () async {
                      await _clearChatHistory();
                      _toggleMenu(); // Close the menu
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

Widget _formatContent(String content, BuildContext context, double fontSize) {
  final RegExp codeBlockRegex = RegExp(r'```(.*?)\n(.*?)```', dotAll: true);
  final RegExp mathBlockRegex = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
  final RegExp sentenceRegex = RegExp(r'([^\.]+?\.)');

  List<Widget> parsedSegments = [];

  while (content.isNotEmpty) {
    // Match code blocks
    if (codeBlockRegex.hasMatch(content)) {
      final match = codeBlockRegex.firstMatch(content);
      if (match != null) {
        final language = match.group(1)?.trim().toLowerCase() ?? 'plaintext';
        final code = match.group(2)?.trim() ?? '';

        parsedSegments.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF282A36),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF6272A4), width: 1.0),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF44475A),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      language.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Code copied to clipboard!"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.copy,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 30.0),
                  child: _TypewriterHighlight(
                    text: code,
                    language: language,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        );

        content = content.replaceFirst(codeBlockRegex, '');
        continue;
      }
    }

    // Handle math blocks (no typewriter effect for now)
    else if (mathBlockRegex.hasMatch(content)) {
      parsedSegments.add(
        md.MarkdownBody(
          selectable: true,
          data: 'latex: \$c = \\pm\\sqrt{a^2 + b^2}\$',
          builders: {
            'latex': LatexElementBuilder(
              textStyle: const TextStyle(
                fontFamily: "Arial",
                color: Color.fromARGB(255, 11, 223, 106),
              ),
              textScaleFactor: 1.2,
            ),
          },
          extensionSet: markdown.ExtensionSet(
            [LatexBlockSyntax()],
            [LatexInlineSyntax()],
          ),
        ),
      );

      content = content.replaceFirst(mathBlockRegex, '');
      continue;
    }

    // Match plain text sentences with typewriter effect
    if (sentenceRegex.hasMatch(content)) {
      final match = sentenceRegex.firstMatch(content);
      if (match != null) {
        final sentence = match.group(0)?.trim() ?? '';

        parsedSegments.add(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TypewriterText(
              text: sentence,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
            ),
          ),
        );

        content = content.replaceFirst(sentenceRegex, '');
        continue;
      }
    }

    // Handle remaining plain text with typewriter effect
    parsedSegments.add(
      TypewriterText(
        text: content,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
    );
    content = ''; // Exit loop
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: parsedSegments,
  );
}

//    Syntax highlightimg

// Custom widget to add typewriter effect to HighlightView
class _TypewriterHighlight extends StatefulWidget {
  final String text;
  final String language;
  final double fontSize;

  const _TypewriterHighlight({
    required this.text,
    required this.language,
    required this.fontSize,
    Key? key,
  }) : super(key: key);

  @override
  _TypewriterHighlightState createState() => _TypewriterHighlightState();
}

class _TypewriterHighlightState extends State<_TypewriterHighlight> {
  String _displayText = '';
  late int _currentIndex;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayText = widget.text.substring(0, _currentIndex + 1);
        });
        _currentIndex++;
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HighlightView(
      _displayText, // Dynamically updating the displayed text
      language: widget.language, // Language name
      theme: draculaTheme, // Theme for syntax highlighting
      padding: const EdgeInsets.all(12),
      textStyle: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: widget.fontSize * 0.8,
      ),
    );
  }
}
