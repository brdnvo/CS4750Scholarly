import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If Firebase is already initialized, get the existing instance
    if (e.toString().contains('already exists')) {
      Firebase.app(); // Get existing instance
    } else {
      // Rethrow if it's a different error
      rethrow;
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const FlashcardApp(),
    ),
  );
}

class FlashcardApp extends StatelessWidget {
  const FlashcardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Scholarly',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data != null) {
            // User is logged in, show dashboard
            return const DashboardScreen();
          }

          // User is not logged in, show login screen
          return const LoginScreen();
        },
      ),
    );
  }
}

// ************* Login *************
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true; // Toggle between login and register
  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isLogin) {
          // Login
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
        } else {
          // Register
          UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

          // Create user document in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'email': _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An error occurred')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(_isLogin ? 'Login' : 'Register'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(_isLogin
                    ? 'Create an account'
                    : 'Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ************* Dashboard/Home Landing *************
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _setTitleController = TextEditingController();

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _addFlashcardSet() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Flashcard Set'),
          content: TextField(
            controller: _setTitleController,
            decoration: const InputDecoration(
              labelText: 'Set Title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_setTitleController.text.trim().isNotEmpty) {
                  String userId = FirebaseAuth.instance.currentUser!.uid;
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('flashcardSets')
                        .doc(_setTitleController.text.trim())
                        .set({
                      'title': _setTitleController.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    _setTitleController.clear();
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFlashcardSet(String setId) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    // First, get all cards in this set
    QuerySnapshot cardsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('flashcardSets')
        .doc(setId)
        .collection('cards')
        .get();

    // Create a batch to delete all documents at once
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // Add delete operations for all cards
    for (DocumentSnapshot cardDoc in cardsSnapshot.docs) {
      batch.delete(cardDoc.reference);
    }

    // Add delete operation for the set itself
    batch.delete(FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('flashcardSets')
        .doc(setId));

    // Commit the batch
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    String userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Scholarly!'),
        actions: [
          // Theme toggle button
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('flashcardSets')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No flashcard sets yet. Create one using the + button.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot doc = snapshot.data!.docs[index];
              String setId = doc.id;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  title: Text(
                    setId,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      // Show confirmation dialog
                      bool confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Set'),
                          content: Text('Are you sure you want to delete "$setId"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ?? false;

                      if (confirm) {
                        await _deleteFlashcardSet(setId);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FlashcardSetScreen(setId: setId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFlashcardSet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ************* Flashcards *************
class FlashcardSetScreen extends StatefulWidget {
  final String setId;

  const FlashcardSetScreen({super.key, required this.setId});

  @override
  FlashcardSetScreenState createState() => FlashcardSetScreenState();
}

class FlashcardSetScreenState extends State<FlashcardSetScreen> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();

  Future<void> _addFlashcard() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Flashcard'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _answerController,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_questionController.text.trim().isNotEmpty &&
                    _answerController.text.trim().isNotEmpty) {
                  String userId = FirebaseAuth.instance.currentUser!.uid;

                  // Generate a unique ID for the card
                  DocumentReference cardRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('flashcardSets')
                      .doc(widget.setId)
                      .collection('cards')
                      .doc();

                  await cardRef.set({
                    'question': _questionController.text.trim(),
                    'answer': _answerController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  _questionController.clear();
                  _answerController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editFlashcard(String cardId, String question, String answer) async {
    _questionController.text = question;
    _answerController.text = answer;

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Flashcard'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _answerController,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_questionController.text.trim().isNotEmpty &&
                    _answerController.text.trim().isNotEmpty) {
                  String userId = FirebaseAuth.instance.currentUser!.uid;

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('flashcardSets')
                      .doc(widget.setId)
                      .collection('cards')
                      .doc(cardId)
                      .update({
                    'question': _questionController.text.trim(),
                    'answer': _answerController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  _questionController.clear();
                  _answerController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFlashcard(String cardId) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('flashcardSets')
        .doc(widget.setId)
        .collection('cards')
        .doc(cardId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setId),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('flashcardSets')
            .doc(widget.setId)
            .collection('cards')
            .orderBy('createdAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No flashcards yet. Add some using the + button.'),
            );
          }

          List<DocumentSnapshot> cards = snapshot.data!.docs;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot card = cards[index];
                    String cardId = card.id;
                    Map<String, dynamic> data = card.data() as Map<String, dynamic>;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: ExpansionTile(
                        title: Text(
                          data['question'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Text(
                                  'Answer: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Expanded(
                                  child: Text(data['answer']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editFlashcard(
                                    cardId,
                                    data['question'],
                                    data['answer'],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteFlashcard(cardId),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: cards.isNotEmpty
                      ? () {
                    // Get all flashcards to pass to the quiz screen
                    List<Map<String, dynamic>> flashcards = cards
                        .map((card) => {
                      'id': card.id,
                      'question': (card.data() as Map<String, dynamic>)['question'],
                      'answer': (card.data() as Map<String, dynamic>)['answer'],
                    })
                        .toList();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizScreen(
                          setId: widget.setId,
                          flashcards: flashcards,
                        ),
                      ),
                    );
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Start Quiz'),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFlashcard,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }
}

// ************* Quiz *************
class QuizScreen extends StatefulWidget {
  final String setId;
  final List<Map<String, dynamic>> flashcards;

  const QuizScreen({
    super.key,
    required this.setId,
    required this.flashcards,
  });

  @override
  QuizScreenState createState() => QuizScreenState();
}

class QuizScreenState extends State<QuizScreen> {
  final Map<String, TextEditingController> _answerControllers = {};
  final Map<String, bool> _results = {};
  bool _quizSubmitted = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each flashcard
    for (var flashcard in widget.flashcards) {
      _answerControllers[flashcard['id']] = TextEditingController();
    }
  }

  void _checkAnswers() {
    setState(() {
      _results.clear();

      for (var flashcard in widget.flashcards) {
        String cardId = flashcard['id'];
        String userAnswer = _answerControllers[cardId]!.text.trim();
        String correctAnswer = flashcard['answer'];

        // Compare answers (case insensitive)
        _results[cardId] = userAnswer.toLowerCase() == correctAnswer.toLowerCase();
      }

      _quizSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz: ${widget.setId}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.flashcards.length,
                itemBuilder: (context, index) {
                  var flashcard = widget.flashcards[index];
                  String cardId = flashcard['id'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question ${index + 1}: ${flashcard['question']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _answerControllers[cardId],
                            decoration: const InputDecoration(
                              labelText: 'Your Answer',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !_quizSubmitted,
                          ),
                          if (_quizSubmitted) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  _results[cardId]! ? Icons.check_circle : Icons.cancel,
                                  color: _results[cardId]! ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _results[cardId]! ? 'Correct!' : 'Incorrect',
                                  style: TextStyle(
                                    color: _results[cardId]! ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (!_results[cardId]!) ...[
                              const SizedBox(height: 5),
                              Text(
                                'Correct answer: ${flashcard['answer']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _quizSubmitted
                  ? () {
                Navigator.pop(context);
              }
                  : _checkAnswers,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(_quizSubmitted ? 'Back to Flashcards' : 'Submit Answers'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}