// ignore_for_file: file_names

abstract class AuthStates {}

class LoginSucces extends AuthStates {}

class Loginfailure extends AuthStates {
  String errmessage;
  Loginfailure({required this.errmessage});
}

class Loginloading extends AuthStates {}

class Loginintial extends AuthStates {}

class RegisterSucces extends AuthStates {
  String successmessage;

  RegisterSucces({required this.successmessage});
}

class Registerfailure extends AuthStates {
  String errrmessage;
  Registerfailure({required this.errrmessage});
}

class Registerloading extends AuthStates {}

class Registerintial extends AuthStates {}

class LogoutSuccess extends AuthStates {}

class LogoutFailure extends AuthStates {
  String errmessage;
  LogoutFailure({required this.errmessage});
}
