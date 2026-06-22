import serial
import keyboard
import time
import threading
import subprocess

PICO_PORT = 'COM4'

print("========================================")
print("   FPGA SMART KEYBOARD INITIALIZATION   ")
print("========================================")
print("1. Microsoft Word (Open manually)")
print("2. Notepad (Auto-Launch)")
print("3. Chrome (Auto-Launch to Search)")
print("========================================")

app_choice = input("Enter 1, 2, or 3: ").strip()
if app_choice not in ['1', '2', '3']: app_choice = '2'

if app_choice == '2':
    print("Launching Notepad...")
    subprocess.Popen(['notepad.exe'])
    time.sleep(1)
elif app_choice == '3':
    print("Launching Chrome...")
    subprocess.Popen(['start', 'chrome'], shell=True)
    time.sleep(1.5)

print(f"\nConnecting to {PICO_PORT}...")
try:
    # FIX 1: Increased timeout from 0.1 to 0.5 so readline() can receive full lines
    ser = serial.Serial(PICO_PORT, 115200, timeout=0.5)
    print("Connected successfully!")
except Exception as e:
    print(f"Failed to connect: {e}")
    exit()

ser.write(b'\x03')  # Ctrl+C to interrupt any running program
time.sleep(0.5)
ser.write(b'\x03')  # Second Ctrl+C for safety
time.sleep(0.5)
ser.write(b'\x05')  # Ctrl+E to enter MicroPython paste mode
time.sleep(0.3)
ser.write(b'try:\r\n')
ser.write(b'    exec(open("code.py").read())\r\n')
ser.write(b'except:\r\n')
ser.write(b'    pass\r\n')
ser.write(b'\x04')  # Ctrl+D to execute the pasted code
time.sleep(2)
ser.reset_input_buffer()

print("\n>>> KEYBOARD ACTIVE - DEBUG MODE ON <<<")
print("Watch this console while you type in Notepad/Chrome!")

current_word = ""
is_correcting = False
lock = threading.Lock()

def correct_word_worker(word_to_check, trigger_key):
    global current_word, is_correcting
    
    print(f"\n[DEBUG] 1. Intercepted: '{word_to_check}'")
    
    try:
        ser.reset_input_buffer()
        # FIX 2: Small delay after clearing buffer to avoid race condition
        time.sleep(0.05)
        # CRITICAL FIX: Added \r\n to ensure the Pico registers the Enter key
        ser.write((word_to_check + '\r\n').encode('utf-8'))
        # FIX 3: Flush to ensure data is sent to Pico immediately
        ser.flush()
    except Exception as e: 
        print(f"[DEBUG] ERROR: Serial write failed - {e}")
        return

    start_time = time.time()
    
    # Increased timeout to 3.0 seconds for safety
    while time.time() - start_time < 3.0:
        try:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            
            if line:
                print(f"[DEBUG] 2. Pico says: '{line}'")
            
            if line.startswith("FPGA Corrected :") or line.startswith(" FPGA Corrected :"):
                echoed_text = line.split(":", 1)[-1].strip()
                print(f"[DEBUG] 3. FPGA Corrected: '{echoed_text}'")
                
                # If the word is different, we must delete and re-type
                if echoed_text and echoed_text.lower() != word_to_check.lower():
                    with lock:
                        is_correcting = True
                        typed_ahead = current_word 
                        
                        print(f"[DEBUG] 4. Triggering Backspaces (Word: '{word_to_check}' -> '{echoed_text}')")
                        
                        if app_choice == '3':
                            keyboard.send('esc')
                            time.sleep(0.05)
                        
                        total_backspaces = len(typed_ahead) + 1 + len(word_to_check)
                        print(f"[DEBUG] 5. Sending {total_backspaces} backspaces...")
                        
                        # Slower backspaces so the app can process each one
                        for _ in range(total_backspaces):
                            keyboard.send('backspace')
                            time.sleep(0.03)
                        
                        time.sleep(0.05)  # Let app finish processing backspaces
                        
                        # Type corrected word with delay between characters
                        keyboard.write(echoed_text, delay=0.03)
                        
                        time.sleep(0.03)
                        if trigger_key == 'space': keyboard.send('space')
                        elif trigger_key == 'enter': keyboard.send('enter')
                        
                        if typed_ahead:
                            time.sleep(0.03)
                            keyboard.write(typed_ahead, delay=0.03)
                        
                        # Wait for all synthetic events to clear the OS queue
                        # before allowing the hook to process new keystrokes
                        time.sleep(0.1)
                        is_correcting = False
                        print("[DEBUG] 6. Typing Complete.")
                else:
                    print("[DEBUG] 4. No correction needed (or FPGA returned identical word).")
                break
        except Exception as e: 
            print(f"[DEBUG] ERROR in read loop: {e}")
            pass
    else:
        print("[DEBUG] ERROR: Timed out! The Pico never responded.")

def on_key_event(event):
    global current_word, is_correcting
    
    if is_correcting: return

    with lock:
        if event.event_type == keyboard.KEY_DOWN:
            if event.name in ['space', 'enter']:
                word_to_check = current_word.strip()
                current_word = "" 
                
                if word_to_check:
                    threading.Thread(target=correct_word_worker, args=(word_to_check, event.name)).start()
            
            elif event.name == 'backspace':
                current_word = current_word[:-1]
            
            elif len(event.name) == 1 and event.name.isprintable():
                current_word += event.name

keyboard.hook(on_key_event)
keyboard.wait()
