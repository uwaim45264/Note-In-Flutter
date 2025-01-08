import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<Map<String, dynamic>> notes = [];
  Set<int> selectedIndexes = {};
  bool isSelectionMode = false;
  String searchQuery = '';
  bool showHiddenNotes = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesData = prefs.getString('notes');
    if (notesData != null) {
      setState(() {
        notes = List<Map<String, dynamic>>.from(jsonDecode(notesData));
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes', jsonEncode(notes));
  }

  void _addNote() {
    String title = '';
    String content = '';
    int priority = 2;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (value) => title = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 3,
                onChanged: (value) => content = value,
              ),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Priority'),
                value: priority,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('High')),
                  DropdownMenuItem(value: 2, child: Text('Medium')),
                  DropdownMenuItem(value: 3, child: Text('Low')),
                ],
                onChanged: (value) => priority = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (title.isNotEmpty && content.isNotEmpty) {
                final newNote = {
                  'title': title,
                  'content': content,
                  'date': DateTime.now().toString(),
                  'tag': 'General',
                  'priority': priority,
                  'favorite': false,
                  'pinned': false,
                  'hidden': false,
                };

                setState(() {
                  notes.insert(0, newNote);
                  _listKey.currentState!.insertItem(0);
                });

                _saveNotes();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissal by tapping outside
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Larger rounding for a modern look
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and Title Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                    size: 50,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Are you sure?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This action will permanently delete the selected note(s). You cannot undo this action.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              // Action Buttons Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  // Delete Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      _deleteSelectedNotes();
    }
  }

  void _deleteSelectedNotes() {
    final deletedNotes = selectedIndexes.map((i) => notes[i]).toList();

    setState(() {
      for (final index in selectedIndexes.toList().reversed) {
        notes.removeAt(index);
        _listKey.currentState!.removeItem(
          index,
              (context, animation) =>
              _buildNoteTile(deletedNotes[selectedIndexes.toList().indexOf(index)], animation, index: index),
        );
      }
      selectedIndexes.clear();
      isSelectionMode = false;
    });

    _saveNotes();
  }

  void _togglePinSelectedNotes() {
    setState(() {
      for (final index in selectedIndexes) {
        notes[index]['pinned'] = !notes[index]['pinned'];
      }
      selectedIndexes.clear();
      isSelectionMode = false;

      notes.sort((a, b) {
        if (a['pinned'] == b['pinned']) return 0;
        return a['pinned'] ? -1 : 1;
      });
    });
    _saveNotes();
  }

  void _toggleHideSelectedNotes() {
    setState(() {
      for (final index in selectedIndexes) {
        notes[index]['hidden'] = !notes[index]['hidden'];
      }
      selectedIndexes.clear();
      isSelectionMode = false;
    });
    _saveNotes();
  }

  Widget _buildNoteTile(Map<String, dynamic> note, Animation<double> animation,
      {required int index}) {
    if (note['hidden'] == true && !showHiddenNotes) {
      return const SizedBox.shrink();
    }

    final priorityColors = [Colors.redAccent, Colors.amber, Colors.green];
    final priorityLabels = ['High', 'Medium', 'Low'];

    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 5,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: isSelectionMode
              ? Checkbox(
            value: selectedIndexes.contains(index),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  selectedIndexes.add(index);
                } else {
                  selectedIndexes.remove(index);
                }
              });
            },
          )
              : Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: priorityColors[note['priority'] - 1],
                child: Text(
                  priorityLabels[note['priority'] - 1][0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (note['pinned'])
                const Positioned(
                  top: -10,
                  right: -10,
                  child: Icon(
                    Icons.push_pin,
                    size: 20,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
          title: Text(
            note['title'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: note['favorite'] ? Colors.red : Colors.black87,
            ),
          ),
          subtitle: Text(
            note['content'],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.5),
          ),
          trailing: isSelectionMode
              ? null
              : IconButton(
            icon: Icon(
              note['favorite'] ? Icons.favorite : Icons.favorite_border,
              color: note['favorite'] ? Colors.red : Colors.grey,
            ),
            onPressed: () => setState(() {
              note['favorite'] = !note['favorite'];
              _saveNotes();
            }),
          ),
          onTap: isSelectionMode
              ? () {
            setState(() {
              if (selectedIndexes.contains(index)) {
                selectedIndexes.remove(index);
              } else {
                selectedIndexes.add(index);
              }
            });
          }
              : null,
          onLongPress: () {
            setState(() {
              isSelectionMode = true;
              selectedIndexes.add(index);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text(isSelectionMode
            ? '${selectedIndexes.length} Selected'
            : 'Notes'),
        actions: isSelectionMode
            ? [
          IconButton(
            icon: const Icon(Icons.push_pin),
            onPressed: _togglePinSelectedNotes,
          ),
          IconButton(
            icon: const Icon(Icons.hide_source),
            onPressed: _toggleHideSelectedNotes,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _showDeleteConfirmation,
          ),
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              setState(() {
                isSelectionMode = false;
                selectedIndexes.clear();
              });
            },
          ),
        ]
            : [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNote,
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search...',
                      prefixIcon: Icon(Icons.search,color: Colors.blueAccent),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(showHiddenNotes ? Icons.visibility : Icons.visibility_off, color: Colors.blueAccent,),
                  onPressed: () {
                    setState(() {
                      showHiddenNotes = !showHiddenNotes;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: notes.length,
              itemBuilder: (context, index, animation) {
                final note = notes[index];

                if (searchQuery.isNotEmpty &&
                    !note['title'].toLowerCase().contains(searchQuery) &&
                    !note['content'].toLowerCase().contains(searchQuery)) {
                  return const SizedBox.shrink();
                }

                return _buildNoteTile(note, animation, index: index);
              },
            ),
          ),
        ],
      ),
    );
  }
}
