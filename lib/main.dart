import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // File hasil generate

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi koneksi ke Firebase
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
      debugShowCheckedModeBanner: false,
      title: 'Live Notes',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

// ==========================================================
// PENTING: Class HomePage yang baru (StatefulWidget)
// ==========================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Referensi Koleksi Firestore
  // Pastikan nama koleksi ('notes') sama dengan yang ada di Firebase
  final CollectionReference _notes =
      FirebaseFirestore.instance.collection('notes');

  // Controller untuk input form (Judul dan Konten)
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // Metode untuk menampilkan Form (Modal Bottom Sheet) untuk Tambah/Edit
  Future<void> _showForm(BuildContext context, [DocumentSnapshot? documentSnapshot]) async {
    // Isi controller jika sedang mengedit dokumen yang sudah ada
    if (documentSnapshot != null) {
      _titleController.text = documentSnapshot['title'];
      _contentController.text = documentSnapshot['content'];
    } else {
      _titleController.text = '';
      _contentController.text = '';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Judul Catatan'),
              ),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Isi Catatan'),
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: Text(documentSnapshot == null ? 'Tambah Baru' : 'Perbarui'),
                onPressed: () async {
                  final String title = _titleController.text;
                  final String content = _contentController.text;

                  // Tambahkan pengecekan if (content.isNotEmpty) seperti di kode Anda
                  if (title.isNotEmpty && content.isNotEmpty) {
                    // Cek apakah mode Tambah atau Edit
                    if (documentSnapshot == null) {
                      // Tambah Catatan Baru
                      await _notes.add({
                        "title": title,
                        "content": content,
                        // MENGGUNAKAN FieldValue.serverTimestamp() seperti saran Anda
                        "timestamp": FieldValue.serverTimestamp(), 
                      });
                    } else {
                      // Perbarui Catatan yang Sudah Ada
                      await _notes.doc(documentSnapshot.id).update({
                        "title": title,
                        "content": content,
                        "timestamp": Timestamp.now(), // Tetap pakai Timestamp.now() untuk update time lokal
                      });
                    }

                    // Bersihkan form dan tutup modal
                    _titleController.text = '';
                    _contentController.text = '';
                    Navigator.of(context).pop();
                  }
                },
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Notes Fire")),

      // STREAMBUILDER : Bagian terpenting untuk Real-time
      body: StreamBuilder(
        // Query untuk mengambil data, diurutkan berdasarkan timestamp terbaru
        // Catatan: Jika Anda menggunakan FieldValue.serverTimestamp(), Anda
        // mungkin perlu mengatur Firestore Security Rules.
        stream: _notes.orderBy('timestamp', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // Kondisi 1: Masih Loading (Menunggu data dari Firebase)
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Kondisi 2: Data Kosong
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Belum ada catatan. Klik '+' untuk menambah."));
          }

          // Kondisi 3: Ada Data -> Tampilkan ListView
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final DocumentSnapshot document = snapshot.data!.docs[index];

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(
                    document['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(document['content']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol Edit (Memanggil _showForm dengan data dokumen)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showForm(context, document),
                      ),
                      // Tombol Hapus
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          // Fungsi Hapus
                          _notes.doc(document.id).delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Catatan berhasil dihapus!'))
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Ketika tombol ditekan, panggil form untuk tambah catatan baru (parameter null)
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}