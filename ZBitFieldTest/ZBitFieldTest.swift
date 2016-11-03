//
//  ZBitFieldTest.swift
//  ZBitFieldTest
//
//  Created by Kaz Yoshikawa on 11/3/16.
//
//

import XCTest

class ZBitfieldTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}

	func testBasic8bit() {
		if let bitfield = ZBitField([("b7", 1), ("b6_1", 6), ("b0", 1)]) {
			XCTAssert(bitfield.length == 1)
			
			bitfield["b6_1"] = 0b101101 ; XCTAssert(bitfield["b6_1"] == 0b101101)
			bitfield["b6_1"] = 0b010010 ; XCTAssert(bitfield["b6_1"] == 0b010010)

			bitfield["b7"] = 1 ; XCTAssert(bitfield["b7"] == 1)
			bitfield["b7"] = 0 ; XCTAssert(bitfield["b7"] == 0)

			bitfield["b0"] = 1 ; XCTAssert(bitfield["b0"] == 1)
			bitfield["b0"] = 0 ; XCTAssert(bitfield["b0"] == 0)
			
		}
	}
	
	func testBasic16bit() {
		if let bitfield = ZBitField([("hi4", 4), ("mi8", 8), ("lo4", 4)]) {
			XCTAssert(bitfield.length == 2)

			bitfield["hi4"] = 0b1001 ; XCTAssert(bitfield["hi4"] == 0b1001)
			bitfield["lo4"] = 0b0110 ; XCTAssert(bitfield["lo4"] == 0b0110)

			// across byte boundary
			bitfield["mi8"] = 0b1111_1111 ; XCTAssert(bitfield["mi8"] == 0b1111_1111)
			bitfield["mi8"] = 0b0000_0000 ; XCTAssert(bitfield["mi8"] == 0b0000_0000)
		}
	}

	func testBasic32bit() {
		if let bitfield = ZBitField([("high4", 4), ("mid24", 24), ("low4", 4)]) {
			XCTAssert(bitfield.length == 4)

			// across byte boundary
			bitfield["mid24"] = 0b1111_1111_1111_1111_1111_1111
			XCTAssert(bitfield["mid24"] == 0b1111_1111_1111_1111_1111_1111)
			XCTAssert(bitfield["high4"] == 0b0000)
			XCTAssert(bitfield["low4"] == 0b0000)

			bitfield["high4"] = 0b1111
			bitfield["low4"] = 0b1111
			bitfield["mid24"] = 0b1001_1000_0100_0010_0001_1001
			XCTAssert(bitfield["mid24"] == 0b1001_1000_0100_0010_0001_1001)
			XCTAssert(bitfield["high4"] == 0b1111)
			XCTAssert(bitfield["low4"] == 0b1111)
		}
	}

	func test1bitx8000() {
		let maxBit = 8192
		var elements: [(String, Int)] = []
		for index in 1...maxBit {
			let element = ("bit\(index)", 1)
			elements.append(element)
		}
		
		if let bitfield = ZBitField(elements) {
			for index in 1...maxBit {
				bitfield["bit\(index)"] = UInt(index % 2)
			}
			for index in 1...maxBit {
				XCTAssert(bitfield["bit\(index)"] == UInt(index % 2))
			}
		}
	}

	func testRandomBits() {

		func randomValueForBitWidths(_ bits: UInt32) -> UInt32 {
			if bits < 32 {
				return arc4random_uniform(0xffff_ffff)  % (1 << bits)
			}
			else {
				return arc4random_uniform(0xffff_ffff)
			}
		}

		var elements: [(String, Int)] = []
		var values: [String: UInt32] = [:]
		var totalBits = 0
		for bits in 1...32 {
			elements += [("a\(bits)", bits)]
			values["a\(bits)"] = UInt32(randomValueForBitWidths(UInt32(bits)))
			totalBits += bits
		}

		if let bitfield = ZBitField(elements) {
			for bits in 1...32 {
				bitfield["a\(bits)"] = UInt(values["a\(bits)"]!)
			}
			for bits in 1...32 {
				XCTAssert(bitfield["a\(bits)"] == UInt(values["a\(bits)"]!))
			}
			XCTAssert(UInt(ceil(Double(totalBits) / 8.0)) == bitfield.length)
		}

	}

	func testNSData() {
		// "551234deadbeefaa" --> "VRI03q2+76o="
		let data = Data(base64Encoded: "VRI03q2+76o=", options: .ignoreUnknownCharacters)
		if let bitfield1 = ZBitField([("a", 8), ("b", 16), ("c", 32), ("d", 8)]) {
			bitfield1["a"] = UInt(0x55)
			bitfield1["b"] = UInt(0x1234)
			bitfield1["c"] = UInt(0xdeadbeef)
			bitfield1["d"] = UInt(0xaa)
			XCTAssert(data! == bitfield1.data)
		}

		if let bitfield2 = ZBitField([("a", 8), ("b", 16), ("c", 32), ("d", 8)]) {
			bitfield2.data = data!
			XCTAssert(bitfield2["a"] == UInt(0x55))
			XCTAssert(bitfield2["b"] == UInt(0x1234))
			XCTAssert(bitfield2["c"] == UInt(0xdeadbeef))
			XCTAssert(bitfield2["d"] == UInt(0xaa))
		}
	}

	func testPerformanceExample() {
		// This is an example of a performance test case.
		self.measure() {
			// Put the code you want to measure the time of here.
		}
	}
	
}
