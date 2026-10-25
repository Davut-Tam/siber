import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// siber-oyun-ilf4c projesinin uygulamaya gömülü Firebase ayarları.
// Bu değerler gizli değildir; veritabanını database.rules.json korur.

const _databaseURL = 'https://siber-oyun-ilf4c-default-rtdb.europe-west1.firebasedatabase.app';
const _projectId = 'siber-oyun-ilf4c';
const _senderId = '799828196925';
const _bucket = 'siber-oyun-ilf4c.firebasestorage.app';

const _web = FirebaseOptions(
  apiKey: 'AIzaSyBtWTWd9bweZA2XS085CWt5Q8OjzCVKZYo',
  appId: '1:799828196925:web:00500b02c744dd8c803454',
  messagingSenderId: _senderId,
  projectId: _projectId,
  authDomain: 'siber-oyun-ilf4c.firebaseapp.com',
  storageBucket: _bucket,
  databaseURL: _databaseURL,
);

const _ios = FirebaseOptions(
  apiKey: 'AIzaSyB6zrGEWt1EI_fe6svCh8mo7Z_mAKtpaXs',
  appId: '1:799828196925:ios:4565174cc0ca06cc803454',
  messagingSenderId: _senderId,
  projectId: _projectId,
  storageBucket: _bucket,
  databaseURL: _databaseURL,
  iosBundleId: 'com.davuttam.siber',
);

const _android = FirebaseOptions(
  apiKey: 'AIzaSyBe3BoZ6ME0eGJgTQjA8ECivKXZeUM-kcw',
  appId: '1:799828196925:android:8d2cf67ae581e7f2803454',
  messagingSenderId: _senderId,
  projectId: _projectId,
  storageBucket: _bucket,
  databaseURL: _databaseURL,
);

/// Çalışılan platforma göre Firebase ayarları
FirebaseOptions get firebaseOptions {
  if (kIsWeb) return _web;
  return defaultTargetPlatform == TargetPlatform.android ? _android : _ios;
}
