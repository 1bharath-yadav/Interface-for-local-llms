// import 'dart:io';
// import 'dart:convert';
// import 'package:intl/intl.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:ollama_dart/ollama_dart.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:markdown/markdown.dart' as markdown;
// import 'package:flutter_highlight/themes/dracula.dart';
// import 'package:flutter_highlight/flutter_highlight.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_markdown/flutter_markdown.dart' as md;
// import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';

// void main() {
//   runApp(const ArcherAssistantApp());
// }

// class ArcherAssistantApp extends StatefulWidget {
//   const ArcherAssistantApp({Key? key}) : super(key: key);

//   @override
//   _ArcherAssistantAppState createState() => _ArcherAssistantAppState();
// }

// class _ArcherAssistantAppState extends State<ArcherAssistantApp> {
//   ThemeMode _themeMode = ThemeMode.system;
//   double _fontSize = 16.0;

//   void _changeTheme(ThemeMode mode) {
//     setState(() {
//       _themeMode = mode;
//     });
//   }

//   void _changeFontSize(double size) {
//     setState(() {
//       _fontSize = size;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Archer Assistant',
//       theme: ThemeData.light(),
//       darkTheme: ThemeData.dark(),
//       themeMode: _themeMode,
//       home: HomePage(
//         themeMode: _themeMode,
//         fontSize: _fontSize,
//         onThemeChanged: _changeTheme,
//         onFontSizeChanged: _changeFontSize,
//       ),
//     );
//   }
// }

// class HomePage extends StatefulWidget {
//   final ThemeMode themeMode;
//   final double fontSize;
//   final ValueChanged<ThemeMode> onThemeChanged;
//   final ValueChanged<double> onFontSizeChanged;

//   const HomePage({
//     Key? key,
//     required this.themeMode,
//     required this.fontSize,
//     required this.onThemeChanged,
//     required this.onFontSizeChanged,
//   }) : super(key: key);

//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   final List<Map<String, dynamic>> _chatHistory = [];
//   final TextEditingController _controller = TextEditingController();
//   late final double _fontSize;
//   final ScrollController _scrollController = ScrollController();
//   bool _isMenuOpen = false;

//   @override
//   void initState() {
//     super.initState();
//     _fontSize = widget.fontSize;
//     _loadChatHistory();
//   }

//   // void _changeFontSize(double newSize) {
//   //   setState(() {
//   //     _fontSize = newSize;
//   //   });
//   // }

//   Future<void> _loadChatHistory() async {
//     final prefs = await SharedPreferences.getInstance();
//     final history = prefs.getString('chatHistory');
//     if (history != null) {
//       setState(() {
//         _chatHistory.clear();
//         _chatHistory
//             .addAll(List<Map<String, dynamic>>.from(jsonDecode(history)));
//       });
//     }
//   }

//   Future<void> _saveChatHistory() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('chatHistory', jsonEncode(_chatHistory));
//   }

//   void _startNewChat() {
//     setState(() {
//       _chatHistory.clear();
//       _controller.clear();
//     });
//   }

//   Future<void> _clearChatHistory() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('chatHistory');
//     setState(() {
//       _chatHistory.clear();
//     });
//   }

//   Future<void> _exportChatHistory(BuildContext context) async {
//     final directory = await getApplicationDocumentsDirectory();
//     final file = File('${directory.path}/chat_history.json');
//     final prefs = await SharedPreferences.getInstance();
//     final history = prefs.getString('chatHistory') ?? '[]';

//     // Write chat history to file
//     await file.writeAsString(history);

//     // Convert to XFile and share
//     final xFile = XFile(file.path);
//     await Share.shareXFiles([xFile], text: 'Chat history exported');
//   }

//   void _sendMessage(String message) async {
//     if (message.isEmpty) return;

//     final timestamp = DateFormat('hh:mm a').format(DateTime.now());
//     setState(() {
//       _chatHistory
//           .add({'role': 'user', 'content': message, 'timestamp': timestamp});
//     });

//     final prefs = await SharedPreferences.getInstance();
//     final selectedModel = prefs.getString('selectedModel') ?? "llama3.2:1b";
//     final chatCompletionType =
//         prefs.getString('chat_completion_type') ?? "generated_response";

//     if (chatCompletionType == "streamed_response") {
//       // Streamed Response Logic
//       try {
//         final client = OllamaClient();
//         final stream = client.generateChatCompletionStream(
//           request: GenerateChatCompletionRequest(
//             model: selectedModel,
//             messages: [
//               Message(role: MessageRole.user, content: message),
//             ],
//             keepAlive: 1,
//           ),
//         );

//         String currentContent = "";

//         await for (final res in stream) {
//           final content = res.message?.content?.trim() ?? "";
//           if (content.isNotEmpty) {
//             setState(() {
//               if (_chatHistory.isNotEmpty &&
//                   _chatHistory.last['role'] == 'assistant') {
//                 _chatHistory.last['content'] = currentContent;
//               } else {
//                 _chatHistory.add({
//                   'role': 'assistant',
//                   'content': currentContent,
//                   'timestamp': timestamp,
//                 });
//               }
//             });

//             if (!_scrollController.position.isScrollingNotifier.value) {
//               _scrollController.animateTo(
//                 _scrollController.position.maxScrollExtent,
//                 duration: const Duration(milliseconds: 400),
//                 curve: Curves.easeInOut,
//               );
//             }
//           }
//         }
//       } catch (e) {
//         setState(() {
//           _chatHistory.add({
//             'role': 'error',
//             'content': 'Error: $e',
//             'timestamp': timestamp,
//           });
//         });
//       } finally {
//         _saveChatHistory();
//         setState(() {});
//       }
//     } else if (chatCompletionType == "generated_response") {
//       // Generated Response Logic
//       try {
//         final client = OllamaClient();

//         final res = await client.generateChatCompletion(
//           request: GenerateChatCompletionRequest(
//             model: selectedModel,
//             messages: [
//               Message(role: MessageRole.user, content: message),
//             ],
//             keepAlive: 1,
//           ),
//         );

//         final content = res.message?.content?.trim() ?? "";
//         if (content.isNotEmpty) {
//           setState(() {
//             if (_chatHistory.isNotEmpty &&
//                 _chatHistory.last['role'] == 'assistant') {
//               _chatHistory.last['content'] = content;
//             } else {
//               _chatHistory.add({
//                 'role': 'assistant',
//                 'content': content,
//                 'timestamp': timestamp
//               });
//             }
//           });

//           if (!_scrollController.position.isScrollingNotifier.value) {
//             _scrollController.animateTo(
//               _scrollController.position.maxScrollExtent,
//               duration: const Duration(milliseconds: 400),
//               curve: Curves.easeInOut,
//             );
//           }
//         }
//       } catch (e) {
//         setState(() {
//           _chatHistory.add({
//             'role': 'error',
//             'content': 'Error: $e',
//             'timestamp': timestamp,
//           });
//         });
//       } finally {
//         _saveChatHistory();
//         setState(() {});
//       }
//     }
//   }

//   Widget _formatContent(String content, BuildContext context, double fontSize) {
//     // Use fontSize passed from HomePage
//     final RegExp codeBlockRegex = RegExp(r'```(.*?)\n(.*?)```', dotAll: true);
//     final RegExp mathBlockRegex = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
//     final RegExp sentenceRegex = RegExp(r'([^\.]+?\.)');

//     List<Widget> parsedSegments = [];

//     while (content.isNotEmpty) {
//       if (codeBlockRegex.hasMatch(content)) {
//         final match = codeBlockRegex.firstMatch(content);
//         if (match != null) {
//           final language = match.group(1)?.trim().toUpperCase() ?? 'CODE';
//           final code = match.group(2)?.trim() ?? '';

//           parsedSegments.add(
//             Container(
//               margin: const EdgeInsets.symmetric(vertical: 8.0),
//               padding: const EdgeInsets.all(8.0),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF282A36),
//                 borderRadius: BorderRadius.circular(12.0),
//                 border: Border.all(color: const Color(0xFF6272A4), width: 1.0),
//               ),
//               child: Stack(
//                 children: [
//                   Positioned(
//                     top: 4,
//                     left: 8,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 6, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF44475A),
//                         borderRadius: BorderRadius.circular(4.0),
//                       ),
//                       child: Text(
//                         language,
//                         style: const TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ),
//                   Positioned(
//                     top: 4,
//                     right: 8,
//                     child: GestureDetector(
//                       onTap: () {
//                         Clipboard.setData(ClipboardData(text: code));
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text("Code copied to clipboard!"),
//                             duration: Duration(seconds: 2),
//                           ),
//                         );
//                       },
//                       child: const Icon(
//                         Icons.copy,
//                         size: 20,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.only(top: 30.0),
//                     child: HighlightView(
//                       code, // Your source code string
//                       language: language,
//                       theme: draculaTheme,
//                       padding: const EdgeInsets.all(12.0),
//                       textStyle: const TextStyle(
//                         fontFamily:
//                             'My awesome monospace font', // Custom monospace font
//                         fontSize: 16, // Font size for code
//                         color:
//                             Color(0xFFF8F8F2), // Use color from SelectableText
//                       ),
//                       duration: const Duration(milliseconds: 20),
//                     ),
//                   )
//                 ],
//               ),
//             ),
//           );
//           content = content.replaceFirst(codeBlockRegex, '');
//           continue;
//         }
//       }
//       // Handle math block rendering
//       else if (mathBlockRegex.hasMatch(content)) {
//         return md.MarkdownBody(
//           selectable: true,
//           data: 'latex: \$c = \\pm\\sqrt{a^2 + b^2}\$',
//           builders: {
//             'latex': LatexElementBuilder(
//               textStyle: const TextStyle(
//                   fontFamily: "Arial",
//                   color: Color.fromARGB(255, 11, 223, 106)),
//               textScaleFactor: 1.2,
//             ),
//           },
//           extensionSet: markdown.ExtensionSet(
//             [LatexBlockSyntax()],
//             [LatexInlineSyntax()],
//           ),
//         );
//       }
//       // Plain text rendering
//       parsedSegments.add(
//         Container(
//           padding: const EdgeInsets.all(8),
//           child: Text(
//             content,
//             style: TextStyle(
//               fontSize: fontSize, // Use updated fontSize here
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//       );
//       content = ''; // Exit loop
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: parsedSegments,
//     );
//   }

//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           Column(
//             children: <Widget>[
//               const SizedBox(height: 24),
//               Expanded(
//                 child: Stack(
//                   children: [
//                     Positioned.fill(
//                       child: ClipRect(
//                         child: Padding(
//                           padding: const EdgeInsets.only(
//                               top: 30.0), // Adjust for "+" button height
//                           child: ListView.builder(
//                             controller: _scrollController,
//                             itemCount: _chatHistory.length,
//                             itemBuilder: (context, index) {
//                               final message = _chatHistory[index];
//                               final isUser = message['role'] == 'user';

//                               return Container(
//                                 margin: const EdgeInsets.symmetric(
//                                     vertical: 4.0, horizontal: 8.0),
//                                 child: Row(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   mainAxisAlignment: isUser
//                                       ? MainAxisAlignment.end
//                                       : MainAxisAlignment.start,
//                                   children: [
//                                     Flexible(
//                                       child: GestureDetector(
//                                         onLongPress: () {
//                                           Clipboard.setData(ClipboardData(
//                                               text: message['content']));
//                                           ScaffoldMessenger.of(context)
//                                               .showSnackBar(
//                                             const SnackBar(
//                                               content: Text(
//                                                   'Message copied to clipboard'),
//                                             ),
//                                           );
//                                         },
//                                         child: Container(
//                                           decoration: BoxDecoration(
//                                             color: isUser
//                                                 ? Colors.blueAccent
//                                                 : const Color.fromARGB(
//                                                     255, 136, 85, 198),
//                                             borderRadius:
//                                                 BorderRadius.circular(12.0),
//                                           ),
//                                           padding: const EdgeInsets.all(8.0),
//                                           child: Column(
//                                             crossAxisAlignment:
//                                                 CrossAxisAlignment.start,
//                                             children: [
//                                               _formatContent(
//                                                   message['content'],
//                                                   context,
//                                                   widget
//                                                       .fontSize // Pass updated fontSize here
//                                                   ),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               //
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _controller,
//                         minLines: 1, // Minimum height for the input box
//                         maxLines: null, // Automatically expand to fit content
//                         decoration: const InputDecoration(
//                           labelText: 'Enter your message',
//                           // border: OutlineInputBorder(),
//                         ),
//                       ),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.send),
//                       onPressed: () {
//                         final message = _controller.text;
//                         _sendMessage(message);
//                         _controller.clear();
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           // Simplified Menu Button
//           Positioned(
//             top: 32,
//             left: 16,
//             child: FloatingActionButton(
//               onPressed: _toggleMenu,
//               child: const Icon(Icons.menu, size: 20),
//               elevation: 0.0,
//               backgroundColor: Colors.transparent,
//             ),
//           ),
//           // Transparent "+" Button

//           Positioned(
//             top: 32,
//             right: 16,
//             child: FloatingActionButton(
//               onPressed: _startNewChat,
//               child: const Icon(Icons.add, size: 20),
//               elevation: 0.0,
//               backgroundColor: Colors.transparent,
//             ),
//           ),
//           if (_isMenuOpen)
//             GestureDetector(
//               onTap: _toggleMenu,
//               child: Container(
//                 color: Colors.black.withOpacity(0.5),
//                 child: Align(
//                   alignment: Alignment.centerLeft,
//                   child: Container(
//                     width: MediaQuery.of(context).size.width * 0.7,
//                     color: Theme.of(context).scaffoldBackgroundColor,
//                     child: Column(
//                       children: [
//                         const SizedBox(height: 24),
//                         ListTile(
//                           leading: const Icon(Icons.settings),
//                           title: const Text('Settings'),
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => SettingsPage(
//                                   themeMode: widget.themeMode,
//                                   fontSize: widget.fontSize,
//                                   onThemeModeChanged: widget.onThemeChanged,
//                                   onFontSizeChanged: widget.onFontSizeChanged,
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                         Expanded(
//                           child: ListView.builder(
//                             itemCount: _chatHistory.length,
//                             itemBuilder: (context, index) {
//                               final history = _chatHistory[index];
//                               return ListTile(
//                                 title: Text(
//                                   history['content'].split('\n').first,
//                                   maxLines: 1,
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                                 subtitle: Text(history['timestamp']),
//                               );
//                             },
//                           ),
//                         ),
//                         ListTile(
//                           leading: const Icon(Icons.delete),
//                           title: const Text('Clear History'),
//                           onTap: () async {
//                             await _clearChatHistory();
//                             _toggleMenu(); // Close the menu
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   void _toggleMenu() {
//     setState(() {
//       _isMenuOpen = !_isMenuOpen;
//     });
//   }
// }

// class SettingsPage extends StatefulWidget {
//   final ThemeMode themeMode;
//   final double fontSize;
//   final ValueChanged<ThemeMode> onThemeModeChanged;
//   final ValueChanged<double> onFontSizeChanged;

//   const SettingsPage({
//     Key? key,
//     required this.themeMode,
//     required this.fontSize,
//     required this.onThemeModeChanged,
//     required this.onFontSizeChanged,
//   }) : super(key: key);

//   @override
//   _SettingsPageState createState() => _SettingsPageState();
// }

// class _SettingsPageState extends State<SettingsPage> {
//   List<Map<String, dynamic>> _models = [];
//   String? _selectedModel;
//   final List<String> _chatCompletionTypes = [
//     "generated_response",
//     "assistant_response",
//     "custom_response"
//   ];
//   String? _selectedType;
//   @override
//   void initState() {
//     super.initState();
//     _loadSelectedModel();
//     _loadChatCompletionType();
//     _fetchModels();
//   }

//   Future<void> _loadChatCompletionType() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _selectedType =
//           prefs.getString('chat_completion_type') ?? "generated_response";
//     });
//   }

//   // Save the selected chat completion type to SharedPreferences
//   Future<void> _saveChatCompletionType(String type) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('chat_completion_type', type);
//   }

//   Future<void> _loadSelectedModel() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _selectedModel = prefs.getString('selectedModel');
//     });
//   }

//   Future<void> _saveSelectedModel(String model) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('selectedModel', model);
//     setState(() {
//       _selectedModel = model;
//     });
//   }

//   Future<void> _fetchModels() async {
//     try {
//       final url = Uri.parse('http://127.0.0.1:11434/api/tags');
//       final response = await http.get(url);

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (data != null && data['models'] != null) {
//           setState(() {
//             _models = List<Map<String, dynamic>>.from(data['models']);

//             var models = data['models'];

//             // Extract model names
//             List<String> modelNames = [];
//             for (var model in models) {
//               modelNames.add(model['name']);
//             }
//           });
//         }
//       } else {
//         throw Exception('Failed to fetch models: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching models: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Settings')),
//       drawerEnableOpenDragGesture:
//           false, // Disable opening the menu with a swipe
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildSectionTitle('Font Size'),
//             _buildFontSizeSlider(),
//             const SizedBox(height: 16),
//             _buildSectionTitle('Theme Mode'),
//             _buildThemeModeButtons(),
//             const SizedBox(height: 16),
//             _buildSectionTitle('Select Model'),
//             _buildModelSelection(),
//             const SizedBox(height: 16),
//             _buildSectionTitle('Chat Completion Type'),
//             _buildChatCompletionTypeSelector(),
//             const SizedBox(height: 16),
//             _buildExportChatHistoryButton(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//     );
//   }

//   Widget _buildFontSizeSlider() {
//     return Slider(
//       value: widget.fontSize,
//       min: 12.0,
//       max: 24.0,
//       divisions: 12,
//       label: '${widget.fontSize.toStringAsFixed(1)} pt',
//       onChanged: (double newValue) {
//         widget.onFontSizeChanged(newValue); // Update font size dynamically
//       },
//     );
//   }

//   Widget _buildThemeModeButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceAround,
//       children: [
//         ElevatedButton(
//           onPressed: () => widget.onThemeModeChanged(ThemeMode.light),
//           child: const Text('Light'),
//           style: ElevatedButton.styleFrom(
//             backgroundColor:
//                 widget.themeMode == ThemeMode.light ? Colors.blue : Colors.grey,
//           ),
//         ),
//         ElevatedButton(
//           onPressed: () => widget.onThemeModeChanged(ThemeMode.dark),
//           child: const Text('Dark'),
//           style: ElevatedButton.styleFrom(
//             backgroundColor:
//                 widget.themeMode == ThemeMode.dark ? Colors.blue : Colors.grey,
//           ),
//         ),
//         ElevatedButton(
//           onPressed: () => widget.onThemeModeChanged(ThemeMode.system),
//           child: const Text('System'),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: widget.themeMode == ThemeMode.system
//                 ? Colors.blue
//                 : Colors.grey,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildModelSelection() {
//     return Expanded(
//       child: _models.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : ListView(
//               children: _models.map((model) {
//                 return RadioListTile<String>(
//                   title: Text(model['name']),
//                   subtitle: Text(
//                     'Modified: ${model['modified_at']}\n'
//                     'Size: ${(model['size'] / (1024 * 1024)).toStringAsFixed(2)} MB',
//                   ),
//                   value: model['name'],
//                   groupValue: _selectedModel,
//                   onChanged: (value) {
//                     if (value != null) {
//                       _saveSelectedModel(value);
//                     }
//                   },
//                 );
//               }).toList(),
//             ),
//     );
//   }

//   Widget _buildChatCompletionTypeSelector() {
//     final List<String> chatCompletionTypes = [
//       "generated_response",
//       "streamed_response"
//     ];
//     return FutureBuilder<String>(
//       future: SharedPreferences.getInstance().then(
//         (prefs) =>
//             prefs.getString('chat_completion_type') ?? "generated_response",
//       ),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const CircularProgressIndicator();
//         }
//         String selectedType = snapshot.data!;
//         return DropdownButton<String>(
//           value: selectedType,
//           items: chatCompletionTypes.map((type) {
//             return DropdownMenuItem<String>(
//               value: type,
//               child: Text(type),
//             );
//           }).toList(),
//           onChanged: (newValue) async {
//             if (newValue != null) {
//               final prefs = await SharedPreferences.getInstance();
//               await prefs.setString('chat_completion_type', newValue);
//               setState(() {});
//             }
//           },
//           isExpanded: true,
//         );
//       },
//     );
//   }

//   Widget _buildExportChatHistoryButton() {
//     return ElevatedButton.icon(
//       onPressed: () async {
//         final directory = await getApplicationDocumentsDirectory();
//         final file = File('${directory.path}/chat_history.json');
//         final prefs = await SharedPreferences.getInstance();
//         final history = prefs.getString('chatHistory') ?? '[]';

//         // Write chat history to file
//         await file.writeAsString(history);

//         // Convert to XFile and share
//         final xFile = XFile(file.path);
//         await Share.shareXFiles([xFile], text: 'Chat history exported');
//       },
//       icon: const Icon(Icons.download),
//       label: const Text('Export Chat History'),
//     );
//   }
// }
