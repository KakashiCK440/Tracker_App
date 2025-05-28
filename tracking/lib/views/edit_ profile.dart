import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  _EditProfileState createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _countryController = TextEditingController();
  File? _image;
  String? _imageUrl;

  final String uid = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', uid)
        .single();

    setState(() {
      _nameController.text = userData['name'] ?? '';
      _phoneController.text = userData['phone'] ?? '';
      _dobController.text = userData['dateofbirth'] ?? '';
      _countryController.text = userData['country'] ?? '';
      _imageUrl = userData['avatar_url'];
    });
  }

  Future<void> updateData() async {
    try {
      await Supabase.instance.client.from('users').update({
        "name": _nameController.text,
        "phone": _phoneController.text,
        "dateofbirth": _dobController.text,
        "country": _countryController.text,
        if (_imageUrl != null) "avatar_url": _imageUrl,
      }).eq('id', uid);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('sucess update')),
      );

      Navigator.pop(context, true); // ترجع true علشان الـ home يعرف يحدّث
    } catch (e) {
      print("error : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('there was a problem while updating   : $e')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileName = 'images/$uid.jpg';

      try {
        final bytes = await file.readAsBytes();

        await Supabase.instance.client.storage
            .from('profileimage')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        final publicUrl = Supabase.instance.client.storage
            .from('profileimage')
            .getPublicUrl(fileName);

        final timestampedUrl =
            '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

        // تحديث الصورة محليًا
        setState(() {
          _image = file;
          _imageUrl = timestampedUrl;
        });

        // تحديث الرابط الجديد في قاعدة البيانات مباشرة
        await Supabase.instance.client
            .from('users')
            .update({"avatar_url": timestampedUrl}).eq('id', uid);

        print('Image uploaded: $timestampedUrl');
      } catch (e) {
        print("Upload error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  void _viewImage() {
    if (_image != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(child: Image.file(_image!)),
      );
    } else if (_imageUrl != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(child: Image.network(_imageUrl!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _viewImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 100,
                      backgroundImage: _image != null
                          ? FileImage(_image!)
                          : (_imageUrl != null
                              ? NetworkImage(_imageUrl!)
                              : null) as ImageProvider?,
                      child: (_image == null && _imageUrl == null)
                          ? const Icon(Icons.person,
                              size: 100, color: Colors.white)
                          : null,
                    ),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera),
                                  title: const Text('Take Photo'),
                                  onTap: () {
                                    _pickImage(ImageSource.camera);
                                    Navigator.pop(context);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('Choose from Gallery'),
                                  onTap: () {
                                    _pickImage(ImageSource.gallery);
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 30,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your mobile number'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your date of birth'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Country/Region',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your country/region'
                    : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      updateData();
                    }
                  },
                  child: const Text(
                    'Save changes',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
