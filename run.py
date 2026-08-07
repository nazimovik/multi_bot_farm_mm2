import requests
import time
import threading
import subprocess
import psutil

from settings import ACCOUNTS, RAM, RAM_PORT, XENO, PLACE_ID, RAM_PASSWORD

start_time = time.time()


def get_best_servers(place_id, count, max_servers=400):
    servers = []
    cursor = None
    while len(servers) < max_servers:
        url = f"https://games.roblox.com/v1/games/{place_id}/servers/Public"
        params = {
            "limit": 100,
            "excludeFullGames": True,
            "sortOrder": "Asc"  # first empty servers
        }
        if cursor:
            params["cursor"] = cursor
        try:
            resp = requests.get(url, params=params, timeout=10)
            if resp.status_code != 200:
                break
            data = resp.json()
            servers.extend(data.get("data", []))
            cursor = data.get("nextPageCursor")
            if not cursor:
                break
        except Exception as e:
            print(f"Error {e}")
            break

    # only where more than 2 people so if in moment where bot enteries server it will still exist 
    filtered = [s for s in servers if s.get("playing", 0) >= 2]
    
    if not filtered:
        filtered = servers  
    
    sorted_servers = sorted(filtered, key=lambda s: s["playing"])
    
    return sorted_servers[:count]


def launch_account_on_server(account, place_id, job_id):
    """launching accounts through RAM API"""
    url = f"http://localhost:{RAM_PORT}/LaunchAccount"
    params = {
        "Account": account,    # login of account
        "PlaceId": place_id,   # id of mm2 minigame
        "JobId": job_id,       # id of the server of mm2 game
        "Password": RAM_PASSWORD
    }
    try:
        resp = requests.get(url, params=params, timeout=10)
        if resp.status_code in (200, 400):
            if resp.status_code == 400 and "error" in resp.text.lower():
                print(f"Error in launch {account}: {resp.text}")
                return False
            print(f"launched {account} on server {job_id[:8]}...")
            return True
        else:
            print(f"Error {account}: status {resp.status_code}, {resp.text}")
            return False
    except Exception as e:
        print(f"Error with connecting RAM for {account}: {e}")
        return False


def launch_accounts():
    best_servers = get_best_servers(PLACE_ID, len(ACCOUNTS))
    
    if len(best_servers) < len(ACCOUNTS):
        print(f"Founded only {len(best_servers)} servers, needed {len(ACCOUNTS)}. some accounts will be launched on roblox random servers")
    
    for i, acc in enumerate(ACCOUNTS):
        if i < len(best_servers):
            job_id = best_servers[i]["id"]
            players = best_servers[i]["playing"]
            max_players = best_servers[i]["maxPlayers"]
            print(f"{acc} server {job_id[:8]}... ({players}/{max_players} players)")
            launch_account_on_server(acc, PLACE_ID, job_id)
        else:
            print(f" for {acc} no servers found")
            params = {
                "Account": acc,
                "PlaceId": PLACE_ID,
                "Password": RAM_PASSWORD
            }
            try:
                resp = requests.get(f"http://localhost:{RAM_PORT}/LaunchAccount", params=params, timeout=5)
                if resp.status_code in (200, 400):
                    print(f"Launched {acc} (random server)")
                else:
                    print(f"Error {acc}: {resp.status_code}")
            except Exception as e:
                print(f"{acc}: {e}")
        time.sleep(20)  


def kill_roblox():
    for p in psutil.process_iter(['name']):
        if p.info['name'] and 'RobloxPlayerBeta' in p.info['name']:
            p.kill()

def kill_xeno():
    for p in psutil.process_iter(['name']):
        if p.info['name'] and 'xeno' in p.info['name'].lower():
            p.kill()

def start_farm():
    kill_roblox()
    kill_xeno()
    subprocess.Popen([RAM])   # Roblox Acount Manager
    print("opening RAM, enter your seted password (30 seconds)") 
    time.sleep(30)
    subprocess.Popen([XENO])  # open Xeno
    print("Xeno launched")
    time.sleep(20)
    launch_accounts()
    print("Accounts launched")

def show_uptime():
    while True:
        elapsed = time.time() - start_time
        hours = int(elapsed // 3600)
        minutes = int((elapsed % 3600) // 60)
        seconds = int(elapsed % 60)
        print(f"\r⏱ Uptime: {hours:02d}:{minutes:02d}:{seconds:02d}", end="")
        time.sleep(1)

threading.Thread(target=show_uptime, daemon=True).start()

if __name__ == "__main__":
    while True:
        start_farm()
        time.sleep(4000)  
        print("\n################### RESTART ###################\n")