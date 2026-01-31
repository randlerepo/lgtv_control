import asyncio
import json
import socket
import argparse
import sys
import time
import os
from pathlib import Path
from aiowebostv import WebOsClient
from wakeonlan import send_magic_packet

CONFIG_PATHS = [
    Path("/etc/lgtv-control/config.json"),
    Path.home() / ".config" / "lgtv-control" / "config.json",
    Path("lgtv_config.json")
]

def get_config_file(write=False):
    # For writing, prefer the system path if writable or already exists there, otherwise user path
    if write:
        # If running as root/sudo, prefer /etc
        if os.geteuid() == 0:
            return CONFIG_PATHS[0]
        # Otherwise typically user config
        return CONFIG_PATHS[1]
    
    # For reading, check in order
    for path in CONFIG_PATHS:
        if path.exists():
            return path
    # Default return locally if nothing found
    return CONFIG_PATHS[2]

def load_config():
    config_file = get_config_file()
    if not config_file.exists():
        return {}
    with open(config_file, "r") as f:
        return json.load(f)

def save_config(config):
    config_file = get_config_file(write=True)
    
    # Ensure directory exists
    config_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(config_file, "w") as f:
        json.dump(config, f, indent=4)

async def auth(ip):
    print(f"Connecting to {ip}...")
    client = WebOsClient(ip, connect_timeout=10)
    try:
        await client.connect()
        print("Please check your TV to accept the connection...")
        
        # Wait for key to be populated (connect() should handle the handshake)
        # We might need to keep the connection open or check the key.
        # aiowebostv updates client.client_key upon registration.
        
        print("Paired successfully!")
        print(f"Client Key: {client.client_key}")
        
        config = load_config()
        config["ip"] = ip
        # Try to get MAC from device_id, otherwise fallback to existing or empty
        mac = client.tv_info.software.get("device_id")
        config["mac"] = mac if mac else config.get("mac", "")
        config["client_key"] = client.client_key
        save_config(config)
        print(f"Configuration saved to {get_config_file(write=True)}")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        await client.disconnect()

async def turn_off():
    config = load_config()
    if not config.get("ip") or not config.get("client_key"):
        print("Error: Not configured. Run 'auth' command first.")
        sys.exit(1)
        
    client = WebOsClient(config["ip"], client_key=config["client_key"], connect_timeout=10)

    
    await client.connect()
    
    # Check if connected/authenticated essentially
    if not client.is_connected():
         print("Authentication failed or could not connect.")
         return

    print("Sending Power Off command...")
    await client.power_off()
    await client.disconnect()

def turn_on():
    config = load_config()
    mac = config.get("mac")
    ip = config.get("ip")
    
    if not mac:
        print("Error: MAC address not found in config. Please add 'mac' to lgtv_config.json")
        sys.exit(1)
        
    print(f"Sending pulsed WoL packets to {mac} for 30 seconds...")
    print("Addresses: Global (255.255.255.255), Subnet (x.x.x.255), and Unicast")

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

async def main():
    parser = argparse.ArgumentParser(description="LGTV Control")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # Auth command
    auth_parser = subparsers.add_parser("auth", help="Pair with TV")
    auth_parser.add_argument("ip", help="IP address of the TV")
    
    # On command
    subparsers.add_parser("on", help="Turn TV On (WoL)")
    
    # Off command
    subparsers.add_parser("off", help="Turn TV Off")

    # Set MAC command (helper)
    mac_parser = subparsers.add_parser("setmac", help="Set MAC address manaually")
    mac_parser.add_argument("mac", help="MAC address (e.g. AA:BB:CC:DD:EE:FF)")

    args = parser.parse_args()

    if args.command == "auth":
        await auth(args.ip)
    elif args.command == "off":
        await turn_off()
    elif args.command == "on":
        turn_on()
    elif args.command == "setmac":
        config = load_config()
        config["mac"] = args.mac
        save_config(config)
        print(f"MAC address saved: {args.mac}")

if __name__ == "__main__":
    asyncio.run(main())
