![swift](https://img.shields.io/badge/swift-3.0-orange.svg) ![license](https://img.shields.io/badge/license-MIT-yellow.svg)


# ZBitField
Utility code to implement bit field operation.  Programming language C provides bit field feature that developer can write some code to read or write bits without bit shifting as follows.

##

```.C
struct RGB_t {
  unsigned int red : 4;
  unsigned int greeb : 4;
  unsigned int blue : 4
  unsigned int alpha : 4
};

struct RGB_t color;
color.red = 0xf
color.green = 0x0
color.blue = 0x8
```

Unfortunatly, Swift does't not have feature of this bit field feature.  ZBitField may help you to implement to deal with complex bit wise operation.

## Example

For example you like to define, 32bit data structure with number of bit field, you may define ZBitField as follows.  Then you may read and write bit field value with key.  The key must be defined or its behavior is undefined.

```.swift
var bitfield = ZBitField(spec: [("red", 4), ("green", 4), ("blue", 4), ("alpha", 4)]!
bitfield["red"] = 0xf
bitfield["green"] = 0x0
bitfield["blue"] = 0x8
bitfield["alpha"] = 0xf
let data = bitfield.data // NSData
```

```.swift
var data = .... // NSData
var bitfield = ZBitField(spec: [("red", 4), ("green", 4), ("blue", 4), ("alpha", 4)]!
bitfield.data = data
let r = bitfield["red"]
let g = bitfield["green"]
let b = bitfield["blue"]
let a = bitfield["alpha"]

```

## Defining Bit format

Bit format is defined by array of tuple (key, bits).  All keys must be unique within the same spec, and bits should be between 1 to 64.  Bit field larger than 64 bit are nor  supported.

```Swift
  [ ("r", 5), ("g", 6), ("b", 6) .... ] // r: 5bit, g: 6bit, b: 5bit

  [ ("unused", 1) ("type", 14), ("unused", 1) ] // error: key "unused" must be unique
  [ ("unused1", 1) ("type", 14), ("unused2", 1) ] // OK

```

## Methods

### Initialize

```.swift
init?(spec: [(String, Int)])
```

Initialized with bit format spec. It fails if it has a duplicate key, it has 0 bit width item or larger than 64 bit width item.

### subscript

```.swift
subscript(key: String) -> UInt { get set}
```

To set or to get bit value by key. Key must be exist, or its behavior is undefined.

### geting the value for keyed bit-field

```.swift
func value(forKey: String) -> UInt64?
```

To get bit value by key. When key is not found, then nil will be returned.

### setting a value for keyed bit-field

```.swift
func setValue(var value: UInt64, forKey key: String)
```

To set bit value for key. When key is not defined, it does nothing.

### finding it's byte length

```.swift
let length: UInt
```

The byte length required for this instance.

### get it's binary representation

```.swift
var data: Data { get set }
```

To get or to set binary data.  You may set indivisual bit value by code and extract whole binary data. Or, you may set any binary data to this instance, and inspect each bit value.  Setting binary must be the same size as the `length` property.

## Contact
Kaz Yoshikawa
* kaz@digitallynx.com

## License

ZBitField is available under the MIT license. See the LICENSE file for more info.
