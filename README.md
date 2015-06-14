# bmp180-rb
Bosch BMP180 temperature sensor ruby library

Straightforward to use:

```
tempPres = TemperaturePressureSensor.new("/dev/i2c-1")
result = tempPres.read(3) # highest accuracy
puts "temperature=#{result.temp}"
```