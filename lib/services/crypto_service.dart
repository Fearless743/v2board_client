import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefPublicKey = 'subscribe_encryption_public_key';
const _prefPrivateKey = 'subscribe_encryption_private_key';
const _prefKeyCreatedAt = 'subscribe_encryption_key_created_at';

const keyValidityDuration = Duration(days: 7);

class CryptoService {
  static const int _rsaKeyBits = 2048;
  static const int _aesKeyLen = 32;
  static const int _gcmNonceLen = 12;
  static const int _gcmTagLen = 128;

  static String? _cachedPublicKey;
  static String? _cachedPrivateKey;

  static Future<bool> hasKeyPair() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefPublicKey) == null ||
        prefs.getString(_prefPrivateKey) == null) {
      return false;
    }
    final createdAtMs = prefs.getInt(_prefKeyCreatedAt);
    if (createdAtMs == null) return false;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    if (DateTime.now().difference(createdAt) > keyValidityDuration) {
      await clearKeyPair();
      return false;
    }
    return true;
  }

  static Future<String> getPublicKeyBase64() async {
    if (_cachedPublicKey != null) return _cachedPublicKey!;
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefPublicKey);
    if (key == null) throw Exception('Encryption key pair not generated');
    _cachedPublicKey = key;
    return key;
  }

  static Future<RSAPublicKey> getPublicKey() async {
    final b64 = await getPublicKeyBase64();
    return _decodePublicKey(base64.decode(b64));
  }

  static Future<RSAPrivateKey> _getPrivateKey() async {
    if (_cachedPrivateKey != null) {
      return _decodePrivateKey(base64.decode(_cachedPrivateKey!));
    }
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefPrivateKey);
    if (key == null) throw Exception('Encryption key pair not generated');
    _cachedPrivateKey = key;
    return _decodePrivateKey(base64.decode(key));
  }

  static Future<void> generateKeyPair() async {
    final secureRandom = _buildSecureRandom();
    final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), _rsaKeyBits, 64);
    final generator = RSAKeyGenerator()
      ..init(ParametersWithRandom(keyParams, secureRandom));
    final pair = generator.generateKeyPair();

    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    final pubBytes = _encodePublicKey(publicKey);
    final privBytes = _encodePrivateKey(privateKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPublicKey, base64.encode(pubBytes));
    await prefs.setString(_prefPrivateKey, base64.encode(privBytes));
    await prefs.setInt(_prefKeyCreatedAt, DateTime.now().millisecondsSinceEpoch);

    _cachedPublicKey = base64.encode(pubBytes);
    _cachedPrivateKey = base64.encode(privBytes);
  }

  static Future<void> clearKeyPair() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPublicKey);
    await prefs.remove(_prefPrivateKey);
    await prefs.remove(_prefKeyCreatedAt);
    _cachedPublicKey = null;
    _cachedPrivateKey = null;
  }

  static Future<Uint8List> decryptHybrid(
    Uint8List encryptedPayload,
  ) async {
    final privateKey = await _getPrivateKey();
    final reader = _ByteReader(encryptedPayload);

    final rsaKeyLen = reader.readUint32();
    final rsaEncryptedKey = reader.readBytes(rsaKeyLen);
    final nonce = reader.readBytes(_gcmNonceLen);
    final ciphertext = reader.readRemaining();

    final aesKey = _rsaDecryptKey(rsaEncryptedKey, privateKey);

    return _aesGcmDecrypt(ciphertext, aesKey, nonce);
  }

  static Uint8List _rsaDecryptKey(
    Uint8List encryptedKey,
    RSAPrivateKey privateKey,
  ) {
    final cipher = PKCS1Encoding(RSAEngine());
    cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return cipher.process(encryptedKey);
  }

  static Uint8List _aesGcmDecrypt(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List nonce,
  ) {
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false,
      AEADParameters(
        KeyParameter(key),
        _gcmTagLen,
        nonce,
        Uint8List(0),
      ),
    );

    final plaintext = Uint8List(ciphertext.length);
    var offset = 0;
    for (var i = 0; i < ciphertext.length;) {
      final remaining = ciphertext.length - i;
      final chunkSize = remaining < 4096 ? remaining : 4096;
      offset += cipher.processBytes(ciphertext, i, chunkSize, plaintext, offset);
      i += chunkSize;
    }
    cipher.doFinal(plaintext, offset);

    return plaintext;
  }

  static RSAPublicKey _decodePublicKey(Uint8List bytes) {
    final reader = ASN1Parser(bytes);
    final seq = reader.nextObject() as ASN1Sequence;
    final modulus = (seq.elements![0] as ASN1Integer).integer!;
    final exponent = (seq.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(modulus, exponent);
  }

  static RSAPrivateKey _decodePrivateKey(Uint8List bytes) {
    final reader = ASN1Parser(bytes);
    final seq = reader.nextObject() as ASN1Sequence;
    final modulus = (seq.elements![1] as ASN1Integer).integer!;
    final publicExponent = (seq.elements![2] as ASN1Integer).integer!;
    final privateExponent = (seq.elements![3] as ASN1Integer).integer!;
    final p = (seq.elements![4] as ASN1Integer).integer!;
    final q = (seq.elements![5] as ASN1Integer).integer!;
    return RSAPrivateKey(modulus, privateExponent, p, q, publicExponent);
  }

  static Uint8List _encodePublicKey(RSAPublicKey publicKey) {
    final seq = ASN1Sequence();
    seq.add(ASN1Integer(publicKey.modulus));
    seq.add(ASN1Integer(publicKey.publicExponent));
    return seq.encode();
  }

  static Uint8List _encodePrivateKey(RSAPrivateKey privateKey) {
    final seq = ASN1Sequence();
    seq.add(ASN1Integer(BigInt.zero));
    seq.add(ASN1Integer(privateKey.n));
    seq.add(ASN1Integer(privateKey.publicExponent));
    seq.add(ASN1Integer(privateKey.privateExponent));
    seq.add(ASN1Integer(privateKey.p));
    seq.add(ASN1Integer(privateKey.q));
    return seq.encode();
  }

  static FortunaRandom _buildSecureRandom() {
    final random = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    random.seed(KeyParameter(Uint8List.fromList(seeds)));
    return random;
  }
}

class _ByteReader {
  final Uint8List _data;
  int _offset = 0;

  _ByteReader(this._data);

  int readUint32() {
    if (_offset + 4 > _data.length) {
      throw Exception('Buffer underflow reading uint32');
    }
    final value = (_data[_offset] << 24) |
        (_data[_offset + 1] << 16) |
        (_data[_offset + 2] << 8) |
        _data[_offset + 3];
    _offset += 4;
    return value;
  }

  Uint8List readBytes(int length) {
    if (_offset + length > _data.length) {
      throw Exception('Buffer underflow reading $length bytes');
    }
    final bytes = _data.sublist(_offset, _offset + length);
    _offset += length;
    return bytes;
  }

  Uint8List readRemaining() {
    final bytes = _data.sublist(_offset);
    _offset = _data.length;
    return bytes;
  }
}
