return function()
	local luaBits = require(script.Parent.luaBits)

	it("should give number of bits needed for integers", function()
		local bits = luaBits.bitsToRepresentInt(1)
		expect(bits).to.equal(1)
		bits = luaBits.bitsToRepresentInt(3)
		expect(bits).to.equal(2)
		bits = luaBits.bitsToRepresentInt(7)
		expect(bits).to.equal(3)
		bits = luaBits.bitsToRepresentInt(15)
		expect(bits).to.equal(4)
		bits = luaBits.bitsToRepresentInt(31)
		expect(bits).to.equal(5)
		bits = luaBits.bitsToRepresentInt(63)
		expect(bits).to.equal(6)
		bits = luaBits.bitsToRepresentInt(127)
		expect(bits).to.equal(7)
		bits = luaBits.bitsToRepresentInt(255)
		expect(bits).to.equal(8)
		bits = luaBits.bitsToRepresentInt(511)
		expect(bits).to.equal(9)
		bits = luaBits.bitsToRepresentInt(1023)
		expect(bits).to.equal(10)
	end)

	it("should encode and decode integers", function()
		local bitString = luaBits.integerToBitString(145, 8)
		local integer = luaBits.bitStringToInteger(bitString)
		expect(integer).to.equal(145)
	end)

	it("should compress and decompress 8 bit data properly", function()
		local bitString = luaBits.integerToBitString(255, 8)
		local compressedBitString = luaBits.compressBitString(bitString)
		local decompressedBitString = luaBits.decompressBitString(compressedBitString)
		local integer = luaBits.bitStringToInteger(decompressedBitString)
		expect(integer).to.equal(255)
	end)
end



--[[0   1  0  1  0 0 1 0
128 64 32 16 8 4 2 1]]
