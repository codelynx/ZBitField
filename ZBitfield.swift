//
//  ZBitfield.swift
//  ZBitfield
//
//  Created by Kaz Yoshikawa on 2015/05/31.
//  Copyright (c) Kaz Yoshikawa. All rights reserved.
//
//	This software may be modified and distributed under the terms
//	of the MIT license.
//

import Foundation

private func bitString<T: IntegerType>(value: T) -> String {
	var value = value
	var string = ""
	var separator = ""
	let bits = sizeof(T) * 8
	for i in 0 ..< bits {
		if i % 4 == 0 { string = separator + string }
		string = ((value % 2 == 0) ? "0" : "1") + string
		value /= 2
		separator = "_"
	}
	return string
}

private func bitMask(index: UInt8, _ bits: UInt8) -> UInt8 {
	assert(bits > 0 && index + bits <= 8)
	var maskbit: UInt8 = 0b1111_1111
	maskbit <<= (8 - bits)
	maskbit >>= index
	return maskbit
}

private func bitsValue(byte: UInt8, _ bitIndex: UInt8, _ bits: UInt8) -> UInt8 {
	let bits2shift: UInt = UInt(8 - (bitIndex + bits))
	let postshift: UInt = UInt(byte) >> bits2shift
	let bitmask: UInt = ~(0xff << UInt(bits))
	let bitvalue: UInt8 = UInt8(postshift & bitmask)
	return bitvalue
}

private func setBitsValue(inout byte: UInt8, _ bitIndex: UInt8, _ bits: UInt8, _ value: UInt8) {
	let bits2shift: UInt = 8 - UInt(bitIndex + bits)
	let shiftValue: UInt = UInt(value) << bits2shift
	let maskbit = bitMask(bitIndex, bits)
	byte = (byte & ~maskbit) | UInt8(shiftValue)
}

class ZBitField {

	let positions: [String: (position: UInt, bits: UInt8)]
	var bytes: [UInt8]
	let length: UInt

	init?(_ spec: [(String, Int)]) {
		var positions: [String: (position: UInt, bits: UInt8)] = [:]
		var position: UInt = 0
		//var names: Set<String> = []
		for (key, bits) in spec {
			assert(position < 0x8_000)
			if bits == 0 || bits > 64 || positions[key] != nil {
				self.positions = [:]
				self.bytes = []
				self.length = 0
				return nil
			}
			positions[key] = (position: UInt(position), bits: UInt8(bits))
			position = position + UInt(bits)
		}
		let length = UInt(ceil(Double(position) / 8.0))
		self.bytes = [UInt8](count: Int(length), repeatedValue: UInt8(0))
		self.length = length
		self.positions = positions
	}

	func valueForKey(key: String) -> UInt64? {
		// find bit position for the key
		if let info = positions[key] {
			let position = UInt(info.position)
			var bits = UInt8(info.bits)
			assert(Int(bits) <= sizeof(UInt64) * 8)
			var value = UInt64(0) // initial value
			var location = Int(position / 8) // location in buffer
			var bitIndex = UInt8(position % 8) // bit offset
			var bitCount = min(8 - bitIndex, bits)
			if bitCount == 0 { bitCount = min(8, bits) ; location -= 1 }
			while (bits > 0) {
				let byte = bytes[location]
				let bitValue = bitsValue(byte, bitIndex, UInt8(bitCount))
				value = (value << UInt64(bitCount)) | UInt64(bitValue)
				location += 1 ; bitIndex = 0
				bits -= bitCount ; bitCount = min(bits, 8)
			}
			return value
		}
		return nil
	}
	
			//	example: 0b11110000_11110000_11110000, index=5, bits=14, value=0b11_0011_0011_0011
			//	0 1 2 3 4 5 6 7   0 1 2 3 4 5 6 7   0 1 2 3 4 5 6 7		<- bit index
			//  1 1 1 1 0 0 0 0   1 1 1 1 0 0 0 0   1 1 1 1 0 0 0 0		<- input
			//	          * * *   * * * * * * * *	* *	*				<- mask (14 bit)
			//	          1 1 0   0 1 1 0 0 1 1 0   0 1 1				<- value
			//	1 1 1 1 0 1 1 0   0 1 1 0 0 1 1 0   0 1 1 1 0 0 0 0		<- output
	
	func setValue(value: UInt64, forKey key: String) {
		assert(value >= 0)
		// find bit position for the key
		if let info = positions[key] {
			let bitPosition = UInt(info.position)
			let bitLength = UInt8(info.bits)

			//	example: 0b11110000_11110000_11110000, index=5, bits=14, value=0b11_0011_0011_0011
			//	0 1 2 3 4 5 6 7   0 1 2 3 4 5 6 7   0 1 2 3 4 5 6 7		<- bit index
			//  1 1 1 1 0 0 0 0   1 1 1 1 0 0 0 0   1 1 1 1 0 0 0 0		<- input
			//	          * * *   * * * * * * * *	* *	*				<- mask (14 bit)
			//	          1 1 0   0 1 1 0 0 1 1 0   0 1 1				<- value
			//	1 1 1 1 0 1 1 0   0 1 1 0 0 1 1 0   0 1 1 1 0 0 0 0		<- output

			// process from backword
			var bitTail = bitPosition + UInt(bitLength)
			var value = UInt(value)
			var bitCount = bitLength
			while (bitCount > 0) {
				let bits = min(bitTail % 8 == 0 ? 8 : bitTail % 8, UInt(bitCount))
				let byteIndex = (bitTail - bits) / 8
				let bitIndex = (bitTail - bits) % 8
				let bitValue = value % UInt(1 << bits)
				setBitsValue(&bytes[Int(byteIndex)], UInt8(bitIndex), UInt8(bits), UInt8(bitValue))
				value >>= bits
				bitTail -= bits
				bitCount -= UInt8(bits)
			}
		}
	}

	subscript(key: String) -> UInt {
		get {
			if let value = valueForKey(key) { return UInt(value)
			} else { fatalError("unknown key: \(key)") }
		}
		set {
			assert(positions[key] != nil, "Unknown key: '\(key)'")
			setValue(UInt64(newValue), forKey: key)
		}
	}

	var data: NSData {
		get {
			let data = NSMutableData()
			data.appendBytes(bytes, length: Int(length))
			return data
		}
		set {
			assert(newValue.length >= Int(length))
			newValue.getBytes(&bytes, length: Int(length))
		}
	}
}
