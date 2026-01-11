import json
import socket
from pathlib import Path
from wakeonlan import send_magic_packet

CONFIG_FILE = Path("lgtv_config.json")

def load_config():
    if not CONFIG_FILE.exists():
        return {}
    with open(CONFIG_FILE, "r") as f:
        return json.load(f)

def turn_on():
    config = load_config()
    mac = config.get("mac")
    ip = config.get("ip")
    
    if not mac:
        print("Error: MAC address not found in config. Please add 'mac' to lgtv_config.json")
        # We don't exit hard here, just return to allow other attempts if we added them? 
        # No, without MAC we can't do anything.
        return
        
    print(f"Sending pulsed WoL packets to {mac} for 30 seconds...")
    print("Addresses: Global (255.255.255.255), Subnet (x.x.x.255), and Unicast")

    import time
    start_time = time.time()
    duration = 30 # Run for 30 seconds
    
    while time.time() - start_time < duration:
        # 1. Standard Global Broadcast
        send_magic_packet(mac, port=9)
        send_magic_packet(mac, port=7)
        
        # 2. Directed / Subnet Broadcasts
        if ip:
            send_magic_packet(mac, ip_address=ip, port=9) # Unicast to IP
            send_magic_packet(mac, ip_address=ip, port=7)
            
            parts = ip.split('.')
            if len(parts) == 4:
                # Assuming /24 mostly, but we can try other common ones if needed
                broadcast_guess = f"{parts[0]}.{parts[1]}.{parts[2]}.255"
                try:
                    send_magic_packet(mac, ip_address=broadcast_guess, port=9)
                    send_magic_packet(mac, ip_address=broadcast_guess, port=7)
                except:
                    pass
        
        time.sleep(1) # Pulse every second
    
    print("WoL Packet pulsing finished.")

if __name__ == "__main__":
    turn_on()
