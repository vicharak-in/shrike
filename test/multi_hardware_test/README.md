# Test Bed for shrike hardware

### Follow these steps to use 

1. Clone the Shrike-lite Project 
```
git clone https://github.com/vicharak-in/shrike-lite.git
```

2. Change directory to the hardware_test dir in test dir

```
cd shrike-lite/test/multi_hardware_test
```

3. Download the MicroPython UF2 file:
```
wget https://github.com/vicharak-in/shrike/releases/download/v1.0.0/shrike-lite-micropython.uf2
```

4. Execute the setup file 

```
sudo chmod +x setup.sh
sudo ./setup.sh
```

5. Execute the test file 
```
sudo chmod +x multi_shrike_test.sh
sudo ./multi_shrike_test.sh
```

6. Connect all the boards at the same time, and you're ready to go.

