import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracking/views/history_view.dart';
import 'package:tracking/widgets/videoimagecont.dart';
import 'package:tracking/views/cameraview.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List data = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getData();
  }

  Future<void> getData() async {
    setState(() {
      isLoading = true;
    });

    try {
      String uid = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('users')
          .select('name, avatar_url')
          .eq('id', uid)
          .single();

      setState(() {
        data = [response];
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching data: $error");
    }
  }

  void _onMenuItemSelected(String value) async {
    switch (value) {
      case 'edit_profile':
        final result = await Navigator.pushNamed(context, 'editprofile');
        if (result == true) {
          await getData();
        }
        break;
      case 'setting':
        Navigator.pushNamed(context, 'setting');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = data.isNotEmpty ? data[0]['avatar_url'] : null;
    final name = data.isNotEmpty ? data[0]['name'] : "No name found";

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            radius: 30,
                            child: avatarUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Welcome,",
                                  style: TextStyle(fontSize: 16)),
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.menu),
                            onSelected: _onMenuItemSelected,
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'Home',
                                child: Text('Home'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'edit_profile',
                                child: Text('Edit Profile'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'setting',
                                child: Text('Setting'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: Videoimagecont(),
                    ),
                  ],
                ),
                const HistoryView(),
              ],
            ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: PhysicalModel(
          color: Colors.white,
          elevation: 12,
          borderRadius: BorderRadius.circular(30),
          shadowColor: Colors.black.withOpacity(0.3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: Colors.white,
              onTap: (index) {
                if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CameraView()),
                  );
                } else {
                  setState(() {
                    _currentIndex = index == 2 ? 1 : index;
                  });
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.camera_alt), label: 'Camera'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.history), label: 'History'),
              ],
              selectedItemColor: const Color(0xffeb5757),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              showUnselectedLabels: true,
            ),
          ),
        ),
      ),
    );
  }
}
