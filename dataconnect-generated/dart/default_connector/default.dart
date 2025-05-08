library default_connector;

import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'dart:convert';

class DefaultConnector {
  DefaultConnector({required this.dataConnect});

  static DefaultConnector get instance {
    return DefaultConnector(
        dataConnect: FirebaseDataConnect.instance);
  }

  FirebaseDataConnect dataConnect;
}
