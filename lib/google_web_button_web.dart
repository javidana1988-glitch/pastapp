import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class _GoogleWebButton extends StatefulWidget {
  final VoidCallback? onSignedIn;

  const _GoogleWebButton({this.onSignedIn});

  @override
  State<_GoogleWebButton> createState() => _GoogleWebButtonState();
}

class _GoogleWebButtonState extends State<_GoogleWebButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        widget.onSignedIn?.call();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return web.renderButton();
  }
}

Widget botonGoogleWeb({VoidCallback? onSignedIn}) {
  return _GoogleWebButton(onSignedIn: onSignedIn);
}
