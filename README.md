# bmp180-rb
[![Code Climate](https://codeclimate.com/github/jannvck/bmp180-rb/badges/gpa.svg)](https://codeclimate.com/github/jannvck/bmp180-rb)

Bosch BMP180 temperature sensor ruby library

Straightforward to use:

```
tempPres = TemperaturePressureSensor.new("/dev/i2c-1")
result = tempPres.read(3) # highest accuracy
puts "temperature=#{result.temp}"
```