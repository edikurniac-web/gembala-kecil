import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

Widget runtimeContentImage(String path, BoxFit fit, Widget Function() error) {
  if (path.startsWith('http')) {
    return Image.network(path, fit: fit, errorBuilder: (_, __, ___) => error());
  }
  if (path.startsWith('assets/')) {
    return Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => error());
  }
  return Image.file(File(path),
      fit: fit, errorBuilder: (_, __, ___) => error());
}

Source runtimeAudioSource(String path) {
  if (path.startsWith('http')) return UrlSource(path);
  if (path.startsWith('assets/')) {
    return AssetSource(path.replaceFirst('assets/', ''));
  }
  return DeviceFileSource(path);
}

Future<String> runtimeLoadText(String path) async {
  if (path.startsWith('http')) return (await http.get(Uri.parse(path))).body;
  if (path.startsWith('assets/')) return rootBundle.loadString(path);
  return File(path).readAsString();
}
