import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

Widget runtimeContentImage(String path, BoxFit fit, Widget Function() error) =>
    path.startsWith('http')
        ? Image.network(path, fit: fit, errorBuilder: (_, __, ___) => error())
        : Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => error());

Source runtimeAudioSource(String path) => path.startsWith('http')
    ? UrlSource(path)
    : AssetSource(path.replaceFirst('assets/', ''));

Future<String> runtimeLoadText(String path) async => path.startsWith('http')
    ? (await http.get(Uri.parse(path))).body
    : rootBundle.loadString(path);
