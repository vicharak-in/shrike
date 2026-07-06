import serial
import keyboard
import time
import threading
import subprocess
import queue

PICO_PORT = 'COM4'
TIMEOUT = 3.0

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
    ser = serial.Serial(PICO_PORT, 115200, timeout=0.5)
    print("Connected successfully!")
except Exception as e:
    print(f"Failed to connect: {e}")
    exit()

ser.write(b'\x03')  # Ctrl+C
time.sleep(0.5)
ser.write(b'\x03')  # Ctrl+C
time.sleep(0.5)
ser.write(b'\x05')  # Ctrl+E
time.sleep(0.3)
ser.write(b'try:\r\n')
ser.write(b'    exec(open("code.py").read())\r\n')
ser.write(b'except:\r\n')
ser.write(b'    pass\r\n')
ser.write(b'\x04')  # Ctrl+D
time.sleep(2)
ser.reset_input_buffer()

print("\n>>> KEYBOARD ACTIVE - DEBUG MODE ON <<<")
print("Watch this console while you type in Notepad/Chrome!")

# ==========================================
# Robust Buffer-Based State Machine
# ==========================================
buffer_text = ""
pending_queue = queue.Queue()  
state_lock = threading.RLock()
is_correcting = False
current_word = ""

def cancel_all_pending():
    global buffer_text, current_word
    with state_lock:
        buffer_text = ""
        current_word = ""
        # Drain the queue to stop pending corrections
        while not pending_queue.empty():
            try:
                pending_queue.get_nowait()
                pending_queue.task_done()
            except queue.Empty:
                break
    print("[DEBUG] 0. Navigation/Mouse detected. Flushed buffer and cancelled pending corrections.")

import string

def correct_word_worker(word_to_check, trigger_key, original_word_len):
    global buffer_text, is_correcting
    
    if any(char in string.punctuation for char in word_to_check):
        print(f"\n[DEBUG] 1. Intercepted: '{word_to_check}' (Contains punctuation - skipping correction)")
        # Skip Pico entirely, treat as uncorrected so it still chops the buffer
        echoed_text = word_to_check
        
        with state_lock:
            idx = buffer_text.find(echoed_text)
            if idx != -1:
                chop_idx = idx + len(echoed_text)
                buffer_text = buffer_text[chop_idx:]
                print(f"[DEBUG] 6. Buffer chopped. Remaining buffer: '{buffer_text}'")
        return

    print(f"\n[DEBUG] 1. Intercepted: '{word_to_check}'")
    
    try:
        ser.reset_input_buffer()
        time.sleep(0.05)
        ser.write((word_to_check + '\r\n').encode('utf-8'))
        ser.flush()
    except Exception as e: 
        print(f"[DEBUG] ERROR: Serial write failed - {e}")
        return

    start_time = time.time()
    correction_found = False
    echoed_text = ""

    while time.time() - start_time < TIMEOUT:
        try:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            if line:
                print(f"[DEBUG] 2. Pico says: '{line}'")
            
            if line.startswith("FPGA Corrected :") or line.startswith(" FPGA Corrected :") or line.startswith("Corrected :"):
                echoed_text = line.split(":", 1)[-1].strip()
                print(f"[DEBUG] 3. FPGA Corrected: '{echoed_text}'")
                correction_found = True
                break
        except Exception as e: 
            print(f"[DEBUG] ERROR in read loop: {e}")
            break
            
    if not correction_found:
        print("[DEBUG] ERROR: Timed out! The Pico never responded.")
        echoed_text = word_to_check

    with state_lock:
        if word_to_check not in buffer_text:
            print("[DEBUG] 4. Word no longer in buffer. Skipping correction.")
            return

        is_correcting = True

        if echoed_text and echoed_text.lower() != word_to_check.lower():
            idx = buffer_text.find(word_to_check)
            if idx != -1:
                print(f"[DEBUG] 4. Triggering Backspaces (Word: '{word_to_check}' -> '{echoed_text}')")
                
                if app_choice == '3':
                    keyboard.send('esc')
                    time.sleep(0.05)
                
                chars_after = buffer_text[idx + original_word_len:]
                total_backspaces = len(buffer_text) - idx
                
                print(f"[DEBUG] 5. Sending {total_backspaces} backspaces...")
                
                for _ in range(total_backspaces):
                    keyboard.send('backspace')
                
                time.sleep(0.05)  
                
                keyboard.write(echoed_text, delay=0.0)
                if chars_after:
                    keyboard.write(chars_after, delay=0.0)
                
                buffer_text = buffer_text[:idx] + echoed_text + chars_after

        # Commit word and chop buffer to maintain performance
        idx = buffer_text.find(echoed_text)
        if idx != -1:
            chop_idx = idx + len(echoed_text)
            buffer_text = buffer_text[chop_idx:]
            print(f"[DEBUG] 6. Buffer chopped. Remaining buffer: '{buffer_text}'")

        time.sleep(0.05)
        is_correcting = False
        print("[DEBUG] 7. Typing Complete.")

def correction_worker():
    while True:
        word, key, original_len = pending_queue.get()
        correct_word_worker(word, key, original_len)
        pending_queue.task_done()

threading.Thread(target=correction_worker, daemon=True).start()

def on_key_event(event):
    global buffer_text, current_word, is_correcting
    
    if is_correcting: 
        return

    nav_keys = ['up', 'down', 'left', 'right', 'page up', 'page down', 'home', 'end', 'tab', 'esc']
    
    if event.event_type == keyboard.KEY_DOWN:
        if event.name in nav_keys:
            cancel_all_pending()
            return

    with state_lock:
        if event.event_type == keyboard.KEY_DOWN:
            if event.name in ['space', 'enter']:
                word_to_check = current_word.strip()
                current_word = "" 
                
                if event.name == 'space':
                    buffer_text += " "
                    
                if word_to_check:
                    pending_queue.put((word_to_check, event.name, len(word_to_check)))
                
                if event.name == 'enter':
                    cancel_all_pending()
            
            elif event.name == 'backspace':
                if current_word:
                    current_word = current_word[:-1]
                if buffer_text:
                    buffer_text = buffer_text[:-1]
            
            elif len(event.name) == 1 and event.name.isprintable():
                current_word += event.name
                buffer_text += event.name

# Try to hook mouse clicks to cancel pending corrections if user clicks away
try:
    import mouse
    mouse.on_click(lambda: cancel_all_pending() if not is_correcting else None)
except ImportError:
    print("[DEBUG] Note: 'mouse' module not found. Mouse clicks won't cancel pending corrections.")

keyboard.hook(on_key_event)
keyboard.wait()
