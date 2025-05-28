// import 'package:flutter/material.dart';

// class CustomTextField extends StatelessWidget {
//   const CustomTextField({
//     super.key,
//     required this.hint,
//     required this.icon,
//     this.labelText,
//     this.onChanged,
//     this.validator,
//   });

//   final Function(String)? onChanged;
//   final String hint;
//   final Icon icon;
//   final String? labelText;
//   final String? Function(String?)? validator;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: TextFormField(
//         validator: validator,
//         onChanged: onChanged,
//         decoration: InputDecoration(
//           prefixIcon: icon,
//           hintText: hint,
//           labelText: labelText,
//           enabledBorder: const OutlineInputBorder(
//             borderRadius: BorderRadius.all(Radius.circular(12)),
//             borderSide: BorderSide(color: Colors.black),
//           ),
//           focusedBorder: const OutlineInputBorder(
//             borderRadius: BorderRadius.all(Radius.circular(12)),
//             borderSide: BorderSide(color: Colors.grey),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.labelText,
    this.onChanged,
    this.validator,
    this.obscureText = false, // Add this line
    this.toggleObscureText, // Add this line
  });

  final Function(String)? onChanged;
  final String hint;
  final Icon icon;
  final String? labelText;
  final String? Function(String?)? validator;
  final bool obscureText; // Add this line
  final VoidCallback? toggleObscureText; // Add this line

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        validator: validator,
        onChanged: onChanged,
        obscureText: obscureText, // Add this line
        decoration: InputDecoration(
          prefixIcon: icon,
          hintText: hint,
          labelText: labelText,
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.black),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey),
          ),
          suffixIcon: toggleObscureText != null // Add this block
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: toggleObscureText,
                )
              : null,
        ),
      ),
    );
  }
}