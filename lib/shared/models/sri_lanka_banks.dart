import 'package:flutter/material.dart';

class SriLankaBank {
  final String name;
  final String code;
  final int minDigits;
  final int maxDigits;
  final String hint;
  final Color color;
  final String logoAsset;

  const SriLankaBank({
    required this.name,
    required this.code,
    required this.minDigits,
    required this.maxDigits,
    required this.hint,
    required this.color,
    required this.logoAsset,
  });

  String get digitRule => minDigits == maxDigits
      ? '$minDigits digits'
      : '$minDigits–$maxDigits digits';
}

const List<SriLankaBank> sriLankaBanks = [
  SriLankaBank(name: 'Bank of Ceylon (BOC)',            code: 'BOC',  minDigits: 10, maxDigits: 10, hint: '10-digit account number',    color: Color(0xFF1A3A6B), logoAsset: 'assets/images/banks/boc.png'),
  SriLankaBank(name: "People's Bank",                   code: 'PB',   minDigits: 15, maxDigits: 15, hint: '15-digit account number',    color: Color(0xFFB22222), logoAsset: 'assets/images/banks/peoples_bank.png'),
  SriLankaBank(name: 'Commercial Bank of Ceylon',       code: 'COM',  minDigits: 13, maxDigits: 13, hint: '13-digit account number',    color: Color(0xFF006400), logoAsset: 'assets/images/banks/commercial_bank.png'),
  SriLankaBank(name: 'Hatton National Bank (HNB)',      code: 'HNB',  minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFFCC0000), logoAsset: 'assets/images/banks/hnb.png'),
  SriLankaBank(name: 'Sampath Bank',                    code: 'SAM',  minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFF0057A8), logoAsset: 'assets/images/banks/sampath.png'),
  SriLankaBank(name: 'Seylan Bank',                     code: 'SEY',  minDigits: 15, maxDigits: 15, hint: '15-digit account number',    color: Color(0xFF003087), logoAsset: 'assets/images/banks/seylan.png'),
  SriLankaBank(name: 'Nations Trust Bank (NTB)',        code: 'NTB',  minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFF8B0000), logoAsset: 'assets/images/banks/ntb.png'),
  SriLankaBank(name: 'National Development Bank (NDB)', code: 'NDB',  minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFF004B87), logoAsset: 'assets/images/banks/ndb.png'),
  SriLankaBank(name: 'DFCC Bank',                       code: 'DFCC', minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFF6A0DAD), logoAsset: 'assets/images/banks/dfcc.png'),
  SriLankaBank(name: 'Pan Asia Banking Corporation',    code: 'PABC', minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFF005F73), logoAsset: 'assets/images/banks/pabc.png'),

  SriLankaBank(name: 'Union Bank of Colombo',           code: 'UBC',  minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFF2E4057), logoAsset: 'assets/images/banks/union_bank.png'),
  SriLankaBank(name: 'Amana Bank',                      code: 'AMA',  minDigits: 13, maxDigits: 13, hint: '13-digit account number',    color: Color(0xFF1B6CA8), logoAsset: 'assets/images/banks/amana.png'),
  SriLankaBank(name: 'Cargills Bank',                   code: 'CAR',  minDigits: 13, maxDigits: 13, hint: '13-digit account number',    color: Color(0xFFE63946), logoAsset: 'assets/images/banks/cargills.png'),
  SriLankaBank(name: 'Sanasa Development Bank (SDB)',   code: 'SDB',  minDigits: 10, maxDigits: 10, hint: '10-digit account number',    color: Color(0xFF2D6A4F), logoAsset: 'assets/images/banks/sdb.png'),
  SriLankaBank(name: 'Regional Development Bank (RDB)', code: 'RDB',  minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFF457B9D), logoAsset: 'assets/images/banks/rdb.png'),
  SriLankaBank(name: 'LOLC Finance',                    code: 'LOLC', minDigits: 11, maxDigits: 11, hint: '11-digit account number',    color: Color(0xFFE76F51), logoAsset: 'assets/images/banks/lolc.png'),
  SriLankaBank(name: 'Citibank N.A.',                   code: 'CITI', minDigits: 10, maxDigits: 11, hint: '10–11 digit account number', color: Color(0xFF003B70), logoAsset: 'assets/images/banks/citibank.png'),
  SriLankaBank(name: 'Standard Chartered Bank',         code: 'SCB',  minDigits: 11, maxDigits: 11, hint: '11-digit account number',    color: Color(0xFF00A3E0), logoAsset: 'assets/images/banks/scb.png'),
  SriLankaBank(name: 'HSBC Sri Lanka',                  code: 'HSBC', minDigits: 9,  maxDigits: 12, hint: '9–12 digit account number',  color: Color(0xFFDB0011), logoAsset: 'assets/images/banks/hsbc.png'),
  SriLankaBank(name: 'Deutsche Bank',                   code: 'DB',   minDigits: 10, maxDigits: 10, hint: '10-digit account number',    color: Color(0xFF003366), logoAsset: 'assets/images/banks/deutsche.png'),
  SriLankaBank(name: 'Indian Bank',                     code: 'IB',   minDigits: 9,  maxDigits: 14, hint: '9–14 digit account number',  color: Color(0xFF800000), logoAsset: 'assets/images/banks/indian_bank.png'),
  SriLankaBank(name: 'Indian Overseas Bank',            code: 'IOB',  minDigits: 9,  maxDigits: 14, hint: '9–14 digit account number',  color: Color(0xFF1A5276), logoAsset: 'assets/images/banks/iob.png'),
  SriLankaBank(name: 'MCB Bank',                        code: 'MCB',  minDigits: 12, maxDigits: 12, hint: '12-digit account number',    color: Color(0xFF006633), logoAsset: 'assets/images/banks/mcb.png'),
  SriLankaBank(name: 'Habib Bank',                      code: 'HBL',  minDigits: 11, maxDigits: 11, hint: '11-digit account number',    color: Color(0xFF004225), logoAsset: 'assets/images/banks/hbl.png'),
];

