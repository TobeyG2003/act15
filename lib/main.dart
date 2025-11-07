import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: LoginScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.user});

  final String title;
  final User user;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _searchController = TextEditingController();

  Future<List<String>> categories = FirestoreService().getCategories();
  final List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void refreshCategories() {
    setState(() {
      categories = FirestoreService().getCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Text('Welcome, ${widget.user.username} (${widget.user.status})'),
          ElevatedButton(onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          }, child: const Text('Logout')),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search',
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              ),
            ),
          ),
          FutureBuilder<List<String>>(
            future: categories,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final categoryList = snapshot.data!;
              if (categoryList.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: categoryList.map((category) {
                    return FilterChip(
                      label: Text(category),
                      selected: _selectedCategories.contains(category),
                      onSelected: (isSelected) {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: FirestoreService().getItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (snapshot.hasData) {
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(
                child: Text('No items found in Firestore'),
              );
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (_searchController.text.isNotEmpty &&
                    !item.name
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase())) {
                  return const SizedBox.shrink();
                }
                if (_selectedCategories.isNotEmpty &&
                    !_selectedCategories.contains(item.category)) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('Quantity: ${item.quantity}, Price: \$${item.price}, Category: ${item.category}, Created At: ${item.createdAt}'),
                  trailing: widget.user.status == 'admin' 
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AddEditItemScreen(item: item),
                            ),
                          );
                          refreshCategories();
                        },
                      )
                    : null,
                );
              },
            );
          }
          return const Center(
            child: Text('No data available'),
          );
        }
            ),
          ),
        ],  
      ),
      floatingActionButton: widget.user.status == 'admin'
        ? FloatingActionButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddEditItemScreen(),
                ),
              );
              refreshCategories();
            },
            tooltip: 'Add Item',
            child: const Icon(Icons.add),
          )
        : null,
    );
  }
}

class Item {
  String? id;
  String name;
  int quantity;
  double price;
  String category;
  DateTime createdAt;

  Item({
    this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'],
      price: map['price'],
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

}

class FirestoreService {
  final CollectionReference itemsCollection =
      FirebaseFirestore.instance.collection('items');

  Future<void> addItem(Item item) async {
    DocumentReference docRef = await itemsCollection.add(item.toMap());
    item.id = docRef.id;
    await docRef.update({'id': item.id});
  }

  Stream<List<Item>> getItemsStream() {
    return itemsCollection.snapshots().map((querySnap) {
      return querySnap.docs.map((doc) {
        try {
          return Item.fromMap(doc.data() as Map<String, dynamic>);
        } catch (e) {
          print('Error parsing document: $e');
          rethrow;
        }
      }).toList();
    });
  }

  Future<List<String>> getCategories() async {
    QuerySnapshot querySnap = await itemsCollection.get();
    Set<String> categories = {};
    for (var doc in querySnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('category')) {
        categories.add(data['category']);
      }
    }
    return categories.toList();
  }

  Future<void> updateItem(Item item) async {
    await itemsCollection.doc(item.id).update(item.toMap());
  }

  Future<void> deleteItem(String id) async {
    await itemsCollection.doc(id).delete();
  }

}

class AddEditItemScreen extends StatefulWidget {
  final Item? item;
  AddEditItemScreen({Key? key, this.item}) : super(key: key);
  @override
  _AddEditItemScreenState createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();

  bool isEditMode = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.item == null) {
      isEditMode = false;
    } else {
      isEditMode = true;
      nameController.text = widget.item!.name;
      quantityController.text = widget.item!.quantity.toString();
      priceController.text = widget.item!.price.toString();
      categoryController.text = widget.item!.category;
    }
  }
  
  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
    categoryController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Item' : 'Add Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (isEditMode) {
                    widget.item!.name = nameController.text;
                    widget.item!.quantity = int.parse(quantityController.text);
                    widget.item!.price = double.parse(priceController.text);
                    widget.item!.category = categoryController.text;
                    FirestoreService().updateItem(widget.item!);
                  } else {
                    final newItem = Item(
                      name: nameController.text,
                      quantity: int.parse(quantityController.text),
                      price: double.parse(priceController.text),
                      category: categoryController.text,
                      createdAt: DateTime.now(),
                    );
                    FirestoreService().addItem(newItem);
                  }
                  Navigator.pop(context);
                },
                child: Text(isEditMode ? 'Update' : 'Add'),
              ),
              if (isEditMode)
                ElevatedButton(
                  onPressed: () {
                    FirestoreService().deleteItem(widget.item!.id!);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                )
            ],
          ),
        ),
      ),
    );
  }
}

class User {
  String username;
  String password;
  String status;

  User({required this.username, required this.password, required this.status});
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';

  void login() async {
    String username = usernameController.text;
    String password = passwordController.text;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .where('password', isEqualTo: password)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      // Login successful
      setState(() {
        errorMessage = '';
      });
      User user = User(
        username: username,
        password: password,
        status: querySnapshot.docs.first['status'],
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage(title: 'Flutter Demo Home Page', user: user)),
      );
    } else {
      setState(() {
        errorMessage = 'Invalid username or password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ElevatedButton(
              onPressed: login,
              child: const Text('Login'),
            ),
            const SizedBox(height: 20),
            Text('sample accounts'),
            Text(
              'Admin: username: testadmin, password: admin123'
            ),
            Text(
              'User: username: user, password: pass'
            ),
          ],
        ),
      ),
    );
  }
}