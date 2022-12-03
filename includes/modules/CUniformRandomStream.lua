--[[
	https://github.com/awesomeusername69420/miscellaneous-gmod-stuff

	https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/public/vstdlib/random.h
	https://github.com/VSES/SourceEngine2007/blob/master/src_main/vstdlib/random.cpp
]]

CUniformRandomStream = {
	Meta = {}
}

CUniformRandomStream.Meta.__index = CUniformRandomStream.Meta

local NTAB = 32

local IA = 16807
local IM = 2147483647
local IQ = 127773
local IR = 2836
local NDIV = 1 + (IM - 1) / NTAB
local MAX_RANDOM_RANGE = 0x7FFFFFFF

local AM = 1 / IM
local EPS = 1.2e-7
local RNMX = 1 - EPS

-- Set the generation seed
function CUniformRandomStream.Meta:SetSeed(Seed)
	self.m_idum = Seed < 0 and Seed or -Seed
	self.m_iy = 0
end

-- Generate a random integer
function CUniformRandomStream.Meta:GenerateRandomNumber()
	local math_floor = math.floor
	local j, k = 0, 0

	if self.m_idum <= 0 or not self.m_iy then
		self.m_idum = -self.m_idum

		if self.m_idum < 1 then
			self.m_idum = 1
		end

		j = NTAB + 8
		while j > 0 do
			j = j - 1

			k = math_floor(self.m_idum / IQ)
			self.m_idum = math_floor(IA * (self.m_idum - k * IQ) - IR * k)

			if self.m_idum < 0 then
				self.m_idum = math_floor(self.m_idum + IM)
			end

			if j < NTAB then
				self.m_iv[j] = math_floor(self.m_idum)
			end
		end

		self.m_iy = self.m_iv[0]
	end

	k = math_floor(self.m_idum / IQ)
	self.m_idum = math_floor(IA * (self.m_idum - k * IQ) - IR * k)

	if self.m_idum < 0 then
		self.m_idum = math_floor(self.m_idum + IM)
	end

	j = math_floor(self.m_iy / NDIV)

	if j >= NTAB or j < 0 then
		ErrorNoHalt(string.format("CUniformRandomStream array overrun; Tried to write %d", j))
		j = math_floor(bit.band(j % NTAB, MAX_RANDOM_RANGE))
	end

	self.m_iy = math_floor(self.m_iv[j])
	self.m_iv[j] = math_floor(self.m_idum)

	return self.m_iy
end

-- Generate a random float
function CUniformRandomStream.Meta:RandomFloat(Min, Max)
	Min = Min or 0
	Max = Max or 1

	local Float = AM * self:GenerateRandomNumber()

	if Float > RNMX then
		Float = RNMX
	end

	return (Float * (Max - Min)) + Min
end

-- Generate a random float to an exponent (Kinda retarded but may as well include it)
function CUniformRandomStream.Meta:RandomFloatExp(Min, Max, Exp)
	local Float = self:RandomFloat(Min, Max)

	if Exp ~= 1 then
		Float = math.pow(Float, Exp)
	end

	return Float
end

-- Generate a random unsigned integer
function CUniformRandomStream.Meta:RandomInt(Min, Max)
	local math_abs = math.abs

	local MaxAcceptable
	local X = math_abs(Max - Min + 1)

	if X <= 1 or MAX_RANDOM_RANGE < X - 1 then
		return Min
	end

	MaxAcceptable = math_abs(MAX_RANDOM_RANGE - ((MAX_RANDOM_RANGE + 1) % X))

	local Int = math_abs(self:GenerateRandomNumber())
	while Int > MaxAcceptable do
		Int = math_abs(self:GenerateRandomNumber())
	end

	return Min + (Int % X)
end

-- Create a new CUniformRandomStream object
function CUniformRandomStream.New()
	local RandomStream = setmetatable({}, CUniformRandomStream.Meta)
	RandomStream.m_iv = {}

	RandomStream:SetSeed(0)

	return RandomStream
end
