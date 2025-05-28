import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracking/Widgets/customButton.dart';
import 'package:tracking/helper.dart';
import 'package:tracking/views/cubits/Auth_cubit.dart';
import 'package:tracking/views/cubits/Auth_state.dart';
import 'package:tracking/widgets/customTextField.dart';

// ignore: must_be_immutable
class RegisterView extends StatelessWidget {
  RegisterView({super.key});

  final GlobalKey<FormState> formKey = GlobalKey();
  String? email;
  String? password;
  String? confirmPassword;
  String? name;
  String? phone;
  bool isLoading = false;
  final isPasswordVisible = ValueNotifier<bool>(false);
  final isConfirmPasswordVisible = ValueNotifier<bool>(false);

  // قم بتعديل الدالة insert لتكون في حالة نجاح التسجيل
  insert() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        print('No user logged in');
        return;
      }

      final uid = user.id;

      final response = await Supabase.instance.client.from('users').insert({
        "id": uid,
        'name': name,
        'email': email,
        'phone': phone,
      });

      if (response.error == null) {
        print('User added successfully!');
      } else {
        print('Error: ${response.error!.message}');
      }
    } catch (e) {
      print('error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthStates>(
      listener: (context, state) async {
        if (state is Registerloading) {
          isLoading = true;
        } else if (state is RegisterSucces) {
          // تنفيذ insert بعد ما يتم تسجيل الحساب بنجاح
          await insert();
          Navigator.pop(context);
          showSnackBar(context, state.successmessage);
          isLoading = false;
        } else if (state is Registerfailure) {
          showSnackBar(context, state.errrmessage);
          isLoading = false;
        }
      },
      builder: (context, state) => ModalProgressHUD(
        inAsyncCall: isLoading,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  const Text(
                    'WELCOME',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    hint: 'Enter your Name',
                    icon: const Icon(Icons.person),
                    onChanged: (data) => name = data,
                  ),
                  CustomTextField(
                    hint: 'Enter your phone',
                    icon: const Icon(Icons.phone),
                    onChanged: (data) => phone = data,
                  ),
                  CustomTextField(
                    hint: 'Enter your Email',
                    icon: const Icon(Icons.email),
                    onChanged: (data) => email = data,
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: isPasswordVisible,
                    builder: (context, isVisible, child) {
                      return CustomTextField(
                        hint: 'Enter Password',
                        icon: const Icon(Icons.lock),
                        obscureText: !isVisible,
                        toggleObscureText: () =>
                            isPasswordVisible.value = !isPasswordVisible.value,
                        onChanged: (data) => password = data,
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: isConfirmPasswordVisible,
                    builder: (context, isVisible, child) {
                      return CustomTextField(
                        hint: 'Confirm Password',
                        icon: const Icon(Icons.lock),
                        obscureText: !isVisible,
                        toggleObscureText: () => isConfirmPasswordVisible
                            .value = !isConfirmPasswordVisible.value,
                        onChanged: (data) => confirmPassword = data,
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  CustomButton(
                    textcolor: Colors.white,
                    color: Colors.black,
                    onTap: () async {
                      if (formKey.currentState!.validate()) {
                        BlocProvider.of<AuthCubit>(context).registerUser(
                          email: email!,
                          password: password!,
                        );
                      }
                    },
                    text: 'Sign up',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
