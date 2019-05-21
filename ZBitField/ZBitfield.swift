//
//	ZBitfield.swift
//	ZKit
//
//	The MIT License (MIT)
//
//	Copyright (c) 2016 Electricwoods LLC, Kaz Yoshikawa.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy 
//	of this software and associated documentation files (the "Software"), to deal 
//	in the Software without restriction, including without limitation the rights 
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
//	copies of the Software, and to permit persons to whom the Software is 
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.
//

import Foundation

private func bitString<T: BinaryInteger>(_ value: T) -> String {
	var value = value
	var string = ""
	var separator = ""
	let bits = MemoryLayout<T>.size * 8
	for i in 0 ..< bits {
		if i % 4 == 0 { string = separator + string }
		string = ((value % 2 == 0) ? "0" : "1") + string
		value /= 2
		separator = "_"
	}
	return string
}

private func bitMask(_ index: UInt8, _ bits: UInt8) -> UInt8 {
	assert(bits > 0 && index + bits <= 8)
	var maskbit: UInt8 = 0b1111_1111
	maskbit <<= (8 - bits)
	maskbit >>= index
	return maskbit
}

private func bitsValue(_ byte: UInt8, _ bitIndex: UInt8, _ bits: UInt8) -> UInt8 {
	let bits2shift: UInt = UInt(8 - (bitIndex + bits))
	let postshift: UInt = UInt(byte) >> bits2shift
	let bitmask: UInt = ~(0xff << UInt(bits))
	let bitvalue: UInt8 = UInt8(postshift & bitmask)
	return bitvalue
}

private func setBitsValue(_ byte: inout UInt8, _ bitIndex: UInt8, _ bits: UInt8, _ value: UInt8) {
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
		self.bytes = [UInt8](repeating: UInt8(0), count: Int(length))
		self.length = length
		self.positions = positions
	}

	func value(forKey key: String) -> UInt64? {
		// find bit position for the key
		if let info = positions[key] {
			let position = UInt(info.position)
			var bits = UInt8(info.bits)
			assert(Int(bits) <= MemoryLayout<UInt64>.size * 8)
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
	
	func setValue(_ value: UInt64, forKey key: String) {
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
				let byteIndex = (bitTail - UInt(bits)) / 8
				let bitIndex = (bitTail - UInt(bits)) % 8
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
			if let value = value(forKey: key) { return UInt(value)
			} else { fatalError("unknown key: \(key)") }
		}
		set {
			assert(positions[key] != nil, "Unknown key: '\(key)'")
			setValue(UInt64(newValue), forKey: key)
		}
	}

	var data: Data {
		get {
			let data = NSMutableData()
			data.append(bytes, length: Int(length))
			return data as Data
		}
		set {
			assert(newValue.count >= Int(length))
			(newValue as NSData).getBytes(&bytes, length: Int(length))
		}
	}
}
