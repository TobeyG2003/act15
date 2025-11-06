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

  final CollectionReference itemsCollection =
      FirebaseFirestore.instance.collection('items');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: StreamBuilder<List<Item>>(
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
                );
              },
            );
          }
          
          return const Center(
            child: Text('No data available'),
          );
        }
      )
    );
  }
}

class Item {
  String? id;
  final String name;
  final int quantity;
  final double price;
  final String category;
  final DateTime createdAt;

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