#!/usr/bin/ruby
require 'i2c' # http://rubydoc.info/gems/i2c/0.2.22/I2C/Dev

class TemperaturePressureSensor
	# Sensor: Bosch BMP180
	DEV_ADDR = 0x77
	#registers
	REG_OUT_XLSB = 0xF8
	REG_OUT_LSB = 0xF7
	REG_OUT_MSB = 0xF6
	REG_CTRL_MEAS = 0xF4
	REG_SOFT_RESET = 0xE0 # set to 0xB6 for a reset
	REG_ID = 0xD0 # fixed value of 0x55
	VAL_CTRL_TEMP = 0x2E # 4,5 ms
	VAL_CTRL_PRESS_OSS0 = 0x34 # 4,5 ms
	VAL_CTRL_PRESS_OSS1 = 0x74 # 7,5 ms
	VAL_CTRL_PRESS_OSS2 = 0xB4 # 13,5 ms
	VAL_CTRL_PRESS_OSS3 = 0xF4 # 25.5 ms
	class CalibrationData
		attr_accessor :ac1, :ac2, :ac3, :ac4, :ac5, :ac6, :b1, :b2, :mb, :mc, :md
	end
	class Result
		attr_accessor :temp, :pressure
	end
	def initialize(bus)
		@bus = I2C.create(bus)
		# verify communication is functioning
                chipId = @bus.read(DEV_ADDR, 1, 0xD0).unpack('c').first
		raise 'Communication not functioning' unless chipId == 0x55
		# read calibration data
		@calibData = CalibrationData.new
		msb = @bus.read(DEV_ADDR, 1, 0xAA).unpack('c').first
		lsb = @bus.read(DEV_ADDR, 1, 0xAB).unpack('c').first
		@calibData.ac1 = (msb << 8) + lsb
		msb = @bus.read(DEV_ADDR, 1, 0xAC).unpack('c').first
                lsb = @bus.read(DEV_ADDR, 1, 0xAD).unpack('c').first
                @calibData.ac2 = (msb << 8) + lsb
		msb = @bus.read(DEV_ADDR, 1, 0xAE).unpack('c').first
                lsb = @bus.read(DEV_ADDR, 1, 0xAF).unpack('c').first
                @calibData.ac3 = (msb << 8) + lsb
                msb = @bus.read(DEV_ADDR, 1, 0xB0).unpack('C').first
                lsb = @bus.read(DEV_ADDR, 1, 0xB1).unpack('C').first
                @calibData.ac4 = (msb << 8) + lsb
                msb = @bus.read(DEV_ADDR, 1, 0xB2).unpack('C').first
                lsb = @bus.read(DEV_ADDR, 1, 0xB3).unpack('C').first
                @calibData.ac5 = (msb << 8) + lsb
                msb = @bus.read(DEV_ADDR, 1, 0xB4).unpack('C').first
                lsb = @bus.read(DEV_ADDR, 1, 0xB5).unpack('C').first
                @calibData.ac6 = (msb << 8) + lsb
                msb = @bus.read(DEV_ADDR, 1, 0xB6).unpack('c').first
                lsb = @bus.read(DEV_ADDR, 1, 0xB7).unpack('c').first
                @calibData.b1 = (msb << 8) + lsb
                msb = @bus.read(DEV_ADDR, 1, 0xB8).unpack('c').first
                lsb = @bus.read(DEV_ADDR, 1, 0xB9).unpack('c').first
                @calibData.b2 = (msb << 8) + lsb
                msb = @bus.read(DEV_ADDR, 1, 0xBA).unpack('c').first
                lsb = @bus.read(DEV_ADDR, 1, 0xBB).unpack('c').first
                @calibData.mb = (msb << 8) + lsb
                msb = @bus.read(DEV_ADDR, 1, 0xBC).unpack('c').first
                lsb = @bus.read(DEV_ADDR, 1, 0xBD).unpack('c').first
                @calibData.mc = (msb << 8) + lsb
                msb = @bus.read(DEV_ADDR, 1, 0xBE).unpack('c').first
                lsb = @bus.read(DEV_ADDR, 1, 0xBF).unpack('c').first
                @calibData.md = (msb << 8) + lsb
	end
	def read(oss = 0x34)
		ut = readUT()
		up = readUP(oss)
		return calc(ut, up, oss)
	end
	# uncompensated temperature value
	def readUT()
		@bus.write(DEV_ADDR, 0xF4, 0x2E)
		sleep 0.1
		msb = @bus.read(DEV_ADDR, 1, 0xF6).unpack('C').first
		lsb = @bus.read(DEV_ADDR, 1, 0xF7).unpack('C').first
		ut = (msb << 8) + lsb
		return ut
	end
	# uncompensated pressure value
	def readUP(oss = 0x34)
		@bus.write(DEV_ADDR, 0xF4, [0x34+(oss<<6)].pack('S'))
		sleep 0.1
		msb = @bus.read(DEV_ADDR, 1, 0xF6).unpack('C').first
		lsb = @bus.read(DEV_ADDR, 1, 0xF7).unpack('C').first
		xlsb = @bus.read(DEV_ADDR, 1, 0xF8).unpack('C').first
		return ((msb<<16) + (lsb<<8) + xlsb)>>(8-oss)
	end
	# true values
	def calc(ut,up,oss)
		# true temperature
		x1 = (ut - @calibData.ac6) * @calibData.ac5 / 2**15
		x2 = @calibData.mc * 2**11 / (x1 + @calibData.md)
		b5 = x1 + x2
		t = (b5 + 8) / 2**4
		# true pressure
		b6 = b5 - 4000
		x1 = (@calibData.b2 * (b6 * b6 / 2**12)) / 2**11
		x2 = @calibData.ac2 * b6 / 2**11
		x3 = x1 + x2
		b3 = (((@calibData.ac1 * 4 + x3) << oss) + 2) / 4
		x1 = @calibData.ac3 * b6 / 2**13
		x2 = (@calibData.b1 * (b6 * b6 / 2**12)) / 2**16
		x3 = ((x1 + x2) + 2) / 2**2
		b4 = @calibData.ac4 * (x3 + 32768) / 2**15
		b7 = (up - b3) * (50000 >> oss)
		p = 0
		if b7 < 0x80000000
			p = (b7 * 2) / b4
		else
			p = (b7 / b4) * 2
		end
		x1 = (p / 2**8) * (p / 2**8)
		x1 = (x1 * 3038) / 2**16
		x2 = (-7357 * p) / 2**16
		p = p+ (x1 + x2 + 3791) / 2**4
		result = Result.new
		result.temp = t
		result.pressure = p
		return result
	end
	def reset()
		@bus.write(DEV_ADDR, REG_SOFT_RESET, 0xB6)
	end
end