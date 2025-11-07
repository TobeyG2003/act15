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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _searchController = TextEditingController();

  final CollectionReference itemsCollection =
      FirebaseFirestore.instance.collection('items');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
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
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('Quantity: ${item.quantity}, Price: \$${item.price}, Category: ${item.category}, Created At: ${item.createdAt}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddEditItemScreen(item: item),
                        ),
                      );
                    },
                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddEditItemScreen(),
            ),
          );
        },
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
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
      // Set controller values for edit mode
      nameController.text = widget.item!.name;
      quantityController.text = widget.item!.quantity.toString();
      priceController.text = widget.item!.price.toString();
      categoryController.text = widget.item!.category;
    }
  }
  
  @override
  void dispose() {
    // Clean up controllers
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
