--[[
	The luabits module provides an API for creating and serializing binary data
	formats with the intention of compressing data for easier storage and
	transportation.
]]

local NAT_LOG_2 = math.log(2)

-- Returns the number of bits needed to represent an integer in binary format.
--[[local function bitsToRepresentInt(integer)
	integer = math.floor(integer)
	local bits = math.ceil(math.log(integer+1)/NAT_LOG_2)
	return math.log(integer)/NAT_LOG_2, bits, (2^bits)-1
end]]

local function bitsToRepresentInt(integer)
	integer = math.floor(integer)
	return math.log(integer+1)/NAT_LOG_2
end

-- Converts an integer into a sequence of bits, stored as a string
local function integerToBitString(integer, bits)
	if not bits then
		bits = bitsToRepresentInt(integer)
	end
	local bitString = ""
	for i = bits, 1, -1 do
		local bitNumber = 2^(i-1)
		if integer >= bitNumber then
			bitString = bitString.."1"
			integer = integer - bitNumber
		else
			bitString = bitString.."0"
		end
	end
	return bitString
end

-- Converts a sequence of bits back into an integer
local function bitStringToInteger(bitString)
	local value = 0
	local length = string.len(bitString)
	for bit in string.gmatch(bitString, ".") do
		length = length - 1
		if bit == "1" then
			value = value + 2^length
		end
	end
	return value
end

local function compressBitString(bitString, forDatastore)
	local charSize = forDatastore and 6 or 8
	 --[[
		 When serializing for DataStores, we can only encoded ASCII characters between
		 the values 0-127. Because of quirks with how JSON encodes certain control
		 characters, 36 of those characters use up to 6 characters in the datastore to
		 encode a single character, meaning 7 bits have the potential to take up to 42
		 bits of space. Thus, it turns out that it's more efficient to forgo 7-bit
		 serialization into all valid 128 ASCII character and use only 6-bit
		 serialization instead.
		 https://devforum.roblox.com/t/text-compression/163637/6
	 ]]
	local charValue = 0
	local bitPosition = 1
	local compressedString = ""
	for bit in string.gmatch(bitString:reverse(), ".") do
		if bit == "1" then
			charValue = charValue+2^(bitPosition-1)
		end
		if bitPosition == charSize then
			if forDatastore then
				charValue = charValue + 35
				if charValue >= 92 then
					-- We skip 92 because the backslash character (92) is encoded in JSON
					--datastores as 2 characters, "\\", an escape backslash, followed by an
					--actual backslash. Characters 1-31 and 34 are also encoded as more than
					--one character, so we start on character 35.
					charValue = charValue + 1
				end
			end
			compressedString = compressedString..string.char(charValue)
			charValue = 0
			bitPosition = 1
		else
			bitPosition = bitPosition + 1
		end
	end
	if charValue > 0 then
		local remainingBits = charSize-bitPosition
		charValue = charValue * (2^remainingBits) -- Shifts bits #remainingBits places left, i.e. appends #remainingBits zeroes to the end, adding enough bits to even out the very last value
		compressedString = compressedString..string.char(charValue)
	end
	return compressedString
end

local function decompressBitString(bitString, forDatastore)
	local numberBits = forDatastore and 6 or 8
	local bits = ""
	for char in string.gmatch(bitString, ".") do
		local integer = string.byte(char)
		if forDatastore and integer >= 93 then
			integer = integer - 1 - 35
			-- We do this, because if the serialized integer is 92 or greater, it is
			-- stored as 1 greater than its actual value in order to skip ASCII character
			-- 92. (see above comments)
			elseif forDatastore then
				integer = integer - 35
			end
		bits = bits..integerToBitString(integer, numberBits)
	end
	return bits
end

local function deserializeBitString(bitString, spec, sizeCallbacks, container, root, position)
	root = root or {}
	container = container or root
	position = position or 1
	if spec.Type == "Table" then
		for i = 1, #spec.Values do
			local value = spec.Values[i]
			position = deserializeBitString(bitString, value, sizeCallbacks, container, position)
		end
		return position
	elseif spec.Type == "Integer" then
		if spec.Size then
			local intSize do
				if typeof(spec.Size) == "number" then
					intSize = spec.Size
				elseif typeof(spec.Size) == "string" then
					if not sizeCallbacks then
						error("LuaBits deserializeBitString: Callbacks table is undefined")
					end
					local callback = sizeCallbacks[spec.Size]
					if callback then
						if typeof(callback) == "function" then
							intSize = callback(root)
							sizeCallbacks[spec.Size] = intSize
						elseif typeof(callback) == "number" then
							intSize = callback
						else
							error("LuaBits deserializeBitString: Incorrect type given for callback ''"..spec.Size.. "', Value must be a function")
						end
					else
						error("LuaBits deserializeBitString: Callback '"..spec.Size.."' is undefined.")
					end
				else
					error("LuaBits deserializeBitString: Incorrect size given for int value ''".. (spec.Key or "[keyless]") .."', must be callback string or integer")
				end
				local integerBits = string.sub(bitString, position, position+intSize-1)
				container[spec.Key or #table+1] = bitStringToInteger(integerBits)
				return position + intSize
			end
		else
			error("LuaBits deserializeBitString: No or size given for int value ".. (spec.Key or "[keyless]"))
		end
	elseif spec.Type == "Boolean" then
		local bit = string.sub(bitString, position)
		container[spec.Key or #table+1] = bit == "1"
		return position + 1
	end
end

local luaBits = {
	bitsToRepresentInt   = bitsToRepresentInt;
	integerToBitString   = integerToBitString;
	bitStringToInteger   = bitStringToInteger;
	compressBitString    = compressBitString;
	decompressBitString  = decompressBitString;
	deserializeBitString = deserializeBitString;
}

return luaBits