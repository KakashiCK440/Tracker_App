import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracking/views/cubits/Auth_state.dart';

class AuthCubit extends Cubit<AuthStates> {
  AuthCubit() : super(Loginintial());

  final supabase = Supabase.instance.client;

  Future<void> loginUser(
      {required String email, required String password}) async {
    emit(Loginloading());
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session != null) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('isLoggedIn', true);
        emit(LoginSucces());
      } else {
        emit(Loginfailure(
            errmessage: 'Authentication failed. Please try again.'));
      }
    } on AuthException catch (ex) {
      if (ex.message.contains('Invalid login credentials')) {
        emit(Loginfailure(errmessage: 'Invalid email or password.'));
      } else {
        emit(Loginfailure(errmessage: ex.message));
      }
    } catch (e) {
      emit(Loginfailure(
          errmessage: 'Something went wrong. Please try again later.'));
    }
  }

  Future<void> registerUser(
      {required String email, required String password}) async {
    emit(Registerloading());
    try {
      final response =
          await supabase.auth.signUp(email: email, password: password);
      if (response.user != null) {
        emit(RegisterSucces(successmessage: 'Successful registration.'));
      } else {
        emit(Registerfailure(
            errrmessage: 'Registration failed. Please try again.'));
      }
    } on AuthException catch (ex) {
      if (ex.message.contains('User already registered')) {
        emit(Registerfailure(
            errrmessage: 'The account already exists for that email.'));
      } else {
        emit(Registerfailure(errrmessage: ex.message));
      }
    } catch (e) {
      emit(Registerfailure(
          errrmessage: 'Something went wrong. Please try again later.'));
    }
  }

  Future<void> logoutUser() async {
    try {
      await supabase.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      emit(LogoutSuccess());
    } catch (e) {
      emit(LogoutFailure(errmessage: 'Failed to logout. Please try again.'));
    }
  }
}
