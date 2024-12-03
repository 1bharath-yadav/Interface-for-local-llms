import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final double fontSize;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<double> onFontSizeChanged;

  const SettingsPage({
    Key? key,
    required this.themeMode,
    required this.fontSize,
    required this.onThemeModeChanged,
    required this.onFontSizeChanged,
  }) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Map<String, dynamic>> _models = [];
  List<Map<String, String>> _chats = []; // Holds the list of chats
  List<Map<String, String>> _filteredChats = []; // For filtered search results

  String? _selectedModel;
  final List<String> _chatCompletionTypes = [
    "generated_response",
    "assistant_response",
    "custom_response"
  ];
  String? _selectedType;
  @override
  void initState() {
    super.initState();
    _loadSelectedModel();
    _loadChatCompletionType();
    _fetchModels();
    _loadSavedChats(); // Load saved chats on app start
  }

  Future<void> _loadSavedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final savedChats = prefs.getString('savedChats');
    if (savedChats != null) {
      setState(() {
        _chats = List<Map<String, String>>.from(jsonDecode(savedChats));
        _filteredChats = _chats; // Initialize filtered list
      });
    }
  }

  Future<void> _loadChatCompletionType() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedType =
          prefs.getString('chat_completion_type') ?? "generated_response";
    });
  }

  // Save the selected chat completion type to SharedPreferences
  Future<void> _saveChatCompletionType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_completion_type', type);
  }

  Future<void> _loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedModel = prefs.getString('selectedModel');
    });
  }

  Future<void> _saveSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedModel', model);
    setState(() {
      _selectedModel = model;
    });
  }

  Future<void> _fetchModels() async {
    try {
      final url = Uri.parse('http://127.0.0.1:11434/api/tags');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['models'] != null) {
          setState(() {
            _models = List<Map<String, dynamic>>.from(data['models']);

            var models = data['models'];

            // Extract model names
            List<String> modelNames = [];
            for (var model in models) {
              modelNames.add(model['name']);
            }
          });
        }
      } else {
        throw Exception('Failed to fetch models: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching models: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawerEnableOpenDragGesture:
          false, // Disable opening the menu with a swipe
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Font Size'),
            _buildFontSizeSlider(),
            const SizedBox(height: 16),
            _buildSectionTitle('Theme Mode'),
            _buildThemeModeButtons(),
            const SizedBox(height: 16),
            _buildSectionTitle('Select Model'),
            _buildModelSelection(),
            const SizedBox(height: 16),
            _buildSectionTitle('Chat Completion Type'),
            _buildChatCompletionTypeSelector(),
            const SizedBox(height: 16),
            _buildExportChatHistoryButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFontSizeSlider() {
    return Slider(
      value: widget.fontSize,
      min: 12.0,
      max: 24.0,
      divisions: 12,
      label: '${widget.fontSize.toStringAsFixed(1)} pt',
      onChanged: (double newValue) {
        widget.onFontSizeChanged(newValue); // Update font size dynamically
      },
    );
  }

  Widget _buildThemeModeButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ElevatedButton(
          onPressed: () => widget.onThemeModeChanged(ThemeMode.light),
          child: const Text('Light'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                widget.themeMode == ThemeMode.light ? Colors.blue : Colors.grey,
          ),
        ),
        ElevatedButton(
          onPressed: () => widget.onThemeModeChanged(ThemeMode.dark),
          child: const Text('Dark'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                widget.themeMode == ThemeMode.dark ? Colors.blue : Colors.grey,
          ),
        ),
        ElevatedButton(
          onPressed: () => widget.onThemeModeChanged(ThemeMode.system),
          child: const Text('System'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.themeMode == ThemeMode.system
                ? Colors.blue
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildModelSelection() {
    return Expanded(
      child: _models.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: _models.map((model) {
                return RadioListTile<String>(
                  title: Text(model['name']),
                  subtitle: Text(
                    'Modified: ${model['modified_at']}\n'
                    'Size: ${(model['size'] / (1024 * 1024)).toStringAsFixed(2)} MB',
                  ),
                  value: model['name'],
                  groupValue: _selectedModel,
                  onChanged: (value) {
                    if (value != null) {
                      _saveSelectedModel(value);
                    }
                  },
                );
              }).toList(),
            ),
    );
  }

  Widget _buildChatCompletionTypeSelector() {
    final List<String> chatCompletionTypes = [
      "generated_response",
      "streamed_response"
    ];
    return FutureBuilder<String>(
      future: SharedPreferences.getInstance().then(
        (prefs) =>
            prefs.getString('chat_completion_type') ?? "generated_response",
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        String selectedType = snapshot.data!;
        return DropdownButton<String>(
          value: selectedType,
          items: chatCompletionTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (newValue) async {
            if (newValue != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('chat_completion_type', newValue);
              setState(() {});
            }
          },
          isExpanded: true,
        );
      },
    );
  }

  Widget _buildExportChatHistoryButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/chat_history.json');
        final prefs = await SharedPreferences.getInstance();
        final history = prefs.getString('chatHistory') ?? '[]';

        // Write chat history to file
        await file.writeAsString(history);

        // Convert to XFile and share
        final xFile = XFile(file.path);
        await Share.shareXFiles([xFile], text: 'Chat history exported');
      },
      icon: const Icon(Icons.download),
      label: const Text('Export Chat History'),
    );
  }
}
