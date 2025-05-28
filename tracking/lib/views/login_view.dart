import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:tracking/Widgets/customButton.dart';
import 'package:tracking/helper.dart';
import 'package:tracking/views/cubits/Auth_cubit.dart';
import 'package:tracking/views/cubits/Auth_state.dart';
import 'package:tracking/widgets/customTextField.dart';

// ignore: must_be_immutable
class LoginView extends StatelessWidget {
  String? email;
  String? password;
  LoginView({super.key});
  GlobalKey<FormState> formkey = GlobalKey();
  bool isLoading = false;

  final isPasswordVisible = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthStates>(
      listener: (context, state) {
        if (state is Loginloading) {
          isLoading = true;
        } else if (state is LoginSucces) {
              Navigator.pushNamedAndRemoveUntil(context, 'homePage', (route) => false);
          isLoading = false;
        } else if (state is Loginfailure) {
          showSnackBar(context, state.errmessage);
          isLoading = false;
        }
      },
      builder: (context, state) => ModalProgressHUD(
        inAsyncCall: isLoading,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 50),
                Image.asset(
                  width: 150,
                  height: 150,
                  'assets/detection-removebg-preview.png',
                ),
                const SizedBox(height: 20),
                Form(
                  key: formkey,
                  child: Column(
                    children: [
                      CustomTextField(
                        labelText: 'Email',
                        onChanged: (data) {
                          email = data;
                        },
                        hint: 'Enter your Email',
                        icon: const Icon(Icons.email),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          } else if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      // Password Field with ValueListenableBuilder
                      ValueListenableBuilder<bool>(
                        valueListenable: isPasswordVisible,
                        builder: (context, isVisible, child) {
                          return CustomTextField(
                            labelText: 'Password',
                            onChanged: (data) {
                              password = data;
                            },
                            hint: 'Enter Password',
                            icon: const Icon(Icons.lock),
                            obscureText: !isVisible, // Toggle visibility
                            toggleObscureText: () {
                              // Update visibility state
                              isPasswordVisible.value =
                                  !isPasswordVisible.value;
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              } else if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      GestureDetector(
                        onTap: () async {
                          if (formkey.currentState!.validate()) {
                            // Show loading indicator
                            isLoading = true;
                            BlocProvider.of<AuthCubit>(context).loginUser(
                              email: email!,
                              password: password!,
                            );
                          }
                        },
                        child: CustomButton(
                          textcolor: Colors.white,
                          color: Colors.black,
                          text: 'Log In',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Row(
                          children: [
                            // Left Divider
                           const Flexible(
                              child: Divider(
                                color: Colors.grey, // Divider color
                                thickness: 1, // Divider thickness
                              ),
                            ),
                            // Text
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Text(
                                'or login with',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 9,
                                ),
                              ),
                            ),
                            // Right Divider
                           const Flexible(
                              child: Divider(
                                color: Colors.grey, // Divider color
                                thickness: 1, // Divider thickness
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                      
                        children: [
                             GestureDetector(onTap: (){},
                         
                               // ignore: avoid_unnecessary_containers
                               child: Container(
                                                           child: Image.asset(width: 70,height: 80,
                                'assets/download.png'),
                                                         ),
                             ),
                          
                          // ignore: avoid_unnecessary_containers
                          Container(
                            child: Image.asset(width: 60,height: 70,
                              'assets/download__2_-removebg-preview.png'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}
